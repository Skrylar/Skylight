
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

proc FindBestRectangleIndex [T](self: MaxRectPacker[T];
  width, height: int): int =
    ## Uses a linear search to find the rectangle which would waste the
    ## least amount of pixels if it were cut up to contain [w, h]
    assert width  > 0
    assert height > 0
    # Set up our control values
    let insertArea = width * height
    var bestScore  = 0x0FFFFFFF
    var here       = -1
    result         = -1
    # Now perform the scan for success
    for x in items(self.freeGeometry):
      inc(here)
      if (x.width < width) or (x.height < height):
        # element is ineligible for consideration
        continue
      else:
        # consider the element; note that the scoring function is key in
        # determining what the "best" rectangle is!
        let score = x.Area - insertArea
        if score < bestScore:
          bestScore = score
          result    = here

proc SplitRectangle[T] (self: Rectangle[T];
  width, height: int;
  outA, outB: var Rectangle[T]) =
    ## Calculates two new rectangles, as though [width, height] had been
    ## removed from 'self' and these new rectangles were the remaining
    ## space on two dimensions.
    outA.Set(self)
    outB.Set(self)
    # now apply the cuts
    outA.Left   = self.Left + width
    outB.Bottom = self.Top + height

proc SplitRectangle[T] (self, other: Rectangle[T];
  outA, outB, outC, outD: var Rectangle[T]) =
    ## Calculates two new rectangles, as though [width, height] had been
    ## removed from 'self' and these new rectangles were the remaining
    ## space on two dimensions.
    outA.Set(self)
    outB.Set(self)
    outC.Set(self)
    outD.Set(self)
    # now apply the cuts
    outA.Left   = other.Right
    outB.Top    = other.Bottom
    outC.Right  = other.Left
    outD.Bottom = other.Top

proc Add[T] (self: var MaxRectPacker[T]; element: Rectangle[T]) =
  ## Adds a rectangle to the packer's free list, but only if the
  ## rectangle is not malformed in some way.
  if element.IsInverted : return
  if element.Area < 0   : return
  self.freeGeometry.Add(element)

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

