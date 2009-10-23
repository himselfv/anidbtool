program anidb;

{$APPTYPE CONSOLE}

uses
  SysUtils, Classes, Windows,
  AnidbConnection in 'AnidbConnection.pas',
  AnidbConsts in 'AnidbConsts.pas',
  md4 in '..\..\#Units\Crypt\Hashes\md4.pas',
  ed2k in '..\..\#Units\Crypt\Hashes\ed2k.pas',
  FileInfo in 'FileInfo.pas';

function Md4ToString(md4: MD4Digest): string;
var i: integer;
begin
  Result := '';
  for i := 0 to Length(md4) - 1 do
    Result := Result + IntToHex(md4[i], 2);
end;

procedure ShowUsage;
begin
  writeln('Usage: '+paramstr(0) + ' <command> <params>');
  writeln('Commands: ');
  writeln('  hash <filename> [/s]');
  writeln('  mylistadd <filename> [/s] [/state <state>] [/watched] [/edit] [/noerrors]');
  writeln('');
  writeln('Where:');
  writeln('  <filename> is file name, mask or directory name');
  writeln('  /s iterates subdirectories');
  writeln('  /state <state> sets file state (unknown/hdd/cd/deleted)');
  writeln('  /watched marks file as watched');
  writeln('  /edit forces edit mode');
  writeln('  /noerrors allows to skip errors and continue adding files');    
end;

var
  Config: TStringList;
  SessionInfo: TStringList;
{$IFDEF DEBUG}
  HashList: TStringList;
{$ENDIF}

  ConfigFilename: string;
  SessionFilename: string;
{$IFDEF DEBUG}
  HashlistFilename: string;
{$ENDIF}

  AnidbServer: TAnidbConnection;

procedure App_Init;
var FPort: integer;
  FTimeout: integer;
  FLastCommandTime: TDatetime;
  FSessionPort: integer;
  FRetryCount: integer;
begin
  ConfigFilename := ChangeFileExt(paramstr(0), '.cfg');
  SessionFilename := ExtractFilePath(paramstr(0)) + 'session.cfg';
{$IFDEF DEBUG}
  HashlistFilename := ExtractFilePath(paramstr(0)) + 'hash.lst';
{$ENDIF}

  if not FileExists(ConfigFilename) then
    raise Exception.Create('Configuration file not found');

  Config := TStringList.Create();
  Config.LoadFromFile(ConfigFilename);

  SessionInfo := TStringList.Create();
  if FileExists(SessionFilename) then
    SessionInfo.LoadFromFile(SessionFilename);

  if not TryStrToInt(Config.Values['Port'], FPort) then
    raise Exception.Create('Incorrect "Port" value set in config.');

  if not TryStrToInt(Config.Values['Timeout'], FTimeout) then
    raise Exception.Create('Incorrect "Timeout" value set in config.');

  if not TryStrToInt(Config.Values['RetryCount'], FRetryCount) then
    raise Exception.Create('Incorrect "RetryCount" value set in config.');

  AnidbServer := TAnidbConnection.Create();
  AnidbServer.Timeout := FTimeout;
  AnidbServer.Client := 'hscan';
  AnidbServer.ClientVer := '1';
  AnidbServer.ProtoVer := '3';
  AnidbServer.RetryCount := FRetryCount;

 //Restore last command time, if available
  if TryStrToDatetime(SessionInfo.Values['LastCommandTime'], FLastCommandTime) then
    AnidbServer.LastCommandTime := FLastCommandTime;

 //If we have SessionInfo stored, let's try to use it
  if SameText(SessionInfo.Values['LoggedIn'],  'True') then begin
    AnidbServer.SessionKey := SessionInfo.Values['SessionKey'];
    if not TryStrToInt(SessionInfo.Values['SessionPort'], FSessionPort) then
      raise Exception.Create('Incorrect "SessionPort" value in cache');
    AnidbServer.LocalPort := FSessionPort;
  end;

  AnidbServer.Connect(Config.Values['Host'], FPort);
  

{$IFDEF DEBUG}
 //Load hash cache
  HashList := TStringList.Create;
  if FileExists(HashlistFilename) then
    HashList.LoadFromFile(HashlistFilename);
 {$ENDIF}
end;

procedure App_SaveSessionInfo;
begin
  SessionInfo.Values['LastCommandTime'] := DatetimeToStr(AnidbServer.LastCommandTime);
  SessionInfo.Values['LoggedIn'] := BoolToStr(AnidbServer.LoggedIn, true);
  if AnidbServer.LoggedIn then begin
    SessionInfo.Values['SessionKey'] := AnidbServer.SessionKey;
    SessionInfo.Values['SessionPort'] := IntToStr(AnidbServer.LocalPort);
  end else begin
    SessionInfo.Values['SessionKey'] := '';
    SessionInfo.Values['SessionPort'] := '';
  end;

  SessionInfo.SaveToFile(SessionFilename);
end;

procedure App_Deinit;
begin
  App_SaveSessionInfo;
{$IFDEF DEBUG}
  Hashlist.SaveToFile(HashlistFilename);
{$ENDIF}  
  FreeAndNil(SessionInfo);
  FreeAndNil(Config);
end;


procedure HashFile(fname: string; out size: int64; out ed2k: MD4Digest);
var h: THandle;
  c: Ed2kContext;

  this_chunk_size: integer;
  bytesRead: cardinal;

  buf: pbyte;
  buf_size: cardinal;

  full_chunk_cnt: integer;
  FirstChunkHash: MD4Digest;
begin
  writeln('Hashing '+fname+'...');

  h := CreateFile(pchar(fname), GENERIC_READ, FILE_SHARE_READ, nil,
    OPEN_EXISTING, 0, 0);
  if (h=INVALID_HANDLE_VALUE) then
    RaiseLastOsError;

  Ed2kInit(c);
  full_chunk_cnt := 0;

 //Use only divisors of ED2K_CHUNK_SIZE!
  buf_size := 4096;
  GetMem(buf, buf_size);

  try
    this_chunk_size := 0;
    repeat
      if not ReadFile(h, buf^, buf_size, bytesRead, nil) then
        RaiseLastOsError;

      Ed2kChunkUpdate(c, buf, bytesRead);
      Inc(this_chunk_size, bytesRead);

      if this_chunk_size >= ED2K_CHUNK_SIZE then begin
       //If this is the first chunk, remember it's hash
        if full_chunk_cnt = 0 then
          Ed2kNextChunk2(c, FirstChunkHash)
        else //we don't care
          Ed2kNextChunk(c);

        this_chunk_size := 0;
        Inc(full_chunk_cnt);
      end;
    until bytesRead < buf_Size;

   Ed2kFinal(c, ed2k);

   size := full_chunk_cnt;
   size := size * ED2K_CHUNK_SIZE;
   size := size + this_chunk_size;

{$IFDEF DEBUG}
  //Record FirstChunkHash to the cache
   HashList.Values[Md4ToString(FirstChunkHash)] := Md4ToString(ed2k);
{$ENDIF}   

  finally
    FreeMem(buf);
    CloseHandle(h);
  end;
end;

//Calculates file hash and outputs it.
procedure Exec_Hash(fname: string);
var hash: MD4Digest;
  size: int64;
begin
  HashFile(fname, size, hash);
  writeln('Size: '+IntToStr(size));  
  writeln('Hash: '+MD4ToString(hash));
end;

//Returns TRUE if the file was successfully added OR it was already in mylist.
//Returns FALSE otherwise
function Exec_Mylistadd(fname: string; FileState: integer; FileWatched: boolean; EditMode: boolean): boolean;
var
  f_size: int64;
  f_ed2k: MD4Digest;
  res: TAnidbResult;
begin
  if not AnidbServer.LoggedIn then begin
    AnidbServer.Login(Config.Values['User'], Config.Values['Pass']);
    writeln('Logged in');
  end;

 //Hash file
 //We're doing it after possible login command to give the connection a break.
 //It's required by AniDB protocol to send commands once in two seconds.
 //Break is strictly enforced by lower level, but if possible, we will try to
 //softly support it from upper levels too.
  HashFile(fname, f_size, f_ed2k);

  res := AnidbServer.MyListAdd(f_size, Md4ToString(f_ed2k), FileState, FileWatched, EditMode);
  if (res.code=INVALID_SESSION)
  or (res.code=LOGIN_FIRST)
  or (res.code=LOGIN_FAILED) then begin
    writeln('Session is obsolete, restoring...');
    AnidbServer.SessionKey := '';
    AnidbServer.Login(Config.Values['User'], Config.Values['Pass']);
    writeln('Logged in');

   //Retry
    res := AnidbServer.MyListAdd(f_size, Md4ToString(f_ed2k), FileState, FileWatched, EditMode);
  end;

  writeln(res.ToString);

  Result := (res.code = MYLIST_ENTRY_ADDED)
    or (res.code = FILE_ALREADY_IN_MYLIST)
    or (res.code = MYLIST_ENTRY_EDITED);
end;

{$REGION 'File enumeration'}
type
  TStringArray = array of string;

procedure AddFile(var files: TStringArray; fname: string); inline;
begin
  SetLength(files, Length(files)+1);
  files[Length(files)-1] := fname;
end;

procedure EnumFiles_in(dir, mask: string; subdirs: boolean; var files: TStringArray);
var SearchRec: TSearchRec;
  res: integer;
begin
 //First we look through files
  res := FindFirst(dir + '\' + mask, faAnyFile and not faDirectory, SearchRec);
  while (res = 0) do begin
    AddFile(files, dir + '\' + SearchRec.Name);
    res := FindNext(SearchRec);
  end;
  SysUtils.FindClose(SearchRec);

 //If no subdir scan is planned, then it's over.
  if not subdirs then exit;

 //Else we go through subdirectories
  res := FindFirst(dir + '\' + '*.*', faAnyFile, SearchRec);
  while (res = 0) do begin
   //Ignore . and ..
    if (SearchRec.Name='.')
    or (SearchRec.Name='..') then begin
    end else

   //Default - directory
    if ((SearchRec.Attr and faDirectory) = faDirectory) then
      EnumFiles_in(dir + '\' + SearchRec.Name, mask, subdirs, files);

    res := FindNext(SearchRec);
  end;
  SysUtils.FindClose(SearchRec);
end;

procedure EnumFiles2(fname: string; subdirs: boolean; var files: TStringArray);
var dir: string;
 mask: string;
begin
 //Single file => no scan
  if FileExists(fname) then begin
    AddFile(files, fname);
    exit;
  end;

  if DirectoryExists(fname) then begin
    dir := fname;
    mask := '*.*';
  end else begin
    dir := ExtractFilePath(fname);
    mask := ExtractFileName(fname);
    if mask='' then
      mask := '*.*';
  end;

  EnumFiles_in(dir, mask, subdirs, files);
end;

function EnumFiles(fname: string; subdirs: boolean): TStringArray;
begin
  SetLength(Result, 0);
  EnumFiles2(fname, subdirs, Result);
end;
{$ENDREGION}

function FileStateFromStr(s: string): integer;
begin
  if SameText(s, 'unknown') then
    Result := STATE_UNKNOWN
  else
  if SameText(s, 'hdd') then
    Result := STATE_HDD
  else
  if SameText(s, 'cd') then
    Result := STATE_CD
  else
  if SameText(s, 'deleted') then
    Result := STATE_DELETED
  else

    raise Exception.Create('Unknown file state: '+s);
end;

function IsSwitch(s: string): boolean;
begin
  Result := (Length(s) > 0) and (s[1] = '/');
end;

procedure OutputSummary(failed_files: TStringArray);
var i: integer;
begin
  if Length(failed_files) = 0 then
    writeln('All files OK.')
  else begin
    writeln('Some files failed: ');
    for i := 0 to Length(failed_files) - 1 do
      writeln('  ' + ExtractFilename(failed_files[i]));
  end;
end;

type
  TAnidbOptions = record
    FileState: integer;
    Watched: boolean;
    EditMode: boolean;
  end;

  TProgramOptions = record
    ParseSubdirs: boolean;
    DontStopOnErrors: boolean;
  end;

procedure Execute();
var i: integer;

  ProgramOptions: TProgramOptions;
  AnidbOptions: TAnidbOptions;

 //All enumerated files + current file
  files: TStringArray;
  file_name: string;

 //Files which failed MyListAdd
  failed_files: TStringArray;

 //Main command, like "hash" or "mylistadd"
  main_command: string;
  param: string;

 //Filemask count. Used to check if at least one was specified.
  filemask_cnt: integer;
begin
 //Default options
  ProgramOptions.ParseSubdirs := false;
  ProgramOptions.DontStopOnErrors := false;
  AnidbOptions.FileState := STATE_UNKNOWN;
  AnidbOptions.Watched := false;
  AnidbOptions.EditMode := false;

 //Read some default options from config
  TryStrToBool(Config.Values['EditMode'], AnidbOptions.EditMode);
  TryStrToBool(Config.Values['DontStopOnErrors'], ProgramOptions.DontStopOnErrors);

 //Parse main command
  if ParamCount < 1 then begin
    ShowUsage;
    exit;
  end;

  main_command := paramstr(1);
  SetLength(files, 0);
  filemask_cnt := 0;

 //Parse switches
  i := 2;
  while i <= ParamCount do begin
    param := paramstr(i);

   //If it's not switch then it's file/directory mask. Add it to file list.
    if not IsSwitch(param) then begin
      EnumFiles2(param, ProgramOptions.ParseSubdirs, files);
      Inc(filemask_cnt);
    end else

   //Available switches

   //Subdirs
    if SameText(param, '/s') then
      ProgramOptions.ParseSubdirs := true
    else

   //State (for mylistadd only)
    if SameText(param, '/state') then begin
      Inc(i);
      if i > ParamCount then begin
        writeln('Incomleted /state sequence.');
        ShowUsage;
        exit;
      end;

      AnidbOptions.FileState := FileStateFromStr(paramstr(i));
    end else

   //Watched (for mylistadd only)
    if SameText(param, '/watched') then begin
      AnidbOptions.Watched := true;
    end else

   //EditMode (for mylistadd only)
    if SameText(param, '/edit')
    or SameText(param, '/editmode') then begin
      AnidbOptions.EditMode := true;
    end else

   //DontStopOnErrors (for mylistadd only)
    if SameText(param, '/noerrors') then begin
      ProgramOptions.DontStopOnErrors := true;
    end else

   //StopOnErrors (for mylistadd only)
    if SameText(param, '/errors') then begin
      ProgramOptions.DontStopOnErrors := false;
    end else

   //Unknown option
    begin
      writeln('Unknown option - '+param);
      ShowUsage;
      exit;
    end;

    Inc(i);
  end;


 //Hash
  if SameText(main_command, 'hash') then begin
   //If no files specified
    if filemask_cnt = 0 then begin
      writeln('Illegal syntax');
      ShowUsage;
      exit;
    end;

   //If no files found by mask
    if Length(files)=0 then
      writeln('No files to hash.')
    else
      if Length(files) > 1 then
        writeln(IntToStr(Length(files)) + ' files found.');

   //Process files
    for file_name in files do begin
      Exec_Hash(file_name);
      writeln('');
    end;
  end else

 //Mylistadd
  if SameText(main_command, 'mylistadd') then begin
   //If no files specified
    if filemask_cnt = 0 then begin
      writeln('Illegal syntax');
      ShowUsage;
      exit;
    end;

   //If no files found by mask
    if Length(files)=0 then
      writeln('No files to add.')
    else
      if Length(files) > 1 then
        writeln(IntToStr(Length(files)) + ' files found.');

   //Process files
    SetLength(failed_files, 0);
    for file_name in files do try

      if not Exec_MyListAdd(file_name, AnidbOptions.FileState,
        AnidbOptions.Watched, AnidbOptions.EditMode) then
        AddFile(failed_files, file_name);
      writeln('');

    except //catch mylistadd errors here
      on E: Exception do begin

       //Output error
        writeln(E.Classname + ': ' + E.Message);

       //Either stop + output files, or continue, as configured
        if ProgramOptions.DontStopOnErrors then
          AddFile(failed_files, file_name)
        else begin
          writeln('Summary up to error:');
          OutputSummary(failed_files);
          raise;
        end;

      end;
    end;

   //If there were more than one file, output summary information
    if Length(files) > 1 then
      OutputSummary(failed_files);

  end else

 //Unknown command
  begin
    writeln('Illegal command: '+paramstr(1));
    ShowUsage;
    exit;
  end;

end;

begin
  try
    App_Init();
    try
      Execute();
    finally
      App_Deinit();
    end;
    
  except
    on E: Exception do
      writeln(E.ClassName + ': ' + E.Message);
  end;
end.
