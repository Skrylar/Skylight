
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
  for x in 1..31:
    let y = uint32(uint32(1) shl uint32(x-1))
    if (mask and y) > 0'u32:
      yield x

proc FirstHopOffset(mask: uint32): int =
  for x in mask.HopOffsets():
    return x

proc DoInsert [K,V](self: var HopscotchTable[K,V]; key: K; value: V): bool =
  # TODO: We should probably make the algorithm adjustable.
  let hash   = Siphash24(key)
  let bucket = int(hash mod uint64(self.Database.len))
  let da = addr(self.Database[bucket])
  if da[].Mask == 0:
    da.Mask     = (1 shl 31)
    da.LocalKey = key
    da.Value    = value
    inc(self.Elements)
    return true
  else:
    # We're adding a child to this element.
    for offset in 1..31:
      if bucket+offset < self.Database.len:
        let db = addr(self.Database[bucket+offset])
        # TODO support shuffling items around (the hopscotch part)
        # check if a good place was found
        if db[].Mask == 0:
          db[].Mask     = (1 shl 31)
          db[].LocalKey = key
          db[].Value    = value
          # now mark the parent with this knowledge
          da[].Mask = da[].Mask or (uint32(1) shl uint32(offset-1))
          # we're good
          inc(self.Elements)
          return true
      else:
        return false
  return false

proc Grow [K,V](self: var HopscotchTable[K,V]) =
  let doubled = self.Database.len * 2
  let newSize = if self.MaximumSize > 0:
      min(self.MaximumSize, doubled)
    else:
      doubled
  if newSize != self.Database.len:
    # switch around to a new database
    var oldDatabase = self.Database
    var newDatabase: seq[HopscotchNode[K,V]] = @[]
    newDatabase.setLen(newSize)
    self.Database = newDatabase
    let z = self.Elements
    # shove everything in to the new area
    for i in 0..high(oldDatabase):
      if oldDatabase[i].Mask != 0:
        if not self.DoInsert(oldDatabase[i].LocalKey, oldDatabase[i].Value):
          self.Database = oldDatabase
          raise newException(EResourceExhausted,
            "Could not rehash contents during table growth.")
    self.Elements = z
  else:
    raise newException(EResourceExhausted,
      "Could not grow hash table (restricted by policy)")

# }}}

# Construction {{{1

proc Init* [K,V](self: var HopscotchTable[K,V]) =
  self.MaximumSize = 0
  self.Elements    = 0
  self.Database    = @[]
  self.Database.setLen(1024)
  zeroMem(addr(self.Database[0]),
    self.Database.len * sizeof(HopscotchNode[K,V]) )

# }}}

# Element access {{{1

proc TryGet* [K,V](self: var HopscotchTable[K,V];
  key: K; outValue: var V): bool =
    ## A safe way to retrieve values from the table. If the value is
    ## found, true is returned and `outValue` receives the value at the
    ## table location.
    let hash   = Siphash24(key)
    let bucket = int(hash mod uint64(self.Database.len))
    if self.Database[bucket].Mask == 0:
      return false
    else:
      if self.Database[bucket].LocalKey == key:
        outValue = self.Database[bucket].Value
        return true
      else:
        for x in self.Database[bucket].Mask.HopOffsets:
          if bucket+x < self.Database.len:
            if self.Database[bucket+x].LocalKey == key:
              outValue = self.Database[bucket+x].Value
              return true
          else:
            return false

proc TryGetPtr* [K,V](self: var HopscotchTable[K,V]; key: K): ptr V =
  ## A less-safe but more efficient version of TryGet, which returns a
  ## pointer to the storage cell instead of a copy. Useful when
  ## high-performance access to a large number of PODs is needed.
  let hash   = Siphash24(key)
  let bucket = int(hash mod uint64(self.Database.len))
  if self.Database[bucket].Mask == 0:
    return nil
  else:
    if self.Database[bucket].LocalKey == key:
      return addr(self.Database[bucket].Value)
    else:
      for x in self.Database[bucket].Mask.HopOffsets:
        if bucket+x < self.Database.len:
          if self.Database[bucket+x].LocalKey == key:
            return addr(self.Database[bucket+x].Value)
        else:
          return nil

proc `[]`* [K,V](self: var HopscotchTable[K,V]; key: K): V =
  if not self.TryGet(key, result):
    raise newException(EOutOfRange,
      "Element not found in Hopscotch table.")

# }}} access

# Element assignment {{{1

proc `[]=`* [K,V](self: var HopscotchTable[K,V]; key: K; value: V) =
  if not self.DoInsert(key, value):
    self.Grow
    if not self.DoInsert(key, value):
      raise newException(EResourceExhausted,
        "Cannot fit new element, even after rehashing.")

# }}} assignment

# Element destruction {{{1

proc Del* [K,V](self: var HopscotchTable[K,V]; key: K) =
  let hash   = Siphash24(key)
  let bucket = int(hash mod uint64(self.Database.len))
  if self.Database[bucket].Mask == 0: return
  elif self.Database[bucket].Mask == (1 shl 31):
    self.Database[bucket].Reset
    dec(self.Elements)
  else:
    dec(self.Elements)
    var ia = bucket
    while true:
      # retrive our current position
      let a = addr self.Database[ia]
      let o = a[].Mask.FirstHopOffset
      assert o > 0
      let ib = ia + o
      let b = addr self.Database[ib]
      # Copy data over
      shallowCopy(a[].LocalKey, b[].LocalKey)
      shallowCopy(a[].Value   , b[].Value)
      # De-mask the area we just zorted
      a[].Mask = a[].Mask xor uint32(uint32(1) shl uint32(o-1))
      # Check if B was on its own
      if b[].Mask == (1 shl 31):
        # we're done
        b[].Reset
        return
      else:
        # Uh oh. Time to do things
        ia = ib

template Delete* [K,V](self: var HopscotchTable[K,V]; key: K) =
  Del(self, key)

# }}}

# Querying {{{1

proc Len* [K,V](self: var HopscotchTable[K,V]): int =
  return self.Elements

proc LoadFactor* [K,V](self: var HopscotchTable[K,V]): int =
  return int((float(self.Elements) / float(self.Database.len)) * 100)

# }}}

# Unit tests {{{1

when isMainModule:
  import unittest
  test "extract nonexistent data":
    var table: HopscotchTable[string, int]
    var output: int
    var result: bool
    table.Init
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
    table.Init

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
    var output: int
    table.Init
    # Throw in loads of data
    checkpoint "initial pass"
    for i in 0..65535:
      var poop: int
      check table.TryGet(i, poop) == false
      check table.TryGetPtr(i) == nil
      check table.Len == i
      table[i] = i xor 7
    # Retrieve loads of data
    checkpoint "verification run"
    for i in 0..65535:
      check table[i] == (i xor 7)
    # Delete loads of data the stupid way
    checkpoint "half deletion run"
    for i in 0..65535:
      if (i mod 2) == 0:
        table.Del(i)
      else:
        check table[i] == (i xor 7)
    # Delete more stuff
    checkpoint "other half deletion run"
    for i in 0..65535:
      if (i mod 2) == 1:
        table.Del(i)
      else:
        check table.TryGet(i, output) == false
    # Check the soup
    check table.len == 0
# }}}

