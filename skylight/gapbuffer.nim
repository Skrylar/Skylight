
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

