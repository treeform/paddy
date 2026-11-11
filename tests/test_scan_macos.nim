import
  paddy/[common, internal],
  backend_source

type
  ID = distinct int
  Class = distinct int
  SEL = distinct int
  IMP = pointer
  NSObject = distinct int
  NSApplication = distinct int
  NSNotificationCenter = distinct int
  NSNotification = distinct int
  NSString = distinct int
  NSArray = distinct int
  NSDictionary = distinct int
  GCController = distinct int
  GCPhysicalInputProfile = distinct int
  GCControllerElement = distinct int
  GCControllerAxisInput = distinct int
  GCControllerButtonInput = distinct int
  GCControllerDirectionPad = distinct int
  GCSystemGestureState = enum GCSystemGestureStateDisabled
  DisconnectCallback = proc(self: ID, cmd: SEL, event: NSNotification) {.cdecl.}

const
  GCControllerDidDisconnectNotification = 99.NSString
  GCInputButtonA = 1.NSString
  GCInputButtonB = 2.NSString
  GCInputButtonX = 3.NSString
  GCInputButtonY = 4.NSString
  GCInputLeftShoulder = 5.NSString
  GCInputRightShoulder = 6.NSString
  GCInputLeftTrigger = 7.NSString
  GCInputRightTrigger = 8.NSString
  GCInputLeftThumbstickButton = 9.NSString
  GCInputRightThumbstickButton = 10.NSString
  GCInputButtonOptions = 11.NSString
  GCInputButtonMenu = 12.NSString
  GCInputButtonHome = 13.NSString
  GCInputDirectionPad = 14.NSString
  GCInputLeftThumbstick = 15.NSString
  GCInputRightThumbstick = 16.NSString

var
  attached, held: array[MaxGamepads, bool]
  references: array[MaxGamepads, int]
  enumerations, observerAdds, observerRemoves, classCreations: int
  notificationSource: int
  disconnectCallback: DisconnectCallback
  observing: bool

template autoreleasepool(body: untyped) =
  ## Runs the production autorelease scope without a native runtime.
  body

proc s(value: string): SEL =
  ## Supplies a fixture selector.
  1.SEL

proc getClass(kind: typedesc[NSObject]): Class =
  ## Supplies the NSObject base class.
  1.Class

proc new(kind: Class): ID =
  ## Allocates the fixture notification observer.
  900.ID

proc objc_allocateClassPair(base: Class, name: cstring): Class =
  ## Counts notification observer class creation.
  inc classCreations
  2.Class

proc class_addMethod(kind: Class, selector: SEL, callback: IMP, types: cstring): bool =
  ## Retains the production callback for simulated native notifications.
  disconnectCallback = cast[DisconnectCallback](callback)
  true

proc objc_registerClassPair(kind: Class) =
  ## Registers the fixture observer class.
  discard

proc defaultCenter(kind: typedesc[NSNotificationCenter]): NSNotificationCenter =
  ## Supplies the notification center.
  1.NSNotificationCenter

proc addObserver(center: NSNotificationCenter, observer: NSObject,
    selector: SEL, name: NSString, source: ID) =
  ## Enables delivery to the production notification callback.
  inc observerAdds
  observing = true

proc removeObserver(center: NSNotificationCenter, observer: NSObject) =
  ## Stops notification delivery when Paddy closes.
  inc observerRemoves
  observing = false

proc `object`(notification: NSNotification): ID =
  ## Identifies the controller carried by a disconnect notification.
  notificationSource.ID

proc retain(value: NSObject): NSObject =
  ## Counts ownership of cached controller objects.
  inc references[value.int - 1]
  value

proc release(value: NSObject) =
  ## Checks that cached controllers are released exactly once.
  if value.int != 900:
    dec references[value.int - 1]
    doAssert references[value.int - 1] >= 0

proc sharedApplication(kind: typedesc[NSApplication]): NSApplication =
  ## Supplies the application instance without opening a desktop app.
  1.NSApplication

proc setShouldMonitorBackgroundEvents(kind: typedesc[GCController], enabled: bool) =
  ## Accepts the existing background input policy.
  discard

proc startWirelessControllerDiscoveryWithCompletionHandler(kind: typedesc[GCController], callback: ID) =
  ## Leaves wireless visibility under fixture control.
  discard

proc controllers(kind: typedesc[GCController]): NSArray =
  ## Counts enumeration of the OS controller list.
  inc enumerations
  1.NSArray

proc count(items: NSArray): uint =
  ## Counts attached fixture controllers.
  for value in attached:
    if value: inc result

proc `[]`(items: NSArray, index: int): ID =
  ## Returns the controller at a position in the current OS list.
  var position = 0
  for i, value in attached:
    if value:
      if position == index: return (i + 1).ID
      inc position

proc physicalInputProfile(controller: GCController): GCPhysicalInputProfile =
  ## Supplies a stable profile identity.
  controller.int.GCPhysicalInputProfile

proc vendorName(controller: GCController): NSString =
  ## Supplies a stable name handle.
  controller.int.NSString

proc `$`(name: NSString): string =
  ## Resolves the fixture controller's name.
  "Controller " & $name.int

proc dpads(profile: GCPhysicalInputProfile): NSDictionary =
  ## Supplies an empty direction-pad dictionary.
  0.NSDictionary

proc buttons(profile: GCPhysicalInputProfile): NSDictionary =
  ## Supplies the profile's one-button dictionary.
  profile.int.NSDictionary

proc `[]`(items: NSDictionary, key: NSString): ID =
  ## Exposes only the fixture's A button.
  if items.int != 0 and key.int == GCInputButtonA.int: (100 + items.int).ID
  else: 0.ID

proc setPreferredSystemGestureState(input: GCControllerElement, state: GCSystemGestureState) =
  ## Accepts the existing gesture policy.
  discard

proc xAxis(input: GCControllerDirectionPad): GCControllerAxisInput =
  ## Reports no analog input.
  0.GCControllerAxisInput

proc yAxis(input: GCControllerDirectionPad): GCControllerAxisInput =
  ## Reports no analog input.
  0.GCControllerAxisInput

proc down(input: GCControllerDirectionPad): GCControllerButtonInput =
  ## Reports no direction-pad button.
  0.GCControllerButtonInput

proc right(input: GCControllerDirectionPad): GCControllerButtonInput =
  ## Reports no direction-pad button.
  0.GCControllerButtonInput

proc left(input: GCControllerDirectionPad): GCControllerButtonInput =
  ## Reports no direction-pad button.
  0.GCControllerButtonInput

proc up(input: GCControllerDirectionPad): GCControllerButtonInput =
  ## Reports no direction-pad button.
  0.GCControllerButtonInput

proc lastEventTimestamp(profile: GCPhysicalInputProfile): float64 =
  ## Supplies a stable timestamp after the fixture's initial input report.
  1.0

proc value(input: GCControllerAxisInput): float32 =
  ## Reports no analog movement.
  0

proc value(input: GCControllerButtonInput): float32 =
  ## Reports the fixture button's pressure.
  float32(held[input.int - 101])

proc isPressed(input: GCControllerButtonInput): bool =
  ## Reports the fixture button's held state.
  held[input.int - 101]

backendSource("macos.nim")

proc testDiscovery() =
  ## Checks native-list gating, disconnect callbacks, and controller ownership.
  scanGamepads()
  doAssert enumerations == 1 and observerAdds == 1
  initGamepads()
  for i in 0 ..< 100: doAssert pollGamepads().len == 0
  doAssert enumerations == 1
  attached[0] = true
  held[0] = true
  doAssert pollGamepads().len == 0
  scanGamepads()
  var pads = pollGamepads()
  doAssert pads.len == 1 and pads[0].id == 0
  doAssert pads[0].buttonPressed(GamepadA)
  scanGamepads()
  pads = pollGamepads()
  doAssert pads[0].button(GamepadA) and not pads[0].buttonPressed(GamepadA)
  doAssert references[0] == 1
  attached[1] = true
  doAssert pollGamepads().len == 1
  scanGamepads()
  pads = pollGamepads()
  doAssert pads.len == 2 and pads[0].id == 0 and pads[1].id == 1
  let scansBefore = enumerations
  for i in 0 ..< 100: discard pollGamepads()
  doAssert enumerations == scansBefore

  attached[0] = false
  notificationSource = 1
  doAssert observing
  disconnectCallback(900.ID, 1.SEL, 1.NSNotification)
  doAssert pollGamepads().len == 1
  doAssert references[0] == 0 and gamepadStates[0].buttons == 0
  attached[0] = true
  doAssert pollGamepads().len == 1
  scanGamepads()
  doAssert pollGamepads().len == 2
  closeGamepads()
  doAssert not observing and observerRemoves == 1
  doAssert references == default(typeof(references))
  let scansClosed = enumerations
  doAssert pollGamepads().len == 2
  doAssert enumerations == scansClosed + 1
  doAssert classCreations == 1 and observerAdds == 2
  closeGamepads()
  doAssert observerRemoves == 2
  doAssert references == default(typeof(references))

testDiscovery()
