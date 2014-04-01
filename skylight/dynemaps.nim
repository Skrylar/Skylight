
import
  macros,
  queues,
  strutils

# Type definitions {{{1

type
  EventTypeUid* = int ## Stores the unique ID of a specific type of event.

  FEventBinding = proc(chan: int; e: pointer) {.closure.}

  ## Procedure which may be bound to receive an event of a given type.
  FPublicEventBinding* [T] = proc(chan: int; e: var T) {.closure.}

  EventBinding = object
    Uid         : EventTypeUid  ## UID for the event to handle
    Channel     : int           ## 0 means "any"
    Transmitter : FEventBinding ## proc to run on event

  EventMap* = object
    ## Special event map object which provides dynamic (event, channel)
    ## -> proc binding.
    Bindings     : seq[EventBinding]

# }}} typedefs

# Event ID assignment {{{1

var NextEventTypeUid {.compileTime.}: int = 1

macro MakeIntoEvent* (etype: typedesc): stmt =
  ## A special macro which creates the `GetEventTypeUid` procedure
  ## against a type, which returns a unique ID to be used within the
  ## event queue.
  let uid = NextEventTypeUID
  Inc(NextEventTypeUID)
  result = quote do:
    proc GetEventTypeUid* (
      self: typedesc[`etype`]): EventTypeUid {.inline.} =
        let x = `uid`
        return x

# }}} event ids

# Constructors {{{1

proc Init*(self: var EventMap) =
  ## Performs first-time initialization on a new event queue.
  self.Bindings    = @[]

# }}} constructors

# Queueing {{{1

proc Emit*[C,T](self: var EventMap; channel: C; e: var T) =
  ## Broadcasts the provided event object on a given channel. Note that
  ## the channel may not actually be read (e.g. if events are bound to
  ## all channels.)
  for h in items(self.bindings):
    if T.GetEventTypeUid == h.Uid:
      h.Transmitter(ord(channel), addr(e))

# }}} queue

# Connection {{{1

template On* [E](self: var EventMap;
  eventType: E; call: FPublicEventBinding[E]) =
    ## Connects an `eventType` to a procedure `call`.
    let closure: FEventBinding =
      proc(c: int; e: pointer) =
        call(c, cast[var eventType](e))
    let binding = EventBinding(Uid: eventType.GetEventTypeUid,
      Channel: 0,
      Transmitter: closure)
    self.bindings.add(binding)

template On* [E,C](self: var EventMap;
  eventType: E;
  chan: C;
  call: FPublicEventBinding[E]) =
    ## Connects an `eventType` to a procedure `call`, provided the
    ## message comes along the specified `chan`nel number. `chan` is
    ## expected to be a raw literal (though you should, in practice,
    ## `never` do this) or the name of an enum literal. `ord()` will be
    ## applied to the parameter automatically, so it is acceptable to
    ## put command names in an enum and simply pass them in for the
    ## channel identifier.
    let c2: int = ord(chan)
    let closure: FEventBinding =
      proc(e: Event[EventSoup]) =
        if e.channel == c2:
          var e2 = e
          var e3 = cast[ptr Event[eventType]](addr e2)
          call(e3)
    let binding = EventBinding(Uid: eventType.GetEventTypeUid,
      Channel: 0,
      Transmitter: closure)
    self.bindings.add(binding)

# TODO: De-duplicate both implementations above.

# }}} connection

# Disconnection {{{1 

proc DisconnectAllImpl(self: var EventMap; uid: int) =
  var i: int = self.bindings.low
  while i < self.bindings.len:
    let e2 = self.bindings[i]
    if e2.Uid == Uid:
      self.bindings.del(i)
    inc i

template DisconnectAll*[E](self: var EventMap; eventType: E) =
  ## Disconnect all events of a specific `eventType`.
  bind DisconnectAllImpl
  DisconnectAllImpl(self, eventType.GetEventTypeUid)

proc DisconnectAllImpl(self: var EventMap; uid, channel: int) =
  var i: int = self.bindings.low
  while i < self.bindings.len:
    let e2 = self.bindings[i]
    if e2.Uid == Uid:
      if e2.Channel == channel:
        self.bindings.del(i)
    inc i

template DisconnectAll*[E,C](self: var EventMap; eventType: E; chan: C) =
  ## Disconnect all events of a specific `eventType` and `chan`-nel
  ## identifier..
  bind DisconnectAllImpl
  DisconnectAllImpl(self, eventType.GetEventTypeUid, ord(chan))

# }}} disconnect

