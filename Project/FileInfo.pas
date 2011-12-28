unit FileInfo;

interface
uses SysUtils, Classes, Windows, MD4, AnidbConsts;

type
  TFileInfo = record
    size: int64;
    ed2k: MD4Digest;
    lead: MD4Digest;
    StateSet: boolean; //the file have been added to Anidb at least once
    State: TAnidbFileState; //information that Anidb has about the file
      //some fields might be missing
  end;
  PFileInfo = ^TFileInfo;


 //Multithread unsafe
  TFileDb = class(TObject)
  protected
    FFilename: string;
    FFiles: array of PFileInfo;
    FLoaded: boolean;
    FChanged: boolean;

  public
    constructor Create(AFilename: string);
    destructor Destroy; override;
    function AddNew: PFileInfo;
    function FindByEd2k(ed2k: MD4Digest): PFileInfo;
    function FindByLead(lead: MD4Digest): PFileInfo;

  private
   //This implementation is subject to change, so I leave these protected.
   //In future versions I might change to not loading the file, but only indices,
   //and then looking in the contents directly.
    procedure Clear;
    procedure LoadFromStream(s: TStream);
    procedure SaveToStream(s: TStream);
    procedure LoadFromFile(Filename: string);
    procedure SaveToFile(Filename: string);

  public
    procedure Touch; //call to force loading db right now
    procedure Changed; //call to instruct FileDb to save changes later
  end;

  TStreamExtender = class helper for TStream
    function ReadInt: integer; inline;
    procedure WriteInt(i: integer); inline;
  end;

implementation

function TStreamExtender.ReadInt: integer;
begin
  ReadBuffer(Result, SizeOf(Result));
end;

procedure TStreamExtender.WriteInt(i: integer);
begin
  WriteBuffer(i, SizeOf(i));
end;

constructor TFileDb.Create(AFilename: string);
begin
  inherited Create;
  FFilename := AFilename;
  FLoaded := false;
end;

destructor TFileDb.Destroy;
begin
 //Save data if needed
  if FLoaded and FChanged then
    SaveToFile(FFilename);

 //Free memory
  Clear;
  inherited;
end;

function TFileDb.AddNew: PFileInfo;
begin
  Touch;

  New(Result);
  ZeroMemory(Result, SizeOf(Result^));
  SetLength(FFiles, Length(FFiles)+1);
  FFiles[Length(FFiles)-1] := Result;

  Changed;
end;

function TFileDb.FindByEd2k(ed2k: MD4Digest): PFileInfo;
var i: integer;
begin
  Touch;

  Result := nil;
  for i := 0 to Length(FFiles) - 1 do
    if SameMd4(FFiles[i].ed2k, ed2k) then begin
      Result := FFiles[i];
      exit;
    end;
end;

function TFileDb.FindByLead(lead: MD4Digest): PFileInfo;
var i: integer;
begin
  Touch;

  Result := nil;
  for i := 0 to Length(FFiles) - 1 do
    if SameMd4(FFiles[i].lead, lead) then begin
      Result := FFiles[i];
      exit;
    end;
end;

//Clears data and releases all the memory.
procedure TFileDb.Clear;
var i: integer;
begin
  for i := Length(FFiles) - 1 downto 0 do
    if FFiles[i] <> nil then begin
      Dispose(FFiles[i]);
      FFiles[i] := nil;
    end;
  SetLength(FFiles, 0);
end;

procedure TFileDb.LoadFromStream(s: TStream);
var i: integer;
begin
  SetLength(FFiles, s.ReadInt);
  for i := 0 to Length(FFiles) - 1 do
    FFiles[i] := nil;

  try
    for i := 0 to Length(FFiles) - 1 do begin
      New(FFiles[i]);
      s.ReadBuffer(FFiles[i]^, SizeOf(FFiles[i]^));
    end;
  except
    Clear; //to not leave inconsistent array 
  end;
end;

procedure TFileDb.SaveToStream(s: TStream);
var i: integer;
begin
  s.WriteInt(Length(FFiles));
  for i := 0 to Length(FFiles) - 1 do
    s.WriteBuffer(FFiles[i]^, SizeOf(FFiles[i]^));
end;

procedure TFileDb.LoadFromFile(Filename: string);
var f: TFileStream;
begin
  f := TFileStream.Create(Filename, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(f);
  finally
    FreeAndNil(f);
  end;
end;

procedure TFileDb.SaveToFile(Filename: string);
var f: TFileStream;
begin
  f := TFileStream.Create(Filename, fmCreate);
  try
    SaveToStream(f);
  finally
    FreeAndNil(f);
  end;
end;

procedure TFileDb.Touch;
begin
  if not FLoaded then begin
    if FileExists(FFilename) then
      LoadFromFile(FFilename);
    FLoaded := true;
  end;
end;

procedure TFileDb.Changed;
begin
  FChanged := true;
end;

end.
