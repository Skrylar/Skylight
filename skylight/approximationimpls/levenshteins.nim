
# This implementation is adapted from:
# "Iterative with two matrix rows"
# http://en.wikipedia.org/wiki/Levenshtein_distance

## Calculates the Levenshtein distance between a `source` and `target`
## string. The Levenshtein distance is the number of insertions,
## substitutions and deletions which must be performed to transform
## `source` into `target`. Note that this is one of the slower distance
## functions, and should only be used if necessary.
##
## You also may want to use strutils.editDistance.
proc LevenshteinDistance*(source, target: string): int =
  # degenerate cases
  if source == target: return 0
  if source.high == target.low: return target.high
  if target.high == source.low: return source.high

  # create two work vectors
  var v0: seq[int]
  var v1: seq[int]
  newSeq(v0, target.len + 1)
  newSeq(v1, target.len + 1)

  # initialize previous row of distances
  for i in v0.low .. v0.high: v0[i] = i

  for i in source.low .. source.high:
    # calculate v1 (current row distances) from previous row v0
    # first element is A[i+1][0]
    v1[0] = i + 1
    # use formula to fill in the rest of the row
    for j in target.low .. target.high:
      let cost = if source[i] == target[j]:
          0
        else:
          1
      v1[j+1] = min(min(v1[j] + 1, v0[j+1] + 1), v0[j]+cost)
    # copy v1 (current row) to v0 (previous row)
    for j in v0.low .. v0.high:
      v0[j] = v1[j]

  return v1[target.len]

when isMainModule:
  doAssert LevenshteinDistance("kitten"   , "sitting")  == 3
  doAssert LevenshteinDistance("sitting"  , "kitten")   == 3
  doAssert LevenshteinDistance("Saturday" , "Sunday")   == 3
  doAssert LevenshteinDistance("Sunday"   , "Saturday") == 3

