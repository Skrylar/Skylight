
proc AmericanSoundexCode(ch: char): int =
  case ch:
    of 'B', 'F', 'P', 'V'                     : return 1
    of 'C', 'G', 'J', 'K', 'Q', 'S', 'X', 'Z' : return 2
    of 'D', 'T'                               : return 3
    of 'L'                                    : return 4
    of 'M', 'N'                               : return 5
    of 'R'                                    : return 6
    of 'A', 'E', 'I', 'O', 'U', 'Y'           : return -1
    else                                      : return 0

## An implementation of "American Soundex", as described in
## http://en.wikipedia.org/wiki/Soundex
##
## Converts a single word of LATIN-1 encoded english in to an American
## Soundex code, which is a four character phonetic hash.
proc AmericanSoundex*(word: string): string =
  var output   = newString(4)
  var lastCode = 0
  var i, j     = 0
  # Get the first character
  while i < word.len:
    var ch = word[i]
    inc i
    # Reduce a lowercase character to an uppercase character
    if ((ch.int >= 97) and (ch.int <= 122)): dec ch, 32
    if ((ch.int >= 65) and (ch.int <= 90)):
      lastCode = AmericanSoundexCode(ch)
      if lastCode < 0: lastCode = 0
      output[j] = ch
      inc j
      break
  # Now lets hash the rest of this stuff
  while i < word.len:
    var ch = word[i]
    inc i
    # Reduce a lowercase character to an uppercase character
    if ((ch.int >= 97) and (ch.int <= 122)): dec ch, 32
    if ((ch.int >= 65) and (ch.int <= 90)):
      var code = AmericanSoundexCode(ch)
      case code:
        of 0: continue
        of -1:
          lastCode = 0
        else:
          if code != lastCode:
            lastCode = code
            output[j] = char(code + 48)
            inc j
            if j == 4: break
  # Pad the remainder of the string with zeroes
  while j < 4:
    output[j] = '0'
    inc j
  # We are done
  return output

when isMainModule:
  doAssert AmericanSoundex("")         == "0000"
  doAssert AmericanSoundex("robert")   == "R163"
  doAssert AmericanSoundex("Robert")   == "R163"
  doAssert AmericanSoundex("Rupert")   == "R163"
  doAssert AmericanSoundex("Ashcraft") == "A261"
  doAssert AmericanSoundex("Ashcroft") == "A261"
  doAssert AmericanSoundex("Tymczak")  == "T522"
  doAssert AmericanSoundex("Pfister")  == "P236"
