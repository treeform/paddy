type
  PaddyError* = object of ValueError
  ## Raised when a Paddy operation fails.

  GamepadButton* = enum
    GamepadA
    GamepadB
    GamepadX
    GamepadY
    GamepadL1
    GamepadR1
    GamepadL2
    GamepadR2
    GamepadSelect
    GamepadStart
    GamepadL3
    GamepadR3
    GamepadUp
    GamepadDown
    GamepadLeft
    GamepadRight
    GamepadHome
    GamepadTouchpad
    GamepadButtonCount

  GamepadAxis* = enum
    GamepadLStickX
    GamepadLStickY
    GamepadRStickX
    GamepadRStickY
    GamepadAxisCount

  Gamepad* = object
    id*: int
    name*: string
    buttons*: uint32
    pressed*: uint32
    released*: uint32
    pressures*: array[GamepadButtonCount.int, float32]
    axes*: array[GamepadAxisCount.int, float32]

const
  MaxGamepads* = 4

proc button*(gamepad: Gamepad, button: GamepadButton): bool =
  ## Returns true when the button is currently down.
  (gamepad.buttons and (1'u32 shl button.int)) != 0

proc buttonPressed*(gamepad: Gamepad, button: GamepadButton): bool =
  ## Returns true when the button was pressed this frame.
  (gamepad.pressed and (1'u32 shl button.int)) != 0

proc buttonReleased*(gamepad: Gamepad, button: GamepadButton): bool =
  ## Returns true when the button was released this frame.
  (gamepad.released and (1'u32 shl button.int)) != 0

proc buttonPressure*(gamepad: Gamepad, button: GamepadButton): float32 =
  ## Returns the pressure for the given button.
  gamepad.pressures[button.int]

proc axis*(gamepad: Gamepad, axis: GamepadAxis): float32 =
  ## Returns the value for the given axis.
  gamepad.axes[axis.int]
