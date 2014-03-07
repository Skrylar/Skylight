
import
  hash,
  unsigned

# Type definition {{{1

type 
  SipHash24Algorithm* = object {.final.} of HashAlgorithm[uint64]

assert sizeof(int64) >= sizeof(pointer)

# }}}

# Pointer arithmetic {{{1
# NB: This should probably get sporked in a separate unit which has
# warnings not to use it irresponsibly.

proc `[]` (self: pointer; index: int): uint8 {.inline.} =
  return (cast[ptr array[0..65535, uint8]](self))[index]

proc `[]=` (self: pointer; index: int; replacement: uint8) {.inline.} =
  (cast[ptr array[0..65535, uint8]](self))[index] = replacement

proc `+` (self: pointer; other: int): pointer {.inline.} =
  return cast[pointer](cast[int64](self) + other)

proc `-` (self: pointer; other: int): pointer {.inline.} =
  return cast[pointer](cast[int64](self) - other)

proc Inc(self: var pointer; amount: int) {.inline.} =
  self = cast[pointer](cast[int64](self)) + amount

proc Dec(self: var pointer; amount: int) {.inline.} =
  self = cast[pointer](cast[int64](self)) - amount

# }}}

# ROTL {{{1

# NB: Maybe we could spork this to a separate unit, since its used in a
# lot of cryptocode.

# NB: We should look in to compiler-specific optimizations, as some have
# special ways of doing a ROTL call.

proc ROTL(x, b: uint64): uint64 {.inline.} =
  return ( (x shl b) or ( x shr (uint64(64) - b) ) )

# }}}

# Integer Decoding {{{1
# NB: This code can probably be moved to a separate module because its
# also useful for non-crypto encoders as well.

proc U32To8LE(p: pointer; v: uint32) {.inline.} =
  p[0] = uint8(v       )
  p[1] = uint8(v shr 8 )
  p[2] = uint8(v shr 16)
  p[3] = uint8(v shr 24)

proc U64To8LE(p: pointer; v: uint64) {.inline.} =
  U32To8LE(p    , uint32(v       ))
  U32To8LE(p + 4, uint32(v shr 32))

proc U8To64LE(p: pointer): uint64 {.inline.} =
  return
    uint64(p[0]) or
    (uint64(p[1]) shl 8) or
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
  inlen: int;
  k: pointer ): int =
    assert inlen >= 0

    # "somepseudorandomlygeneratedbytes"
    var v0 : uint64 = uint64(0x736F6D6570736575)
    var v1 : uint64 = uint64(0x646F72616E646F6D)
    var v2 : uint64 = uint64(0x6C7967656E657261)
    var v3 : uint64 = uint64(0x7465646279746573)
    var b  : uint64
    var k0 : uint64 = U8To64LE(k)
    var k1 : uint64 = U8To64LE(k + 8)
    var m  : uint64

    let eof: pointer = sof + ( inlen - ( inlen mod sizeof(uint64) ) )
    let left = cint(inlen and 7)

    var pos = sof

    b = uint64(inlen) shl 56

    v3 = v3 xor k1
    v2 = v2 xor k0
    v1 = v1 xor k1
    v0 = v0 xor k0

    while pos < eof:
      m = U8To64LE(sof)
      # Debug printing omitted.
      v3 = v3 xor m
      Sipround(v0, v1, v2, v3)
      Sipround(v0, v1, v2, v3)
      v0 = v0 xor m
      inc(pos, 8)

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

    # Debug printing omitted.

    v3 = v3 xor b
    Sipround(v0, v1, v2, v3)
    Sipround(v0, v1, v2, v3)
    v0 = v0 xor b

    # Debug printing omitted.

    v2 = v2 xor 0xFF
    Sipround(v0, v1, v2, v3)
    Sipround(v0, v1, v2, v3)
    Sipround(v0, v1, v2, v3)
    Sipround(v0, v1, v2, v3)
    b = v0 xor v1 xor v2 xor v3
    U64To8LE(output, b)

    return 0

# }}}

