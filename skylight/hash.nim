
# Type definition {{{1

type
  HashAlgorithm*[T] = object {.inheritable.}
    Value*: T ## Stores the final output of the last hashing.

# }}}

# Hash management {{{1

method Reset*[T](self: var HashAlgorithm[T]): bool =
  ## Ask a hash algorithm to reset itself, clearing state back to
  ## whatever is needed to hash a clean set of data. Returns true if the
  ## hash algorithm is reset and can be used again, false if the hash
  ## algorithm has broken and should be considered unusable.
  return false

method Finalize*[T](self: var HashAlgorithm[T]): bool =
  ## Inform a hash algorithm that no more data is required and any
  ## remaining steps to produce the completed hash should be performed
  ## now.
  return false

# }}}

# Adding data {{{1

method Add*[T](self: var HashAlgorithm[T];
  data: Pointer; length: int): bool =
    return false

method Add*[T](self: var HashAlgorithm[T];
  data: string; start: int = 0; stop: int = -1): bool =
    ## Adds the given string to the hash result, with an optional start
    ## and stop slice.
    assert start >= 0
    let actualStop = if stop < 0: data.len else: stop
    return self.Add(addr(data[start]), actualStop - start)

template DefAdd(typ: typedesc): stmt =
  method Add*[T](self: var HashAlgorithm[T];
    data: typ): bool {.inline.} =
      return self.Add(addr(data), sizeof(typ))

DefAdd(int)
DefAdd(int8)
DefAdd(int16)
DefAdd(int32)
DefAdd(int64)
DefAdd(uint)
DefAdd(uint8)
DefAdd(uint16)
DefAdd(uint32)
DefAdd(uint64)

# }}}

