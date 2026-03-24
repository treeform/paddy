import
  ../[common, internal],
  macos_defs

type
  GamepadProfile = object
    numButtons: int8
    numAxes: int8

var
  initialized: bool
  gamepadProfiles: array[MaxGamepads, GCPhysicalInputProfile]
  gamepadMeta: array[MaxGamepads, GamepadProfile]
  gamepadStates: array[MaxGamepads, GamepadState]
  gamepadTimestamps: array[MaxGamepads, float64]
  gamepadAxisLookup: array[
    MaxGamepads,
    array[GamepadAxisCount.int, int8]
  ]
  gamepadAxisInputs: array[
    MaxGamepads,
    array[GamepadAxisCount.int, GCControllerAxisInput]
  ]
  gamepadButtonLookup: array[
    MaxGamepads,
    array[GamepadButtonCount.int, int8]
  ]
  gamepadButtonInputs: array[
    MaxGamepads,
    array[GamepadButtonCount.int, GCControllerButtonInput]
  ]

proc clearSlot(index: int) =
  ## Clears a macOS gamepad slot.
  gamepadProfiles[index] = 0.GCPhysicalInputProfile
  gamepadTimestamps[index] = 0.0
  gamepadMeta[index] = GamepadProfile()
  gamepadResetState(gamepadStates[index])

proc assignController(slot: int, controller: GCController) =
  ## Assigns a controller profile to a slot and caches its inputs.
  let profile = controller.physicalInputProfile()
  let
    dpads = profile.dpads()
    buttons = profile.buttons()
  var
    numAxes = 0
    numButtons = 0

  proc addButton(input: GCControllerButtonInput, index: GamepadButton) =
    if input.int != 0:
      input.GCControllerElement.setPreferredSystemGestureState(
        GCSystemGestureStateDisabled
      )
      gamepadButtonInputs[slot][numButtons] = input
      gamepadButtonLookup[slot][numButtons] = index.int8
      inc numButtons

  proc addAxis(input: GCControllerAxisInput, index: GamepadAxis) =
    if input.int != 0:
      gamepadAxisInputs[slot][numAxes] = input
      gamepadAxisLookup[slot][numAxes] = index.int8
      inc numAxes

  proc addStick(
    stick: GCControllerDirectionPad,
    x: GamepadAxis,
    y: GamepadAxis
  ) =
    if stick.int != 0:
      addAxis(stick.xAxis, x)
      addAxis(stick.yAxis, y)

  let dpad = dpads[GCInputDirectionPad].GCControllerDirectionPad
  if dpad.int != 0:
    addButton(dpad.down, GamepadDown)
    addButton(dpad.right, GamepadRight)
    addButton(dpad.left, GamepadLeft)
    addButton(dpad.up, GamepadUp)

  addButton(buttons[GCInputButtonA].GCControllerButtonInput, GamepadA)
  addButton(buttons[GCInputButtonB].GCControllerButtonInput, GamepadB)
  addButton(buttons[GCInputButtonX].GCControllerButtonInput, GamepadX)
  addButton(buttons[GCInputButtonY].GCControllerButtonInput, GamepadY)
  addButton(
    buttons[GCInputLeftShoulder].GCControllerButtonInput,
    GamepadL1
  )
  addButton(
    buttons[GCInputRightShoulder].GCControllerButtonInput,
    GamepadR1
  )
  addButton(buttons[GCInputLeftTrigger].GCControllerButtonInput, GamepadL2)
  addButton(buttons[GCInputRightTrigger].GCControllerButtonInput, GamepadR2)
  addButton(
    buttons[GCInputLeftThumbstickButton].GCControllerButtonInput,
    GamepadL3
  )
  addButton(
    buttons[GCInputRightThumbstickButton].GCControllerButtonInput,
    GamepadR3
  )
  addButton(
    buttons[GCInputButtonOptions].GCControllerButtonInput,
    GamepadSelect
  )
  addButton(buttons[GCInputButtonMenu].GCControllerButtonInput, GamepadStart)
  addButton(buttons[GCInputButtonHome].GCControllerButtonInput, GamepadHome)
  addStick(
    dpads[GCInputLeftThumbstick].GCControllerDirectionPad,
    GamepadLStickX,
    GamepadLStickY
  )
  addStick(
    dpads[GCInputRightThumbstick].GCControllerDirectionPad,
    GamepadRStickX,
    GamepadRStickY
  )

  let vendorName = controller.vendorName()
  gamepadProfiles[slot] = profile
  gamepadMeta[slot].numButtons = numButtons.int8
  gamepadMeta[slot].numAxes = numAxes.int8
  gamepadStates[slot].name =
    if vendorName.int == 0:
      ""
    else:
      $vendorName

proc syncControllers() =
  ## Synchronizes the slot table with currently available controllers.
  var seen: array[MaxGamepads, bool]
  let controllers = GCController.controllers()

  for i in 0 ..< controllers.count.int:
    let controller = controllers[i].GCController
    let profile = controller.physicalInputProfile()
    var slot = -1

    for j in 0 ..< MaxGamepads:
      if gamepadProfiles[j].int == profile.int:
        slot = j
        break

    if slot == -1:
      for j in 0 ..< MaxGamepads:
        if gamepadProfiles[j].int == 0:
          slot = j
          assignController(j, controller)
          break

    if slot != -1:
      seen[slot] = true

  for i in 0 ..< MaxGamepads:
    if gamepadProfiles[i].int != 0 and not seen[i]:
      clearSlot(i)

proc initGamepads*() =
  ## Initializes macOS gamepad support.
  if initialized:
    return

  autoreleasepool:
    discard NSApplication.sharedApplication()
    GCController.startWirelessControllerDiscoveryWithCompletionHandler(0.ID)
    syncControllers()

  initialized = true

proc closeGamepads*() =
  ## Closes macOS gamepad support.
  if not initialized:
    return

  for i in 0 ..< MaxGamepads:
    clearSlot(i)

  initialized = false

proc pollGamepads*(): seq[Gamepad] =
  ## Polls macOS gamepads and returns connected snapshots.
  if not initialized:
    initGamepads()

  autoreleasepool:
    syncControllers()

    for i in 0 ..< MaxGamepads:
      let profile = gamepadProfiles[i]
      if profile.int == 0:
        continue

      let epoch = profile.lastEventTimestamp()
      var state = addr gamepadStates[i]
      if epoch <= gamepadTimestamps[i]:
        state.pressed = 0'u64
        state.released = 0'u64
      else:
        gamepadTimestamps[i] = epoch

        for j in 0 ..< gamepadMeta[i].numAxes:
          state.axes[gamepadAxisLookup[i][j]] =
            gamepadAxisInputs[i][j].value()

        var buttons = 0'u64
        for j in 0 ..< gamepadMeta[i].numButtons:
          let button = gamepadButtonInputs[i][j]
          let index = gamepadButtonLookup[i][j]
          state.pressures[index] = button.value()
          if button.isPressed():
            buttons = buttons or (1'u64 shl index)

        gamepadUpdateButtons(state[], buttons)

      result.add state[].toGamepad(i)
