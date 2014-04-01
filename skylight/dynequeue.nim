
import
  macros,
  queues,
  strutils

# Type definitions {{{1

type
  EventTypeUid* = int ## Stores the unique ID of a specific type of event.

  EventSoup* = object
    ## Stores sixteen machine words. Note that you are not intended to use
    ## these fields to access data directly, it simply holds space so that 
    a, b, c, d, e, f, g, h: int
    j, k, m, n, o, p, q, r: int

  Event* [T]= object
    ## Special container for currying events within the event queue.
    Uid*     : EventTypeUid ## Unique ID for this event type.
    Timestamp: int          ## TODO: Implement this.
    Channel* : int          ## Channel which the event happens on.
    Data*    : T            ## Reference field for event data.

  FEventBinding = proc(e: Event[EventSoup]) {.closure.}

  ## Procedure which may be bound to receive an event of a given type.
  FPublicEventBinding* [T] = proc(e: ptr Event[T]) {.closure.}

  ## Procedure to deal with events that do not get intercepted by an
  ## event binding.
  FPublicEventUnhandled* = proc(e: Event[EventSoup]) {.closure.}

  EventBinding = object
    Uid         : EventTypeUid  ## UID for the event to handle
    Channel     : int           ## 0 means "any"
    Transmitter : FEventBinding ## proc to run on event

  EventQueue* = object
    ## Special event queue object which provides dynamic (event, channel)
    ## -> proc binding.
    Scheduled    : TQueue[Event[EventSoup]]
    Bindings     : seq[EventBinding]
    OnUnhandled* : FPublicEventUnhandled

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

proc Init*(self: var EventQueue) =
  ## Performs first-time initialization on a new event queue.
  self.Scheduled   = InitQueue[Event[EventSoup]]()
  self.Bindings    = @[]
  self.OnUnhandled = proc(e: Event[EventSoup]) = discard

# }}} constructors

# Queueing {{{1

proc Enqueue*[C,T](self: var EventQueue; channel: C; e: var T) =
  ## Inserts the provided event object on a given channel. Note that the
  ## channel may not actually be read (e.g. if events are bound to all
  ## channels.) If a channel is significant (e.g. a unique ID for a
  ## command) then it should *never* be a static magic number; it
  ## should be carried along from a definition in userspace code.
  doAssert(sizeof(T) <= sizeof(Event[EventSoup]),
    "Events which are larger than 16 machine words cannot be enqueued.")
  # TODO: Move the above assert in to the "MakeIntoEvent" macro somehow
  var box: Event[EventSoup]
  box.uid     = T.GetEventTypeUid
  box.channel = ord(channel)
  copyMem(addr(box.Data), addr(e), sizeof(T))
  self.scheduled.enqueue(box)

# }}} queue

# Dequeuing {{{1

iterator Items*(self: var EventQueue): Event =
  ## Iterates through each scheduled event, removing them from the
  ## queue as they are returned.
  while self.scheduled.len > 0:
    yield self.scheduled.dequeue()

# }}} dequeue

# Connection {{{1

template On* [E](self: var EventQueue;
  eventType: E; call: FPublicEventBinding[E]) =
    ## Connects an `eventType` to a procedure `call`.
    let closure: FEventBinding =
      proc(e: Event[EventSoup]) =
        var e2 = e
        var e3 = cast[ptr Event[eventType]](addr e2)
        call(e3)
    let binding = EventBinding(Uid: eventType.GetEventTypeUid,
      Channel: 0,
      Transmitter: closure)
    self.bindings.add(binding)

template On* [E,C](self: var EventQueue;
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

proc DisconnectAllImpl(self: var EventQueue; uid: int) =
  var i: int = self.bindings.low
  while i < self.bindings.len:
    let e2 = self.bindings[i]
    if e2.Uid == Uid:
      self.bindings.del(i)
    inc i

template DisconnectAll*[E](self: var EventQueue; eventType: E) =
  ## Disconnect all events of a specific `eventType`.
  bind DisconnectAllImpl
  DisconnectAllImpl(self, eventType.GetEventTypeUid)

proc DisconnectAllImpl(self: var EventQueue; uid, channel: int) =
  var i: int = self.bindings.low
  while i < self.bindings.len:
    let e2 = self.bindings[i]
    if e2.Uid == Uid:
      if e2.Channel == channel:
        self.bindings.del(i)
    inc i

template DisconnectAll*[E,C](self: var EventQueue; eventType: E; chan: C) =
  ## Disconnect all events of a specific `eventType` and `chan`-nel
  ## identifier..
  bind DisconnectAllImpl
  DisconnectAllImpl(self, eventType.GetEventTypeUid, ord(chan))

# }}} disconnect

# Processing {{{1

# TODO: consider adding a "process just one event"?

proc Process*(self: var EventQueue) =
  ## Processes all outstanding events against the table of connected
  ## bindings.
  for e in items(self.scheduled):
    var handled = false
    for h in items(self.bindings):
      if e.Uid == h.Uid:
        h.Transmitter(e)
        handled = true
        break # Binding handled
    if not handled:
      self.OnUnhandled(e)

# }}} processing

