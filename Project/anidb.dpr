program anidb;

{$APPTYPE CONSOLE}

//If set, uses multi-threaded hasher instead of a simple single-threaded one.
//Try disabling when debugging hashing problems.
{$DEFINE THREADEDHASHER}

uses
  SysUtils, Classes, Windows, StrUtils, UniStrUtils, DirectoryEnum, FilenameUtils,
  AnidbConnection in 'AnidbConnection.pas',
  AnidbConsts in 'AnidbConsts.pas',
  FileInfo in 'FileInfo.pas',
  SessionLock in 'SessionLock.pas',
  md4, ed2k,
  ParallelEd2k in 'ParallelEd2k.pas';

type
  TAnidbOptions = record
    FileState: TAnidbFileState;
    EditMode: boolean;
  end;
  PAnidbOptions = ^TAnidbOptions;

  TProgramOptions = record
    ParseSubdirs: boolean;
    DontStopOnErrors: boolean;
    AutoEditExisting: boolean;
    UseCachedHashes: boolean;
    UpdateCache: boolean;
    IgnoreUnchangedFiles: boolean;
    Verbose: boolean;
    IgnoreExtensions: string;
    UseOnlyExtensions: string;
    SaveFailedList: string; //file name to save the list of failed files to.
    GenerateEd2kLinks: boolean;
    function AllowedExtension(ext: string): boolean;
  end;
  PProgramOptions = ^TProgramOptions;

 //Receives AnidbConnection events
  TAnidbTool = class
  public //Events
    procedure ServerBusy(Sender: TAnidbConnection; wait_interval: cardinal);
    procedure NoAnswer(Sender: TAnidbConnection; wait_interval: cardinal);
  end;

  TProgramStats = record
    HashedFiles: integer;       //full hash calculated
    HashCachedFiles: integer;   //cached hash used
    AddedFiles: integer;        //added to AniDB
    EditedFiles: integer;       //edited on AniDB
    IgnoredFiles: integer;      //ignored because of filter
    UnchangedFiles: integer;    //ignored because unchanged
  end;

var
  Config: TStringList;
  SessionInfo: TSessionLock;

  ConfigFilename: string;
  FileDbFilename: string;

  Tool: TAnidbTool;
  AnidbServer: TAnidbConnection;
  FileDb: TFileDb;

  ProgramOptions: TProgramOptions;
  AnidbOptions: TAnidbOptions;
  Stats: TProgramStats;

  Hasher: TEd2kHasher;

procedure ShowUsage;
begin
 { We only print the most important options here.
  Some options are dependent on the program configuration }
  writeln('Usage: '+ExtractFilename(paramstr(0)) + ' <command> <params>');
  writeln('Commands: ');
  writeln('  hash <filename> [/s] [/ed2klink]');
  writeln('  mylistadd <filename> [/s] [file state] [other flags]');
  writeln('  mylistedit [see mylistadd]');
  writeln('  myliststats');
  writeln('');
  writeln('Where:');
  writeln('  <filename> is file name, mask or directory name');
  writeln('  /s iterates subdirectories');
  writeln('');

  writeln('File state flags:');
  writeln('  /state <state> sets file state (unknown/hdd/cd/deleted)');
  writeln('  /watched marks file as watched');
  writeln('  /watchdate sets the date you watched this episode/series');
  writeln('  /source <source> sets file source (any string)');
  writeln('  /storage <storage> sets file storage (any string)');
  writeln('  /other <other> sets other remarks (any string)');
  writeln('If you''re editing a file, only those flags you specify will be changed.');
  writeln('');

  writeln('Other flags:');
  if not ProgramOptions.AutoEditExisting then
    writeln('  /autoedit tries to add file, if it''s in mylist then update it');
  if ProgramOptions.DontStopOnErrors then
    writeln('  /errors stops the app on critical errors')
  else
    writeln('  /noerrors ignores errors and continues adding files');
  if ProgramOptions.UseCachedHashes then
    writeln('  /forcerehash disables the use of cached hashes')
  else
    writeln('  /usecachedhashes enables the use of cached hashes');
  if ProgramOptions.IgnoreUnchangedFiles then
    writeln('  /forceunchangedfiles forces updates to AniDB even when file is not changed')
  else
    writeln('  /ignoreunchangedfiles skips AniDB request when file is not changed');
  writeln('  /verbose displays more messages');
  writeln('');
  writeln('See help file for other options.');
end;

//These are missing in windows.pas
type
  EXECUTION_STATE = DWORD;

const
  ES_SYSTEM_REQUIRED = $00000001;
  ES_DISPLAY_REQUIRED = $00000002;
  ES_USER_PRESENT = $00000004;
  ES_AWAYMODE_REQUIRED = $00000040; //Vista+
  ES_CONTINUOUS = $80000000;

function SetThreadExecutionState(esFlags: EXECUTION_STATE): EXECUTION_STATE; stdcall; external kernel32;

procedure App_Init;
var FPort: integer;
  FTimeout: integer;
  FLastCommandTime: TDatetime;
  FSessionPort: integer;
  FRetryCount: integer;
  SessionFilename: string;
begin
  Tool := TAnidbTool.Create;

  ConfigFilename := ChangeFileExt(paramstr(0), '.cfg');
  SessionFilename := ExtractFilePath(paramstr(0)) + 'session.cfg';
  FileDbFilename := ExtractFilePath(paramstr(0)) + 'file.db';

 //Read config
  if not FileExists(ConfigFilename) then
    raise Exception.Create('Configuration file not found');

  Config := TStringList.Create();
  Config.LoadFromFile(ConfigFilename);

  if not TryStrToInt(Config.Values['Port'], FPort) then
    raise Exception.Create('Incorrect "Port" value set in config.');

  if not TryStrToInt(Config.Values['Timeout'], FTimeout) then
    raise Exception.Create('Incorrect "Timeout" value set in config.');

  if not TryStrToInt(Config.Values['RetryCount'], FRetryCount) then
    raise Exception.Create('Incorrect "RetryCount" value set in config.');

 //Lock session
  SessionInfo := TSessionLock.Create(SessionFilename);

 //Create anidb client
  AnidbServer := TAnidbConnection.Create();
  AnidbServer.Timeout := FTimeout;
  AnidbServer.Client := 'hscan';
  AnidbServer.ClientVer := '1';
  AnidbServer.ProtoVer := '3';
  AnidbServer.RetryCount := FRetryCount;
  AnidbServer.OnServerBusy := Tool.ServerBusy;
  AnidbServer.OnNoAnswer := Tool.NoAnswer;

 //Restore last command time, if available
  if TryStrToDatetime(SessionInfo.Values['LastCommandTime'], FLastCommandTime) then
    AnidbServer.LastCommandTime := FLastCommandTime;

 //If we have SessionInfo stored, let's try to use it
  if SameText(SessionInfo.Values['LoggedIn'],  'True') then begin
    AnidbServer.SessionKey := AnsiString(SessionInfo.Values['SessionKey']);
    if not TryStrToInt(SessionInfo.Values['SessionPort'], FSessionPort) then
      raise Exception.Create('Incorrect "SessionPort" value in cache');
    AnidbServer.LocalPort := FSessionPort;
  end;

 //Create hasher
 {$IFDEF THREADEDHASHER}
  Hasher := TParallelEd2kHasher.Create;
 {$ELSE}
  Hasher := TSimpleEd2kHasher.Create;
 {$ENDIF}

 //Open file database
  FileDb := TFileDb.Create(FileDbFilename);

 //Default options
  ProgramOptions.ParseSubdirs := false;
  ProgramOptions.DontStopOnErrors := false;
  ProgramOptions.UseCachedHashes := true;
  ProgramOptions.UpdateCache := true;
  ProgramOptions.IgnoreUnchangedFiles := true;
  ProgramOptions.Verbose := false;
  FillChar(AnidbOptions, SizeOf(AnidbOptions), 0);
  AnidbOptions.EditMode := false;

 //Read some default options from config
  TryStrToBool(Config.Values['EditMode'], AnidbOptions.EditMode);
  TryStrToBool(Config.Values['DontStopOnErrors'], ProgramOptions.DontStopOnErrors);
  TryStrToBool(Config.Values['AutoEditExisting'], ProgramOptions.AutoEditExisting);
  TryStrToBool(Config.Values['UseCachedHashes'], ProgramOptions.UseCachedHashes);
  TryStrToBool(Config.Values['UpdateCache'], ProgramOptions.UpdateCache);
  TryStrToBool(Config.Values['IgnoreUnchangedFiles'], ProgramOptions.IgnoreUnchangedFiles);
  TryStrToBool(Config.Values['Verbose'], ProgramOptions.Verbose);
  ProgramOptions.IgnoreExtensions := Config.Values['IgnoreExtensions'];
  ProgramOptions.UseOnlyExtensions := Config.Values['UseOnlyExtensions'];

 //Don't go to sleep on us
  if SetThreadExecutionState(ES_CONTINUOUS or ES_SYSTEM_REQUIRED) = 0 then
    if ProgramOptions.Verbose then
      writeln('Failed to disable auto-sleep while running.');

  ZeroMemory(@Stats, SizeOf(Stats));

 //Connect to anidb (well, formally; UDP has no connections in practice)
  AnidbServer.Connect(AnsiString(Config.Values['Host']), FPort);
end;

procedure App_SaveSessionInfo;
begin
  SessionInfo.Values['LastCommandTime'] := DatetimeToStr(AnidbServer.LastCommandTime);
  SessionInfo.Values['LoggedIn'] := BoolToStr(AnidbServer.LoggedIn, true);
  if AnidbServer.LoggedIn then begin
    SessionInfo.Values['SessionKey'] := string(AnidbServer.SessionKey);
    SessionInfo.Values['SessionPort'] := IntToStr(AnidbServer.LocalPort);
  end else begin
    SessionInfo.Values['SessionKey'] := '';
    SessionInfo.Values['SessionPort'] := '';
  end;

  SessionInfo.Save;
end;

procedure App_Deinit;
begin
  App_SaveSessionInfo;

 //Enable going to sleep (though it will be enabled when the thread terminates anyway)
  SetThreadExecutionState(ES_CONTINUOUS);

  FreeAndNil(FileDb);
  FreeAndNil(SessionInfo);
  FreeAndNil(Hasher);
  FreeAndNil(Config);
  FreeAndNil(Tool);
end;

////////////////////////////////////////////////////////////////////////////////

//Checks that the list of form "asd,bsd,csd" contans extension "ext"
function ContainsExt(list: string; ext: string): boolean;
begin
  if StartsText(ext, list) then begin
   //Simple match
    if Length(list)<=Length(ext) then begin
      Result := true;
      exit;
    end;

   //Verify that this is not extSOMETHINGELSE,bsd,csd
    if list[Length(ext)+1]=',' then begin
      Result := true;
      exit;
    end;

   //No "Result := false" because although the extension at the beginning
   //of the string doesn't fit, we might still find another match later.
  end;

  if EndsText(ext, list) then begin
   //Not checking for a simple match, already checked that in StartsText

   //Verify that it's not asd,bsd,SOMETHINGELSEext   
    if list[Length(list)-Length(ext)]=',' then begin
      Result := true;
      exit;
    end;

   //No "Result := false" because we still have a chance of finding the match inside.
  end;

  Result := ContainsText(list, ','+ext+','); //param order inversed to Starts/Ends
end;

function TProgramOptions.AllowedExtension(ext: string): boolean;
begin
 //Special case: empty extensions are replaced with "."
  if ext='' then ext := '.';

  if UseOnlyExtensions <> '' then
    Result := ContainsExt(UseOnlyExtensions, ext)
  else
    Result := (IgnoreExtensions <> '') and not ContainsExt(IgnoreExtensions, ext);
end;

////////////////////////////////////////////////////////////////////////////////

procedure TAnidbTool.ServerBusy(Sender: TAnidbConnection; wait_interval: cardinal);
begin
  writeln('Server busy, sleeping '+IntToStr(wait_interval)+' msec...');
end;

procedure TAnidbTool.NoAnswer(Sender: TAnidbConnection; wait_interval: cardinal);
begin
  writeln('No answer, sleeping '+IntToStr(wait_interval)+' msec...');
end;

////////////////////////////////////////////////////////////////////////////////

type
  TPartialHashChecker = class
  public
    f: PFileInfo;
    constructor Create;
    procedure OnLeadPartDone(Sender: TEd2kHasher; Lead: MD4Digest);
  end;

constructor TPartialHashChecker.Create;
begin
  f := nil;
end;

//Note that if filesize < size(lead_part), we'll never get here
procedure TPartialHashChecker.OnLeadPartDone(Sender: TEd2kHasher; Lead: MD4Digest);
begin
 //Many features require the FileDB record so we find it here in any case
 //(even if we are going to hash to the end)
  f := FileDb.FindByLead(lead);

 //If configured to use cached hashed, don't scan any further
  if ProgramOptions.UseCachedHashes and Assigned(f) then
    Sender.Terminated := true;
end;

procedure HashFile(fname: string; out size: int64; out ed2k: MD4Digest; out f: PFileInfo);
var Checker: TPartialHashChecker;
begin
  writeln('Hashing '+fname+'...');

  Checker := TPartialHashChecker.Create;
  try
    Hasher.OnLeadPartDone := Checker.OnLeadPartDone;
    Hasher.HashFile(fname);
    Hasher.OnLeadPartDone := nil;

    Size := Hasher.FileSize;

   //we might have never had a chance to look by lead because the file was like 30 bytes (less than lead in size => no OnLeadPartDone call)
    if (Checker.f=nil) and (Size < ED2K_CHUNK_SIZE) then
      Checker.f := FileDb.FindByEd2k(ed2k);

    if (Checker.f<>nil) and ProgramOptions.UseCachedHashes then
      Inc(Stats.HashCachedFiles)
    else
      Inc(Stats.HashedFiles);

   //DB record not found
    if Checker.f=nil then begin
      if ProgramOptions.UpdateCache then begin
        ed2k := Hasher.Ed2k;
        f := FileDb.AddNew;
        f.size := Hasher.FileSize;
        f.ed2k := Hasher.Ed2k;
        f.lead := Hasher.Lead;
        FileDb.Changed; //contains only hash for now
      end else
      begin end; //not updating => no record
    end
    else
   //Record found + using cached hashes
    if ProgramOptions.UseCachedHashes then begin
      f := Checker.f;
      if ProgramOptions.Verbose then
        writeln('Partial hash found, using cache.');
      ed2k := f.ed2k;
    end else
   //Record found + not using cached hashes + updating record
    if ProgramOptions.UpdateCache then begin
      ed2k := Hasher.Ed2k;
      f := Checker.f;
      if ProgramOptions.Verbose then
        writeln('Updating partial=>full hash assignment.');
      f.ed2k := ed2k;
      FileDb.Changed;
    end else
   //Record found + not using it + not updating => just keep it for IgnoringUnchangedFiles later.
    begin
      f := Checker.f;
    end;

  finally
    FreeAndNil(Checker);
  end;
end;

//Calculates file hash and outputs it.
procedure Exec_Hash(fname: string);
var hash: MD4Digest;
  size: int64;
  f: PFileInfo;
begin
  HashFile(fname, size, hash, f);
  writeln('Size: '+IntToStr(size));
  writeln('Hash: '+MD4ToString(hash));
  if ProgramOptions.GenerateEd2kLinks then
   //AniDB Ed2k link doesn't respect the "space as +" encoding part
    writeln('ed2k://|file|'+string(UrlEncode(ExtractFilename(fname), [ueNoSpacePlus]))
      +'|'+IntToStr(size)+'|'+MD4ToString(hash)+'|/');
end;

////////////////////////////////////////////////////////////////////////////////

//Returns TRUE if the file was successfully added OR it was already in mylist.
//Returns FALSE otherwise
function Exec_Mylistadd(fname: string; AnidbOptions: PAnidbOptions; ProgramOptions: PProgramOptions): boolean;
var
  f_size: int64;
  f_ed2k: MD4Digest;
  res: TAnidbResult;
  f: PFileInfo;
  EditMode: boolean;
  fs: TAnidbFileState; //resulting file state to set
begin
  if not AnidbServer.LoggedIn then begin
    AnidbServer.Login(AnsiString(Config.Values['User']), AnsiString(Config.Values['Pass']));
    App_SaveSessionInfo; {in case we're interrupted later}
    writeln('Logged in');
  end;

 //Hash file
 //We're doing it after possible login command to give the connection a break.
 //It's required by AniDB protocol to send commands once in two seconds.
 //Break is strictly enforced by lower level, but if possible, we will try to
 //softly support it from upper levels too.
  HashFile(fname, f_size, f_ed2k, f);

  fs := AnidbOptions.FileState; //AnidbOptions.FileState is shared by many files
  if ProgramOptions.IgnoreUnchangedFiles
  and Assigned(f) and (f.StateSet) then begin
   //Disable all the info which haven't been changed
    if f.State.State_set and fs.State_set
    and (f.State.State = fs.State) then
      fs.State_set := false;

    if f.State.Viewed_set and fs.Viewed_set
    and (f.State.Viewed = fs.Viewed) then
      fs.Viewed_set := false;

    if f.State.ViewDate_set and fs.ViewDate_set
    and (f.State.ViewDate = fs.ViewDate) then
      fs.ViewDate_set := false;

    if f.State.Source_set and fs.Source_set
    and SameStr(f.State.Source, fs.Source) then
      fs.Source_set := false;

    if f.State.Storage_set and fs.Storage_set
    and SameStr(f.State.Storage, fs.Storage) then
      fs.Storage_set := false;

    if f.State.Other_set and fs.Other_set
    and SameStr(f.State.Other, fs.Other) then
      fs.Other_set := false;

   //Now if there's nothing to change then skip the file
    if not AfsSomethingIsSet(fs) then begin
      writeln('File unchanged, ignoring.');
      Inc(Stats.IgnoredFiles);
      Result := true;
      exit;
    end;

  end;

 //If the file is in cache, we're sure it's already in mylist, so just edit it.
  EditMode := AnidbOptions.EditMode or (Assigned(f) and f.StateSet);

 //AniDB will complain if we EDIT and have no fields to set
  if EditMode and not AfsSomethingIsSet(fs) then begin
    writeln('File already in AniDB and nothing to set about it: ignoring.');
    Inc(Stats.UnchangedFiles);
    Result := true;
    exit;
  end;

  res := AnidbServer.MyListAdd(f_size, AnsiString(Md4ToString(f_ed2k)), fs, EditMode);
  if (res.code=INVALID_SESSION)
  or (res.code=LOGIN_FIRST)
  or (res.code=LOGIN_FAILED) then begin
    if ProgramOptions.Verbose then
      writeln(res.ToString);
    writeln('Session is obsolete, restoring...');
    AnidbServer.SessionKey := '';
    AnidbServer.Login(AnsiString(Config.Values['User']), AnsiString(Config.Values['Pass']));
    App_SaveSessionInfo; {in case we're interrupted later}
    writeln('Logged in');

   //Retry
    res := AnidbServer.MyListAdd(f_size, AnsiString(Md4ToString(f_ed2k)), fs, EditMode);
  end;

  if res.code=MYLIST_ENTRY_ADDED then
    Inc(Stats.AddedFiles);
  if res.code=MYLIST_ENTRY_EDITED then
    Inc(Stats.EditedFiles);

 //AniDB will complain if we EDIT and have no fields to set
  if (res.code = FILE_ALREADY_IN_MYLIST)
  and not AfsSomethingIsSet(fs) then
   //Trick the rest of the code into thinking we successfully edited the file
   //(Or it'll be marked as failed for the user)
    res.code := MYLIST_ENTRY_EDITED;

 //If we were already editing and not adding, no need to try editing again
  if (not EditMode) and (ProgramOptions.AutoEditExisting)
  and (res.code = FILE_ALREADY_IN_MYLIST) then begin
    if ProgramOptions.Verbose then
      writeln(res.ToString);
    writeln('File in mylist, editing...');

   //Trying again, editing this time
    res := AnidbServer.MyListAdd(f_size, AnsiString(Md4ToString(f_ed2k)), fs, {EditMode=}true);

    if res.code=MYLIST_ENTRY_EDITED then
      Inc(Stats.EditedFiles);
  end;

  writeln(res.ToString);

  Result := (res.code = MYLIST_ENTRY_ADDED)
    or ((res.code = FILE_ALREADY_IN_MYLIST) and not ProgramOptions.AutoEditExisting) //if we AutoEditExisting, this error should not occur
    or (res.code = MYLIST_ENTRY_EDITED);

  if ProgramOptions.UpdateCache and Result then begin
   //If UpdateCache is on, we should have f assigned.
    Assert(Assigned(f), 'UpdateCache is on and yet cache record is not assigned.');

   { Merge state }
    AfsUpdate(f.State, fs);
    f.StateSet := true;
    FileDb.Changed;
  end;
end;

procedure Exec_MyListStats;
var Stats: TAnidbMylistStats;
  res: TAnidbResult;
begin
  res := AnidbServer.MyListStats(Stats);
  if (res.code=INVALID_SESSION)
  or (res.code=LOGIN_FIRST)
  or (res.code=LOGIN_FAILED) then begin
    if ProgramOptions.Verbose then
      writeln(res.ToString);  
    writeln('Session is obsolete, restoring...');
    AnidbServer.SessionKey := '';
    AnidbServer.Login(AnsiString(Config.Values['User']), AnsiString(Config.Values['Pass']));
    App_SaveSessionInfo; {in case we're interrupted later}
    writeln('Logged in');

   //Retry
    res := AnidbServer.MyListStats(Stats);
  end;

 //Errors => exit
  if res.code <> MYLIST_STATS then begin
    writeln(res.ToString);
    exit;
  end;

  writeln('Mylist Stats:');
  writeln('  Total animes: ', Stats.cAnimes, ', episodes: ', Stats.cEps,
    ', files: ', Stats.cFiles, '.');
  if Stats.cSizeOfFiles < 1024 then
    writeln('  Total size of files: ', Stats.cSizeOfFiles, 'Mb.')
  else
    if Stats.cSizeOfFiles < 1024 * 1024 then
      writeln('  Total size of files: ', Trunc(Stats.cSizeOfFiles/1024), 'Gb (',
        Stats.cSizeOfFiles, 'Mb).');
  writeln('  Added animes: ', Stats.cAddedAnimes, ', episodes: ', Stats.cAddedEps,
    ', files: ', Stats.cAddedFiles, ', groups: ', Stats.cAddedGroups, '.');
  writeln('  Leech: ', Stats.pcLeech, '%, glory: ', Stats.pcGlory, '%.');
  writeln('  Viewed eps: ', Stats.cViewedEps, ', of anidb: ', Stats.pcViewedOfDb,
    '%, mylist of anidb: ', Stats.pcMylistOfDb, '%, vieved of mylist: ',
    Stats.pcViewedOfMylist, '%.');
  writeln('  Votes: ', Stats.cVotes, ', reviews: ', Stats.cReviews, '.');
end;

////////////////////////////////////////////////////////////////////////////////

//Decodes string parameter: removes surrounding quotes, decodes special chars
function DecodeStrParam(s: string): string;
begin
  if Length(s)<2 then begin
    Result := '';
    exit;
  end;

 //Windows does it this way so we don't care if the last " is escaped
  if (s[1]='"') and (s[Length(s)]='"') then
    s := StrSub(@s[2], @s[Length(s)-1]);

 //De-escape the rest
  Result := UniReplaceStr(s, '\"', '"');
end;

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

procedure SaveListToFile(list: TStringArray; filename: string);
var f: TStringList;
  i: integer;
begin
 //Let's play stupid and reuse TStringList code
  f := TStringList.Create;
  try
    for i := 0 to Length(list) - 1 do
      f.Add(list[i]);
    f.SaveToFile(filename);
  finally
    FreeAndNil(f);
  end;
end;

function FileExt(fn: string): string;
begin
  Result := ExtractFileExt(fn);
 //Delete starting '.'
  if Result <> '' then
    Result := RightStr(Result, Length(Result)-1);
end;


procedure Execute();
var i: integer;

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

 //Parse main command
  if ParamCount < 1 then begin
    ShowUsage;
    exit;
  end;

  main_command := ''; //by default the command is not set
  SetLength(files, 0);
  filemask_cnt := 0;

 //Parse switches
  i := 1;
  while i <= ParamCount do begin
    param := paramstr(i);

   //If it's not a switch then it's a command or a mask
    if not IsSwitch(param) then begin
     //Treat first non-switch as a command.
      if main_command='' then
        main_command := param
      else
      
     //Later we might write a different non-switch-handling code here.
     //For now everything that's not a switch nor a command is a file/directory mask.
      begin
        EnumAddFiles(param, ProgramOptions.ParseSubdirs, files);
        Inc(filemask_cnt);
      end;
    end else

   //Available switches
    if SameText(param, '/?') then begin
      ShowUsage;
      exit;
    end else

   //Subdirs
    if SameText(param, '/s') then
      ProgramOptions.ParseSubdirs := true
    else

   //State (for mylistadd only)
    if SameText(param, '/state') then begin
      Inc(i);
      if i > ParamCount then begin
        writeln('Incomlete /state sequence.');
        ShowUsage;
        exit;
      end;

      AnidbOptions.FileState.State := FileStateFromStr(paramstr(i));
      AnidbOptions.FileState.State_set := true;
    end else

   //Watched (for mylistadd only)
    if SameText(param, '/watched') then begin
      AnidbOptions.FileState.Viewed := true;
      AnidbOptions.FileState.Viewed_set := true;
    end else

   //WatchDate (for mylistadd only)
    if SameText(param, '/watchdate') then begin
      Inc(i);
      if i > ParamCount then begin
        writeln('Incomlete /watchdate sequence.');
        ShowUsage;
        exit;
      end;

      AnidbOptions.FileState.ViewDate := StrToDatetime(DecodeStrParam(paramstr(i)));
      AnidbOptions.FileState.ViewDate_set := true;
    end else

   //Source (for mylistadd only)
    if SameText(param, '/source') then begin
      Inc(i);
      if i > ParamCount then begin
        writeln('Incomlete /source sequence.');
        ShowUsage;
        exit;
      end;

      AnidbOptions.FileState.Source := DecodeStrParam(paramstr(i));
      AnidbOptions.FileState.Source_set := true;
    end else

   //Storage (for mylistadd only)
    if SameText(param, '/storage') then begin
      Inc(i);
      if i > ParamCount then begin
        writeln('Incomlete /storage sequence.');
        ShowUsage;
        exit;
      end;

      AnidbOptions.FileState.Storage := DecodeStrParam(paramstr(i));
      AnidbOptions.FileState.Storage_set := true;
    end else

   //Other (for mylistadd only)
    if SameText(param, '/other') then begin
      Inc(i);
      if i > ParamCount then begin
        writeln('Incomlete /other sequence.');
        ShowUsage;
        exit;
      end;

      AnidbOptions.FileState.Other := DecodeStrParam(paramstr(i));
      AnidbOptions.FileState.Other_set := true;
    end else

   //EditMode (for mylistadd only)
    if SameText(param, '/edit')
    or SameText(param, '/editmode') then begin
      AnidbOptions.EditMode := true;
    end else

   //Disable EditMode (for mylistadd only)
    if SameText(param, '/-edit')
    or SameText(param, '/-editmode') then begin
      AnidbOptions.EditMode := false;
    end else

   //DontStopOnErrors (for mylistadd only)
    if SameText(param, '/noerrors') then begin
      ProgramOptions.DontStopOnErrors := true;
    end else

   //Disable DontStopOnErrors (for mylistadd only)
    if SameText(param, '/-noerrors')
    or SameText(param, '/errors') then begin
      ProgramOptions.DontStopOnErrors := false;
    end else

   //AutoEditExisting (for mylistadd only)
    if SameText(param, '/autoedit')
    or SameText(param, '/autoeditexisting') then begin
      ProgramOptions.AutoEditExisting := true;
    end else

   //Disable AutoEditExisting (for mylistadd only)
    if SameText(param, '/-autoedit')
    or SameText(param, '/-autoeditexisting') then begin
      ProgramOptions.AutoEditExisting := false;
    end else

   //UseCachedHashes
    if SameText(param, '/usecachedhashes') then begin
      ProgramOptions.UseCachedHashes := true;
    end else

   //Disable UseCachedHashes
    if SameText(param, '/-usecachedhashes')
    or SameText(param, '/forcerehash') then begin
      ProgramOptions.UseCachedHashes := false;
    end else

   //UpdateCache
    if SameText(param, '/updatecache') then begin
      ProgramOptions.UpdateCache := true;
    end else

   //Disable UpdateCache
    if SameText(param, '/-updatecache') then begin
      ProgramOptions.UpdateCache := false;
    end else

   //IgnoreUnchangedFiles (for mylistadd only)
    if SameText(param, '/ignoreunchangedfiles') then begin
      ProgramOptions.IgnoreUnchangedFiles := true;
    end else

   //-IgnoreUnchangedFiles (for mylistadd only)
    if SameText(param, '/-ignoreunchangedfiles')
    or SameText(param, '/forceunchangedfiles') then begin
      ProgramOptions.IgnoreUnchangedFiles := false;
    end else

    if SameText(param, '/savefailed') then begin
      Inc(i);
      if i > ParamCount then begin
        writeln('Incomlete /savefailed sequence.');
        ShowUsage;
        exit;
      end;

      ProgramOptions.SaveFailedList := DecodeStrParam(paramstr(i));
      if IsRelativePath(PChar(ProgramOptions.SaveFailedList)) then
        ProgramOptions.SaveFailedList := AppFolder + '\' + ProgramOptions.SaveFailedList;

    end else

   //Ed2k links
    if SameText(param, '/ed2klink') then begin
      ProgramOptions.GenerateEd2kLinks := true;
    end else

   //Disable Ed2k links
    if SameText(param, '/-ed2klink') then begin
      ProgramOptions.GenerateEd2kLinks := false;
    end else

   //Verbose
    if SameText(param, '/verbose') then begin
      ProgramOptions.Verbose := true;
    end else

   //Disable Verbose
    if SameText(param, '/-verbose') then begin
      ProgramOptions.Verbose := false;
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
     //We do not check extension filter with hashes.
     //I think this is usually what you want.

     //Perform operation
      Exec_Hash(file_name);
      writeln('');
    end;

   //Output stats
    writeln('Hashed files: '+IntToStr(Stats.HashedFiles));
    writeln('Used cached hashe: '+IntToStr(Stats.HashCachedFiles));
  end else

 //Mylistadd
  if SameText(main_command, 'mylistadd')
  or SameText(main_command, 'mylistedit') then begin

   //mylistedit === mylistadd + editmode
    if SameText(main_command, 'mylistedit')
   //except the case when AutoEdit because that's obviously meant for no editmode
    and not ProgramOptions.AutoEditExisting then
      AnidbOptions.EditMode := true;

   //If no files specified
    if filemask_cnt = 0 then begin
      writeln('No files specified.');
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
     //Check extension filter
      if not ProgramOptions.AllowedExtension(FileExt(file_name)) then begin
        if ProgramOptions.Verbose then
          writeln(ExtractFileName(file_name)+': disabled extension, ignoring.');
        continue;
      end;

     //Perform operation
      if not Exec_MyListAdd(file_name, @AnidbOptions, @ProgramOptions) then
        AddFile(failed_files, file_name);
      writeln('');

    except //catch mylistadd errors here
      on E: Exception do begin

       //Output error
        writeln(E.Classname + ': ' + E.Message);

       //Either stop + output files, or continue, as configured
        if ProgramOptions.DontStopOnErrors and not (E is ECritical) then
          AddFile(failed_files, file_name)
        else begin
          writeln('Summary up to error:');
          OutputSummary(failed_files);
          raise;
        end;

      end;
    end;

   //If there were more than one file, output summary information
    if Length(files) > 1 then begin
     //Stats
      writeln('Hashed files: '+IntToStr(Stats.HashedFiles));
      writeln('Used cached hashe: '+IntToStr(Stats.HashCachedFiles));
      writeln('Added files: '+IntToStr(Stats.AddedFiles));
      writeln('Edited files: '+IntToStr(Stats.EditedFiles));
      writeln('Ignored files: '+IntToStr(Stats.IgnoredFiles));
      writeln('Unchanged files: '+IntToStr(Stats.UnchangedFiles));

     //Failed files
      OutputSummary(failed_files);
    end;

   //Save failed file list
    if ProgramOptions.SaveFailedList<>'' then
      SaveListToFile(failed_files, ProgramOptions.SaveFailedList);

  end else

 //Myliststats
  if SameText(main_command, 'myliststats') then begin
   //Files are specified
    if filemask_cnt <> 0 then begin
      writeln('This command does not support specifying files.');
      exit;
    end;

   //Execute
    try
      Exec_MyListStats();
    except
      on E: Exception do begin
       //Output error
        writeln(E.Classname + ': ' + E.Message);
      end;
    end;
  end else

 //Unknown command
  begin
    writeln('Illegal command: '+paramstr(1));
    ShowUsage;
    exit;
  end;

{$IFDEF HASH_STATS}
  writeln('TotalTimeHashing: ', Hasher.TotalTime);
  writeln('ReadingTime: ', Hasher.ReadingTime);
  writeln('HashingTime: ', Hasher.HashingTime);
{$ENDIF}
end;

begin
  IsMultithread := true;
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
