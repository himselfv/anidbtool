unit AnidbConnection;

interface
uses SysUtils, DateUtils, WinSock, AnidbConsts;

//Single-threaded usage only!

type
  ESocketError = class(Exception)
  public
    constructor Create(hr: integer); overload;
    constructor Create(hr: integer; op: string); overload;
  end;

const
  INFINITE = cardinal(-1);

const
  ANIDB_REQUEST_PAUSE = 2 * OneSecond + 500 * OneMillisecond;

type
  TUdpConnection = class
  protected
    WsaData: TWsaData;
    FSocket: TSocket;
    FHostAddr: in_addr;
    FPort: word;

    FLocalPort: word;
    function GetLocalPort: word;
    procedure SetLocalPort(Value: word);


 //Speed-up hacks
  protected
   //Used for select()
    fdRead: TFdSet;

    function HostnameToAddr(name: string; out addr: in_addr): boolean;

  private
   //Buffers for reading things out
    buf: pbyte;
    bufsz: integer;
    procedure FreeBuffers;
  protected
    function PendingDataSize: integer;
    procedure FlushInput;

  public
    constructor Create;
    destructor Destroy; override;
    procedure Connect(AHost: string; APort: word);
    procedure Disconnect;
    function Connected: boolean;

    procedure Send(s: string);
    function Recv(out s: string; Timeout: cardinal = INFINITE): boolean;
    function Exchange(inp: string; Timeout: cardinal = INFINITE; RetryCount: integer = 1): string;

    property HostAddr: in_addr read FHostAddr;
    property Port: word read FPort;
    property LocalPort: word read GetLocalPort write SetLocalPort;
  end;


type
  TStringArray=array of string;
  PStringArray=^TStringArray;

  TAnidbResult = record
    code: integer;
    msg: string;
    function ToString: string;
  end;
  PAnidbResult = ^TAnidbResult;

  EAnidbError = class(Exception)
  public
    constructor Create(res: TAnidbResult);
  end;

  TAnidbConnection = class(TUdpConnection)
  protected
    FTimeout: cardinal;

    FClient: string;
    FClientVer: string;
    FProtoVer: string;

    FSessionKey: string;

   //Date and time when last command was issued.
    FLastCommandTime: TDatetime;

    FRetryCount: integer;    

  public
    constructor Create;

    function Exchange(cmd, params: string; var outp: TStringArray): TAnidbResult;
    function SessionExchange(cmd, params: string; var outp: TStringArray): TAnidbResult;

    function Login(AUser: string; APass: string): TAnidbResult;
    procedure Logout;
    function LoggedIn: boolean;

    property Timeout: cardinal read FTimeout write FTimeout;
    property Client: string read FClient write FClient;
    property ClientVer: string read FClientVer write FClientVer;
    property ProtoVer: string read FProtoVer write FProtoVer;

    property RetryCount: integer read FRetryCount write FRetryCount;    

   //Session-related cookies
    property SessionKey: string read FSessionKey write FSessionKey;
    property LastCommandTime: TDatetime read FLastCommandTime write FLastCommandTime;

  public
    function MyListAdd(size: int64; ed2k: string; state: integer;
      viewed: boolean; edit: boolean): TAnidbResult;
  end;

implementation

constructor ESocketError.Create(hr: integer);
begin
  inherited Create('Socket error '+IntToStr(hr));
end;

constructor ESocketError.Create(hr: integer; op: string);
begin
  inherited Create('Socket error '+IntToStr(hr)+' on '+op);
end;

constructor TUdpConnection.Create;
begin
  inherited;
  FSocket := INVALID_SOCKET;
  FLocalPort := 0; //random local port
  buf := nil;
  bufsz := 0;
end;

destructor TUdpConnection.Destroy;
begin
  if Connected then
    Disconnect;
  FreeBuffers;
  inherited;
end;

procedure TUdpConnection.FreeBuffers;
begin
  if Assigned(buf) then
    FreeMem(buf);
  buf := nil;
  bufsz := 0;
end;

function TUdpConnection.HostnameToAddr(name: string; out addr: in_addr): boolean;
var host_ent: PHostEnt;
begin
 //Try to decode host address and port
  addr.S_addr := inet_addr(pchar(name));
  if (FHostAddr.S_addr <> INADDR_NONE) then begin
    Result := true;
    exit;
  end;

 //Else we can just try to use this as host name
  host_ent := gethostbyname(pchar(name));
  if (host_ent = nil) or (host_ent.h_addrtype <> AF_INET) then begin
    Result := false;
    exit;
  end;

  addr.S_addr := pinteger(host_ent^.h_addr^)^;
  Result := true;
end;

procedure TUdpConnection.Connect(AHost: string; APort: word);
var hr: integer;
  addr: sockaddr_in;
begin
 //Initialize WinSock
  hr := WsaStartup($0202, WsaData);
  if (hr <> 0) then
    raise ESocketError.Create(hr, 'WsaStartup');

 //Try to decode host name and addr
  FPort := htons(APort);
  if not HostnameToAddr(AHost, FHostAddr) then begin
    WsaCleanup;
    raise ESocketError.Create('Cannot decode hostname/find host '+AHost+'.');
  end;

 //Create socket
  FSocket := socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (FSocket = INVALID_SOCKET) then begin
    hr := WsaGetLastError;
    WsaCleanup;
    raise ESocketError.Create(hr, 'socket()');
  end;

 //Bind local socket randomly (but to specified port)
  addr.sin_family := AF_INET;
  addr.sin_port := htons(FLocalPort);
  addr.sin_addr.S_addr := 0;
  if (bind(FSocket, addr, SizeOf(addr)) <> 0) then begin
    hr := WsaGetLastError;
    closesocket(FSocket);
    FSocket := INVALID_SOCKET;
    WsaCleanup;
    raise ESocketError.Create(hr, 'local bind()');
  end;

 //Connect socket
  addr.sin_family := AF_INET;
  addr.sin_port := FPort;
  addr.sin_addr := FHostAddr;
  if (WinSock.connect(FSocket, addr, SizeOf(addr)) <> 0) then begin
    hr := WsaGetLastError;
    closesocket(FSocket);
    FSocket := INVALID_SOCKET;
    WsaCleanup;
    raise ESocketError.Create(hr, 'connect()');
  end;

  fdRead.fd_count := 1;
  fdRead.fd_array[0] := FSocket;
end;

procedure TUdpConnection.Disconnect;
begin
 //Purge hacks
  fdRead.fd_count := 0;

 //Close socket (this terminates everything and unbinds it)
  closesocket(FSocket);
  FSocket := INVALID_SOCKET;

 //Deinit WinSock
  WsaCleanup;
end;

function TUdpConnection.Connected: boolean;
begin
  Result := (FSocket <> INVALID_SOCKET);
end;

function TUdpConnection.GetLocalPort: word;
var addr: sockaddr_in;
  addr_sz: integer;
begin
  if not Connected then
    Result := FLocalPort
  else begin
    addr_sz := sizeof(addr);
    if (getsockname(FSocket, addr, addr_sz) <> 0) then
      raise ESocketError.Create(WsaGetLastError, 'getsockname()');
    Result := ntohs(addr.sin_port);
  end;
end;

procedure TUdpConnection.SetLocalPort(Value: word);
begin
 //We can't change active port if we're connected, so we just plan to use new port in the future.
  FLocalPort := Value;
end;

procedure TUdpConnection.Send(s: string);
begin
  if not (WinSock.send(FSocket, s[1], Length(s), 0)=Length(s)) then
    raise ESocketError.Create(WsaGetLastError, 'send()');
end;

function TUdpConnection.Recv(out s: string; Timeout: cardinal): boolean;
var sel: integer;
  tm: Timeval;
  sz: integer;
begin
 //Timeout-wait for data
  fdread.fd_count := 1;
  fdread.fd_array[0] := FSocket; 
  if Timeout <> INFINITE then begin
    tm.tv_sec := Timeout div 1000;
    tm.tv_usec := Timeout mod 1000;
    sel := select(0, @fdRead, nil, nil, @tm);
  end else begin
    sel := select(0, @fdRead, nil, nil, nil);
  end;

  if (sel=SOCKET_ERROR) then
    raise ESocketError.Create(WsaGetLastError, 'select()');

  if (sel<=0) then begin
    s := '';
    Result := false;
    exit;
  end;

 //Retrieve the amount of data available (>= than the size of first packet)
  if(ioctlsocket(FSocket, FIONREAD, sz) <> 0) then
    raise ESocketError.Create(WsaGetLastError, 'ioctlsocket()');

  SetLength(s, sz);
  sz := WinSock.Recv(FSocket, s[1], sz, 0);

  if (sz < 0) then
    raise ESocketError.Create(WsaGetLastError, 'recv()');
  SetLength(s, sz);

  Result := true;
end;


//Returns the size of the data pending in the input buffer. This may differ
//from how much winsock will actually return on recv. See docs for FIONREAD.
function TUdpConnection.PendingDataSize: integer;
begin
  if ioctlsocket(FSocket, FIONREAD, Result) <> 0 then
    raise ESocketError.Create(WsaGetLastError, 'ioctlsocket()');
end;

//Reads out everything in the input buffer. Use to clean up and minimize
//the chances of getting the answer to the previous question.
procedure TUdpConnection.FlushInput;
var sz: integer;
begin
  sz := PendingDataSize;
  while sz > 0 do begin
    if bufsz < sz then begin
      bufsz := sz;
      ReallocMem(buf, bufsz);
    end;

    if WinSock.recv(FSocket, buf^, sz, 0) < 0 then
      raise ESocketError.Create(WsaGetLastError, 'recv()');

    sz := PendingDataSize;
  end;
end;

function TUdpConnection.Exchange(inp: string; Timeout: cardinal; RetryCount: integer): string;
var i: integer;
  done: boolean;
begin
  i := 0;
  repeat
    FlushInput();
    Send(inp);
    done := Recv(Result, Timeout);
    Inc(i);
  until done or (i >= RetryCount);

  if not done then
    raise ESocketError.Create('No answer from server');
end;

function TAnidbResult.ToString: string;
begin
  Result := IntToStr(code) + ' ' + msg;
end;

constructor EAnidbError.Create(res: TAnidbResult);
begin
 //We do not use res.ToString here since we want special treatment.
  inherited Create('Anidb error '+IntToStr(res.code) + ': ' + res.msg);
end;

function SplitStr(s: string; sep: char): TStringArray;
var sepcnt, i: integer;
  last_sep: integer;
begin
 //Count the occurences of char
  sepcnt := 0;
  for i := 1 to Length(s) do
    if s[i]=sep then Inc(sepcnt);

 //Allocate memory
  SetLength(Result, sepcnt+1);

 //Parse string;
  last_sep := 0;
  sepcnt := 0;
  for i := 1 to Length(s) do
    if s[i]=sep then begin
      SetLength(Result[sepcnt], i-last_sep-1);
      Move(s[last_sep+1], Result[sepcnt][1], i-last_sep-1);
      last_sep := i;
      Inc(sepcnt);
    end;

 //Last block
  SetLength(Result[sepcnt], Length(s)-last_sep);
  Move(s[last_sep+1], Result[sepcnt][1], Length(s)-last_sep);
end;

constructor TAnidbConnection.Create;
begin
  inherited;
  FLastCommandTime := 0;
end;

function TAnidbConnection.Exchange(cmd, params: string; var outp: TStringArray): TAnidbResult;
var str: string;
  i: integer;
begin
  while now - LastCommandTime < ANIDB_REQUEST_PAUSE do
    Sleep( Trunc(MilliSecondSpan(now, LastCommandTime + ANIDB_REQUEST_PAUSE)) );

  str := inherited Exchange(cmd + ' ' + params, Timeout, RetryCount);

  LastCommandTime := now;  

 //Split result string;
  outp := SplitStr(str, #10);
  if Length(outp) <= 0 then
    raise ESocketError.Create('Illegal answer from server');

  str := outp[0];
 //At least code should be there
  if (Length(str) < 3)
  or not TryStrToInt(str[1] + str[2] + str[3], Result.code) then
    raise ESocketError.Create('Illegal answer from server');

  if (Result.Code=LOGIN_ACCEPTED)
  or (Result.Code=LOGIN_ACCEPTED_NEW_VER) then begin
   //Test if the code is there (at least one byte of it)
    if (Length(str) < 5) or (str[4] <> ' ') then
    raise ESocketError.Create('Illegal LOGIN_ACCEPTED answer from server');

   //Retrieve new session id
    FSessionKey := '';
    i := 5;
    while (i <= Length(str)) and (str[i] <> ' ') do begin
      FSessionKey := FSessionKey + str[i];
      Inc(i);
    end;

   //The remainder is the message
    if (i <= Length(str)) then
     //str[i] is the separator
      Result.msg := pchar(@str[i+1])
    else
      Result.msg := '';

  end else
   //Default mode: everything to the right is message
    if Length(str) > 4 then
      Result.msg := pchar(@str[5])
    else
      Result.msg := '';
end;

function TAnidbConnection.SessionExchange(cmd, params: string; var outp: TStringArray): TAnidbResult;
begin
  if params <> '' then
    params := params + '&s='+FSessionKey
  else
    params := 's='+FSessionKey;
  Result := Exchange(cmd, params, outp);
end;

function TAnidbConnection.Login(AUser: string; APass: string): TAnidbResult;
var ans: TStringArray;
begin
  Result := Exchange('AUTH',
    'user='+AUser+'&'+
    'pass='+APass+'&'+
    'protover='+ProtoVer+'&'+
    'client='+Client+'&'+
    'clientver='+ClientVer,
    ans);

  if (Result.code <> LOGIN_ACCEPTED)
  and (Result.code <> LOGIN_ACCEPTED_NEW_VER) then
    raise EAnidbError.Create(Result);
end;

procedure TAnidbConnection.Logout;
var ans: TStringArray;
  res: TAnidbResult;
begin
  res := SessionExchange('LOGOUT', '', ans);

  if (res.code <> LOGGED_OUT) then
    raise EAnidbError.Create(res);
  FSessionKey := '';
end;

function TAnidbConnection.LoggedIn: boolean;
begin
  Result := (FSessionKey <> '');
end;


function AnidbBool(value: boolean): string; inline;
begin
  if value then
    Result := '1'
  else
    Result := '0';
end;

function TAnidbConnection.MyListAdd(size: int64; ed2k: string; state: integer;
  viewed: boolean; edit: boolean): TAnidbResult;
var ans: TStringArray;
begin
  Result := SessionExchange('MYLISTADD',
    'size='+IntToStr(size)+'&'+
    'ed2k='+ed2k+'&'+
    'state='+IntToStr(state)+'&'+
    'viewed='+AnidbBool(viewed)+'&'+
    'edit='+AnidbBool(edit),
    ans);
end;

end.
