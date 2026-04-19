import macos_objc

export macos_objc

{.passL: "-framework Foundation -framework AppKit -framework GameController".}

type
  NSObject* = distinct int
  NSArray* = distinct NSObject
  NSDictionary* = distinct NSObject
  NSApplication* = distinct NSObject
  NSString* = macos_objc.NSString

  GCController* = distinct NSObject
  GCPhysicalInputProfile* = distinct NSObject
  GCControllerElement* = distinct NSObject
  GCControllerAxisInput* = distinct GCControllerElement
  GCControllerButtonInput* = distinct GCControllerElement
  GCControllerDirectionPad* = distinct GCControllerElement

  GCSystemGestureState* = enum
    GCSystemGestureStateEnabled
    GCSystemGestureStateAlwaysReceive
    GCSystemGestureStateDisabled

var
  GCInputLeftShoulder* {.importc.}: NSString
  GCInputRightShoulder* {.importc.}: NSString
  GCInputLeftTrigger* {.importc.}: NSString
  GCInputRightTrigger* {.importc.}: NSString
  GCInputButtonMenu* {.importc.}: NSString
  GCInputButtonHome* {.importc.}: NSString
  GCInputButtonOptions* {.importc.}: NSString
  GCInputButtonA* {.importc.}: NSString
  GCInputButtonB* {.importc.}: NSString
  GCInputButtonX* {.importc.}: NSString
  GCInputButtonY* {.importc.}: NSString
  GCInputDirectionPad* {.importc.}: NSString
  GCInputLeftThumbstick* {.importc.}: NSString
  GCInputRightThumbstick* {.importc.}: NSString
  GCInputLeftThumbstickButton* {.importc.}: NSString
  GCInputRightThumbstickButton* {.importc.}: NSString

objc:
  proc sharedApplication*(class: typedesc[NSApplication]): NSApplication
  proc count*(self: NSArray): uint
  proc objectAtIndex*(self: NSArray, x: uint): ID
  proc valueForKey*(self: NSDictionary, x: NSString): ID
  proc controllers*(class: typedesc[GCController]): NSArray
  proc setShouldMonitorBackgroundEvents*(
    class: typedesc[GCController],
    x: bool
  )
  proc startWirelessControllerDiscoveryWithCompletionHandler*(
    class: typedesc[GCController],
    x: ID
  )
  proc physicalInputProfile*(self: GCController): GCPhysicalInputProfile
  proc vendorName*(self: GCController): NSString
  proc lastEventTimestamp*(self: GCPhysicalInputProfile): float64
  proc dpads*(self: GCPhysicalInputProfile): NSDictionary
  proc buttons*(self: GCPhysicalInputProfile): NSDictionary
  proc xAxis*(self: GCControllerDirectionPad): GCControllerAxisInput
  proc yAxis*(self: GCControllerDirectionPad): GCControllerAxisInput
  proc down*(self: GCControllerDirectionPad): GCControllerButtonInput
  proc right*(self: GCControllerDirectionPad): GCControllerButtonInput
  proc left*(self: GCControllerDirectionPad): GCControllerButtonInput
  proc up*(self: GCControllerDirectionPad): GCControllerButtonInput
  proc value*(self: GCControllerAxisInput): float32
  proc value*(self: GCControllerButtonInput): float32
  proc isPressed*(self: GCControllerButtonInput): bool
  proc setPreferredSystemGestureState*(
    self: GCControllerElement,
    x: GCSystemGestureState
  )

template `[]`*(dict: NSDictionary, key: NSString): ID =
  dict.valueForKey(key)

template `[]`*(items: NSArray, index: int): ID =
  items.objectAtIndex(index.uint)
