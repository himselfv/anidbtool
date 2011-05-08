unit SessionLock;
{ Contains session information/lock functions }

interface
uses SysUtils, Classes, Windows, UniStrUtils;

type
  TSessionLock = class(TStringList)
  protected
    hFile: THandle;
    procedure Load;
  public
    constructor Create(LockFile: UniString);
    destructor Destroy;
    procedure Save;
  end;

implementation

constructor TSessionLock.Create(LockFile: UniString);
begin
  inherited Create;
  hFile := CreateFileW(PWideChar(LockFile),
    GENERIC_READ or GENERIC_WRITE,
    0, {exclusive access}
    nil, 0, OPEN_ALWAYS, 0);
  if hFile=INVALID_HANDLE_VALUE then
    RaiseLastOsError();
  Load;
end;

destructor TSessionLock.Destroy;
begin
  if hFile<>INVALID_HANDLE_VALUE then
    CloseHandle(hFile);
  inherited;
end;

procedure TSessionLock.Load;
var hs: THandleStream;
begin
  hs := THandleStream.Create(hFile);
  try
    hs.Seek(0, soBeginning);
    LoadFromStream(hs);
  finally
    FreeAndNil(hs);
  end;
end;

procedure TSessionLock.Save;
var hs: THandleStream;
begin
  hs := THandleStream.Create(hFile);
  try
    hs.Seek(0, soBeginning);
    SaveToStream(hs);
  finally
    FreeAndNil(hs);
  end;
  SetEndOfFile(hFile); {just in case}
end;

end.
