import
  ../[common, internal],
  emscripten_defs

var
  initialized: bool
  gamepadsConnectedMask: uint8
  gamepadStates: array[MaxGamepads, GamepadState]

proc toCString(buffer: openArray[char]): cstring =
  ## Returns the start of a null-terminated char buffer.
  if buffer.len == 0:
    return nil
  cast[cstring](unsafeAddr buffer[0])

proc toString(buffer: openArray[char]): string =
  ## Converts a null-terminated char buffer into a Nim string.
  let value = buffer.toCString()
  if value == nil:
    ""
  else:
    $value

proc onGamepadConnected(
  eventType: cint,
  gamepadEvent: ptr EmscriptenGamepadEvent,
  userData: pointer
): EM_BOOL {.cdecl.} =
  ## Tracks a connected browser gamepad.
  discard eventType
  discard userData

  if strcmp(gamepadEvent.mapping.toCString(), "standard") == 0:
    gamepadsConnectedMask =
      gamepadsConnectedMask or (1'u8 shl gamepadEvent.index)
    gamepadStates[gamepadEvent.index].name = gamepadEvent.id.toString()
  1

proc onGamepadDisconnected(
  eventType: cint,
  gamepadEvent: ptr EmscriptenGamepadEvent,
  userData: pointer
): EM_BOOL {.cdecl.} =
  ## Tracks a disconnected browser gamepad.
  discard eventType
  discard userData

  if (gamepadsConnectedMask and (1'u8 shl gamepadEvent.index)) != 0:
    gamepadsConnectedMask =
      gamepadsConnectedMask and (not (1'u8 shl gamepadEvent.index))
    gamepadResetState(gamepadStates[gamepadEvent.index])
  1

proc setupGamepads() =
  ## Samples any already-connected browser gamepads.
  discard emscripten_sample_gamepad_data()

  var gamepad: EmscriptenGamepadEvent
  for i in 0 ..< MaxGamepads:
    if emscripten_get_gamepad_status(cint i, addr gamepad) == 0 and
      gamepad.connected:
        discard onGamepadConnected(0, addr gamepad, nil)

proc initGamepads*() =
  ## Initializes Emscripten gamepad support.
  if initialized:
    return

  discard emscripten_set_gamepadconnected_callback_on_thread(
    nil,
    1,
    onGamepadConnected,
    EM_CALLBACK_THREAD_CONTEXT
  )
  discard emscripten_set_gamepaddisconnected_callback_on_thread(
    nil,
    1,
    onGamepadDisconnected,
    EM_CALLBACK_THREAD_CONTEXT
  )
  setupGamepads()
  initialized = true

proc closeGamepads*() =
  ## Closes Emscripten gamepad support.
  gamepadsConnectedMask = 0
  for i in 0 ..< MaxGamepads:
    gamepadResetState(gamepadStates[i])
  initialized = false

proc pollGamepads*(): seq[Gamepad] =
  ## Polls browser gamepads and returns connected snapshots.
  if not initialized:
    initGamepads()

  discard emscripten_sample_gamepad_data()

  var gamepad: EmscriptenGamepadEvent
  for i in 0 ..< MaxGamepads:
    if (gamepadsConnectedMask and (1'u8 shl i)) == 0:
      continue

    discard emscripten_get_gamepad_status(cint i, addr gamepad)

    var
      state = addr gamepadStates[i]
      buttons = 0'u64

    for j in 0 ..< GamepadButtonCount.int:
      state.pressures[j] = gamepad.analogButton[j].float32
      if gamepad.digitalButton[j]:
        buttons = buttons or (1'u64 shl j)

    for j in 0 ..< GamepadAxisCount.int:
      state.axes[j] = gamepadFilterDeadZone(gamepad.axis[j].float32)

    gamepadUpdateButtons(state[], buttons)
    result.add state[].toGamepad(i)
