
import
  hopscotches

# Type declarations {{{1

type
  GlyphCacheEntry* [T,D] = object
    Details*          : D
    HorizontalAdvance : T
    HorizontalOffset  : T
    VerticalAdvance   : T
    VerticalOffset    : T
    Width             : T
    Height            : T

  FGlyphCacheEntryCreator* [T,D] =
    proc(codepoint: uint;
      output: var GlyphCacheEntry[T,D]): bool {.closure.}

  GlyphCache* [T,D] = object
    table: HopscotchTable[uint, GlyphCacheEntry[T, D]]

# }}} types

# Constructors {{{1

proc Init* [T,D](self: var GlyphCache[T,D]) =
  self.table.Init()

# }}} constructors

# Accessing {{{1

proc TryGet* [T,D](self: var GlyphCache[T,D];
  key: uint;
  outValue: var GlyphCacheEntry[T,D]): bool =
    return self.table.TryGet(key, outValue)

proc TryGetPtr* [T,D](self: var GlyphCache[T,D];
  key: uint): ptr GlyphCacheEntry[T,D] =
    return self.table.TryGetPtr(key)

template GetOrCreate* [T,D](self: var GlyphCacheEntry[T,D];
  key: uint;
  outValue: var GlyphCacheEntry[T,D];
  creator: FGlyphCacheEntryCreator): bool =
    if self.TryGet(key, outValue) == false:
      var newGlyph: GlyphCacheEntry[T,D]
      if creator(key, newGlyph):
        self.table[key] = newGlyph
        outValue = newGlyph
        return true
      else:
        return false
    else:
      return true

template GetOrCreatePtr* [T,D](self: var GlyphCacheEntry[T,D];
  key: uint;
  creator: FGlyphCacheEntryCreator): ptr GlyphCacheEntry[T,D] =
    result = self.TryGetPtr(key)
    if result == nil:
      var newGlyph: GlyphCacheEntry[T,D]
      if creator(key, newGlyph):
        self.table[key] = newGlyph
        result = self.TryGetPtr(key)

# TODO: de-duplicate the templates above

# }}}

