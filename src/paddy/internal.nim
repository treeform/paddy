import common

const
  GamepadDeadzone* = 0.1'f

type
  GamepadState* = object
    buttons*: uint64
    pressed*: uint64
    released*: uint64
    pressures*: array[GamepadButtonCount.int, float32]
    axes*: array[GamepadAxisCount.int, float32]
    name*: string

proc gamepadFilterDeadZone*(value: float32): float32 =
  ## Filters small axis values to zero.
  if abs(value) < GamepadDeadzone:
    0.0'f
  else:
    value

template gamepadUpdateButtons*(state: var GamepadState, buttons: uint64) =
  let prevButtons = state.buttons
  state.buttons = buttons
  state.pressed = buttons and (not prevButtons)
  state.released = prevButtons and (not buttons)

proc gamepadResetState*(state: var GamepadState) =
  ## Resets the gamepad state to a disconnected default.
  state.buttons = 0'u32
  state.pressed = 0'u32
  state.released = 0'u32
  for i in 0 ..< GamepadButtonCount.int:
    state.pressures[i] = 0.0'f
  for i in 0 ..< GamepadAxisCount.int:
    state.axes[i] = 0.0'f
  state.name = ""

proc toGamepad*(state: GamepadState, id: int): Gamepad =
  ## Converts an internal gamepad state into a public gamepad snapshot.
  result.id = id
  result.name = state.name
  result.buttons = state.buttons
  result.pressed = state.pressed
  result.released = state.released
  result.pressures = state.pressures
  result.axes = state.axes
