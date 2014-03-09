
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
  FnvOffset64 = 0x14650FB0739D0383'u64

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
  let actualInput = cast[RawData](input)
  result = FnvOffset32
  for i in 0..length:
    result = (result * FnvPrime32) xor actualInput[i]

proc Fnv1aHash32*(input: pointer; length: int): uint32 =
  let actualInput = cast[RawData](input)
  result = FnvOffset32
  for i in 0..length:
    result = (result xor actualInput[i]) * FnvPrime32

{.pop.}

# }}} 32-bit

# 64-bit implementation {{{2

{.push checks: off.}

proc Fnv1Hash64*(input: pointer; length: int): uint64 =
  let actualInput = cast[RawData](input)
  result = FnvOffset64
  for i in 0..length:
    result = (result * FnvPrime64) xor actualInput[i]

proc Fnv1aHash64*(input: pointer; length: int): uint64 =
  let actualInput = cast[RawData](input)
  result = FnvOffset64
  for i in 0..length:
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
# TODO
# }}}

