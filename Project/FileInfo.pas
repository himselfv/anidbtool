unit FileInfo;

interface
uses SysUtils, Classes, Windows, MD4, AnidbConsts;

//If set, FileDB will be saved to disk every time a change is made.
//Otherwise it'll be only flushed on exit.
{$DEFINE UPDATEDBOFTEN}

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
    procedure Save; //to save DB at a critical points
    procedure Changed; //call every time you make a change
  end;

  TStreamExtender = class helper for TStream
    function ReadInt: integer; inline;
    procedure WriteInt(i: integer); inline;
    function ReadString: string; inline;
    procedure WriteString(s: string); inline;
    function ReadBool: boolean; inline;
    procedure WriteBool(b: boolean); inline;
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

function TStreamExtender.ReadString: string;
begin
  SetLength(Result, ReadInt);
  ReadBuffer(Result[1], Length(Result)*SizeOf(Result[1]));
end;

procedure TStreamExtender.WriteString(s: string);
begin
  if Length(s)<=0 then
    WriteInt(0)
  else
    WriteInt(Length(s));
  WriteBuffer(s[1], Length(s)*SizeOf(s[1]));
end;

function TStreamExtender.ReadBool: boolean;
begin
  Result := boolean(ReadInt);
end;

procedure TStreamExtender.WriteBool(b: boolean);
begin
  WriteInt(integer(b));
end;

constructor TFileDb.Create(AFilename: string);
begin
  inherited Create;
  FFilename := AFilename;
  FLoaded := false;
end;

destructor TFileDb.Destroy;
begin
  Save; //Even when UpdatingDBOften, no harm in checking FChanged again

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

 //Don't call Changed() just now because the data's still not set.
 //Clients must call Changed() after populating new record with (maybe default) info.
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
  Clear;
  SetLength(FFiles, s.ReadInt);
  for i := 0 to Length(FFiles) - 1 do
    FFiles[i] := nil;

  try
    for i := 0 to Length(FFiles) - 1 do begin
      New(FFiles[i]);
      s.ReadBuffer(FFiles[i]^, integer(@FFiles[i]^.State) - integer(@FFiles[i]^));
      s.ReadBuffer(FFiles[i]^.State, integer(@FFiles[i]^.State.Source) - integer(@FFiles[i]^.State));
     { Остаток - строки }
      FFiles[i].State.Source := s.ReadString;
      FFiles[i].State.Source_set := s.ReadBool;
      FFiles[i].State.Storage := s.ReadString;
      FFiles[i].State.Storage_set := s.ReadBool;
      FFiles[i].State.Other := s.ReadString;
      FFiles[i].State.Other_set := s.ReadBool;
    end;
  except
    Clear; //to not leave inconsistent array
  end;
end;

procedure TFileDb.SaveToStream(s: TStream);
var i: integer;
begin
  s.WriteInt(Length(FFiles));
  for i := 0 to Length(FFiles) - 1 do begin
    s.WriteBuffer(FFiles[i]^, integer(@FFiles[i]^.State) - integer(@FFiles[i]^));
    s.WriteBuffer(FFiles[i]^.State, integer(@FFiles[i]^.State.Source) - integer(@FFiles[i]^.State));
   { Остаток - строки }
    s.WriteString(FFiles[i].State.Source);
    s.WriteBool(FFiles[i].State.Source_set);
    s.WriteString(FFiles[i].State.Storage);
    s.WriteBool(FFiles[i].State.Storage_set);
    s.WriteString(FFiles[i].State.Other);
    s.WriteBool(FFiles[i].State.Other_set);
  end;
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

procedure TFileDb.Save;
begin
 //Save data if needed
  if FLoaded and FChanged then
    SaveToFile(FFilename);
  FChanged := false;
end;

procedure TFileDb.Changed;
begin
 {$IFDEF UPDATEDBOFTEN}
  FChanged := true;
  Save; //Right now
 {$ELSE}
  FChanged := true; //Will save at a later time
 {$ENDIF}
end;

end.
