unit DirectoryEnum;

interface
uses UniStrUtils;

{Enumerates files in a directory and possibly subdirectories,
 and adds them to the list.}
procedure EnumFiles_in(dir, mask: string; subdirs: boolean; var files: TStringArray);
procedure EnumAddFiles(fname: string; subdirs: boolean; var files: TStringArray);
function EnumFiles(fname: string; subdirs: boolean): TStringArray;

procedure AddFile(var files: TStringArray; fname: string); inline;

implementation
uses SysUtils;

procedure AddFile(var files: TStringArray; fname: string); inline;
begin
  SetLength(files, Length(files)+1);
  files[Length(files)-1] := fname;
end;

{Enumerates files in a directory and possibly subdirectories,
 and adds them to the list.}
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

procedure EnumAddFiles(fname: string; subdirs: boolean; var files: TStringArray);
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
  EnumAddFiles(fname, subdirs, Result);
end;

end.