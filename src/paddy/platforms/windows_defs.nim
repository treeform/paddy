type
  DWORD* = uint32
  WORD* = uint16
  BYTE* = uint8
  SHORT* = int16

  XInputGamepad* {.pure.} = object
    wButtons*: WORD
    bLeftTrigger*: BYTE
    bRightTrigger*: BYTE
    sThumbLX*: SHORT
    sThumbLY*: SHORT
    sThumbRX*: SHORT
    sThumbRY*: SHORT

  XInputState* {.pure.} = object
    dwPacketNumber*: DWORD
    gamepad*: XInputGamepad

const
  ErrorSuccess* = 0'u32
  ErrorDeviceNotConnected* = 1167'u32

  XInputGamepadDpadUp* = 0x0001'u16
  XInputGamepadDpadDown* = 0x0002'u16
  XInputGamepadDpadLeft* = 0x0004'u16
  XInputGamepadDpadRight* = 0x0008'u16
  XInputGamepadStart* = 0x0010'u16
  XInputGamepadBack* = 0x0020'u16
  XInputGamepadLeftThumb* = 0x0040'u16
  XInputGamepadRightThumb* = 0x0080'u16
  XInputGamepadLeftShoulder* = 0x0100'u16
  XInputGamepadRightShoulder* = 0x0200'u16
  XInputGamepadA* = 0x1000'u16
  XInputGamepadB* = 0x2000'u16
  XInputGamepadX* = 0x4000'u16
  XInputGamepadY* = 0x8000'u16

  XInputGamepadLeftThumbDeadzone* = 7849'i16
  XInputGamepadRightThumbDeadzone* = 8689'i16
  XInputGamepadTriggerThreshold* = 30'u8
  XUserMaxCount* = 4
