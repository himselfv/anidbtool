unit ed2k;

interface
uses md4;

const
  ED2K_CHUNK_SIZE = 9728000;

type
  Ed2kContext = record
    Md4: Md4Context;
    chunks: array of MD4Digest;
    chunk_size: integer;
  end;

procedure Ed2kInit( var Context: Ed2kContext );
procedure Ed2kFinal( var Context: Ed2kContext; var Digest: MD4Digest );

procedure Ed2kChunkUpdate( var Context: Ed2kContext; lpData: pointer; wwDataSize: integer );
procedure Ed2kNextChunk2( var Context: Ed2kContext; out Digest: MD4Digest );
procedure Ed2kNextChunk( var Context: Ed2kContext );

implementation

procedure Ed2kInit( var Context: Ed2kContext );
begin
  MD4Init(Context.Md4);
  SetLength(Context.chunks, 0);
  Context.chunk_size := 0;
end;

procedure Ed2kChunkUpdate( var Context: Ed2kContext; lpData: pointer; wwDataSize: integer );
begin
  Context.chunk_size := Context.chunk_size + wwDataSize;
  MD4Update(Context.Md4, PAnsiChar(lpData), wwDataSize);
end;

procedure Ed2kNextChunk( var Context: Ed2kContext );
var Digest: MD4Digest;
begin
  Ed2kNextChunk2(Context, Digest);
end;

//Allows to get current chunk md4, in case you need it.
procedure Ed2kNextChunk2( var Context: Ed2kContext; out Digest: MD4Digest );
begin
  MD4Final(Context.Md4, Digest);
  with Context do begin
    SetLength(chunks, Length(chunks) + 1);
    chunks[Length(chunks)-1] := Digest;
  end;

  MD4Init( Context.Md4 );
  Context.chunk_size := 0;
end;

procedure Ed2kFinal( var Context: Ed2kContext; var Digest: MD4Digest );
begin
 //Close last chunk (maybe zero-sized)
  Ed2kNextChunk(Context);

 //If there's exactly one chunk, we just use it's md4
  if Length(Context.chunks) = 1 then begin
    Digest := Context.chunks[0];
    exit;
  end;

  MD4Init( Context.Md4 );
  MD4Update( Context.Md4, @Context.chunks[0], Length(Context.chunks)*SizeOf(Md4Digest) );
  MD4Final( Context.Md4, Digest );
end;


end.
