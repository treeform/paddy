import
  ../[common, internal],
  macos_defs

type
  GamepadProfile = object
    numButtons: int8
    numAxes: int8

var
  initialized: bool
  disconnectObserverClass: Class
  disconnectObserver: NSObject
  disconnected: array[MaxGamepads, bool]
  gamepadControllers: array[MaxGamepads, GCController]
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
  if gamepadControllers[index].int != 0:
    gamepadControllers[index].NSObject.release()
  gamepadControllers[index] = 0.GCController
  gamepadProfiles[index] = 0.GCPhysicalInputProfile
  gamepadTimestamps[index] = 0.0
  gamepadMeta[index] = GamepadProfile()
  disconnected[index] = false
  gamepadResetState(gamepadStates[index])

proc controllerDisconnected(self: ID, cmd: SEL, notification: NSNotification) {.cdecl.} =
  ## Marks known controllers for removal when input is next polled or scanned.
  let controller = notification.object().GCController
  for i in 0 ..< MaxGamepads:
    if gamepadControllers[i].int == controller.int:
      disconnected[i] = true

proc removeDisconnected() =
  ## Clears notified slots before their cached inputs are accessed.
  for i in 0 ..< MaxGamepads:
    if disconnected[i]:
      clearSlot(i)

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
  gamepadControllers[slot] = controller.NSObject.retain().GCController
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
  removeDisconnected()
  var seen: array[MaxGamepads, bool]
  let controllers = GCController.controllers()

  for i in 0 ..< controllers.count.int:
    let controller = controllers[i].GCController
    var slot = -1

    for j in 0 ..< MaxGamepads:
      if gamepadControllers[j].int == controller.int:
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
  ## Initializes gamepad support and performs a potentially blocking startup scan.
  if initialized:
    return

  autoreleasepool:
    discard NSApplication.sharedApplication()
    GCController.setShouldMonitorBackgroundEvents(true)
    GCController.startWirelessControllerDiscoveryWithCompletionHandler(0.ID)
    if disconnectObserverClass.int == 0:
      disconnectObserverClass = objc_allocateClassPair(
        NSObject.getClass(), "PaddyDisconnectObserver"
      )
      if disconnectObserverClass.int == 0 or not class_addMethod(
        disconnectObserverClass,
        s"controllerDisconnected:",
        cast[IMP](controllerDisconnected),
        "v@:@"
      ):
        raise newException(PaddyError, "Unable to create controller disconnect observer")
      objc_registerClassPair(disconnectObserverClass)
    disconnectObserver = disconnectObserverClass.new().NSObject
    NSNotificationCenter.defaultCenter().addObserver(
      disconnectObserver,
      s"controllerDisconnected:",
      GCControllerDidDisconnectNotification,
      0.ID
    )
    syncControllers()

  initialized = true

proc scanGamepads*() =
  ## Discovers available controllers without resetting existing input; may block.
  if not initialized:
    initGamepads()
  else:
    autoreleasepool:
      syncControllers()

proc closeGamepads*() =
  ## Closes macOS gamepad support.
  if not initialized:
    return

  NSNotificationCenter.defaultCenter().removeObserver(disconnectObserver)
  disconnectObserver.release()
  disconnectObserver = 0.NSObject
  for i in 0 ..< MaxGamepads:
    clearSlot(i)

  initialized = false

proc pollGamepads*(): seq[Gamepad] =
  ## Reads known controllers and removes disconnected ones without discovery.
  ## The first call initializes and scans if initGamepads was not called.
  if not initialized:
    initGamepads()

  autoreleasepool:
    removeDisconnected()

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
