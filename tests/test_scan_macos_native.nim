include ../src/paddy/platforms/macos

objc:
  proc postNotificationName(self: NSNotificationCenter, x: macos_defs.NSString, object_mangle: ID)

proc testObserver() =
  ## Exercises the actual Objective-C observer registration and cleanup on macOS.
  for iteration in 0 ..< 2:
    initGamepads()
    var slot = -1
    for i in 0 ..< MaxGamepads:
      if gamepadControllers[i].int == 0:
        slot = i
        break
    doAssert slot >= 0
    let marker = NSObject.new()
    gamepadControllers[slot] = marker.GCController
    gamepadStates[slot].buttons = 1
    NSNotificationCenter.defaultCenter().postNotificationName(
      GCControllerDidDisconnectNotification, marker.ID
    )
    doAssert disconnected[slot]
    discard pollGamepads()
    doAssert gamepadControllers[slot].int == 0
    doAssert gamepadStates[slot].buttons == 0
    closeGamepads()
    doAssert disconnectObserver.int == 0

testObserver()
