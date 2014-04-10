
# Based on the reference implementation for ANSI C of Porter's stemmer:
# 
# Porter, 1980, An algorithm for suffix stripping, Program, Vol. 14,
# no. 3, pp 130-137,
# 
# See also http://www.tartarus.org/~martin/PorterStemmer

# The main part of the stemming algorithm starts here. b is a buffer
# holding a word to be stemmed. The letters are in b[k0], b[k0+1] ...
# ending at b[k]. In fact k0 = 0 in this demo program. k is readjusted
# downwards as the stemming progresses. Zero termination is not in fact
# used in the algorithm.
#
# Note that only lower case sequences are stemmed. Forcing to lower case
# should be done before stem(...) is called.

# static char * b;       # buffer for word to be stemmed
# static int k,k0,j;     # j is a general offset into the string

# cons(i) is TRUE <=> b[i] is a consonant.

proc IsConsonate(word: var seq[char]; i: int): bool =
  let k0 = 0
  case word[i]:
    of 'a', 'e', 'i', 'o', 'u': return false
    of 'y':
      if i == k0:
        return true
      else:
        return not IsConsonate(word, i-1)
    else: return true

# m() measures the number of consonant sequences between k0 and j. if c is
# a consonant sequence and v a vowel sequence, and <..> indicates arbitrary
# presence,
#
#    <c><v>       gives 0
#    <c>vc<v>     gives 1
#    <c>vcvc<v>   gives 2
#    <c>vcvcvc<v> gives 3
#    ....

proc MeasureConsonants(word: var seq[char]; j2: int): int =
  var n = 0
  var i = 0 # = k0
  let j = word.high - j2
  while(true):
    if i > j: return n
    if not IsConsonate(word, i): break
    inc i
  inc i
  while(true):
    while(true):
      if i > j: return n
      if IsConsonate(word, i): break
      inc i
    inc i
    inc n
    while(true):
      if i > j: return n
      if not IsConsonate(word, i): break
      inc i
    inc i

# VowelInStem() is TRUE <=> k0,...j contains a vowel

proc VowelInStem(word: var seq[char]): bool =
  for i in 0 .. word.high:
    if not IsConsonate(word, i):
      return true
  return false

# doublec(j) is TRUE <=> j,(j-1) contain a double consonant.

proc doublec(word: var seq[char]; j: int): bool =
  let k0 = 0
  if j < (k0+1)           : return false
  if word[j] != word[j-1] : return false
  return IsConsonate(word, j)

# cvc(i) is TRUE <=> i-2,i-1,i has the form consonant - vowel -
# consonant and also if the second c is not w,x or y. this is used when
# trying to restore an e at the end of a short word. e.g.
#
#    cav(e), lov(e), hop(e), crim(e), but
#    snow, box, tray.

proc cvc(word: var seq[char]; i2: int): bool =
  let k0 = 0
  var i = i2
  if (i < (k0+2)) or
    (not IsConsonate(word, i)) or
    IsConsonate(word, i-1) or
    (not IsConsonate(word, i-2)):
      return false
  else:
    case word[i]:
      of 'w', 'x', 'y': return false
      else: return true

# ends(s) is TRUE <=> k0,...k ends with the string s.

# proc ends(s: string): int =
#   var length = s[0];
#   if s[length] != b[k]: return false
#   if length > (k-k0+1): return false
#   if memcmp(b + k - length + 1, s + 1, length) != 0: return false
#   j = k - length;
#   return true

# String ending check {{{1

# TODO: Port 'endswith' to another module.

proc EndsWith(self, ending: string): bool =
  if ending.len > self.len: return false
  # XXX It would be nicer if we could do a zero-copy of this
  return substr(self, self.len - ending.len) == ending

proc EndsWith(self: var seq[char], ending: string): bool =
  if ending.len > self.len: return false
  # XXX It would be nicer if we could do a zero-copy of this
  var e = ending
  return equalMem(addr(self[self.len - ending.len]),
    addr(e[0]),
    ending.len)

proc EndsWithZerocopy(self, ending: var string): bool =
  if ending.len > self.len: return false
  return equalMem(addr(self[self.len - ending.len]),
    addr(ending[0]),
    ending.len)

when isMainModule:
  doAssert "bacon".EndsWith("on") == true
  doAssert "bees".EndsWith("bees") == true

  var a1 = "bacon"
  var a2 = "bees"
  var b1 = "on"
  var b2 = "bees"

  doAssert a1.EndsWithZerocopy(b1) == true
  doAssert a2.EndsWithZerocopy(b2) == true

# }}} string ending

# setto(s) sets (j+1),...k to the characters in the string s,
# readjusting k.

# proc setto(s: string) =
#   var length = s[0]
#   memmove(b + j + 1, s + 1, length)
#   k = j + length

# r(s) is used further down.

# proc r(s: string) =
#   if MeasureConsonants() > 0:
#     setto(s);

# Step 1 AB {{{1

# step1ab() gets rid of plurals and -ed or -ing. e.g.
#
#       caresses  ->  caress
#       ponies    ->  poni
#       ties      ->  ti
#       caress    ->  caress
#       cats      ->  cat
#
#       feed      ->  feed
#       agreed    ->  agree
#       disabled  ->  disable
#
#       matting   ->  mat
#       mating    ->  mate
#       meeting   ->  meet
#       milling   ->  mill
#       messing   ->  mess
#
#       meetings  ->  meet

proc step1ab(word: var seq[char]) =
  if word[word.high] == 's':
    if word.EndsWith("sses"):
      word.delete(word.high)
      word.delete(word.high)
    elif word.EndsWith("ies"):
      word.delete(word.high)
      word.delete(word.high)
      # setto("\01" "i")
    elif word[word.high-1] != 's':
      word.delete(word.high)
  
  if word.EndsWith("eed"):
    if MeasureConsonants(word, 3) > 0:
      word.delete(word.high)
  else: # (EndsWith("\02" "ed") or EndsWith("\03" "ing")) and VowelInStem():
    block:
      # Check for the first pieces of the stem
      if word.EndsWith("ed"):
        word.delete(word.high)
        word.delete(word.high)
      elif word.EndsWith("ing") and VowelInStem(word):
        word.delete(word.high)
        word.delete(word.high)
        word.delete(word.high)
      else:
        break
      # Now do the rest of the stemming
      if word.EndsWith("at"):
        word.add 'e'
        # setto("\03" "ate")
      elif word.EndsWith("bl"):
        word.add 'e'
        # setto("\03" "ble")
      elif word.EndsWith("iz"):
        word.add 'e'
        # setto("\03" "ize")
      elif word.doublec(word.high):
        case word[word.high]:
          of 'l', 's', 'z': discard
          else: word.delete(word.high)
      elif MeasureConsonants(word, 0) == 1 and word.cvc(word.high):
        word.add 'e'
        # setto("\01" "e");

# }}} step1ab

# step1c() turns terminal y to i when there is another vowel in the stem.

proc step1c(word: var seq[char]) =
  if word[word.high] == 'y' and VowelInStem(word):
    word[word.high] = 'i';

# step2() maps double suffices to single ones. so -ization ( = -ize plus
# -ation) maps to -ize etc. note that the string before the suffix must give
# m() > 0.

proc step2(word: var seq[char]) =
  case word[word.high-1]:
    of 'a':
      if word.EndsWith("ational"):
        word.setLen(word.high - 4)
        word[word.high] = 'e'
        # r("\03" "ate")
      elif word.EndsWith("tional"):
        word.setLen(word.high - 2)
        # r("\04" "tion")
    of 'c':
      if word.EndsWith("enci"):
        word[word.high] = 'e'
        # r("\04" "ence")
      elif word.EndsWith("anci"):
        word[word.high] = 'e'
        # r("\04" "ance")
    of 'e':
      if word.EndsWith("izer"):
        word.delete(word.high)
        # r("\03" "ize")
    of 'l':
      if word.EndsWith("bli"):
        word[word.high] = 'e'
        # r("\03" "ble") #-DEPARTURE-
      elif word.EndsWith("alli"):
        # To match the published algorithm, replace this line with
        # case 'l': if (ends("\04" "abli")) { r("\04" "able"); break; }
        word.setLen(word.high - 2)
        # r("\02" "al")
      elif word.EndsWith("entli"):
        word.setLen(word.high - 2)
        # r("\03" "ent")
      elif word.EndsWith("eli"):
        word[word.high] = 'e'
        # r("\01" "e")
      elif word.EndsWith("ousli"):
        word.setLen(word.high - 2)
        # r("\03" "ous")
    of 'o':
      if word.EndsWith("ization"):
        word.setLen(word.high - 4)
        word[word.high] = 'e'
        # r("\03" "ize")
      elif word.EndsWith("ation"):
        word.setLen(word.high - 2)
        word[word.high] = 'e'
        # r("\03" "ate")
      elif word.EndsWith("ator"):
        word.delete(word.high)
        word[word.high] = 'e'
        # r("\03" "ate")
    of 's':
      if word.EndsWith("alism"):
        word.setLen(word.high - 3)
        # r("\02" "al")
      elif word.EndsWith("iveness"):
        word.setLen(word.high - 4)
        # r("\03" "ive")
      elif word.EndsWith("fulness"):
        word.setLen(word.high - 4)
        # r("\03" "ful")
      elif word.EndsWith("ousness"):
        word.setLen(word.high - 4)
        # r("\03" "ous")
    of 't':
      if word.EndsWith("aliti"):
        word.setLen(word.high - 4)
        # r("\02" "al")
      elif word.EndsWith("iviti"):
        word.setLen(word.high - 2)
        word[word.high] = 'e'
        # r("\03" "ive")
      elif word.EndsWith("biliti"):
        word.setLen(word.high - 2)
        word[word.high-1] = 'l'
        word[word.high] = 'e'
        # r("\03" "ble")
    of 'g':
      if word.EndsWith("logi"):
        word.delete(word.high)
        # r("\03" "log") #-DEPARTURE-
        # To match the published algorithm, delete this line
    else: return

# step3() deals with -ic-, -full, -ness etc. similar strategy to step2.

proc step3(word: var seq[char]) =
  case word[word.high]:
    of 'e':
      if word.EndsWith("icate"):
        word.setLen(word.high - 3)
        # r("\02" "ic")
      elif word.EndsWith("ative"):
        word.setLen(word.high - 5)
        # r("\00" "")
      elif word.EndsWith("alize"):
        word.setLen(word.high - 3)
        # r("\02" "al")
    of 'i':
      if word.EndsWith("iciti"):
        word.setLen(word.high - 3)
        # r("\02" "ic")
    of 'l':
      if word.EndsWith("ical"):
        word.setLen(word.high - 2)
        # r("\02" "ic")
      elif word.EndsWith("ful"):
        word.setLen(word.high - 3)
        # r("\00" "")
    of 's':
      if word.EndsWith("ness"):
        word.setLen(word.high - 4)
        # r("\00" "")
    else: return

# step4() takes off -ant, -ence etc., in context <c>vcvc<v>.

proc step4(word: var seq[char]) =
  var j = 0
  block:
    case word[word.high-1]:
      of 'a':
        if word.EndsWith("al"):
          j = 2
          break
        return
      of 'c':
        if word.EndsWith("ance"):
          j = 4
          break
        elif word.EndsWith("ence"):
          j = 4
          break
        return
      of 'e':
        if word.EndsWith("er"):
          j = 2
          break
        return
      of 'i':
        if word.EndsWith("ic"):
          j = 2
          break
        return
      of 'l':
        if word.EndsWith("able"):
          j = 4
          break
        elif word.EndsWith("ible"):
          j = 4
        return
      of 'n':
        if word.EndsWith("ant"):
          j = 3
          break
        elif word.EndsWith("ement"):
          j = 5
          break
        elif word.EndsWith("ment"):
          j = 4
          break
        elif word.EndsWith("ent"):
          j = 3
          break
        else: return
      of 'o':
        j = 3
        let jx = word.high - j
        if word.EndsWith("ion") and
          (jx > 0) and
          (word[jx] == 's') or
          (word[jx] == 't'):
            break
        elif word.EndsWith("ou"):
          j = 2
          break
        return
        # takes care of -ous
      of 's':
        if word.EndsWith("ism"):
          j = 3
          break
        return
      of 't':
        if word.EndsWith("ate"):
          j = 3
          break
        elif word.EndsWith("iti"):
          j = 3
          break
        return
      of 'u':
        if word.EndsWith("ous"):
          j = 3
          break
        return
      of 'v':
        if word.EndsWith("ive"):
          j = 3
          break
        return
      of 'z':
        if word.EndsWith("ize"):
          j = 3
          break
        return
      else: return
  if MeasureConsonants(word, j) > 1:
    word.setLen(word.high - j)

# step5() removes a final -e if m() > 1, and changes -ll to -l if m() >
# 1.

proc step5(word: var seq[char]) =
  if word[word.high] == 'e':
    var a = MeasureConsonants(word, 0)
    if (a > 1) or
      (a == 1 and (not word.cvc(word.high-1))):
        word.delete(word.high)
  if (word[word.high] == 'l') and
    word.doublec(word.high) and
    (MeasureConsonants(word, word.high) > 1):
      word.delete(word.high)

# In stem(p,i,j), p is a char pointer, and the string to be stemmed is
# from p[i] to p[j] inclusive. Typically i is zero and j is the offset
# to the last character of a string, (p[j+1] == '\0'). The stemmer
# adjusts the characters p[i] ... p[j] and returns the new end-point of
# the string, k.  Stemming never increases word length, so i <= k <= j.
# To turn the stemmer into a module, declare 'stem' as extern, and
# delete the remainder of this file.

proc StemWordEnglish*(word: string): string =
  var wordBuffer: seq[char]
  # XXX Is there a better way to do this?
  var x = 0
  newSeq(wordBuffer, word.len)
  for ch in items(word):
    wordBuffer[x] = ch
    inc x
  # Now begin the stemming process
  step1ab(wordBuffer)
  if word.len > 2:
    step1c(wordBuffer)
    step2(wordBuffer)
    step3(wordBuffer)
    step4(wordBuffer)
    step5(wordBuffer)
  # XXX Is there a better way to do this?
  var outString = newString(wordBuffer.len)
  x = 0
  for ch in items(wordBuffer):
    outString[x] = ch
    inc x
  return outString

# TODO: Note that words should be normalized/lowercased first.

when isMainModule:
  # Step 1 AB testing
  doAssert StemWordEnglish("caresses") == "caress"
  doAssert StemWordEnglish("caress")   == "caress"
  doAssert StemWordEnglish("cats")     == "cat"
  doAssert StemWordEnglish("feed")     == "feed"
  doAssert StemWordEnglish("agreed")   == "agree"
  doAssert StemWordEnglish("disabled") == "disable"
  doAssert StemWordEnglish("mating")   == "mate"
  doAssert StemWordEnglish("meeting")  == "meet"
  doAssert StemWordEnglish("milling")  == "mill"
  doAssert StemWordEnglish("messing")  == "mess"
  doAssert StemWordEnglish("meetings") == "meet"

