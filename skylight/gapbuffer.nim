
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

