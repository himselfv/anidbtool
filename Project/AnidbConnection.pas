unit AnidbConnection;
//Single-threaded usage only!

interface
uses SysUtils, DateUtils, WinSock, Windows, AnidbConsts, StrUtils, UniStrUtils;

//Use UTF8 instead of ANSI+HTML_encoding
{$DEFINE ENC_UTF8}

type
{$IFDEF ENC_UTF8}
  RawString = UnicodeString; //convert to UTF8 at the latest moment
  RawChar = WideChar;
{$ELSE}
  RawString = AnsiString;
  RawChar = AnsiChar;
{$ENDIF}
  PRawChar = ^RawChar;

type
  ESocketError = class(Exception)
  public
    constructor Create(hr: integer); overload;
    constructor Create(hr: integer; op: string); overload;
  end;

  ENoAnswerFromServer = class(Exception);

 //Exceptions of this kind stop the execution no matter what.
  ECritical = class(Exception);

const
  INFINITE = cardinal(-1);

  ANIDB_REQUEST_PAUSE: TDatetime = 2 * OneSecond + 500 * OneMillisecond;
  ANIDB_BUSY_PAUSE: cardinal = 5000; //milliseconds

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
    function HostnameToAddr(name: AnsiString; out addr: in_addr): boolean;

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
    procedure Connect(AHost: AnsiString; APort: word);
    procedure Disconnect;
    function Connected: boolean;

    procedure Send(s: RawString);
    function Recv(out s: RawString; Timeout: cardinal = INFINITE): boolean;
    function Exchange(inp: RawString; Timeout: cardinal = INFINITE; RetryCount: integer = 1): RawString;

    property HostAddr: in_addr read FHostAddr;
    property Port: word read FPort;
    property LocalPort: word read GetLocalPort write SetLocalPort;
  end;


type
  TRawStringArray=array of RawString;
  PRawStringArray=^TRawStringArray;

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

  TAnidbMylistStats = record
    cAnimes: integer;
    cEps: integer;
    cFiles: integer;
    cSizeOfFiles: integer;
    cAddedAnimes: integer;
    cAddedEps: integer;
    cAddedFiles: integer;
    cAddedGroups: integer;
    pcLeech: integer;
    pcGlory: integer;
    pcViewedOfDb: integer;
    pcMylistOfDb: integer;
    pcViewedOfMylist: integer;
    cViewedEps: integer;
    cVotes: integer;
    cReviews: integer;
  end;
  PAnidbMylistStats = ^TAnidbMylistStats;


  TAnidbConnection = class;
  TShortTimeoutEvent = procedure(Sender: TAnidbConnection; Time: cardinal) of object;
  TServerBusyEvent = procedure(Sender: TAnidbConnection; WaitTime: cardinal) of object;
  TNoAnswerEvent = procedure(Sender: TAnidbConnection; WaitTime: cardinal) of object;
  TAnidbConnection = class(TUdpConnection)
  protected
    FTimeout: cardinal;
    FRetryCount: integer;    

    FSessionKey: AnsiString;

   //Date and time when last command was issued.
    FLastCommandTime: TDatetime;

    FOnShortTimeout: TShortTimeoutEvent;
    FOnServerBusy: TServerBusyEvent;
    FOnNoAnswer: TNoAnswerEvent;
    function Exchange_int(cmd, params: RawString; var outp: TRawStringArray): TAnidbResult;
  public
    constructor Create;

    function Exchange(cmd, params: RawString; var outp: TRawStringArray): TAnidbResult;
    function SessionExchange(cmd, params: RawString; var outp: TRawStringArray): TAnidbResult;

    property Timeout: cardinal read FTimeout write FTimeout;
    property RetryCount: integer read FRetryCount write FRetryCount;

   //Session-related cookies
    property SessionKey: AnsiString read FSessionKey write FSessionKey;
    property LastCommandTime: TDatetime read FLastCommandTime write FLastCommandTime;

    property OnShortTimeout: TShortTimeoutEvent read FOnShortTimeout write FOnShortTimeout;
    property OnServerBusy: TServerBusyEvent read FOnServerBusy write FOnServerBusy;
    property OnNoAnswer: TNoAnswerEvent read FOnNoAnswer write FOnNoAnswer;

  protected //Login
    FClient: AnsiString;
    FClientVer: AnsiString;
    FProtoVer: AnsiString;
  public
    function Login(AUser: AnsiString; APass: AnsiString): TAnidbResult;
    procedure Logout;
    function LoggedIn: boolean;

    property Client: AnsiString read FClient write FClient;
    property ClientVer: AnsiString read FClientVer write FClientVer;
    property ProtoVer: AnsiString read FProtoVer write FProtoVer;

  public //Commands
    function MyListAdd(size: int64; ed2k: AnsiString; state: TAnidbFileState; edit: boolean): TAnidbResult;
    function MyListStats(out Stats: TAnidbMylistStats): TAnidbResult;
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

function TUdpConnection.HostnameToAddr(name: AnsiString; out addr: in_addr): boolean;
var host_ent: PHostEnt;
begin
 //Try to decode host address and port
  addr.S_addr := inet_addr(PAnsiChar(name));
  if (FHostAddr.S_addr <> integer(INADDR_NONE)) then begin
    Result := true;
    exit;
  end;

 //Else we can just try to use this as host name
  host_ent := gethostbyname(PAnsiChar(name));
  if (host_ent = nil) or (host_ent.h_addrtype <> AF_INET) then begin
    Result := false;
    exit;
  end;

  addr.S_addr := pinteger(host_ent^.h_addr^)^;
  Result := true;
end;

procedure TUdpConnection.Connect(AHost: AnsiString; APort: word);
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
    raise ESocketError.Create('Cannot decode hostname/find host '+string(AHost)+'.');
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

procedure TUdpConnection.Send(s: RawString);
{$IFDEF ENC_UTF8}
var u: UTF8String;
{$ENDIF}
begin
{$IFDEF ENC_UTF8}
  u := UTF8String(s);
  if not (WinSock.send(FSocket, u[1], Length(u), 0)=Length(u)) then
{$ELSE}
  if not (WinSock.send(FSocket, s[1], Length(s), 0)=Length(s)) then
{$ENDIF}
    raise ESocketError.Create(WsaGetLastError, 'send()');
end;

function TUdpConnection.Recv(out s: RawString; Timeout: cardinal): boolean;
var sel: integer;
  tm: Timeval;
  sz: integer;
{$IFDEF ENC_UTF8}
  u: UTF8String;
{$ENDIF}
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

 {$IFDEF ENC_UTF8}
  SetLength(u, sz);
  sz := WinSock.Recv(FSocket, u[1], sz, 0);
 {$ELSE}
  SetLength(s, sz);
  sz := WinSock.Recv(FSocket, s[1], sz, 0);
 {$ENDIF}

  if sz < 0 then
    raise ESocketError.Create(WsaGetLastError, 'recv()');
 {$IFDEF ENC_UTF8}
  SetLength(u, sz);
  s := string(u);
 {$ELSE}
  SetLength(s, sz);
 {$ENDIF}

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

function TUdpConnection.Exchange(inp: RawString; Timeout: cardinal; RetryCount: integer): RawString;
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
    raise ENoAnswerFromServer.Create('No answer from server');
end;

////////////////////////////////////////////////////////////////////////////////

function TAnidbResult.ToString: string;
begin
  Result := IntToStr(code) + ' ' + string(msg);
end;

constructor EAnidbError.Create(res: TAnidbResult);
begin
 //We do not use res.ToString here since we want special treatment.
  inherited Create('Anidb error '+IntToStr(res.code) + ': ' + string(res.msg));
end;

function SplitStr(s: RawString; sep: RawChar): TRawStringArray;
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
      Move(s[last_sep+1], Result[sepcnt][1], (i-last_sep-1)*sizeof(s[1]));
      last_sep := i;
      Inc(sepcnt);
    end;

 //Last block
  SetLength(Result[sepcnt], Length(s)-last_sep);
  Move(s[last_sep+1], Result[sepcnt][1], (Length(s)-last_sep)*sizeof(s[last_sep+1]));
end;

constructor TAnidbConnection.Create;
begin
  inherited;
  FLastCommandTime := 0;
end;

function TAnidbConnection.Exchange_int(cmd, params: RawString; var outp: TRawStringArray): TAnidbResult;
var str: RawString;
  tm: cardinal;
  i: integer;
begin
  while now - LastCommandTime < ANIDB_REQUEST_PAUSE do begin
   //If not yet allowed to send, sleep the remaining time
    tm := Trunc(MilliSecondSpan(now, LastCommandTime + ANIDB_REQUEST_PAUSE));
    if Assigned(FOnShortTimeout) then FOnShortTimeout(Self, tm);
    Sleep(tm);
  end;

  str := inherited Exchange(cmd + ' ' + params, Timeout, 1); //make one try

  LastCommandTime := now;  

 //Split result string;
  outp := SplitStr(str, #10);
  if Length(outp) <= 0 then
    raise ESocketError.Create('Illegal answer from server');

  str := outp[0];
 //At least the code should be there
  if (Length(str) < 3)
  or not TryStrToInt(string(str[1] + str[2] + str[3]), Result.code) then
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
      FSessionKey := FSessionKey + AnsiChar(str[i]);
      Inc(i);
    end;

   //The remainder is the message
    if (i <= Length(str)) then
     //str[i] is the separator
      Result.msg := string(PRawChar(@str[i+1]))
    else
      Result.msg := '';

  end else
   //Default mode: everything to the right is message
    if Length(str) > 4 then
      Result.msg := string(PRawChar(@str[5]))
    else
      Result.msg := '';
end;

//Automatically retries on SERVER_BUSY or on no answer.
function TAnidbConnection.Exchange(cmd, params: RawString; var outp: TRawStringArray): TAnidbResult;
var retries_left: integer;
  wait_interval: integer;
begin
  retries_left := RetryCount;
  wait_interval := ANIDB_BUSY_PAUSE;

  while retries_left > 0 do try
    Result := Exchange_int(cmd, params, outp);

   //Out of service
    if Result.Code = ANIDB_OUT_OF_SERVICE then
      raise ECritical.Create('AniDB is out of service - try again no earlier than 30 minutes later.');

    if (Result.Code = ILLEGAL_INPUT_OR_ACCESS_DENIED)
    or (Result.Code = ACCESS_DENIED)
    or (Result.Code = UNKNOWN_COMMAND)
    or (Result.Code = INTERNAL_SERVER_ERROR) then
      raise ECritical.Create('AniDB error '+Result.ToString+'. Unrecoverable.');

    if (Result.Code = BANNED) then
      raise ECritical.Create('You were banned from anidb. Investigate the case before retrying.');

   //Other results
    if Result.code <> SERVER_BUSY then exit;

   //Busy
    Dec(retries_left);
    if retries_left > 0 then begin
      if Assigned(FOnServerBusy) then FOnServerBusy(Self, wait_interval);
      Sleep(wait_interval);
      Inc(wait_interval, ANIDB_BUSY_PAUSE);
    end;
  except
   //No answer
    on ENoAnswerFromServer do begin
      Dec(retries_left);
      if retries_left > 0 then begin
        if Assigned(FOnNoAnswer) then FOnNoAnswer(Self, wait_interval);
        Sleep(wait_interval);
        Inc(wait_interval, ANIDB_BUSY_PAUSE);
      end;
    end;
  end;

  raise ECritical.Create('Anidb server is not accessible. Impossible to continue.');
end;

function TAnidbConnection.SessionExchange(cmd, params: RawString; var outp: TRawStringArray): TAnidbResult;
begin
  if params <> '' then
    params := params + '&s=' + RawString(FSessionKey)
  else
    params := 's='+RawString(FSessionKey);
  Result := Exchange(cmd, params, outp);
end;

function TAnidbConnection.Login(AUser: AnsiString; APass: AnsiString): TAnidbResult;
var ans: TRawStringArray;
begin
  Result := Exchange('AUTH',
    'user='+RawString(AUser)+'&'+
    'pass='+RawString(APass)+'&'+
    'protover='+RawString(ProtoVer)+'&'+
   {$IFDEF ENC_UTF8}
    'enc=utf8&'+
   {$ENDIF}
    'client='+RawString(Client)+'&'+
    'clientver='+RawString(ClientVer),
    ans);

  if (Result.code <> LOGIN_ACCEPTED)
  and (Result.code <> LOGIN_ACCEPTED_NEW_VER) then
    raise EAnidbError.Create(Result);
end;

procedure TAnidbConnection.Logout;
var ans: TRawStringArray;
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

//Boolean in andb
function AnidbBool(value: boolean): RawString; inline;
begin
  if value then
    Result := '1'
  else
    Result := '0';
end;

const
  // Sets UnixStartDate to TDateTime of 01/01/1970
  UnixStartDate: TDateTime = 25569.0;

function DateTimeToUnix(ConvDate: TDateTime): Longint;
begin
  Result := Round((ConvDate - UnixStartDate) * 86400);
end;

function UnixToDateTime(USec: Longint): TDateTime;
begin
  Result := (Usec / 86400) + UnixStartDate;
end;

//Datetime in anidb: string representation of integer
function AnidbDatetime(dt: TDatetime): RawString;
begin
  Result := RawString(IntToStr(DatetimeToUnix(dt)));
end;

function RawReplaceStr(const AText, AFromText, AToText: RawString): RawString; inline;
begin
{$IFDEF ENC_UTF8}
  Result := UniReplaceStr(AText, AFromText, AToText);
{$ELSE}
  Result := AnsiReplaceStr(AText, AFromText, AToText);
{$ENDIF}
end;

type
  TAnidbStringOption = (
  	asoNoNewlines //remove all newlines instead of replacing them with "<br />"
  );
  TAnidbStringOptions = set of TAnidbStringOption;

//Strings in anidb: html encoded
function AnidbString(s: string; opt: TAnidbStringOptions=[]): RawString;
var r: RawString;
begin
 {
  Anidb uses some kind of a strange encoding scheme.
  They declare it as "form encoding scheme" and &param=value+value would
  have been logical but it doesn't work. Neither does value%20value.
  &amp; works but other %#321; codes don't.

  Newlines are replaced with <br />s per documentation, but not allowed
  in some cases.
 }

 //First we either escape HTML tags or HTML tags+all non-unicode chars,
 //depending on encoding scheme used
 {$IFDEF ENC_UTF8}
  r := HtmlEscape(s);
 {$ELSE}
  r := HtmlEscapeToAnsi(s);
 {$ENDIF}

 //Next we escape Anidb-specific stuff
  { Slow, can be made faster }
  if asoNoNewlines in opt then begin
    r := RawReplaceStr(r, #13, '');
    r := RawReplaceStr(r, #10, '');
  end else begin
    r := RawReplaceStr(r, #13#10, '<br />');
    r := RawReplaceStr(r, #13, '<br />');
    r := RawReplaceStr(r, #10, '<br />');
  end;

  Result := r;
end;


function TAnidbConnection.MyListAdd(size: int64; ed2k: AnsiString;
  state: TAnidbFileState; edit: boolean): TAnidbResult;
var ans: TRawStringArray;
  s: RawString;
begin
  s := 'size='+RawString(IntToStr(size))+'&ed2k='+RawString(ed2k)+'&edit='+AnidbBool(edit);

  if state.State_set then
    s := s + '&state='+RawString(IntToStr(state.State));
  if state.Viewed_set then
    s := s + '&viewed='+AnidbBool(state.Viewed);
  if state.ViewDate_set then
    s := s + '&viewdate='+AnidbDatetime(state.ViewDate);
  if state.Source_set then
    s := s + '&source='+AnidbString(state.Source);
  if state.Storage_set then
    s := s + '&storage='+AnidbString(state.Storage);
  if state.Other_set then
    s := s + '&other='+AnidbString(state.Other);

  Result := SessionExchange('MYLISTADD', s, ans);
end;

function TAnidbConnection.MyListStats(out Stats: TAnidbMylistStats): TAnidbResult;
var ans: TRawStringArray;
  vals: TStringArray;
begin
  Result := SessionExchange('MYLISTSTATS', '', ans);
  if Result.code = MYLIST_STATS then begin
   //The answer should have at least one string
    if Length(ans) < 2 then
      raise Exception.Create('Illegal answer from server: no data.');

    ZeroMemory(@Stats, SizeOf(Stats));
    vals := SepSplit(string(ans[1]), '|');
    if (Length(vals) < 16)
    or not TryStrToInt(vals[00], Stats.cAnimes)
    or not TryStrToInt(vals[01], Stats.cEps)
    or not TryStrToInt(vals[02], Stats.cFiles)
    or not TryStrToInt(vals[03], Stats.cSizeOfFiles)
    or not TryStrToInt(vals[04], Stats.cAddedAnimes)
    or not TryStrToInt(vals[05], Stats.cAddedEps)
    or not TryStrToInt(vals[06], Stats.cAddedFiles)
    or not TryStrToInt(vals[07], Stats.cAddedGroups)
    or not TryStrToInt(vals[08], Stats.pcLeech)
    or not TryStrToInt(vals[09], Stats.pcGlory)
    or not TryStrToInt(vals[10], Stats.pcViewedOfDb)
    or not TryStrToInt(vals[11], Stats.pcMylistOfDb)
    or not TryStrToInt(vals[12], Stats.pcViewedOfMylist)
    or not TryStrToInt(vals[13], Stats.cViewedEps)
    or not TryStrToInt(vals[14], Stats.cVotes)
    or not TryStrToInt(vals[15], Stats.cReviews)
    then
      raise Exception.Create('Invalid answer format.');
  end;
end;

end.

