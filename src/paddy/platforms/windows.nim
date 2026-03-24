import
  std/dynlib,
  ../[common, internal],
  windows_defs

var
  initialized: bool
  xinputLoaded: bool
  xinputLib: LibHandle
  xinputGetState: proc(
    dwUserIndex: DWORD,
    pState: ptr XInputState
  ): DWORD {.stdcall.}
  gamepadStates: array[MaxGamepads, GamepadState]

proc normalizeStick(value: SHORT, deadzone: SHORT): float32 =
  ## Normalizes a stick value to the -1..1 range.
  let absValue = abs(value.int)
  if absValue <= deadzone.int:
    return 0.0'f

  let
    maxValue =
      if value < 0:
        32768.0'f
      else:
        32767.0'f
    scaled =
      if value < 0:
        (value.float32 + deadzone.float32) / (maxValue - deadzone.float32)
      else:
        (value.float32 - deadzone.float32) / (maxValue - deadzone.float32)
  gamepadFilterDeadZone(scaled)

proc normalizeTrigger(value: BYTE): float32 =
  ## Normalizes a trigger value to the 0..1 range.
  if value <= XInputGamepadTriggerThreshold:
    return 0.0'f
  (value.float32 - XInputGamepadTriggerThreshold.float32) /
    (255.0'f - XInputGamepadTriggerThreshold.float32)

proc initGamepads*() =
  ## Initializes Windows gamepad support through XInput.
  if initialized:
    return

  for dllName in ["xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll"]:
    xinputLib = loadLib(dllName)
    if xinputLib != nil:
      break

  if xinputLib != nil:
    xinputGetState = cast[typeof(xinputGetState)](
      symAddr(xinputLib, "XInputGetState")
    )
    xinputLoaded = xinputGetState != nil

  initialized = true

proc clearState(index: int) =
  ## Clears a Windows gamepad slot.
  gamepadResetState(gamepadStates[index])
  gamepadStates[index].name = ""

proc closeGamepads*() =
  ## Closes Windows gamepad support and releases resources.
  if not initialized:
    return

  for i in 0 ..< MaxGamepads:
    clearState(i)

  if xinputLib != nil:
    unloadLib(xinputLib)
    xinputLib = nil

  xinputGetState = nil
  xinputLoaded = false

  initialized = false

proc pollGamepads*(): seq[Gamepad] =
  ## Polls Windows gamepads and returns connected snapshots.
  if not initialized:
    initGamepads()

  if not xinputLoaded:
    return

  for i in 0 ..< min(MaxGamepads, XUserMaxCount):
    var xinputState: XInputState
    let status = xinputGetState(i.DWORD, addr xinputState)

    var state = addr gamepadStates[i]
    if status == ErrorDeviceNotConnected:
      clearState(i)
      continue
    elif status != ErrorSuccess:
      state.pressed = 0'u32
      state.released = 0'u32
      result.add state[].toGamepad(i)
      continue

    state.name = "XInput Controller " & $i

    var buttons = 0'u32

    template button(src: WORD, dst: GamepadButton) =
      if (xinputState.gamepad.wButtons and src) != 0:
        buttons = buttons or (1'u32 shl dst.int)

    template remap(src: BYTE, dst: GamepadButton) =
      let value = normalizeTrigger(src)
      state.pressures[dst.int] = value
      if value > 0:
        buttons = buttons or (1'u32 shl dst.int)

    state.axes[GamepadLStickX.int] = normalizeStick(
      xinputState.gamepad.sThumbLX,
      XInputGamepadLeftThumbDeadzone
    )
    state.axes[GamepadLStickY.int] = normalizeStick(
      xinputState.gamepad.sThumbLY,
      XInputGamepadLeftThumbDeadzone
    )
    state.axes[GamepadRStickX.int] = normalizeStick(
      xinputState.gamepad.sThumbRX,
      XInputGamepadRightThumbDeadzone
    )
    state.axes[GamepadRStickY.int] = normalizeStick(
      xinputState.gamepad.sThumbRY,
      XInputGamepadRightThumbDeadzone
    )
    remap(xinputState.gamepad.bLeftTrigger, GamepadL2)
    remap(xinputState.gamepad.bRightTrigger, GamepadR2)
    button(XInputGamepadStart, GamepadStart)
    button(XInputGamepadBack, GamepadSelect)
    button(XInputGamepadA, GamepadA)
    button(XInputGamepadB, GamepadB)
    button(XInputGamepadX, GamepadX)
    button(XInputGamepadY, GamepadY)
    button(XInputGamepadDpadUp, GamepadUp)
    button(XInputGamepadDpadDown, GamepadDown)
    button(XInputGamepadDpadLeft, GamepadLeft)
    button(XInputGamepadDpadRight, GamepadRight)
    button(XInputGamepadLeftShoulder, GamepadL1)
    button(XInputGamepadRightShoulder, GamepadR1)
    button(XInputGamepadLeftThumb, GamepadL3)
    button(XInputGamepadRightThumb, GamepadR3)

    gamepadUpdateButtons(state[], buttons)
    result.add state[].toGamepad(i)
