unit FilenameUtils;
{$WEAKPACKAGEUNIT ON}

interface
uses SysUtils, StrUtils, UniStrUtils, Windows;

(*
  � Delphi ���� ������������ � ���� string. �� ������ ������������ ��� AnsiString,
  �� ����� - WideString.

  ������� ������� ����������� � ��� ���������, ��� � UniStrUtils:
    Ansi-������ (������ Ansi)
    Unicode-������ (������ ��������� Unicode)
    String-������ (������� string)
*)

(*
 �����������. ��������� ���� �����:
 1. ������:
    D:\Folder\Subfolder\file.ext
 2. �������������:
    Subfolder\file.ext
    \Subfolder\file.ext
    .\Subfolder\file.ext
 3. ������-����:
    \\Server\Share\Subfolder\file.ext
 4. ���������:
    \\?\D:\Folder\Subfolder\file.ext
    \\?\UNC\Server\Share\Subfolder\file.ext
    \\.\PhysicalDriveX\Folder\Subfolder\file.ext
    \\.\{GUID}\Folder\Subfolder\file.ext

����������� �����:
 1. �������� �������:
    D:\Folder\.\Subfolder\..\Subfolder\file.ext
 2. ��������� ������ ����� ������:
    D:\Folder\\\Subfolder\\file.ext
 3. ��������� ����� �����:
    D:/Folder/Subfolder/file.ext
   �� �������� ��� ��������� ����� � ������\����:
    \\.\{GUID} <--- ������ � ����� �����
    \\Server\Share <--- ������ � ����� �����
 4. ����� ����� �������� ����� ����� ���� ������ �����������:
    D:
 5. ����� ����� �����, � ������� ����������, ����� ���� ������ \:
    D:\Folder\Subfolder\
*)

const
  aDevicePrefix: AnsiString = '\\.\';
  aKernelFilePrefix: AnsiString = '\\?\';

//�������� �����-�����. �������� ��������, ��� ����������� �� ������� �����,
//� ������ ���������� ������. ��������,
//  \\?\UNC\Server\Share
//...����� true �� IsKernelFilePath � false �� IsServerSharePath.

//Checks if the path is of type 'C:\[rest]'
function IsDriveFolderPathA(a: PAnsiChar): boolean;
function IsDriveFolderPathW(a: PUniChar): boolean;
function IsDriveFolderPath(a: PChar): boolean;

//Checks if the path is of type '\\[rest]'.
//If you need to verify it's not \\.\ or \\?\, use IsDevicePath and IsKernelFilePath
function IsServerSharePathA(a: PAnsiChar): boolean;
function IsServerSharePathW(a: PUniChar): boolean;
function IsServerSharePath(a: PChar): boolean;

//Returns true if the path is relative one.
function IsRelativePathA(a: PAnsiChar): boolean;
function IsRelativePathW(a: PUniChar): boolean;
function IsRelativePath(a: PChar): boolean;

function IsAbsolutePathA(a: PAnsiChar): boolean;
function IsAbsolutePathW(a: PUniChar): boolean;
function IsAbsolutePath(a: PChar): boolean;

//Checks if the path is of type '\\.\'
function IsDevicePathA(a: PAnsiChar): boolean;
function IsDevicePathW(a: PUniChar): boolean;
function IsDevicePath(a: PChar): boolean;

//Checks if the path is of type '\\?\'
function IsKernelFilePathA(a: PAnsiChar): boolean;
function IsKernelFilePathW(a: PUniChar): boolean;
function IsKernelFilePath(a: PChar): boolean;

//Checks if the path is of type '\\?\' or '\\.\'
function IsKernelPathA(a: PAnsiChar): boolean;
function IsKernelPathW(a: PUniChar): boolean;
function IsKernelPath(a: PChar): boolean;


(*
 ��������� ������������ ����� ����� ������� ���� '*f.?sd'.
 �������:
   1. ������� �������� �������
   2. ������ * �������� ����� ����� ����� ������
   3. ������ ? �������� ����� ����, ����� �����
 ����:
   http://xoomer.virgilio.it/acantato/dev/wildcard/wildmatch.html
*)
function WildcardMatchA(a, w: PAnsiChar): boolean;
function WildcardMatchW(a, w: PUniChar): boolean;
function WildcardMatch(a, w: PChar): boolean;

//�� �� �����, �� � ������ ��������
function WildcardMatchCaseA(a, w: PAnsiChar): boolean;
function WildcardMatchCaseW(a, w: PUniChar): boolean;
function WildcardMatchCase(a, w: PChar): boolean;

//������� ��� ���������� ShGetFolderPath
function GetFolderPathA(folder: integer): AnsiString;
function GetFolderPathW(folder: integer): UniString;
function GetFolderPath(folder: integer): string;


//Expands environment variables
function ExpandStringA(str: PAnsiChar): AnsiString;
function ExpandStringW(str: PUniChar): UniString;
function ExpandString(str: PChar): string;

//Appends root dir to relative paths.
function ExpandPathA(path: AnsiString; root: AnsiString): AnsiString;
function ExpandPathW(path: UniString; root: UniString): UniString;
function ExpandPath(path: string; root: string): string;


//Wide versions of various path utils
//�� ����� ������������ ����������� � ��������� �������
function LastDelimiterA(const Delimiters, S: AnsiString): Integer;
function LastDelimiterW(const Delimiters, S: UniString): Integer;
//������ ���������� �����
function ChangeFileExtA(const FileName, Extension: AnsiString): AnsiString;
function ChangeFileExtW(const FileName, Extension: UniString): UniString;
//���������� ���� � �����, ������� ��������� �����������
function ExtractFilePathA(const FileName: AnsiString): AnsiString;
function ExtractFilePathW(const FileName: UniString): UniString;
//���������� ��� ����� ��� ����
function ExtractFileNameA(const FileName: AnsiString): AnsiString;
function ExtractFileNameW(const FileName: UniString): UniString;
//��������� ��� ����� �� �������, ��������� /..
function ExpandFileNameA(const FileName: AnsiString): AnsiString;
function ExpandFileNameW(const FileName: UniString): UniString;

//������ � ������������
function GetCurrentDirA: AnsiString;
function GetCurrentDirW: UniString;
function SetCurrentDirA(const Dir: AnsiString): Boolean;
function SetCurrentDirW(const Dir: UniString): Boolean;
function CreateDirA(const Dir: AnsiString): Boolean;
function CreateDirW(const Dir: UniString): Boolean;
function RemoveDirA(const Dir: AnsiString): Boolean;
function RemoveDirW(const Dir: UniString): Boolean;
function ForceDirectoriesA(Dir: AnsiString): Boolean;
function ForceDirectoriesW(Dir: UniString): Boolean;


//Returns full image address for specified module
//If hModule is zero, returns full executable image address
function GetModuleFilenameStrA(hModule: HMODULE = 0): AnsiString;
function GetModuleFilenameStrW(hModule: HMODULE = 0): UniString;
function GetModuleFilenameStr(hModule: HMODULE = 0): string;

function GetModulePathByNameA(ModuleName: PAnsiChar): AnsiString;
function GetModulePathByNameW(ModuleName: PUniChar): UniString;
function GetModulePathByName(ModuleName: PChar): string;

//Returns application main folder (where executable is placed)
function AppFolderA: AnsiString;
function AppFolderW: UniString;
function AppFolder: string;

//Returns application executable name without path
function AppFilenameA: AnsiString;
function AppFilenameW: UniString;
function AppFilename: string;

//Returns application parameters without app filename
function AppParamsA: AnsiString;
function AppParamsW: UniString;
function AppParams: string;

//Returns current module folder (where binary file is placed)
function ThisModuleFolderA: AnsiString;
function ThisModuleFolderW: UniString;
function ThisModuleFolder: string;

//Returns current module name without path
function ThisModuleFilenameA: AnsiString;
function ThisModuleFilenameW: UniString;
function ThisModuleFilename: string;

//���������� ����� Windows
function GetWindowsDirA: AnsiString;
function GetWindowsDirW: UniString;
function GetWindowsDir: string;


//���������� ������������ ���������� ����� ��� �����
function GetParentDirectoryA(path: AnsiString): AnsiString;
function GetParentDirectoryW(path: UniString): UniString;
function GetParentDirectory(path: string): string;

//������ ��� ����� �� ������ � ���������� �����.
function ForceFilePathA(Filename: AnsiString): boolean;
function ForceFilePathW(Filename: UniString): boolean;
function ForceFilePath(Filename: string): boolean;

//���������� ������ ���� � ��� ����� �� ��������������, �.�. ��������� ����������� (�����, ���������)
function GetFullPathNameStrA(Filename: AnsiString): AnsiString;
function GetFullPathNameStrW(Filename: UniString): UniString;
function GetFullPathNameStr(Filename: string): string;


type
  TNameGenOptions = (ngmHexadec, ngmCurDate, ngmCurTime);
  TNameGenMethod = set of TNameGenOptions;

//���������� ��������� ��� ����� �� ��������, ��������� �� ������
function GetRandomFilename(APrefix, AExtension: string; AMethod: TNameGenMethod = [ngmHexadec]): string;

{ ���������� ������ ������ �� ����� }
function ListFiles(const path: string; attr: integer): TStringArray;

resourcestring
  eCannotObtainSpecialFolderPath = 'Cannot obtain special folder path.';

implementation
uses WideStrUtils, SystemUtils, ShFolder, SysConst;
//SysConst is needed in some CompilerVersion<21 function reimplementations.

//Checks if the path is of type 'C:\[rest]'
function IsDriveFolderPathA(a: PAnsiChar): boolean;
begin
 //C:
  Result := (a <> nil) and (a^ <> #00) and AnsiCharIsLatinSymbol(a^)
    and (a[1]=':')
 //������ ���� ����� ������, ���� "\"
    and ((a[2]='\') or (a[2]=#00))
end;

function IsDriveFolderPathW(a: PUniChar): boolean;
begin
 //C:
  Result := (a <> nil) and (a^ <> #00) and WideCharIsLatinSymbol(a^)
    and (a[1]=':')
 //������ ���� ����� ������, ���� "\"
    and ((a[2]='\') or (a[2]=#00));
end;

function IsDriveFolderPath(a: PChar): boolean;
begin
 {$IFDEF UNICODE}
  Result := IsDriveFolderPathW(a);
 {$ELSE}
  Result := IsDriveFolderPathA(a);
 {$ENDIF}
end;

//Checks if the path is of type '\\[rest]'
function IsServerSharePathA(a: PAnsiChar): boolean;
begin
  Result := (a <> nil) and (a^ <> #00) and (a[0]='\') and (a[1]='\');
end;

function IsServerSharePathW(a: PUniChar): boolean;
begin
  Result := (a <> nil) and (a^ <> #00) and (a[0]='\') and (a[1]='\');
end;

function IsServerSharePath(a: PChar): boolean;
begin
 {$IFDEF UNICODE}
  Result := IsServerSharePathW(a);
 {$ELSE}
  Result := IsServerSharePathA(a);
 {$ENDIF}
end;

//Returns true if the path is relative one.
function IsRelativePathA(a: PAnsiChar): boolean;
begin
 //Absolute paths have one of the following forms:
 //  C:\[path]
 //  \\[path]
 //  \\.\[path]
 //  \\?\[path]
 //Latter two are identified as ServerSharePaths, but that's fine, we don't care.

  Result := (not IsDriveFolderPathA(a)) and (not IsServerSharePathA(a));
end;

function IsRelativePathW(a: PUniChar): boolean;
begin
  Result := (not IsDriveFolderPathW(a)) and (not IsServerSharePathW(a));
end;

function IsRelativePath(a: PChar): boolean;
begin
 {$IFDEF UNICODE}
  Result := IsRelativePathW(a);
 {$ELSE}
  Result := IsRelativePathA(a);
 {$ENDIF}
end;

function IsAbsolutePathA(a: PAnsiChar): boolean;
begin
  Result := not IsRelativePathA(a);
end;

function IsAbsolutePathW(a: PUniChar): boolean;
begin
  Result := not IsRelativePathW(a);
end;

function IsAbsolutePath(a: PChar): boolean;
begin
  Result := not IsRelativePath(a);
end;

//Checks if the path is of type '\\.\'
function IsDevicePathA(a: PAnsiChar): boolean;
begin
  Result := (a[0]='\') and (a[1]='\') and (a[2]='.') and (a[3]='\');
end;

function IsDevicePathW(a: PUniChar): boolean;
begin
  Result := (a[0]='\') and (a[1]='\') and (a[2]='.') and (a[3]='\');
end;

function IsDevicePath(a: PChar): boolean;
begin
 {$IFDEF UNICODE}
  Result := IsDevicePathW(a);
 {$ELSE}
  Result := IsDevicePathA(a);
 {$ENDIF}
end;

//Checks if the path is of type '\\?\'
function IsKernelFilePathA(a: PAnsiChar): boolean;
begin
  Result := (a[0]='\') and (a[1]='\') and (a[2]='?') and (a[3]='\');
end;

function IsKernelFilePathW(a: PUniChar): boolean;
begin
  Result := (a[0]='\') and (a[1]='\') and (a[2]='?') and (a[3]='\');
end;

function IsKernelFilePath(a: PChar): boolean;
begin
 {$IFDEF UNICODE}
  Result := IsKernelFilePathW(a);
 {$ELSE}
  Result := IsKernelFilePathA(a);
 {$ENDIF}
end;

//Checks if the path is of type '\\?\' or '\\.\'
function IsKernelPathA(a: PAnsiChar): boolean;
begin
  Result := (a[0]='\') and (a[1]='\') and ((a[2]='?') or (a[2]='.')) and (a[3]='\');
end;

function IsKernelPathW(a: PUniChar): boolean;
begin
  Result := (a[0]='\') and (a[1]='\') and ((a[2]='?') or (a[2]='.')) and (a[3]='\');
end;

function IsKernelPath(a: PChar): boolean;
begin
 {$IFDEF UNICODE}
  Result := IsKernelPathW(a);
 {$ELSE}
  Result := IsKernelPathA(a);
 {$ENDIF}
end;



(*
 ��������� ������������ ����� ����� ������� ���� '*f.?sd'.
*)
function WildcardMatchA(a, w: PAnsiChar): boolean;
begin
  Result := WildcardMatchCaseA(
    PAnsiChar(AnsiLowerCase(AnsiString(a))),
    PAnsiChar(AnsiLowerCase(AnsiString(w))));
end;

function WildcardMatchW(a, w: PUniChar): boolean;
begin
 {$IFDEF UNICODE}
 //More efficient to stay away from WideString
  Result := WildcardMatchCaseW(
    PWideChar(LowerCase(a)),
    PWideChar(LowerCase(w)));
 {$ELSE}
  Result := WildcardMatchCaseW(
    PWideChar(WideLowerCase(a)),
    PWideChar(WideLowerCase(w)));
 {$ENDIF}
end;

function WildcardMatch(a, w: PChar): boolean;
begin
 {$IFDEF UNICODE}
  Result := WildcardMatchCaseW(
    PWideChar(StrLower(a)),
    PWideChar(StrLower(w)));
 {$ELSE}
  Result := WildcardMatchCaseA(
    PAnsiChar(StrLower(a)),
    PAnsiChar(StrLower(w)));
 {$ENDIF}
end;


//�� �� �����, �� � ������ ��������
//��������� ������� � ��� ������� ���������!
function WildcardMatchCaseA(a, w: PAnsiChar): boolean;
label new_segment, test_match;
var i: integer;
  star: boolean;
begin
new_segment:
  star := false;
  if w^='*' then begin
    star := true;
    repeat Inc(w) until w^ <> '*';
  end;

test_match:
  i := 0;
  while (w[i]<>#00) and (w[i]<>'*') do
    if a[i] <> w[i] then begin
      if a[i]=#00 then begin
        Result := false;
        exit;
      end;
      if (w[i]='?') and (a[i] <> '.') then begin
        Inc(i);
        continue;
      end;
      if not star then begin
        Result := false;
        exit;
      end;
      Inc(a);
      goto test_match;
    end else
      Inc(i);

  if w[i]='*' then begin
    Inc(a, i);
    Inc(w, i);
    goto new_segment;
  end;

  if a[i]=#00 then begin
    Result := true;
    exit;
  end;

  if (i > 0) and (w[i-1]='*') then begin
    Result := true;
    exit;
  end;

  if not star then begin
    Result := false;
    exit;
  end;

  Inc(a);
  goto test_match;
end;

function WildcardMatchCaseW(a, w: PUniChar): boolean;
label new_segment, test_match;
var i: integer;
  star: boolean;
begin
new_segment:
  star := false;
  if w^='*' then begin
    star := true;
    repeat Inc(w) until w^ <> '*';
  end;

test_match:
  i := 0;
  while (w[i]<>#00) and (w[i]<>'*') do
    if a[i] <> w[i] then begin
      if a[i]=#00 then begin
        Result := false;
        exit;
      end;
      if (w[i]='?') and (a[i] <> '.') then begin
        Inc(i);
        continue;
      end;
      if not star then begin
        Result := false;
        exit;
      end;
      Inc(a);
      goto test_match;
    end else
      Inc(i);

  if w[i]='*' then begin
    Inc(a, i);
    Inc(w, i);
    goto new_segment;
  end;

  if a[i]=#00 then begin
    Result := true;
    exit;
  end;

  if (i > 0) and (w[i-1]='*') then begin
    Result := true;
    exit;
  end;

  if not star then begin
    Result := false;
    exit;
  end;

  Inc(a);
  goto test_match;
end;

function WildcardMatchCase(a, w: PChar): boolean;
begin
 {$IFDEF UNICODE}
  Result := WildcardMatchCaseW(
    PWideChar(StrLower(a)),
    PWideChar(StrLower(w)));
 {$ELSE}
  Result := WildcardMatchCaseA(
    PAnsiChar(StrLower(a)),
    PAnsiChar(StrLower(w)));
 {$ENDIF}
end;


////////////////////////////////////////////////////////////////////////////////

function GetFolderPathA(folder: integer): AnsiString;
const SHGFP_TYPE_CURRENT = 0;
var hr: HRESULT;
begin
  SetLength(Result, MAX_PATH+1);
  hr := SHGetFolderPathA(0, folder, 0, SHGFP_TYPE_CURRENT, @Result[1]);
  if FAILED(hr) then
    raise Exception.Create(eCannotObtainSpecialFolderPath);
 //Truncate result
  SetLength(Result, StrLen(PAnsiChar(Result)));
end;

function GetFolderPathW(folder: integer): UniString;
const SHGFP_TYPE_CURRENT = 0;
var hr: HRESULT;
begin
  SetLength(Result, MAX_PATH+1);
  hr := SHGetFolderPathW(0, folder, 0, SHGFP_TYPE_CURRENT, @Result[1]);
  if FAILED(hr) then
    raise Exception.Create(eCannotObtainSpecialFolderPath);

 //Truncate result
  SetLength(Result, WStrLen(PWideChar(Result)));
end;

function GetFolderPath(folder: integer): string;
begin
 {$IFDEF UNICODE}
  Result := GetFolderPathW(folder);
 {$ELSE}
  Result := GetFolderPathA(folder);
 {$ENDIF}
end;


////////////////////////////////////////////////////////////////////////////////
//Expands environment variables
function ExpandStringA(str: PAnsiChar): AnsiString;
var p1, p2: PAnsiChar;
  var_name: AnsiString;
begin
  Result := '';

 //First, expand environment vars
  p2 := str;
  p1 := StrPos(p2, '%');
  while p1 <> nil do begin
   //Copy the part before the opening %
    Result := Result + SubStrPchA(p2, p1);
    Inc(p1); //skip %

    p2 := StrPos(p1, '%'); //Unicode Delphi still keeps ansi version too
    if p2=nil then begin //misconstructred string
     //just copy the remainder
      Result := Result + p1;
     //and stop
      p1 := nil;
      continue;
    end;

   //copy the var name
    var_name := SubStrPchA(p1, p2);
    Result := Result + AnsiString(GetEnvVar(WideString(var_name)));

   //find next inclusion
    Inc(p2); //skip %
    p1 := StrPos(p2, '%');
  end;

 //Copy the remainder
  Result := Result + p2;
end;

function ExpandStringW(str: PUniChar): UniString;
var p1, p2: PWideChar;
  var_name: WideString;
begin
  Result := '';

 //First, expand environment vars
  p2 := str;
  p1 := WStrPos(p2, '%');
  while p1 <> nil do begin
   //Copy the part before the opening %
    Result := Result + SubStrPchW(p2, p1);
    Inc(p1); //skip %

   {$IF CompilerVersion >= 21}
    p2 := StrPos(p1, '%'); //Unicode Delphi has more efficient StrPos
   {$ELSE}
    p2 := WStrPos(p1, '%');
   {$IFEND}
    if p2=nil then begin //misconstructred string
     //just copy the remainder
      Result := Result + p1;
     //and stop
      p1 := nil;
      continue;
    end;

   //copy the var name
    var_name := SubStrPchW(p1, p2);
    Result := Result + GetEnvVar(var_name);

   //find next inclusion
    Inc(p2); //skip %
   {$IF CompilerVersion >= 21}
    p1 := StrPos(p2, '%');
   {$ELSE}
    p1 := WStrPos(p2, '%');
   {$IFEND}
  end;

 //Copy the remainder
  Result := Result + p2;
end;

function ExpandString(str: PChar): string;
begin
 {$IFDEF UNICODE}
  Result := ExpandStringW(str);
 {$ELSE}
  Result := ExpandStringA(str);
 {$ENDIF}
end;

//Appends root dir to relative paths.
function ExpandPathA(path: AnsiString; root: AnsiString): AnsiString;
begin
  if not IsRelativePathA(PAnsiChar(path)) then begin
    Result := path;
    exit;
  end;

 //Decide whether to add another '\'
  if ((Length(path) > 1) and (path[1]='\'))
  or ((Length(root) > 1) and (root[Length(root)]='\')) then
    Result := root + path
  else
    Result := root + '\' + path;
end;

function ExpandPathW(path: UniString; root: UniString): UniString;
begin
  if not IsRelativePathW(PWideChar(path)) then begin
    Result := path;
    exit;
  end;

 //Decide whether to add another '\'
  if ((Length(path) > 1) and (path[1]='\'))
  or ((Length(root) > 1) and (root[Length(root)]='\')) then
    Result := root + path
  else
    Result := root + '\' + path;
end;

function ExpandPath(path: string; root: string): string;
begin
 {$IFDEF UNICODE}
  Result := ExpandPathW(path, root);
 {$ELSE}
  Result := ExpandPathA(path, root);
 {$ENDIF}
end;


////////////////////////////////////////////////////////////////////////////////
/// Wide versions of various path utils
/// �� ����� ������������ ����������� � ��������� �������.
/// ����-������ ������ ����������� � ��������� �������, �� ���� ��-�������.

function LastDelimiterA(const Delimiters, S: AnsiString): Integer;
begin
{$IFDEF UNICODE}
  Result := LastDelimiter(string(Delimiters), string(S));
{$ELSE}
  Result := LastDelimiter(Delimiters, S);
{$ENDIF}
end;

function LastDelimiterW(const Delimiters, S: UniString): Integer;
{$IF CompilerVersion >= 21}
begin
  Result := SysUtils.LastDelimiter(Delimiters, S);
end;
{$ELSE}
var P: PWideChar;
begin
  Result := Length(S);
  P := PWideChar(Delimiters);
  while Result > 0 do
  begin
    if (S[Result] <> #0) and (WStrScan(P, S[Result]) <> nil) then
     //Every byte is considered single-byte.
      Exit;
    Dec(Result);
  end;
end;
{$IFEND}

function ChangeFileExtA(const FileName, Extension: AnsiString): AnsiString;
begin
{$IF CompilerVersion >= 21}
  Result := AnsiString(ChangeFileExt(string(Filename), string(Extension)));
{$ELSE}
  Result := ChangeFileExt(Filename, Extension);
{$IFEND}
end;

function ChangeFileExtW(const FileName, Extension: UniString): UniString;
{$IF CompilerVersion >= 21}
begin
  Result := ChangeFileExt(Filename, Extension);
end;
{$ELSE}
var I: Integer;
begin
  I := LastDelimiterW('.' + PathDelim + DriveDelim,Filename);
  if (I = 0) or (FileName[I] <> '.') then I := MaxInt;
  Result := Copy(FileName, 1, I - 1) + Extension;
end;
{$IFEND}

//���������� ���� � �����, ������� ��������� �����������
function ExtractFilePathA(const FileName: AnsiString): AnsiString;
begin
{$IF CompilerVersion >= 21}
  Result := AnsiString(ExtractFilePath(string(Filename)));
{$ELSE}
  Result := ExtractFilePath(Filename);
{$IFEND}
end;

function ExtractFilePathW(const FileName: UniString): UniString;
{$IF CompilerVersion >= 21}
begin
  Result := SysUtils.ExtractFilePath(Filename);
end;
{$ELSE}
var I: Integer;
begin
  I := LastDelimiterW(PathDelim + DriveDelim, FileName);
  Result := Copy(FileName, 1, I);
end;
{$IFEND}

function ExtractFileNameA(const FileName: AnsiString): AnsiString;
begin
{$IF CompilerVersion >= 21}
  Result := AnsiString(ExtractFilename(string(Filename)));
{$ELSE}
  Result := ExtractFilename(Filename);
{$IFEND}
end;

function ExtractFileNameW(const FileName: UniString): UniString;
{$IF CompilerVersion >= 21}
begin
  Result := SysUtils.ExtractFileName(Filename);
end;
{$ELSE}
var I: Integer;
begin
  I := LastDelimiterW(PathDelim + DriveDelim, FileName);
  Result := Copy(FileName, I + 1, MaxInt);
end;
{$IFEND}


//��������� ��������� ��������:
//  1. ��������� ���������� ���� (������� �����) � ������, ��� �������������.
//  2. ����������� ��� / � \ (���� �� ���� �������� \\?\)
//  3. ���������� .\ � ..\
function ExpandFileNameA(const FileName: AnsiString): AnsiString;
begin
{$IF CompilerVersion >= 21}
  Result := AnsiString(ExtractFilename(string(Filename)));
{$ELSE}
  Result := ExtractFilename(Filename);
{$IFEND}
end;

function ExpandFileNameW(const FileName: UniString): UniString;
{$IF CompilerVersion >= 21}
begin
  Result := SysUtils.ExpandFileName(Filename);
end;
{$ELSE}
var FName: PWideChar;
  sz: integer;
begin
  FName := nil;
  SetLength(Result, MAX_PATH+1);
  sz := GetFullPathNameW(PWideChar(FileName), MAX_PATH, PWideChar(Result), FName);
  if sz > MAX_PATH then begin
    SetLength(Result, sz+1);
    sz := GetFullPathNameW(PWideChar(FileName), sz, PWideChar(Result), FName);
  end;
  if sz < Length(Result) then
    SetLength(Result, sz);
end;
{$IFEND}

function GetCurrentDirA: AnsiString;
begin
{$IF CompilerVersion >= 21}
  Result := AnsiString(GetCurrentDir);
{$ELSE}
  Result := GetCurrentDir;
{$IFEND}
end;

function GetCurrentDirW: UniString;
{$IF CompilerVersion >= 21}
begin
  Result := SysUtils.GetCurrentDir();
end;
{$ELSE}
var len: integer;
  res: cardinal;
begin
  len := MAX_PATH+1;
  SetLength(Result, len);
  res := GetCurrentDirectoryW(len, PWideChar(Result));
  while integer(res) > len do begin
    len := res+1;
    SetLength(Result, len);
    res := GetCurrentDirectoryW(len, PWideChar(Result));
  end;
  if res = 0 then RaiseLastOsError;
  SetLength(Result, res); //truncate
end;
{$IFEND}

function SetCurrentDirA(const Dir: AnsiString): Boolean;
begin
{$IF CompilerVersion >= 21}
  Result := SetCurrentDir(string(dir));
{$ELSE}
  Result := SetCurrentDir(dir);
{$IFEND}
end;

function SetCurrentDirW(const Dir: UniString): Boolean;
{$IF CompilerVersion >= 21}
begin
  Result := SysUtils.SetCurrentDir(dir);
end;
{$ELSE}
begin
  Result := SetCurrentDirectoryW(PWideChar(Dir));
end;
{$IFEND}

function CreateDirA(const Dir: AnsiString): Boolean;
begin
{$IF CompilerVersion >= 21}
  Result := CreateDir(string(Dir));
{$ELSE}
  Result := CreateDir(Dir);
{$IFEND}
end;

function CreateDirW(const Dir: UniString): Boolean;
{$IF CompilerVersion >= 21}
begin
  Result := SysUtils.CreateDir(dir);
end;
{$ELSE}
begin
  Result := CreateDirectoryW(PWideChar(Dir), nil);
end;
{$IFEND}

function RemoveDirA(const Dir: AnsiString): Boolean;
begin
{$IF CompilerVersion >= 21}
  Result := RemoveDir(string(Dir));
{$ELSE}
  Result := RemoveDir(Dir);
{$IFEND}
end;

function RemoveDirW(const Dir: UniString): Boolean;
{$IF CompilerVersion >= 21}
begin
  Result := SysUtils.RemoveDir(dir);
end;
{$ELSE}
begin
  Result := RemoveDirectoryW(PWideChar(Dir));
end;
{$IFEND}

function ForceDirectoriesA(Dir: AnsiString): Boolean;
begin
{$IF CompilerVersion >= 21}
  Result := ForceDirectories(string(Dir));
{$ELSE}
  Result := ForceDirectories(Dir);
{$IFEND}
end;

function ForceDirectoriesW(Dir: UniString): Boolean;
{$IF CompilerVersion >= 21}
begin
  Result := SysUtils.ForceDirectories(Dir);
end;
{$ELSE}
var
  E: EInOutError;
begin
  Result := True;
  if Dir = '' then
  begin
    E := EInOutError.CreateRes(@SCannotCreateDir);
    E.ErrorCode := 3;
    raise E;
  end;
  Dir := ExcludeTrailingPathDelimiter(Dir); {TODO: ExclusdeTrailingPathDelimiterW}
  if (Length(Dir) < 3) or DirectoryExists(Dir) {TODO: DirectoryExistsW}
    or (ExtractFilePath(Dir) = Dir) then Exit; // avoid 'xyz:\' problem. {TODO: ExtractFilePathW}
  Result := ForceDirectories(ExtractFilePath(Dir)) and CreateDir(Dir); {TODO: ForceDirectoriesW, ExtractFilePathW}
end;
{$IFEND}

////////////////////////////////////////////////////////////////////////////////

//Max length, in symbols, of supported image path size.
const
  MAX_PATH_LEN = 8192;

(*
  Returns full image address for specified module
  If hModule is zero, returns full executable image address
*)
function GetModuleFilenameStrA(hModule: HMODULE = 0): AnsiString;
var nSize, nRes: dword;
begin
 (*
   MSDN:
    If the length of the path is less than nSize characters, the function succeeds
    and the path is returned as a null-terminated string.

    If the length of the path exceeds nSize, the function succeeds and the string
    is truncated to nSize characters including the terminating null character.

    Windows XP/2000: The string is truncated to nSize characters and is not null terminated.
 *)

  nSize := 256;
  SetLength(Result, nSize);

  nRes := GetModuleFilenameA(hModule, @Result[1], nSize);
  while (nRes <> 0) and (nRes >= nSize) and (nSize < MAX_PATH_LEN) do begin
    nSize := nSize * 2;
    SetLength(Result, nSize+1);
    nRes := GetModuleFilenameA(hModule, @Result[1], nSize);
  end;

  if nRes = 0 then begin
    Result := ''; //cannot retrieve path, return null
    exit;
  end;

  if nRes >= nSize then begin
    Result := ''; //path too long, exceeded MAX_PATH_LEN and still not enough, return null
    exit;
  end;

  SetLength(Result, nRes); //else truncate the string, set terminating null
end;

function GetModuleFilenameStrW(hModule: HMODULE = 0): UniString;
var nSize, nRes: dword;
begin
  nSize := 256;
  SetLength(Result, nSize);

  nRes := GetModuleFilenameW(hModule, @Result[1], nSize);
  while (nRes <> 0) and (nRes >= nSize) and (nSize < MAX_PATH_LEN) do begin
    nSize := nSize * 2;
    SetLength(Result, nSize);
    nRes := GetModuleFilenameW(hModule, @Result[1], nSize);
  end;

  if nRes = 0 then begin
    Result := '';
    exit;
  end;

  if nRes >= nSize then begin
    Result := '';
    exit;
  end;

  SetLength(Result, nRes);
end;

function GetModuleFilenameStr(hModule: HMODULE = 0): string;
begin
 {$IF CompilerVersion >= 21}
  Result := GetModuleFilenameStrW(hModule);
 {$ELSE}
  Result := GetModuleFilenameStrA(hModule);
 {$IFEND}
end;

//Returns full module path and filename by it's name
function GetModulePathByNameA(ModuleName: PAnsiChar): AnsiString;
var Name: array[0..255] of AnsiChar;
  hMod: HMODULE;
begin
  result := '';
  ZeroMemory(@Name, SizeOf(Name));
  hMod := GetModuleHandleA(ModuleName);
  if (hMod > 0) and (GetModuleFileNameA(hMod, @Name, Length(Name)) > 0) then
    Result := ExtractFilePathA(Name);
end;

function GetModulePathByNameW(ModuleName: PUniChar): UniString;
var Name: array[0..255] of UniChar;
  hMod: HMODULE;
begin
  result := '';
  ZeroMemory(@Name, SizeOf(Name));
  hMod := GetModuleHandleW(ModuleName);
  if (hMod > 0) and (GetModuleFileNameW(hMod, @Name, Length(Name)) > 0) then
    Result := ExtractFilePathW(Name);
end;

function GetModulePathByName(ModuleName: PChar): string;
begin
 {$IF CompilerVersion >= 21}
  Result := GetModulePathByNameW(ModuleName);
 {$ELSE}
  Result := GetModulePathByNameA(ModuleName);
 {$IFEND}
end;

//��������� ���������� � ������������� ����, ���������� ���������� ����
//� ������������ ����� (����), ���� ������ ������, ���� ������� ���.
function GetParentDirectoryA(path: AnsiString): AnsiString;
begin
 //���� ���������� � ����-������
  Result := AnsiString(GetParentDirectoryW(WideString(path)));
end;

function GetParentDirectoryW(path: UniString): UniString;
var i, j: integer;
  RestoreBackslash: boolean; //�������� � ����� �������, ���� ��������� �� �����
begin
 //��������� ���������� ����, ����������� \, ���������� "..\" � ".\"
  Result := ExpandFileName(path);
  if Length(Result)<1 then exit;

 //������� ����������� "\"
  i := Length(Result);
  while (i>=1) and (Result[i]='\') do
    Dec(i);

 //������� �� �� ���������� � ����� "\"
  while (i>=1) and (Result[i]<>'\') do
    Dec(i);
 //������� ���� ����������� (��������� ������� "\\")
  while (i>=1) and (Result[i]='\') do
    Dec(i);
  if i<=0 then begin
    Result := '';
    exit;
  end;

 //�������� ����� ��������:
 //  \\.\, \\?\                    +
 //  \\Server\                     +
 //  \\?\UNC\Server\
 //  \\?\UNC\

 //���������� ��������:
 //  D:\                           +
 //  \\?\D:\                       +
 //  \\.\DeviceName\


  RestoreBackslash := false;

 //j ��������� �� ������� ������������ ��������� ���� (�����������)
  j := 1;
  if IsDevicePathW(PWideChar(Result)) then begin
    Inc(j, 4);
  (* � �������� �������� ������� ������ ���� ��������������� ������
    while (j <= Length(Result)) and (Result[j]='\') do
      Inc(j);
   //���������� ������ ���
    while (j <= Length(Result)) and (Result[j]<>'\') do
      Inc(j);
    while (j <= Length(Result)) and (Result[j]='\') do
      Inc(j);
   //����� ������ ������� ��-�������������� ����������
  *)
    RestoreBackslash := true; //� ������� ������ ����
  end else

  if IsKernelFilePathW(PWideChar(Result)) then begin
    Inc(j, 4);
    while (j <= Length(Result)) and (Result[j]='\') do
      Inc(j);
   //Special case: \\?\UNC\ - ���������� "UNC\"
    if (j <= Length(Result)-3) and (Result[j]='U') and (Result[j+1]='N') and (Result[j+2]='C')
      and ((j+4 > Length(Result)) or (Result[j+4]='\')) then
    begin
      Inc(j, 4);
     //���������� ������ ���
      while (j <= Length(Result)) and (Result[j]<>'\') do
        Inc(j);
      while (j <= Length(Result)) and (Result[j]='\') do
        Inc(j);
     //����� ������ ������� �� ����� �������
    end;
   //�� ���� ��������� ������� ��� ��� �����. ������ ��������� �������
    RestoreBackslash := true
  end else

  if IsServerSharePathW(PWideChar(Result)) then begin
    Inc(j, 2);
   //���������� ������ ���
    while (j <= Length(Result)) and (Result[j]<>'\') do
      Inc(j);
    while (j <= Length(Result)) and (Result[j]='\') do
      Inc(j);
    RestoreBackslash := true;
  end else

  if IsDriveFolderPathW(PWideChar(Result)) then begin
   //����������� �� ������
    RestoreBackslash := true;
  end;


 //���� ��� ��������� ����� ������ ����, ���������� ����
  if i < j then begin
    Result := '';
    exit;
  end else begin
   //���� ���������� �� ������� ���������, ���������� RestoreBackslash
    while j<i do
      if Result[j]='\' then begin
        RestoreBackslash := false;
        break;
      end
      else Inc(j);

   //����� �������� �� ���������
    if RestoreBackslash then begin
      SetLength(Result, i+1);
      Result[i+1] := '\';
    end else
      SetLength(Result, i);
    exit;
  end;
end;

function GetParentDirectory(path: string): string;
begin
 //��������� ����-������ �� ����� ��������� �� ����-������, ��������� ���:
  Result := GetParentDirectoryW(path);
end;


//Returns application main folder (where executable is placed)
function AppFolderA: AnsiString;
begin
  Result := GetModuleFilenameStrA();
  if Result <> '' then
    Result := ExtractFilePathA(Result);
end;

function AppFolderW: UniString;
begin
  Result := GetModuleFilenameStrW();
  if Result <> '' then
    Result := ExtractFilePathW(Result);
end;

function AppFolder: string;
begin
 {$IF CompilerVersion >= 21}
  Result := AppFolderW;
 {$ELSE}
  Result := AppFolderA;
 {$IFEND}
end;

//Returns application main folder (where executable is placed)
function AppFilenameA: AnsiString;
begin
  Result := GetModuleFilenameStrA();
  if Result <> '' then
    Result := ExtractFilenameA(Result);
end;

function AppFilenameW: UniString;
begin
  Result := GetModuleFilenameStrW();
  if Result <> '' then
    Result := ExtractFilenameW(Result);
end;

function AppFilename: string;
begin
 {$IF CompilerVersion >= 21}
  Result := AppFilenameW;
 {$ELSE}
  Result := AppFilenameA;
 {$IFEND}
end;

//Returns application parameters without app filename
function AppParamsA: AnsiString;
begin
  Result := AnsiString(AppParamsW); { parsing is done in unicode just to be safe }
end;

function AppParamsW: UniString;
var pw: PWideChar;
  inquotes: boolean;
begin
  Result := GetCommandLine();
  if Result='' then exit;

  pw := @Result[1];
  inquotes := false;
  while (pw^<>#00) and (inquotes or (pw^<>' ')) do begin
    if pw^='"' then
      inquotes := not inquotes;
    Inc(pw);
  end;

 { Skip starting spaces }
  while (pw^=' ') do Inc(pw);

  Result := pw;
end;

function AppParams: string;
begin
 {$IF CompilerVersion >= 21}
  Result := AppParamsW;
 {$ELSE}
  Result := AppParamsA;
 {$IFEND}
end;

//Returns current module folder (where executable is placed)
function ThisModuleFolderA: AnsiString;
begin
  Result := GetModuleFilenameStrA(SysInit.HInstance);
  if Result <> '' then
    Result := ExtractFilePathA(Result);
end;

function ThisModuleFolderW: UniString;
begin
  Result := GetModuleFilenameStrW(SysInit.HInstance);
  if Result <> '' then
    Result := ExtractFilePathW(Result);
end;

function ThisModuleFolder: string;
begin
 {$IF CompilerVersion >= 21}
  Result := ThisModuleFolderW;
 {$ELSE}
  Result := ThisModuleFolderA;
 {$IFEND}
end;

//Returns current main folder (where executable is placed)
function ThisModuleFilenameA: AnsiString;
begin
  Result := GetModuleFilenameStrA(SysInit.HInstance);
  if Result <> '' then
    Result := ExtractFilenameA(Result);
end;

function ThisModuleFilenameW: UniString;
begin
  Result := GetModuleFilenameStrW(SysInit.HInstance);
  if Result <> '' then
    Result := ExtractFilenameW(Result);
end;

function ThisModuleFilename: string;
begin
 {$IF CompilerVersion >= 21}
  Result := ThisModuleFilenameW;
 {$ELSE}
  Result := ThisModuleFilenameA;
 {$IFEND}
end;


function GetWindowsDirA: AnsiString;
var res: integer;
begin
  SetLength(Result, MAX_PATH+1);
  res := GetWindowsDirectoryA(PAnsiChar(@Result[1]), MAX_PATH);
  if res > MAX_PATH then begin
    SetLength(Result, res+1);
    res := GetWindowsDirectoryA(PAnsiChar(@Result[1]), res);
    Assert(res <= MAX_PATH);
  end;
  if res=0 then
    RaiseLastOsError();
  SetLength(Result, res);
end;

function GetWindowsDirW: UniString;
var res: integer;
begin
  SetLength(Result, MAX_PATH+1);
  res := GetWindowsDirectoryW(PWideChar(@Result[1]), MAX_PATH);
  if res > MAX_PATH then begin
    SetLength(Result, res+1);
    res := GetWindowsDirectoryW(PWideChar(@Result[1]), res);
    Assert(res <= MAX_PATH);
  end;
  if res=0 then
    RaiseLastOsError();
  SetLength(Result, res);
end;

function GetWindowsDir: string;
begin
 {$IF CompilerVersion >= 21}
  Result := GetWindowsDirW;
 {$ELSE}
  Result := GetWindowsDirA;
 {$IFEND}
end;


//������ ��� ����� �� ������ � ���������� �����.
//���� ��������� ����� \ �� �����, ��������� ������� �� ��������, ���������
//���������� �������� ��� �� ����� �����.
//����������� � ����� ������� ����������� ForceDirectories
function ForceFilePathA(Filename: AnsiString): boolean;
var Path: AnsiString;
begin
  Path := ExtractFilePathA(Filename);
  if Path = '' then begin
    Result := true; //������� ���������� ������ ����������
    exit;
  end;

  Result := ForceDirectoriesA(Path);
end;

function ForceFilePathW(Filename: UniString): boolean;
var Path: UniString;
begin
  Path := ExtractFilePathW(Filename);
  if Path = '' then begin
    Result := true; //������� ���������� ������ ����������
    exit;
  end;

  Result := ForceDirectoriesW(Path);
end;

function ForceFilePath(Filename: string): boolean;
begin
 {$IF CompilerVersion >= 21}
  Result := ForceFilePathW(Filename);
 {$ELSE}
  Result := ForceFilePathA(Filename);
 {$IFEND}
end;


function GetFullPathNameStrA(Filename: AnsiString): AnsiString;
var sz: integer;
  lpFilePart: PAnsiChar;
begin
  SetLength(Result, MAX_PATH+1);
  sz := GetFullPathNameA(PAnsiChar(Filename), Length(Result), @Result[1], lpFilePart);
  if sz >= Length(Result) then begin
    SetLength(Result, sz);
    sz := GetFullPathNameA(PAnsiChar(Filename), Length(Result), @Result[1],
      lpFilePart);
  end;
  if (sz=0) or (sz >= Length(Result)) then
    RaiseLastOsError();
  SetLength(Result, StrLen(PAnsiChar(@Result[1]))); //trim
end;

function GetFullPathNameStrW(Filename: UniString): UniString;
var sz: integer;
  lpFilePart: PWideChar;
begin
  SetLength(Result, MAX_PATH+1);
  sz := GetFullPathNameW(PWideChar(Filename), Length(Result), @Result[1], lpFilePart);
  if sz >= Length(Result) then begin
    SetLength(Result, sz);
    sz := GetFullPathNameW(PWideChar(Filename), Length(Result), @Result[1],
      lpFilePart);
  end;
  if (sz=0) or (sz >= Length(Result)) then
    RaiseLastOsError();
  SetLength(Result, WStrLen(PWideChar(@Result[1]))); //trim
end;

function GetFullPathNameStr(Filename: string): string;
begin
{$IFDEF UNICODE}
  Result := GetFullPathNameStrW(Filename);
{$ELSE}
  Result := GetFullPathNameStrA(Filename);
{$ENDIF}
end;

function GetRandomFilename(APrefix, AExtension: string; AMethod: TNameGenMethod = [ngmHexadec]): string;
begin
  Result := APrefix;
  if (ngmCurDate in AMethod) then Result := Result + '_' + ReplaceText(DateToStr(now), DateSeparator, '');
  if (ngmCurTime in AMethod) then Result := Result + '_' + ReplaceText(TimeToStr(now), TimeSeparator, '');
  if (ngmHexadec in AMethod) then Result := Result + '_' + IntToHex(Random($FFFFFF), 6);
  Result := Result + '.' + AExtension;
end;

function ListFiles(const path: string; attr: integer): TStringArray;
var rec: TSearchRec;
  res: integer;
begin
  SetLength(Result, 0);
  res := FindFirst(path, attr, rec);
  while res=0 do begin
    SetLength(Result, Length(Result)+1);
    Result[Length(Result)-1] := rec.Name; 
    res := FindNext(rec);
  end;
  SysUtils.FindClose(rec);
end;

end.
