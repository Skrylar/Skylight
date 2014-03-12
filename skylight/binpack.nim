
import
  rectangle

# Type definitions {{{1

type 
  BinPack2D* [T] = object {.inheritable.}
    ## Base type for two-dimensional bin packing solvers.
    initialWidth*, initialHeight*: T

# }}}

method TryGet* [T](self: var BinPack2D[T];
  width, height: T;
  outRectangle: Rectangle[T]): bool =
    ## Attempts to retrieve a rectangle from the bin packer, splitting
    ## up free space from within the packer and returning it if
    ## possible.
    return false

method Reset* [T](self: var BinPack2D[T]) =
  ## Instructs the bin packer to reset its free space back to [0, 0,
  ## initialWidth, initialHeight]
  discard

