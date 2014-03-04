
import
  unicode

# Type definition {{{1

type
  RGapBuffer* = ref GapBuffer
  GapBuffer* = object
    buffer: string
    startByte, endByte: int
    cursor: int
    cursorDirty: bool # TODO find a way to merge this and save some space

# }}}

# Constructor {{{1

proc InitGapBuffer*(self: var GapBuffer; initialLength: int = 0) =
  self.buffer = newString(initialLength)
  let eof     = self.buffer.len
  # set up initial gap status
  self.startByte   = 0
  self.endByte     = eof
  # set up initial cursor status
  self.cursor      = 0
  self.cursorDirty = false

proc NewGapBuffer*(initialLength: int): RGapBuffer =
  new(result)
  InitGapBuffer(result[], initialLength)

# }}}

# Metrics {{{1

proc GapLen*(self: GapBuffer): int {.noSideEffect.} =
  ## Returns the length of the available gap space, in bytes.
  assert self.startByte <= self.endByte
  self.endByte - self.startByte

proc Len*(self: GapBuffer): int {.noSideEffect.} =
  ## Returns the length of the gap buffer's contents, not including
  ## available gap space, in bytes.
  self.buffer.len() - self.GapLen

# }}}

# Redaction {{{1

proc Delback*(self: var GapBuffer) {.noSideEffect.} =
  if self.startByte > 0:
    dec(self.startByte) # move back one for sure
    # now move back more, if we hit unicrap
    dec(self.startByte, FindSplitLeftUtf8(self.buffer, self.startByte))

proc Delforward*(self: var GapBuffer) {.noSideEffect.} =
  if self.endByte < self.buffer.len:
    inc(self.endByte) # move forward one for sure
    # now move forward more, if we hit unicrap
    inc(self.endByte, FindSplitRightUtf8(self.buffer, self.endByte))

# }}}

# Lazy Cursor {{{1

proc SetCursor*(self: var GapBuffer; n: int) {.noSideEffect.} =
  ## Sets the position of the editing cursor within the gap buffer.
  if n != self.startByte:
    # TODO i haven't decided how to handle setting the cursor all the
    # way to the right somewhere
    assert n <= self.endByte
    if n < 0:
      self.cursor = 0
    else:
      self.cursor = n
      self.cursorDirty = true

# }}}

# Gap management {{{1

proc AutoGrowBuffer(self: var GapBuffer) =
  ## Grows the length of the buffer, choosing the appropriate buffer
  ## growth strategy. If other strategies are added to this module, this
  ## function must select what it believes is the best one and perform
  ## that.
  # TODO refactor so we can set a maximum size for buffer growth
  # check the length after the gap
  let initialLen  = self.buffer.len
  let resizedLen  = initialLen * 2
  let initialTail = initialLen - self.endByte
  # realloc the buffer
  self.buffer.setLen(resizedLen)
  # was there memory?
  if self.buffer.len < resizedLen:
    quit "TODO get a proper out of memory exception"
  # was there any data after the gap?
  if initialTail > 0:
    let tailPos    = initialLen - initialTail
    let newTailPos = resizedLen - initialTail
    # move the post-gap data to the end of the buffer
    moveMem(addr(self.buffer[newTailPos]),
      addr(self.buffer[tailPos]),
      initialTail)
  # update the "end" of the gap
  self.endByte = resizedLen - initialTail
  # done!
  return

proc CloseGap(self: var GapBuffer) =
  let eof = self.buffer.len
  if self.endByte < eof:
    let tailLen = eof - self.endByte
    moveMem(addr(self.buffer[self.startByte]),
      addr(self.buffer[self.endByte]),
      tailLen)
    self.endByte   = eof
    self.startByte = eof - tailLen

proc SetGap(self: var GapBuffer; index: int) =
  ## Sets the gap position to an arbitrary position, moving data around
  ## as necessary.
  assert index >= 0
  assert index <= self.buffer.len
  let gapLength = GapLen(self)
  # where is the new gap?
  if index < self.startByte:
    # before the start
    let prefixLen = self.startByte - index
    let targetPos = self.endByte   - prefixLen
    moveMem(addr(self.buffer[targetPos]),
      addr(self.buffer[index]),
      prefixLen)
  else:
    let prefixLen = index - self.startByte
    moveMem(addr(self.buffer[self.startByte]),
      addr(self.buffer[self.endByte]),
      prefixLen)
  # adjust the gap position
  self.startByte = index
  self.endByte   = index + gapLength

proc CommitCursor(self: var GapBuffer) =
  ## Commits moving the gap to accomidate the buffer's cursor.
  # is the cursor dirty?
  if self.cursorDirty:
    # find closest unicode-safe split point
    let safepoint = FindSplitUtf8(self.buffer, self.cursor)
    if safepoint != self.startByte:
      self.SetGap(safepoint)
    # cursor is no longer dirty
    self.cursorDirty = false
  # done
  return

# }}}

# Appending content {{{1

template PrepareToAdd(self, space: expr): stmt =
  self.CommitCursor
  if GapLen(self) < space:
    AutoGrowBuffer(self)

proc Add*(self: var GapBuffer; ch: char) =
  ## Adds a 7-bit character to the gap buffer. Note that this is for
  ## adding ANSI characters, *not* arbitrary binary data!
  # Ensure user obedience.
  assert ch >= char(0)
  assert ch <= char(127)
  # is the gap length >= input?
  PrepareToAdd self, 1
  # insert bytes at start
  self.buffer[self.startByte] = ch
  # increment start
  inc self.startByte

proc Add*(self: var GapBuffer; str: string) =
  ## Adds each byte from the given string to the gap buffer. Note that
  ## this does not check if the input string contains invalid UTF-8, be
  ## warned.
  PrepareToAdd self, str.len
  # put everything from the string in the buffer
  for ch in items(str):
    self.buffer[self.startByte] = ch
    inc self.startByte

proc Add*(self: var GapBuffer; cp: Codepoint) =
  ## Encodes the given codepoint to a series of bytes within the gap
  ## buffer.
  PrepareToAdd self, cp.LenUtf8()
  # put everything in the gap
  for b in EncodedBytesUtf8(cp):
    self.buffer[self.startByte] = char(b)
    inc self.startByte

proc Add*(self: var GapBuffer; gm: Grapheme) =
  ## Encodes the given grapheme to a series of bytes within the gap
  ## buffer.
  PrepareToAdd(self, LenUtf8(gm))
  # go over each grapheme
  for g in items(gm):
    # encode each point
    for b in EncodedBytesUtf8(g):
      self.buffer[self.startByte] = char(b)
      inc self.startByte

# }}}

# Extraction {{{1

proc `$` *(self: var GapBuffer): string =
  ## Extracts the content of the gap buffer in to a new string.
  let dataLen = self.buffer.len - GapLen(self)
  if dataLen > 0:
    let eof = self.buffer.len
    result  = newString(eof - GapLen(self))
    var pos = 0
    if self.startByte > 0:
      copyMem(addr(result[0]),
        addr(self.buffer[0]),
        self.startByte)
      inc pos, self.startByte
    if self.endByte < eof:
      copyMem(addr(result[pos]),
        addr(self.buffer[self.endByte]),
        eof - self.endByte)
  else:
    result = ""

iterator Chars(self: GapBuffer): char =
  ## Iterates through each character in the gap buffer.
  let eof = self.buffer.len
  var i = 0
  while i < self.startByte:
    yield self.buffer[i]
    inc i
  i = self.endByte
  while i < eof:
    yield self.buffer[i]
    inc i

iterator Graphemes(self: var GapBuffer): Grapheme =
  ## Iterates through each grapheme in the gap buffer.
  if GapLen(self) > 0:
    # zero out the start byte, just to prevent potential stupidity from
    # the grapheme reader
    self.buffer[self.startByte] = char(0)
  if self.startByte > 0:
    for gp in Utf8GraphemesSliced(0, self.startByte, self.buffer):
      yield gp
  if self.endByte <= 0:
    for gp in Utf8GraphemesSliced(self.endByte, self.buffer.len, self.buffer):
      yield gp

# }}} extraction

# Unit testing {{{1

when isMainModule:
  import unittest
  test "basic usage":
    var buffer: GapBuffer
    checkpoint "initialize"
    InitGapBuffer(buffer, 32)
    # put stuff in here
    checkpoint "first append"
    buffer.Add "snort"
    buffer.Add ' '
    buffer.Add "bacon"
    # check it
    check($buffer == "snort bacon")
    # lets prepend some stuff
    checkpoint "prepend"
    buffer.SetCursor(0)
    buffer.Add "don't "
    # check it
    check($buffer == "don't snort bacon")
    # okay now lets mangle other stuff
    checkpoint "middle insertion"
    buffer.SetCursor(12)
    buffer.Add "old "
    # check it
    check($buffer == "don't snort old bacon")
  # TODO do some tests with unicrap and make sure it won't mangle stuff
  # TODO do some tests with iterators to make sure sadness doesn't happen

# }}}

