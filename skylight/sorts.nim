
type
  FSortComparator*[T] = proc(a, b: T): bool {.closure.}

proc InsertionSort*[T] (self: var seq[T]; cmp: FSortComparator[T]) =
  ## Performs an insertion sort on the given sequence, with a given
  ## comparator. `cmp` is treated with similar semantics as the `<`
  ## system function.
  var i : int = 0
  while i < high(self):
    var j = i
    var k = i + 1
    while cmp(self[j], self[k]):
      swap(self[j], self[k])
      if j > 0:
        dec(j)
        dec(k)
      else:
        break
    inc(i)

