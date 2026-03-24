import paddy

echo "Testing paddy"

doAssert MaxGamepads == 4

block:
  var gamepad = Gamepad(id: 1, name: "Test Pad")
  gamepad.buttons = 1'u32 shl GamepadA.int
  gamepad.pressed = gamepad.buttons
  gamepad.pressures[GamepadA.int] = 1.0'f
  gamepad.axes[GamepadLStickX.int] = 0.5'f

  doAssert gamepad.button(GamepadA)
  doAssert gamepad.buttonPressed(GamepadA)
  doAssert not gamepad.buttonReleased(GamepadA)
  doAssert gamepad.buttonPressure(GamepadA) == 1.0'f
  doAssert gamepad.axis(GamepadLStickX) == 0.5'f

echo "Success"
