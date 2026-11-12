import
  paddy/[common, internal],
  backend_source

type
  EM_BOOL = cint
  EmscriptenGamepadEvent = object
    timestamp: cdouble
    numAxes, numButtons: cint
    axis, analogButton: array[64, cdouble]
    digitalButton: array[64, bool]
    connected: bool
    index: cint
    id, mapping: array[64, char]
  DisconnectCallback = proc(kind: cint, event: ptr EmscriptenGamepadEvent,
    context: pointer): EM_BOOL {.cdecl.}

const EM_CALLBACK_THREAD_CONTEXT = cast[pointer](1)

var
  nativePads: array[MaxGamepads, EmscriptenGamepadEvent]
  reads: array[MaxGamepads, int]
  samples, callbackRegistrations: int
  disconnectCallback: DisconnectCallback

proc emscripten_sample_gamepad_data(): cint =
  ## Samples the fixture's browser-visible device state.
  inc samples

proc emscripten_get_gamepad_status(index: cint,
    state: ptr EmscriptenGamepadEvent): cint =
  ## Counts requested slots and copies their native state.
  inc reads[index]
  state[] = nativePads[index]

proc emscripten_set_gamepaddisconnected_callback_on_thread(context: pointer,
    capture: cint, callback: DisconnectCallback, thread: pointer): cint =
  ## Registers or unregisters the fixture's browser callback.
  inc callbackRegistrations
  disconnectCallback = callback

backendSource("emscripten.nim")

proc attach(index: int) =
  ## Makes a standard-mapped device visible to the simulated browser.
  nativePads[index] = EmscriptenGamepadEvent(connected: true, index: index.cint)
  for i, ch in "standard": nativePads[index].mapping[i] = ch
  nativePads[index].id[0] = char(ord('A') + index)

proc testDiscovery() =
  ## Checks registration, input edges, callbacks, and lifecycle boundaries.
  scanGamepads()
  doAssert samples == 1 and callbackRegistrations == 1
  initGamepads()
  doAssert samples == 1
  let initialReads = reads
  for i in 0 ..< 100:
    doAssert pollGamepads().len == 0
  doAssert reads == initialReads

  attach(0)
  nativePads[0].digitalButton[GamepadA.int] = true
  doAssert pollGamepads().len == 0
  scanGamepads()
  var pads = pollGamepads()
  doAssert pads.len == 1 and pads[0].id == 0
  doAssert pads[0].buttonPressed(GamepadA)
  scanGamepads()
  pads = pollGamepads()
  doAssert pads[0].button(GamepadA) and not pads[0].buttonPressed(GamepadA)
  let knownReads = reads
  discard pollGamepads()
  doAssert reads[1 .. ^1] == knownReads[1 .. ^1]

  attach(1)
  doAssert pollGamepads().len == 1
  scanGamepads()
  pads = pollGamepads()
  doAssert pads.len == 2 and pads[0].id == 0 and pads[1].id == 1

  nativePads[0].connected = false
  discard disconnectCallback(0, addr nativePads[0], nil)
  doAssert pollGamepads().len == 1
  doAssert gamepadStates[0].buttons == 0
  attach(0)
  doAssert pollGamepads().len == 1
  scanGamepads()
  doAssert pollGamepads().len == 2
  nativePads[1].connected = false
  doAssert pollGamepads().len == 1

  var invalid = EmscriptenGamepadEvent(index: -1)
  discard disconnectCallback(0, addr invalid, nil)
  invalid.index = MaxGamepads.cint
  discard disconnectCallback(0, addr invalid, nil)
  closeGamepads()
  doAssert disconnectCallback == nil and not initialized
  doAssert gamepadsConnectedMask == 0
  closeGamepads()
  let previousSamples = samples
  doAssert pollGamepads().len == 1
  doAssert samples == previousSamples + 2
  doAssert callbackRegistrations == 3
  closeGamepads()

testDiscovery()
