unit FileInfo;

interface
uses MD4;

type
  TFileInfo = record
    size: int64;
    ed2k: MD4Digest;
    lead: MD4Digest;
  end;

implementation

end.
