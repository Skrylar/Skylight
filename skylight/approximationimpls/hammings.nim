
## Calculates the hamming distance between `source` and `target`
## strings. The hamming distance is the number of characters which must
## be substituted in order for `source` to become `target`, where both
## strings are intended to be the same length. If both strings are *not*
## the same length, the shorter of two strings is compared and the
## difference in length is added as additional misses.
proc HammingDistance(source, target: string): int =
  let h = min(source.high, target.high)
  let overflow = abs(source.high - target.high).int
  var miss = 0
  for x in source.low .. h:
    if source[x] != target[x]: inc miss
  return miss + overflow

when isMainModule:
  doAssert HammingDistance("Fish" , "Fish") == 0
  doAssert HammingDistance("Fish" , "Fish") == 0
  doAssert HammingDistance("Fog"  , "Dog" ) == 1
  doAssert HammingDistance("Piss" , "Plus") == 2
  doAssert HammingDistance("yes"  , "no"  ) == 3

