unit ParallelEd2k;
{ Contains ED2K hashing functions, multi- and singlethreaded. }

interface
uses SysUtils, Classes, Windows, md4, FileInfo, UniStrUtils;

//{$DEFINE HASH_STATS}
//Enable to gather hashing statistics

const
  ED2K_CHUNK_SIZE = 9728000;

type
 { Generic hasher }
  TEd2kHasher = class;
  TLeadPartDoneEvent = procedure(Sender: TEd2kHasher; Hash: MD4Digest) of object;
  TEd2kHasher = class
  public { Results }
    FileSize: int64;
    Ed2k: MD4Digest;
    Lead: MD4Digest;

 {$IFDEF HASH_STATS}
  public
    TotalTime: cardinal;
    ReadingTime: cardinal;
    HashingTime: cardinal;
 {$ENDIF}

  protected
    FOnLeadPartDone: TLeadPartDoneEvent;
  public
    Terminated: boolean;
    procedure HashFile(Filename: UniString); virtual; abstract;
    property OnLeadPartDone: TLeadPartDoneEvent read FOnLeadPartDone write FOnLeadPartDone;
  end;

type {Single-threaded hasher}
  TSimpleEd2kHasher = class(TEd2kHasher)
  protected
    buf: pointer;
    Parts: array of MD4Digest;
  public
    constructor Create;
    destructor Destroy; override;
    procedure HashFile(filename: UniString); override;
  end;

type {Multithreaded hasher}
  THashThread = class;

  TParallelEd2kHasher = class(TEd2kHasher)
  protected
    FWakeUp: THandle;
    Workers: array of THashThread;
    WorkerIdle: array of boolean;
    WorkersIdle: integer;
    procedure WakeUp;
    function GetFreeWorker: integer;
    function GetFreeMemoryBlock: integer;
    procedure WaitAllWorkersFree;
    function GetFreeWorkerCount: integer;
    procedure WaitEvent;

  protected
    Parts: array of MD4Digest;
    PartsDone: array of boolean;
    MemoryBlocks: array of pointer;
    MemoryBlocksFree: array of boolean;

  protected
    LeadPartReported: boolean;
  public
    constructor Create(MaxThreads: cardinal = 0);
    destructor Destroy; override;
    procedure HashFile(filename: UniString); override;

  end;

  THashThread = class(TThread)
  protected
    Parent: TParallelEd2kHasher;
    WorkerIndex: integer;
    FWakeUp: THandle;

    Context: Md4Context;

   {$IFDEF HASH_STATS}
    HashingTime: cardinal;
   {$ENDIF}

   {Set these before waking the thread. All the data must be available.
    It'll be released upon completion.}
    JobData: pointer;
    JobSize: integer;
    PartIndex: integer;
    MemBlockIndex: integer;
    procedure HashJob;
  public
    constructor Create(AParent: TParallelEd2kHasher; AWorkerIndex: integer);
    destructor Destroy; override;
    procedure Execute; override;
    procedure Terminate; reintroduce;
    procedure WakeUp;
  end;

const
  ZeroSizeHash: MD4Digest = (
    $d4, $1d, $8c, $d9, $8f, $00, $b2, $04,
    $e9, $80, $09, $98, $ec, $f8, $42, $7e);

function GetFileSizeEx(hFile: THandle; lpFileSize: PInt64): longbool; stdcall; external kernel32;

implementation

constructor TSimpleEd2kHasher.Create;
begin
  inherited Create;
  GetMem(buf, ED2K_CHUNK_SIZE);
end;

destructor TSimpleEd2kHasher.Destroy;
begin
  FreeMem(buf);
  inherited Destroy;
end;

procedure TSimpleEd2kHasher.HashFile(filename: UniString);
var h: THandle;
  BytesRead: cardinal;
  PartIndex: integer;
  Context: MD4Context;
 {$IFDEF HASH_STATS}
  total_tm, tm: cardinal;
 {$ENDIF}
begin
 {$IFDEF HASH_STATS}
  total_tm := GetTickCount;
 {$ENDIF}

  h := CreateFileW(PWideChar(filename), GENERIC_READ, FILE_SHARE_READ, nil,
    OPEN_EXISTING, 0, 0);
  if h=INVALID_HANDLE_VALUE then
    RaiseLastOsError;

  if not GetFileSizeEx(h, @FileSize) then
    RaiseLastOsError();

 { Empty file }
  if FileSize=0 then begin
    Ed2k := ZeroSizeHash;
    Lead := ZeroSizeHash;
    exit;
  end;

 { Allocate parts.
   ED2K always requires last chunk to be incomplete, even when it's size is zero.
     LASTCHUN + K.......
     LASTCHNK + ........
     LASTCH..
 }
  SetLength(Parts, FileSize div ED2K_CHUNK_SIZE+1);

 { Process }
  PartIndex := 0;
  repeat
   {$IFDEF HASH_STATS}
    tm := GetTickCount;
   {$ENDIF}
   { Read next chunk, maybe empty or incomplete }
    if not ReadFile(h, buf^, ED2K_CHUNK_SIZE, BytesRead, nil) then
      RaiseLastOsError;
   {$IFDEF HASH_STATS}
    ReadingTime := ReadingTime + GetTickCount-tm;
   {$ENDIF}

   {$IFDEF HASH_STATS}
    tm := GetTickCount;
   {$ENDIF}
    MD4Init(Context);
    MD4Update(Context, PAnsiChar(buf), BytesRead);
    MD4Final(Context, Parts[PartIndex]);
   {$IFDEF HASH_STATS}
    HashingTime := HashingTime + GetTickCount-tm;
   {$ENDIF}

    if PartIndex=0 then
      if Assigned(FOnLeadPartDone) then
        FOnLeadPartDone(Self, Parts[0]);

    Inc(PartIndex)
  until (PartIndex >= Length(Parts)) or Terminated;

 { Finalize hash }
  Lead := Parts[0];
  if Length(Parts)=1 then begin
    Ed2k := Parts[0];
    exit;
  end;

  MD4Init(Context);
  MD4Update(Context, @Parts[0], Length(Parts)*SizeOf(Md4Digest));
  MD4Final(Context, Ed2k);

  CloseHandle(h);

 {$IFDEF HASH_STATS}
  TotalTime := TotalTime + GetTickCount-total_tm;
 {$ENDIF}
end;

////////////////////////////////////////////////////////////////////////////////

constructor TParallelEd2kHasher.Create(MaxThreads: cardinal = 0);
var sysinfo: SYSTEM_INFO;
  i: integer;
begin
  inherited Create;

 {$IFDEF HASH_STATS}
  TotalTime := 0;
  HashingTime := 0;
  ReadingTime := 0;
 {$ENDIF}

  FWakeUp := CreateEvent(nil, false, false, nil);

 { MD5 hashing is slow, so create as many processing threads as there are cores }
  GetSystemInfo(&sysinfo);
  if (MaxThreads>0) and (MaxThreads < sysinfo.dwNumberOfProcessors) then
    sysinfo.dwNumberOfProcessors := MaxThreads;
  SetLength(Workers, sysinfo.dwNumberOfProcessors);

 { Zero-initialize in case of premature destruction }
  for i := 0 to Length(Workers) - 1 do
    Workers[i] := nil;

 { This controls whether the thread is idle.
   When a thread enters idle state, it sets it's idle cell to true, then wakes
   main thread up.
   After assigning work main thread sets this to false and wakes worker thread up. }
  SetLength(WorkerIdle, Length(Workers));
  for i := 0 to Length(WorkerIdle) - 1 do
    WorkerIdle[i] := true;

 { We allocate all the memory blocks from the start to save on memory reallocations.
   It's alright, if the computer has many cores it's likely to have enough memory. }
  SetLength(MemoryBlocks, Length(Workers)+1); {one for loading}
  for i := 0 to Length(MemoryBlocks)-1 do
    MemoryBlocks[i] := nil;
  for i := 0 to Length(MemoryBlocks)-1 do
    GetMem(MemoryBlocks[i], ED2K_CHUNK_SIZE);

  SetLength(MemoryBlocksFree, Length(MemoryBlocks));
  for i := 0 to Length(MemoryBlocksFree)-1 do
    MemoryBlocksFree[i] := true;

 { Create threads }
  for i := 0 to Length(Workers) - 1 do
    Workers[i] := THashThread.Create(Self, i);
end;

destructor TParallelEd2kHasher.Destroy;
var i: integer;
begin
 { Worker threads }
  for i := 0 to Length(Workers) - 1 do
    FreeAndNil(Workers[i]);

 { Memory blocks }
  for i := 0 to Length(MemoryBlocks) - 1 do begin
    FreeMem(MemoryBlocks[i]);
    MemoryBlocks[i] := nil;
  end;

  CloseHandle(FWakeUp);
  inherited;
end;

{ Wakes the main thread up to check for free workers }
procedure TParallelEd2kHasher.WakeUp;
begin
  SetEvent(FWakeUp);
end;

{ Waits until there are worker threads available. Returns first available thread index. }
function TParallelEd2kHasher.GetFreeWorker: integer;
var i, hr: integer;
begin
  repeat
    for i := 0 to Length(Workers) - 1 do
      if WorkerIdle[i] then begin
        Result := i;
        exit;
      end;

    hr := WaitForSingleObject(FWakeUp, INFINITE);
    if hr <> WAIT_OBJECT_0 then
      RaiseLastOsError();
  until false;
end;

//Calculates free worker count.
//Call from the main thread only.
//This might raise in multithreaded environment, but only main thread can make this number go down.
function TParallelEd2kHasher.GetFreeWorkerCount: integer;
var i: integer;
begin
  Result := 0;
  for i := 0 to Length(Workers) - 1 do
    if WorkerIdle[i] then
      Inc(Result);
end;

//Sleeps until something happens (usually a thread signalling something)
procedure TParallelEd2kHasher.WaitEvent;
var hr: integer;
begin
  hr := WaitForSingleObject(FWakeUp, INFINITE);
  if hr <> WAIT_OBJECT_0 then
    RaiseLastOsError();
end;

{ Waits until all workers become free }
//Deprecated, don't use: there could be different reasons for waking up,
//not only the worker being freed.
procedure TParallelEd2kHasher.WaitAllWorkersFree;
begin
  repeat
    if GetFreeWorkerCount>=Length(Workers) then exit;
    WaitEvent;
  until false;
end;

{ Searches for a first free memory block. This should always be available,
 because we don't search for a next block until we gave out the preious one. }
function TParallelEd2kHasher.GetFreeMemoryBlock: integer;
var i: integer;
begin
  for i := 0 to Length(MemoryBlocks) - 1 do
    if MemoryBlocksFree[i] then begin
      Result := i;
      exit;
    end;
  raise Exception.Create('ED2K Hasher: No free pre-allocated blocks, unexpected failure.');
end;

procedure TParallelEd2kHasher.HashFile(filename: UniString);
var h: THandle;
  BytesRead: cardinal;
  PartIndex: integer;
  MemBlockIndex: integer;
  Worker: integer;
  Context: MD4Context;
  i: integer;
 {$IFDEF HASH_STATS}
  total_tm, tm: cardinal;
 {$ENDIF}
begin
 {$IFDEF HASH_STATS}
  total_tm := GetTickCount;
  for i := 0 to Length(Workers) - 1 do
    Workers[i].HashingTime := 0;
 {$ENDIF}

  ResetEvent(FWakeUp);
  Terminated := false;

  h := CreateFileW(PWideChar(filename), GENERIC_READ, FILE_SHARE_READ, nil,
    OPEN_EXISTING, 0, 0);
  if h=INVALID_HANDLE_VALUE then
    RaiseLastOsError;

  if not GetFileSizeEx(h, @FileSize) then
    RaiseLastOsError();

 { Empty file }
  if FileSize=0 then begin
    Ed2k := ZeroSizeHash;
    Lead := ZeroSizeHash;
    exit;
  end;

 { Allocate parts.
   ED2K always requires last chunk to be incomplete, even when it's size is zero.
     LASTCHUN + K.......
     LASTCHNK + ........
     LASTCH..
 }
  SetLength(Parts, FileSize div ED2K_CHUNK_SIZE+1);

  SetLength(PartsDone, Length(Parts));
  for i := 0 to Length(PartsDone) - 1 do
    PartsDone[i] := false;

 { Process }
  PartIndex := 0;
  LeadPartReported := false;
  repeat
   { If we have calculated the lead part, maybe it's time to report it }
    if (not LeadPartReported) and PartsDone[0] then begin
      if Assigned(FOnLeadPartDone) then
        FOnLeadPartDone(Self, Parts[0]);
      LeadPartReported := true;
    end;

   { Find free memory block }
    MemBlockIndex := GetFreeMemoryBlock;
    MemoryBlocksFree[MemBlockIndex] := false;

   {$IFDEF HASH_STATS}
    tm := GetTickCount;
   {$ENDIF}
   { Read next chunk, maybe empty or incomplete }
    if not ReadFile(h, MemoryBlocks[MemBlockIndex]^, ED2K_CHUNK_SIZE, BytesRead, nil) then
      RaiseLastOsError;
   {$IFDEF HASH_STATS}
    ReadingTime := ReadingTime + GetTickCount-tm;
   {$ENDIF}

   { Wait for worker to become available }
    Worker := GetFreeWorker;
    WorkerIdle[Worker] := false;

   { Assign a task }
    Workers[Worker].JobData := MemoryBlocks[MemBlockIndex];
    Workers[Worker].JobSize := BytesRead;
    Workers[Worker].PartIndex := PartIndex;
    Workers[Worker].MemBlockIndex := MemBlockIndex;
    Workers[Worker].WakeUp;

    Inc(PartIndex)
  until (PartIndex >= Length(Parts)) or Terminated;

 { Wait for all workers to finish their jobs }
  repeat
   { Lead part might be not done yet for small files }
    if (not LeadPartReported) and PartsDone[0] then begin
      if Assigned(FOnLeadPartDone) then
        FOnLeadPartDone(Self, Parts[0]);
      LeadPartReported := true;
    end;

   { All workers free: exit }
    if GetFreeWorkerCount>=Length(Workers) then break;

   { Sleep }
    WaitEvent;
  until false;

 { Finalize hash }
  Lead := Parts[0];
  if Length(Parts)=1 then begin
    Ed2k := Parts[0];
    exit;
  end;

  MD4Init(Context);
  MD4Update(Context, @Parts[0], Length(Parts)*SizeOf(Md4Digest));
  MD4Final(Context, Ed2k);

  CloseHandle(h);

 {$IFDEF HASH_STATS}
  TotalTime := TotalTime + GetTickCount-total_tm;
  for i := 0 to Length(Workers) - 1 do
    HashingTime := HashingTime + Workers[i].HashingTime;
 {$ENDIF}
end;

constructor THashThread.Create(AParent: TParallelEd2kHasher; AWorkerIndex: integer);
begin
  inherited Create({Suspended:}true);
  Parent := AParent;
  WorkerIndex := AWorkerIndex;
  FWakeUp := CreateEvent(nil, false, false, nil);
  Resume;
end;

destructor THashThread.Destroy;
begin
  Terminate;
  WaitFor();
  CloseHandle(FWakeUp);
  inherited;
end;

procedure THashThread.Execute;
var hr: integer;
begin
  while not Terminated do begin
    hr := WaitForSingleObject(FWakeUp, INFINITE);
    if hr<>WAIT_OBJECT_0 then
      RaiseLastOsError();

    if Terminated then exit;
    if JobData<>nil then
      HashJob;
  end;
end;

procedure THashThread.Terminate;
begin
  inherited Terminate;
  WakeUp;
end;

procedure THashThread.WakeUp;
begin
  SetEvent(FWakeUp);
end;

{ Work function. Hashes the assigned job, then resets it,
  increments the completed job counter, adds itself to a free workers list
  and notifies main thread. }
procedure THashThread.HashJob;
{$IFDEF HASH_STATS}
var tm: cardinal;
{$ENDIF}
begin
 {$IFDEF HASH_STATS}
  tm := GetTickCount;
 {$ENDIF}
  MD4Init(Context);
  MD4Update(Context, PAnsiChar(JobData), JobSize);
  MD4Final(Context, Parent.Parts[PartIndex]);
 {$IFDEF HASH_STATS}
  HashingTime := HashingTime + GetTickCount-tm;
 {$ENDIF}

  Parent.PartsDone[PartIndex] := true;
  Parent.MemoryBlocksFree[MemBlockIndex] := true;

  JobData := nil;
  JobSize := 0;
  PartIndex := -1;
  MemBlockIndex := -1;

  Parent.WorkerIdle[WorkerIndex] := true;
  Parent.WakeUp;
end;

end.
