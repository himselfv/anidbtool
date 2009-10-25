unit md4;

interface
uses SysUtils, Windows;

const
  MD4_BLOCK_SIZE = 16 * 4;
  MD4_LENGTH_SIZE = 2 * 4;

type
  MD4State = record
    A, B, C, D: cardinal;
  end;

  MD4Context = record
    wwSize: int64;
    wwRemSize: int64;
    lpRemData: array[1..MD4_BLOCK_SIZE] of byte;
    State: MD4State;
  end;

  MD4Digest = array[0..15] of byte;

procedure MD4Init( var Context: MD4Context );
procedure MD4Final( var Context: MD4Context; var Digest: MD4Digest );
procedure MD4Update( var Context: MD4Context; lpData: pchar; wwDataSize: int64 );

function SameMd4(a, b: MD4Digest): boolean; inline;
function Md4ToString(md4: MD4Digest): string;

implementation

////////////////////////////////////////////////////////////////////////////////

type
  MD4Block = array[0..15] of cardinal;
  PMD4Block = ^MD4Block;

procedure MD4_ProcessBlock( lpX: pdword; var State: MD4State );
var OldState: MD4State;
    X: PMD4Block;

  function F(X, Y, Z: cardinal): cardinal;
  begin
    Result := (X and Y) or ((not X) and Z);
  end;

  function G(X, Y, Z: cardinal): cardinal;
  begin
    Result := (X and Y) or (X and Z) or (Z and Y);
  end;

  function H(X, Y, Z: cardinal): cardinal;
  begin
    Result := X xor Y xor Z;
  end;

  procedure S_1( var a, b, c, d: cardinal; k, s: byte );
  begin
    a := (a + F(b, c, d) + X^[k]);
    a := ( a shl s ) or ( a shr (32-s) );
  end;

  procedure S_2( var a, b, c, d: cardinal; k, s: byte );
  begin
    a := (a + G(b, c, d) + X^[k] + $5A827999);
    a := ( a shl s ) or ( a shr (32-s) );
  end;

  procedure S_3( var a, b, c, d: cardinal; k, s: byte );
  begin
    a := (a + H(b, c, d) + X^[k] + $6ED9EBA1);
    a := ( a shl s ) or ( a shr (32-s) );    
  end;

begin
  OldState := State;
  X := PMD4Block(lpX);

  with State do begin
   //Round 1
    S_1( A,B,C,D, 0, 3 );
    S_1( D,A,B,C, 1, 7 );
    S_1( C,D,A,B, 2, 11 );
    S_1( B,C,D,A, 3, 19 );

    S_1( A,B,C,D, 4, 3 );
    S_1( D,A,B,C, 5, 7 );
    S_1( C,D,A,B, 6, 11 );
    S_1( B,C,D,A, 7, 19 );

    S_1( A,B,C,D, 8, 3 );
    S_1( D,A,B,C, 9, 7 );
    S_1( C,D,A,B, 10, 11 );
    S_1( B,C,D,A, 11, 19 );

    S_1( A,B,C,D, 12, 3 );
    S_1( D,A,B,C, 13, 7 );
    S_1( C,D,A,B, 14, 11 );
    S_1( B,C,D,A, 15, 19 );

   //Round 2
    S_2( A,B,C,D, 0, 3 );
    S_2( D,A,B,C, 4, 5 );
    S_2( C,D,A,B, 8, 9 );
    S_2( B,C,D,A, 12, 13 );

    S_2( A,B,C,D, 1, 3 );
    S_2( D,A,B,C, 5, 5 );
    S_2( C,D,A,B, 9, 9 );
    S_2( B,C,D,A, 13, 13 );

    S_2( A,B,C,D, 2, 3 );
    S_2( D,A,B,C, 6, 5 );
    S_2( C,D,A,B, 10, 9 );
    S_2( B,C,D,A, 14, 13 );

    S_2( A,B,C,D, 3, 3 );
    S_2( D,A,B,C, 7, 5 );
    S_2( C,D,A,B, 11, 9 );
    S_2( B,C,D,A, 15, 13 );

   // Round 3
    S_3( A,B,C,D, 0, 3 );
    S_3( D,A,B,C, 8, 9 );
    S_3( C,D,A,B, 4, 11 );
    S_3( B,C,D,A, 12, 15 );

    S_3( A,B,C,D, 2, 3 );
    S_3( D,A,B,C, 10, 9 );
    S_3( C,D,A,B, 6, 11 );
    S_3( B,C,D,A, 14, 15 );

    S_3( A,B,C,D, 1, 3 );
    S_3( D,A,B,C, 9, 9 );
    S_3( C,D,A,B, 5, 11 );
    S_3( B,C,D,A, 13, 15 );

    S_3( A,B,C,D, 3, 3 );
    S_3( D,A,B,C, 11, 9 );
    S_3( C,D,A,B, 7, 11 );
    S_3( B,C,D,A, 15, 15 );
  end;

  Inc(State.A, OldState.A);
  Inc(State.B, OldState.B);
  Inc(State.C, OldState.C);
  Inc(State.D, OldState.D);
end;

////////////////////////////////////////////////////////////////////////////////

procedure MD4Init( var Context: MD4Context );
begin
  with Context do begin
    wwSize := 0;
    wwRemSize := 0;
    State.A := $67452301;
    State.B := $EFCDAB89;
    State.C := $98BADCFE;
    State.D := $10325476;
  end;
end;

procedure MD4Update( var Context: MD4Context; lpData: pchar; wwDataSize: int64 );
begin
  with Context do begin
    Inc(wwSize, wwDataSize);

   //First pass - check if there's unused data from previous sessions
    if( wwRemSize + wwDataSize >= MD4_BLOCK_SIZE )
    and( wwRemSize > 0 )then begin
      Dec( wwDataSize, MD4_BLOCK_SIZE-wwRemSize );
      CopyMemory( @lpRemData[wwRemSize+1], lpData, MD4_BLOCK_SIZE - wwRemSize );
      MD4_ProcessBlock( @lpRemData[1], State );
      Inc( lpData, MD4_BLOCK_SIZE - wwRemSize );
      wwRemSize := 0;
    end;

   //Further passes - use the data without copying
    while( wwDataSize >= MD4_BLOCK_SIZE ) do begin
      Dec( wwDataSize, MD4_BLOCK_SIZE );
      MD4_ProcessBlock( pdword(lpData), State );
      Inc( lpData, MD4_BLOCK_SIZE );
    end;

   //Save the remaining data for the next updates
    if( wwDataSize > 0 )then begin
      CopyMemory( @lpRemData[wwRemSize+1], lpData, wwDataSize );
      wwRemSize := wwRemSize + wwDataSize;
    end;

  end;
end;

procedure MD4Final( var Context: MD4Context; var Digest: MD4Digest );
var dwRem: cardinal;
    lpDta: array of byte;
begin
  with Context do begin
   //Calculate zeroes count
    dwRem := (wwSize+1) mod MD4_BLOCK_SIZE;
    if( dwRem <= MD4_BLOCK_SIZE - MD4_LENGTH_SIZE )then
      dwRem := MD4_BLOCK_SIZE - MD4_LENGTH_SIZE - dwRem
    else
      dwRem := 2*MD4_BLOCK_SIZE - MD4_LENGTH_SIZE - dwRem;

   //Create appendix array
    SetLength( lpDta, 1+dwRem+MD4_LENGTH_SIZE );
    lpDta[0] := $80;
    ZeroMemory( @lpDta[1], dwRem );
    pint64(@lpDta[1+dwRem])^ := wwSize*8; // Length in bits

   //Process appendix array
    MD4Update( Context, @lpDta[0], 1+dwRem+MD4_LENGTH_SIZE );

   //Create digest
    CopyMemory( @Digest[0], @State, sizeof(Digest) );

  end;
end;

function SameMd4(a, b: MD4Digest): boolean; inline;
begin
  Result := CompareMem(@a, @b, SizeOf(a));
end;

function Md4ToString(md4: MD4Digest): string;
var i: integer;
begin
  Result := '';
  for i := 0 to Length(md4) - 1 do
    Result := Result + IntToHex(md4[i], 2);
end;

end.
