
import hashbase

# Type definition {{{1

type 
  SipHash24Algorithm* = object {.final.} of HashAlgorithm[uint64]

# }}}

# ROTL {{{1

# NB: Maybe we could spork this to a separate unit, since its used in a
# lot of cryptocode.

# NB: We should look in to compiler-specific optimizations, as some have
# special ways of doing a ROTL call.

template Rotl(x, b: uint64): stmt =
  ( (x shl b) or ( x shr (64 - b) ) )

# }}}

# Integer Decoding {{{1
# NB: This code can probably be moved to a separate module because its
# also useful for non-crypto encoders as well.

template U32To8LE(p: pointer; v: uint32): stmt =
  p[0] = uint8(v       )
  p[1] = uint8(v shr 8 )
  p[2] = uint8(v shr 16)
  p[3] = uint8(v shr 24)

template U64To8LE(p: pointer; v: uint64): stmt =
  U32To8LE(p    , uint32(v       ))
  U32To8LE(p + 4, uint32(v shr 32))

template U8To64LE(p: pointer): uint64 =
  return
    uint64(p[0])  or
    (uint64(p[1]) shl  8) or
    (uint64(p[2]) shl 16) or
    (uint64(p[3]) shl 24) or
    (uint64(p[4]) shl 32) or
    (uint64(p[5]) shl 40) or
    (uint64(p[6]) shl 48) or
    (uint64(p[7]) shl 56)

# }}}

# Siphash Implementation {{{1

template Sipround(v0, v1, v2, v3: expr): stmt =
  v0 = v0 + v1; v1 = ROTL(v1, 13); v1 = v1 xor v0; v0 = ROTL(v0, 32)
  v2 = v2 + v3; v3 = ROTL(v3, 16); v3 = v3 xor v2
  v0 = v0 + v3; v3 = ROTL(v3, 21); v3 = v3 xor v0
  v2 = v2 + v1; v1 = ROTL(v1, 17); v1 = v1 xor v2; v2 = ROTL(v2, 32)

# SipHash-2-4
proc crypto_auth(
  output, sof: pointer;
  inlen: uint64;
  k: pointer ): int =

    # "somepseudorandomlygeneratedbytes"
    var v0 : uint64 = uint64(0x736F6D6570736575)
    var v1 : uint64 = uint64(0x646F72616E646F6D)
    var v2 : uint64 = uint64(0x6C7967656E657261)
    var v3 : uint64 = uint64(0x7465646279746573)
    var b  : uint64
    var k0 : uint64 = U8To64LE(k)
    var k1 : uint64 = U8To64LE(k + 8)
    var m  : uint64

    let eof: pointer = sof + inlen - ( inlen mod sizeof(uint64) )
    let left = cint(inlen and 7)

    b = uint64(inlen) shl 56

    v3 = v3 xor k1
    v2 = v2 xor k0
    v1 = v1 xor k1
    v0 = v0 xor k0

    while sof < eof:
      m = U8To64LE(sof)
      # printf( "(%3d) v0 %08x %08x\n", ( int )inlen, ( u32 )( v0 >> 32 ), ( u32 )v0 )
      # printf( "(%3d) v1 %08x %08x\n", ( int )inlen, ( u32 )( v1 >> 32 ), ( u32 )v1 )
      # printf( "(%3d) v2 %08x %08x\n", ( int )inlen, ( u32 )( v2 >> 32 ), ( u32 )v2 )
      # printf( "(%3d) v3 %08x %08x\n", ( int )inlen, ( u32 )( v3 >> 32 ), ( u32 )v3 )
      # printf( "(%3d) compress %08x %08x\n", ( int )inlen, ( u32 )( m >> 32 ), ( u32 )m )
      v3 = v3 xor m
      Sipround(v0, v1, v2, v3)
      Sipround(v0, v1, v2, v3)
      v0 = v0 xor m
      inc(sof, 8)

    # TODO Unroll this manually
    # switch( left ):
    #   case 7: b |= ( ( u64 )sof[6] )  << 48
    #   case 6: b |= ( ( u64 )sof[5] )  << 40
    #   case 5: b |= ( ( u64 )sof[4] )  << 32
    #   case 4: b |= ( ( u64 )sof[3] )  << 24
    #   case 3: b |= ( ( u64 )sof[2] )  << 16
    #   case 2: b |= ( ( u64 )sof[1] )  <<  8
    #   case 1: b |= ( ( u64 )sof[0] ); break
    #   case 0: break

    # printf( "(%3d) v0 %08x %08x\n", ( int )inlen, ( u32 )( v0 >> 32 ), ( u32 )v0 )
    # printf( "(%3d) v1 %08x %08x\n", ( int )inlen, ( u32 )( v1 >> 32 ), ( u32 )v1 )
    # printf( "(%3d) v2 %08x %08x\n", ( int )inlen, ( u32 )( v2 >> 32 ), ( u32 )v2 )
    # printf( "(%3d) v3 %08x %08x\n", ( int )inlen, ( u32 )( v3 >> 32 ), ( u32 )v3 )
    # printf( "(%3d) padding   %08x %08x\n", ( int )inlen, ( u32 )( b >> 32 ), ( u32 )b )
 
    v3 = v3 xor b
    Sipround(v0, v1, v2, v3)
    Sipround(v0, v1, v2, v3)
    v0 = v0 xor b

    # printf( "(%3d) v0 %08x %08x\n", ( int )inlen, ( u32 )( v0 >> 32 ), ( u32 )v0 )
    # printf( "(%3d) v1 %08x %08x\n", ( int )inlen, ( u32 )( v1 >> 32 ), ( u32 )v1 )
    # printf( "(%3d) v2 %08x %08x\n", ( int )inlen, ( u32 )( v2 >> 32 ), ( u32 )v2 )
    # printf( "(%3d) v3 %08x %08x\n", ( int )inlen, ( u32 )( v3 >> 32 ), ( u32 )v3 )

    v2 = v2 xor 0xFF
    Sipround(v0, v1, v2, v3)
    Sipround(v0, v1, v2, v3)
    Sipround(v0, v1, v2, v3)
    Sipround(v0, v1, v2, v3)
    b = v0 xor v1 xor v2 xor v3
    U64To8LE(output, b)

    return 0

# }}}

