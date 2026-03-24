import windy, paddy

let window = newWindow("Paddy Basic", ivec2(1280, 720))

initGamepads()

proc sampleGamepad(gamepad: paddy.Gamepad) =
  ## Prints the full controller state in a simple text form.
  for button in paddy.GamepadA ..< paddy.GamepadButtonCount:
    if gamepad.buttonPressed(button):
      echo gamepad.name, " pressed ", button

    if gamepad.buttonReleased(button):
      echo gamepad.name, " released ", button

    let pressure = gamepad.buttonPressure(button)
    if pressure > 0.0'f and pressure < 1.0'f:
      echo gamepad.name, " pressure ", button, ": ", pressure

  for axis in paddy.GamepadLStickX ..< paddy.GamepadAxisCount:
    let value = gamepad.axis(axis)
    if value != 0.0'f:
      echo gamepad.name, " axis ", axis, ": ", value

while not window.closeRequested:
  for gamepad in pollGamepads():
    sampleGamepad(gamepad)

  pollEvents()
