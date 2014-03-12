
import
  siphash,
  unsigned

# Type definition {{{1

type
  HopscotchTable*[K,V] = object
    MaximumSize*: int

# }}}

# Construction {{{1

proc InitHopscotchTable*(self: var HopscotchTable) =
  discard

# }}}

# Element access {{{1

proc TryGet* [K,V](self: var HopscotchTable[K,V]; key: K; outValue: V): bool =
  return false

proc `[]`* [K,V](self: var HopscotchTable[K,V]; key: K): V =
  discard

proc `[]=`* [K,V](self: var HopscotchTable[K,V]; key: K; value: V) =
  discard

proc Del* [K,V](self: var HopscotchTable[K,V]; key: K) =
  discard

template Delete* [K,V](self: var HopscotchTable[K,V]; key: K) =
  Del(self, key)

# }}}

# Querying {{{1

proc Len* [K,V](self: var HopscotchTable[K,V]): int =
  return 0 # TODO

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
    result = table.TryGet(57, output) == true
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

