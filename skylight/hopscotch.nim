
import
  siphash,
  unsigned

# Type definition {{{1

type
  HopscotchNode[K,V] = object
    Mask     : uint32
    LocalKey : K
    Value    : V

  HopscotchTable*[K,V] = object
    MaximumSize* : int
    Database     : seq[HopscotchNode[K,V]]
    Elements     : int

# }}}

# Internal code {{{1

proc Reset [K,V](self: var HopscotchNode[K,V]) =
  zeroMem(addr(self), sizeof(HopscotchNode[K,V]))

iterator HopOffsets(mask: uint32): int =
  for x in 30..0:
    let y = uint32(1 shl x)
    if (mask and y) > 0'u32:
      yield (30-x)

proc DoInsert [K,V](self: var HopscotchTable[K,V]; key: K; value: V): bool =
  # TODO: We should probably make the algorithm adjustable.
  let hash   = Siphash24(key)
  let bucket = int(hash mod uint64(self.Database.len))
  if self.Database[bucket].Mask == 0:
    self.Database[bucket].Mask     = (1 shl 31)
    self.Database[bucket].LocalKey = key
    self.Database[bucket].Value    = value
    inc(self.Elements)
    return true
  else:
    # We're adding a child to this element.
    for offset in 0..31:
      if bucket+offset < self.Database.len:
        # TODO support bouncing people out of the neighborhood
        # check if a good place was found
        if self.Database[bucket+offset].Mask == 0:
          self.Database[bucket+offset].Mask     = (1 shl 31)
          self.Database[bucket+offset].LocalKey = key
          self.Database[bucket+offset].Value    = value
          # now mark the parent with this knowledge
          self.Database[bucket].Mask =
            self.Database[bucket].Mask or (uint32(1) shl uint32(offset))
          # we're good
          inc(self.Elements)
          return true
      else:
        return false
  return false

# }}}

# Construction {{{1

proc InitHopscotchTable* [K,V](self: var HopscotchTable[K,V]) =
  self.MaximumSize = 0
  self.Elements    = 0
  self.Database    = @[]
  self.Database.setLen(1024)
  zeroMem(addr(self.Database[0]),
    self.Database.len * sizeof(HopscotchNode[K,V]) )

# }}}

# Element access {{{1

proc TryGet* [K,V](self: var HopscotchTable[K,V]; key: K; outValue: var V): bool =
  let hash   = Siphash24(key)
  let bucket = int(hash mod uint64(self.Database.len))
  if self.Database[bucket].Mask == 0:
    return false
  else:
    if self.Database[bucket].LocalKey == key:
      outValue = self.Database[bucket].Value
      return true
    else:
      quit "TODO linear probe"

proc `[]`* [K,V](self: var HopscotchTable[K,V]; key: K): V =
  if not self.TryGet(key, result):
    raise newException(EOutOfRange,
      "Element not found in Hopscotch table.")

proc `[]=`* [K,V](self: var HopscotchTable[K,V]; key: K; value: V) =
  if not self.DoInsert(key, value):
    # TODO: Grow and rehash
    if not self.DoInsert(key, value):
      raise newException(EResourceExhausted,
        "Cannot fit new element, even after rehashing.")

proc Del* [K,V](self: var HopscotchTable[K,V]; key: K) =
  let hash   = Siphash24(key)
  let bucket = int(hash mod uint64(self.Database.len))
  if self.Database[bucket].Mask == 0: return
  elif self.Database[bucket].Mask == (1 shl 31):
    self.Database[bucket].Reset
    dec(self.Elements)
  else:
    quit "TODO linear deletion probe"

template Delete* [K,V](self: var HopscotchTable[K,V]; key: K) =
  Del(self, key)

# }}}

# Querying {{{1

proc Len* [K,V](self: var HopscotchTable[K,V]): int =
  return self.Elements

# }}}

# Unit tests {{{1

when isMainModule:
  import unittest
  test "extract nonexistent data":
    var table: HopscotchTable[string, int]
    var output: int
    var result: bool
    InitHopscotchTable(table)
    # Should start empty
    check table.len == 0
    # Should be a no-op
    table.Delete("i don't exist")
    # Should fail
    result = table.TryGet("spoons", output)
    check result == false

  test "simple hashery":
    var table: HopscotchTable[int, string]
    var output: string
    var result: bool
    InitHopscotchTable(table)

    checkpoint "start"
    check table.len == 0

    checkpoint "insertion"
    table[57] = "i am soup"
    check table.len == 1
    table[58] = "bacon salad"
    check table.len == 2

    checkpoint "retrieval"
    result = table.TryGet(57, output)
    check result == true
    check output == "i am soup"
    check table[57] == "i am soup"

    checkpoint "removal"
    table.del 57
    check table.len == 1
    table.del 58
    check table.len == 0
    check table.TryGet(57, output) == false

  test "stress test":
    var table: HopscotchTable[int, int]
    InitHopscotchTable(table)
    # Throw in loads of data
    checkpoint "initial pass"
    for i in 0..65535:
      check table.Len == i
      table[i] = i xor 7
      for j in 0..i:
        check table[j] == (j xor 7)
    # Retrieve loads of data
    checkpoint "verification run"
    for i in 0..65535:
      check table[i] == (i xor 7)
    # Delete loads of data the stupid way
    checkpoint "deletion run"
    for i in 0..65535:
      table.Del(i)

# }}}

