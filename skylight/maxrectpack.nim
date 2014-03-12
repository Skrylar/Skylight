
# Based on "A Thousand Ways to Pack the Bin" at
# http://clb.demon.fi/files/RectangleBinPack.pdf

import
  binpack,
  rectangle

# Type definitions {{{1

type 
  MaxRectPacker* [T] = object of BinPack2D[T]
    freeGeometry: seq[Rectangle[T]]

# }}}

# Internal code {{{1

# }}}

# Public interface {{{1

method TryGet* [T](self: var MaxRectPacker[T];
  width, height: T;
  outRectangle: Rectangle[T]): bool =
    ## Attempts to retrieve a rectangle from the bin packer, splitting
    ## up free space from within the packer and returning it if
    ## possible.
    return false

method Reset* [T](self: var MaxRectPacker[T]) =
  ## Instructs the bin packer to reset its free space back to [0, 0,
  ## initialWidth, initialHeight]
  assert self.initialWidth  > 0
  assert self.initialHeight > 0
  self.freeGeometry.setLen(1)
  self.freeGeometry[0].Set(0, 0, self.initialWidth, self.initialHeight)

# }}}

# Constructors {{{1

proc InitMaxRectPacker* [T](self: var MaxRectPacker[T]) =
  reset(self)

# }}}

