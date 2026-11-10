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

proc onGamepadDisconnected(
  eventType: cint,
  gamepadEvent: ptr EmscriptenGamepadEvent,
  userData: pointer
): EM_BOOL {.cdecl.} =
  ## Tracks a disconnected browser gamepad.
  discard eventType
  discard userData

  if gamepadEvent.index in 0 ..< MaxGamepads and
    (gamepadsConnectedMask and (1'u8 shl gamepadEvent.index)) != 0:
    gamepadsConnectedMask =
      gamepadsConnectedMask and (not (1'u8 shl gamepadEvent.index))
    gamepadResetState(gamepadStates[gamepadEvent.index])
  1

proc setupGamepads() =
  ## Registers currently visible standard-mapped browser gamepads.
  discard emscripten_sample_gamepad_data()

  var gamepad: EmscriptenGamepadEvent
  for i in 0 ..< MaxGamepads:
    let bit = 1'u8 shl i
    if emscripten_get_gamepad_status(cint i, addr gamepad) == 0 and
      gamepad.connected and gamepad.mapping.toString() == "standard":
        gamepadsConnectedMask = gamepadsConnectedMask or bit
        gamepadStates[i].name = gamepad.id.toString()
    else:
      gamepadsConnectedMask = gamepadsConnectedMask and not bit
      gamepadResetState(gamepadStates[i])

proc initGamepads*() =
  ## Initializes gamepad support and scans controllers visible to the browser.
  if initialized:
    return

  discard emscripten_set_gamepaddisconnected_callback_on_thread(
    nil,
    1,
    onGamepadDisconnected,
    EM_CALLBACK_THREAD_CONTEXT
  )
  setupGamepads()
  initialized = true

proc scanGamepads*() =
  ## Discovers visible controllers without resetting existing input; may block.
  if not initialized:
    initGamepads()
  else:
    setupGamepads()

proc closeGamepads*() =
  ## Closes Emscripten gamepad support.
  if not initialized:
    return
  discard emscripten_set_gamepaddisconnected_callback_on_thread(
    nil, 1, nil, EM_CALLBACK_THREAD_CONTEXT
  )
  gamepadsConnectedMask = 0
  for i in 0 ..< MaxGamepads:
    gamepadResetState(gamepadStates[i])
  initialized = false

proc pollGamepads*(): seq[Gamepad] =
  ## Reads known controllers and removes disconnected ones without discovery.
  ## The first call initializes and scans if initGamepads was not called.
  if not initialized:
    initGamepads()

  discard emscripten_sample_gamepad_data()

  var gamepad: EmscriptenGamepadEvent
  for i in 0 ..< MaxGamepads:
    if (gamepadsConnectedMask and (1'u8 shl i)) == 0:
      continue

    if emscripten_get_gamepad_status(cint i, addr gamepad) != 0 or
      not gamepad.connected:
      gamepadsConnectedMask = gamepadsConnectedMask and not (1'u8 shl i)
      gamepadResetState(gamepadStates[i])
      continue

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
