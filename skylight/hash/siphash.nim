
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
  p[0] = uint8(v      )
  p[1] = uint8(v shr 8 )
  p[2] = uint8(v shr 16)
  p[3] = uint8(v shr 24)

template U64To8LE(p: pointer; v: uint64): stmt =
  U32To8LE(p,     uint32(v      ))
  U32To8LE(p + 4, uint32(v shr 32))

template U8To64LE(p: pointer): uint64 =
  return
    (uint64(p[0])       ) or
     uint64(p[1]) shl  8) or
     uint64(p[2]) shl 16) or
     uint64(p[3]) shl 24) or
     uint64(p[4]) shl 32) or
     uint64(p[5]) shl 40) or
     uint64(p[6]) shl 48) or
     uint64(p[7]) shl 56))

# }}}


