
# Ported from: http://www.isthe.com/chongo/tech/comp/fnv/ by Joshua
# "Skrylar" Cearley.
#
# This file (fnv.nim) is released in to the public domain (CC0 License),
# the author releases all claims of copyright on it.

import
  unsigned

# Type definitions {{{1

type
  RawData = ptr array[0..65535, uint8]

# }}}

# Magic {{{1

const
  # 32 bit FNV_prime = 224 + 28 + 0x93 = 16777619
  FnvPrime32 = 16777619'u32

  # 64 bit FNV_prime = 240 + 28 + 0xb3 = 1099511628211
  FnvPrime64 = 1099511628211'u64

  # 128 bit FNV_prime = 288 + 28 + 0x3b = 30948500982134506872
  # 4781371

  # 256 bit FNV_prime = 2168 + 28 + 0x63 = 3741444191567111470
  # 60143317175368453031918731002211

  # 512 bit FNV_prime = 2344 + 28 + 0x57 = 3583591587484486736
  # 8919076489095108449946327955754392558399825615420669938882
  # 575126094039892345713852759

  # 1024 bit FNV_prime = 2680 + 28 + 0x8d = 501645651011311865
  # 5434598811035278955030765345404790744303017523831112055108
  # 1474515091576922202953827161626518785268952493852922918165
  # 2437508374669137180409427187316048473796672026038921768447
  # 6157468082573 

  # 32 bit offset_basis = 2166136261
  FnvOffset32 = 2166136261'u32

  # 64 bit offset_basis = 14695981039346656037
  FnvOffset64 = 0xCBF29CE484222325'u64

  # 128 bit offset_basis = 14406626329776981559649562966706236
  # 7629

  # 256 bit offset_basis = 10002925795805258090707096862062570
  # 4837092796014241193945225284501741471925557

  # 512 bit offset_basis = 96593031294966694980094354007163104
  # 6609041874567263789610837432943446265799458293219771643844
  # 9813051892206539805784495328239340083876191928701583869517
  # 785

  # 1024 bit offset_basis = 1419779506494762106872207064140321
  # 8320880622795441933960878474914617582723252296732303717722
  # 1508640965212023555493656281746691085718147604710150761480
  # 2975596980407732015769245856300321530495715015740364446036
  # 3550505412711285966361610267868082893823963790439336411086
  # 884584107735010676915 

# }}}

# One-shots {{{1

# 32-bit implementation {{{2

{.push checks: off.}

proc Fnv1Hash32*(input: pointer; length: int): uint32 =
  assert length >= 0
  let actualInput = cast[RawData](input)
  result = FnvOffset32
  for i in 0..(length-1):
    result = (result * FnvPrime32) xor actualInput[i]

proc Fnv1aHash32*(input: pointer; length: int): uint32 =
  assert length >= 0
  let actualInput = cast[RawData](input)
  result = FnvOffset32
  for i in 0..(length-1):
    result = (result xor actualInput[i]) * FnvPrime32

{.pop.}

# }}} 32-bit

# 64-bit implementation {{{2

{.push checks: off.}

proc Fnv1Hash64*(input: pointer; length: int): uint64 =
  assert length >= 0
  let actualInput = cast[RawData](input)
  result = FnvOffset64
  for i in 0..(length-1):
    result = (result * FnvPrime64) xor actualInput[i]

proc Fnv1aHash64*(input: pointer; length: int): uint64 =
  assert length >= 0
  let actualInput = cast[RawData](input)
  result = FnvOffset64
  for i in 0..(length-1):
    result = (result xor actualInput[i]) * FnvPrime64

{.pop.}

# }}} 64-bit

# }}} one-shots

# User Helpers {{{1

proc Fnv1Hash32(input: string): uint32 =
  var data = input
  return Fnv1Hash32(addr(data[0]), data.len)

proc Fnv1aHash32(input: string): uint32 =
  var data = input
  return Fnv1aHash32(addr(data[0]), data.len)

proc Fnv1Hash64(input: string): uint64 =
  var data = input
  return Fnv1Hash64(addr(data[0]), data.len)

proc Fnv1aHash64(input: string): uint64 =
  var data = input
  return Fnv1aHash64(addr(data[0]), data.len)

template DefHash(typ: typedesc): stmt =
  proc Fnv1Hash32*(input: typ): uint64 =
    var data = input
    return Fnv1Hash32(addr(data), sizeof(typ))
  proc Fnv1aHash32*(input: typ): uint64 =
    var data = input
    return Fnv1aHash32(addr(data), sizeof(typ))
  proc Fnv1Hash64*(input: typ): uint64 =
    var data = input
    return Fnv1Hash64(addr(data), sizeof(typ))
  proc Fnv1aHash64*(input: typ): uint64 =
    var data = input
    return Fnv1aHash64(addr(data), sizeof(typ))

DefHash(int)
DefHash(int8)
DefHash(int16)
DefHash(int32)
DefHash(int64)
DefHash(uint)
DefHash(uint8)
DefHash(uint16)
DefHash(uint32)
DefHash(uint64)

# }}}

# Unit testing {{{1

when isMainModule:
  import unittest

  test "FNV-1 (32-bit)":
    check Fnv1Hash32(""      ) == 0x811C9DC5'u32
    check Fnv1Hash32("a"     ) == 0x050C5D7E'u32
    check Fnv1Hash32("b"     ) == 0x050C5D7D'u32
    check Fnv1Hash32("c"     ) == 0x050C5D7C'u32
    check Fnv1Hash32("d"     ) == 0x050C5D7B'u32
    check Fnv1Hash32("e"     ) == 0x050C5D7A'u32
    check Fnv1Hash32("f"     ) == 0x050C5D79'u32
    check Fnv1Hash32("fo"    ) == 0x6B772514'u32
    check Fnv1Hash32("foo"   ) == 0x408F5E13'u32
    check Fnv1Hash32("foob"  ) == 0xB4B1178B'u32
    check Fnv1Hash32("fooba" ) == 0xFDC80FB0'u32
    check Fnv1Hash32("foobar") == 0x31F0B262'u32

  test "FNV-1a (32-bit)":
    check Fnv1aHash32(""      ) == 0x811C9DC5'u32
    check Fnv1aHash32("a"     ) == 0xE40C292C'u32
    check Fnv1aHash32("b"     ) == 0xE70C2DE5'u32
    check Fnv1aHash32("c"     ) == 0xE60C2C52'u32
    check Fnv1aHash32("d"     ) == 0xE10C2473'u32
    check Fnv1aHash32("e"     ) == 0xE00C22E0'u32
    check Fnv1aHash32("f"     ) == 0xE30C2799'u32
    check Fnv1aHash32("fo"    ) == 0x6222E842'u32
    check Fnv1aHash32("foo"   ) == 0xA9F37ED7'u32
    check Fnv1aHash32("foob"  ) == 0x3F5076EF'u32
    check Fnv1aHash32("fooba" ) == 0x39AAA18A'u32
    check Fnv1aHash32("foobar") == 0xBF9CF968'u32

  test "FNV-1 (64-bit)":
    check Fnv1Hash64(""      ) == 0xCBF29CE484222325'u64
    check Fnv1Hash64("a"     ) == 0xAF63BD4C8601B7BE'u64
    check Fnv1Hash64("b"     ) == 0xAF63BD4C8601B7BD'u64
    check Fnv1Hash64("c"     ) == 0xAF63BD4C8601B7BC'u64
    check Fnv1Hash64("d"     ) == 0xAF63BD4C8601B7BB'u64
    check Fnv1Hash64("e"     ) == 0xAF63BD4C8601B7BA'u64
    check Fnv1Hash64("f"     ) == 0xAF63BD4C8601B7B9'u64
    check Fnv1Hash64("fo"    ) == 0x08326207B4EB2F34'u64
    check Fnv1Hash64("foo"   ) == 0xD8CBC7186BA13533'u64
    check Fnv1Hash64("foob"  ) == 0x0378817EE2ED65CB'u64
    check Fnv1Hash64("fooba" ) == 0xD329D59B9963F790'u64
    check Fnv1Hash64("foobar") == 0x340D8765A4DDA9C2'u64

  test "FNV-1a (64-bit)":
    check Fnv1aHash64(""      ) == 0xCBF29CE484222325'u64
    check Fnv1aHash64("a"     ) == 0xAF63DC4C8601EC8C'u64
    check Fnv1aHash64("b"     ) == 0xAF63DF4C8601F1A5'u64
    check Fnv1aHash64("c"     ) == 0xAF63DE4C8601EFF2'u64
    check Fnv1aHash64("d"     ) == 0xAF63D94C8601E773'u64
    check Fnv1aHash64("e"     ) == 0xAF63D84C8601E5C0'u64
    check Fnv1aHash64("f"     ) == 0xAF63DB4C8601EAD9'u64
    check Fnv1aHash64("fo"    ) == 0x08985907B541D342'u64
    check Fnv1aHash64("foo"   ) == 0xDCB27518FED9D577'u64
    check Fnv1aHash64("foob"  ) == 0xDD120E790C2512AF'u64
    check Fnv1aHash64("fooba" ) == 0xCAC165AFA2FEF40A'u64
    check Fnv1aHash64("foobar") == 0x85944171F73967E8'u64

# }}}

