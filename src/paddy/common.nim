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
    GamepadC
    GamepadZ
    GamepadGearDown
    GamepadGearUp
    GamepadGripL
    GamepadGripR
    GamepadGripL2
    GamepadGripR2
    GamepadMisc0
    GamepadMisc1
    GamepadMisc2
    GamepadMisc3
    GamepadMisc4
    GamepadMisc5
    GamepadMisc6
    GamepadMisc7
    GamepadMisc8
    GamepadMisc9
    GamepadHappy1
    GamepadHappy2
    GamepadHappy3
    GamepadHappy4
    GamepadHappy5
    GamepadHappy6
    GamepadHappy7
    GamepadHappy8
    GamepadHappy9
    GamepadHappy10
    GamepadHappy11
    GamepadHappy12
    GamepadHappy13
    GamepadHappy14
    GamepadHappy15
    GamepadHappy16
    GamepadHappy17
    GamepadHappy18
    GamepadHappy19
    GamepadHappy20
    GamepadHappy21
    GamepadHappy22
    GamepadHappy23
    GamepadHappy24
    GamepadHappy25
    GamepadHappy26
    GamepadHappy27
    GamepadHappy28
    GamepadButtonCount

  GamepadAxis* = enum
    GamepadLStickX
    GamepadLStickY
    GamepadRStickX
    GamepadRStickY
    GamepadLTrigger
    GamepadRTrigger
    GamepadThrottle
    GamepadRudder
    GamepadAxisCount

  Gamepad* = object
    id*: int
    name*: string
    buttons*: uint64
    pressed*: uint64
    released*: uint64
    pressures*: array[GamepadButtonCount.int, float32]
    axes*: array[GamepadAxisCount.int, float32]

const
  MaxGamepads* = 4

proc button*(gamepad: Gamepad, button: GamepadButton): bool =
  ## Returns true when the button is currently down.
  (gamepad.buttons and (1'u64 shl button.int)) != 0

proc buttonPressed*(gamepad: Gamepad, button: GamepadButton): bool =
  ## Returns true when the button was pressed this frame.
  (gamepad.pressed and (1'u64 shl button.int)) != 0

proc buttonReleased*(gamepad: Gamepad, button: GamepadButton): bool =
  ## Returns true when the button was released this frame.
  (gamepad.released and (1'u64 shl button.int)) != 0

proc buttonPressure*(gamepad: Gamepad, button: GamepadButton): float32 =
  ## Returns the pressure for the given button.
  gamepad.pressures[button.int]

proc axis*(gamepad: Gamepad, axis: GamepadAxis): float32 =
  ## Returns the value for the given axis.
  gamepad.axes[axis.int]
