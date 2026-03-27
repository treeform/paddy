import
  std/[dynlib, times, strutils],
  ../[common, internal],
  windows_directinput_defs,
  windows_defs

const
  MaxDinputDevices* = MaxGamepads - XUserMaxCount  ## Slots available for DI
  EnumerateIntervalSec = 2.0  ## Re-enumerate devices every 2 seconds
  AxisSettlePolls = 30  ## Consecutive same-value polls before recalibrating

type
  DinputDeviceInfo = object
    device: ptr IDirectInputDevice8W
    guidInstance: GUID
    connected: bool
    numButtons: int
    numAxes: int
    numPovs: int
    hasAxis: array[8, bool]  ## Which axes this device actually has
    axisRanges: array[8, tuple[min, max: int32]]
    axisCenter: array[8, int32]  ## Rest values (auto-detected)
    axisPrev: array[8, int32]  ## Previous raw value for settle detection
    axisStable: array[8, int]  ## Consecutive polls at same value

var
  dinputInitialized: bool
  dinputLoaded: bool
  dinputLib: LibHandle
  comOwned: bool
  directInput: ptr IDirectInput8W
  dinputDevices: array[MaxDinputDevices, DinputDeviceInfo]
  dinputStates: array[MaxDinputDevices, GamepadState]
  lastEnumerateTime: float
  directInput8Create: DirectInput8CreateProc

proc guidEqual(a, b: GUID): bool =
  ## Compares two GUIDs for equality.
  a.Data1 == b.Data1 and a.Data2 == b.Data2 and
    a.Data3 == b.Data3 and a.Data4 == b.Data4

proc wcharToString(wstr: openArray[WCHAR]): string =
  ## Converts a null-terminated WCHAR array to a Nim string (ASCII subset).
  result = ""
  for ch in wstr:
    if ch == 0:
      break
    result.add(chr(ch and 0xFF))

proc wcharContains(wstr: openArray[WCHAR], needle: string): bool =
  ## Checks if a WCHAR string contains a substring (case-insensitive ASCII).
  let s = wcharToString(wstr)
  let needleUpper = needle.toUpperAscii()
  let sUpper = s.toUpperAscii()
  needleUpper in sUpper

proc calibratedAxis(raw, center, rangeMin, rangeMax: int32): float32 =
  ## Normalizes an axis relative to its rest center.
  ## Scales positive and negative directions independently from center.
  let delta = float32(raw - center)
  if delta > 0:
    let dist = float32(rangeMax - center)
    if dist <= 0: return 0.0'f
    gamepadFilterDeadZone(clamp(delta / dist, 0.0'f, 1.0'f))
  elif delta < 0:
    let dist = float32(center - rangeMin)
    if dist <= 0: return 0.0'f
    gamepadFilterDeadZone(clamp(delta / dist, -1.0'f, 0.0'f))
  else:
    0.0'f

proc clearDinputState(index: int) =
  ## Clears a DirectInput device slot.
  gamepadResetState(dinputStates[index])
  dinputStates[index].name = ""

proc releaseDevice(index: int) =
  ## Releases a DirectInput device and clears its slot.
  if dinputDevices[index].device != nil:
    discard dinputDevices[index].device.lpVtbl.Unacquire(dinputDevices[index].device)
    discard dinputDevices[index].device.lpVtbl.Release(dinputDevices[index].device)
    dinputDevices[index].device = nil
  dinputDevices[index].connected = false
  clearDinputState(index)

proc isXInputDevice(deviceInstance: ptr DIDEVICEINSTANCEW): bool =
  ## Returns true if this device is an XInput controller.
  ## Uses the Microsoft-documented "IG_" check on product name.
  wcharContains(deviceInstance.tszProductName, "IG_")

proc findFreeSlot(): int =
  ## Returns the index of a free DI device slot, or -1 if full.
  for i in 0 ..< MaxDinputDevices:
    if not dinputDevices[i].connected:
      return i
  return -1

proc findDeviceByGuid(guid: GUID): int =
  ## Returns the slot index for a device GUID, or -1 if not found.
  for i in 0 ..< MaxDinputDevices:
    if dinputDevices[i].connected and guidEqual(dinputDevices[i].guidInstance, guid):
      return i
  return -1

type
  EnumAxisContext = object
    device: ptr IDirectInputDevice8W
    devInfo: ptr DinputDeviceInfo

proc guidToAxisIndex(guid: GUID): int =
  ## Maps a DirectInput axis GUID to our axis index (0-7).
  ## Returns -1 if not a recognized axis.
  ## Matches by Data1 only — some devices report variant Data3 values
  ## (e.g., 0x11CF instead of the SDK-defined 0x11CE).
  let d = guid.Data1
  if d == 0xA36D02E0'u32: return 0   # GUID_XAxis
  if d == 0xA36D02E1'u32: return 1   # GUID_YAxis
  if d == 0xA36D02E2'u32: return 2   # GUID_ZAxis
  if d == 0xA36D02F4'u32: return 3   # GUID_RxAxis
  if d == 0xA36D02F5'u32: return 4   # GUID_RyAxis
  if d == 0xA36D02E3'u32: return 5   # GUID_RzAxis
  if d == 0xA36D02E4'u32: return 6   # GUID_Slider
  return -1

proc enumAxisCallback(
  lpddoi: ptr DIDEVICEOBJECTINSTANCEW,
  pvRef: pointer
): int32 {.stdcall.} =
  ## Callback for EnumObjects — discovers axes and sets their ranges.
  let ctx = cast[ptr EnumAxisContext](pvRef)
  let axisIndex = guidToAxisIndex(lpddoi.guidType)

  if axisIndex < 0:
    return DIENUM_CONTINUE

  # Handle second slider → index 7
  var actualIndex = axisIndex
  if axisIndex == 6 and ctx.devInfo.hasAxis[6]:
    actualIndex = 7  # Second slider

  # Try to set range, then always read back the actual effective range.
  # Some drivers accept SetProperty but silently keep the native range.
  var propRange: DIPROPRANGE
  propRange.diph.dwSize = uint32 sizeof(DIPROPRANGE)
  propRange.diph.dwHeaderSize = uint32 sizeof(DIPROPHEADER)
  propRange.diph.dwObj = lpddoi.dwType
  propRange.diph.dwHow = DIPH_BYID
  propRange.lMin = -32768
  propRange.lMax = 32767
  discard ctx.device.lpVtbl.SetProperty(ctx.device, dipropRange(), addr propRange.diph)

  # Read back the actual range the device is using
  var readRange: DIPROPRANGE
  readRange.diph.dwSize = uint32 sizeof(DIPROPRANGE)
  readRange.diph.dwHeaderSize = uint32 sizeof(DIPROPHEADER)
  readRange.diph.dwObj = lpddoi.dwType
  readRange.diph.dwHow = DIPH_BYID

  let getHr = ctx.device.lpVtbl.GetProperty(ctx.device, dipropRange(), addr readRange.diph)
  ctx.devInfo.hasAxis[actualIndex] = true
  if getHr == DI_OK and readRange.lMax > readRange.lMin:
    ctx.devInfo.axisRanges[actualIndex] = (min: readRange.lMin, max: readRange.lMax)
  else:
    ctx.devInfo.axisRanges[actualIndex] = (min: -32768'i32, max: 32767'i32)

  return DIENUM_CONTINUE

proc setupDevice(slot: int, deviceInstance: ptr DIDEVICEINSTANCEW): bool =
  ## Creates, configures, and acquires a DirectInput device. Returns true on success.
  var device: ptr IDirectInputDevice8W

  var hr = directInput.lpVtbl.CreateDevice(
    directInput,
    addr deviceInstance.guidInstance,
    addr device,
    nil
  )
  if hr != DI_OK:
    return false

  # Set data format to DIJOYSTATE2
  hr = device.lpVtbl.SetDataFormat(device, addr dfDIJoystick2)
  if hr != DI_OK:
    discard device.lpVtbl.Release(device)
    return false

  # Set cooperative level: background + nonexclusive
  let hwnd = GetDesktopWindow()
  hr = device.lpVtbl.SetCooperativeLevel(
    device, hwnd, DISCL_BACKGROUND or DISCL_NONEXCLUSIVE
  )
  if hr != DI_OK:
    discard device.lpVtbl.Release(device)
    return false

  # Get device capabilities
  var caps: DIDEVCAPS
  caps.dwSize = uint32 sizeof(DIDEVCAPS)
  hr = device.lpVtbl.GetCapabilities(device, addr caps)
  if hr != DI_OK:
    discard device.lpVtbl.Release(device)
    return false

  dinputDevices[slot].device = device
  dinputDevices[slot].guidInstance = deviceInstance.guidInstance
  dinputDevices[slot].connected = true
  dinputDevices[slot].numButtons = int caps.dwButtons
  dinputDevices[slot].numAxes = int caps.dwAxes
  dinputDevices[slot].numPovs = int caps.dwPOVs

  # Discover axes via EnumObjects and configure their ranges
  var axisCtx = EnumAxisContext(
    device: device,
    devInfo: addr dinputDevices[slot]
  )
  discard device.lpVtbl.EnumObjects(
    device,
    enumAxisCallback,
    addr axisCtx,
    DIDFT_ALL
  )

  dinputStates[slot].name = wcharToString(deviceInstance.tszProductName)
  if dinputStates[slot].name.len == 0:
    dinputStates[slot].name = "DirectInput Controller " & $slot

  # Acquire the device and capture rest values from the first poll.
  discard device.lpVtbl.Acquire(device)
  discard device.lpVtbl.Poll(device)
  var initState: DIJOYSTATE2
  let pollHr = device.lpVtbl.GetDeviceState(
    device, uint32 sizeof(DIJOYSTATE2), addr initState
  )
  if pollHr == DI_OK:
    let rawAxes = [
      initState.lX, initState.lY, initState.lZ,
      initState.lRx, initState.lRy, initState.lRz,
      initState.rglSlider[0], initState.rglSlider[1]
    ]
    for a in 0 ..< 8:
      if dinputDevices[slot].hasAxis[a]:
        dinputDevices[slot].axisCenter[a] = rawAxes[a]
        dinputDevices[slot].axisPrev[a] = rawAxes[a]

  return true

type
  EnumContext = object
    devicesFound: int

proc enumDevicesCallback(
  lpddi: ptr DIDEVICEINSTANCEW,
  pvRef: pointer
): int32 {.stdcall.} =
  ## Callback for IDirectInput8::EnumDevices.
  ## Filters XInput devices and registers new DirectInput devices.
  let ctx = cast[ptr EnumContext](pvRef)

  # Skip XInput devices to avoid double-reporting
  if isXInputDevice(lpddi):
    return DIENUM_CONTINUE

  # Skip if already registered
  if findDeviceByGuid(lpddi.guidInstance) >= 0:
    return DIENUM_CONTINUE

  # Find a free slot
  let slot = findFreeSlot()
  if slot < 0:
    return DIENUM_STOP  # No more slots

  if setupDevice(slot, lpddi):
    inc ctx.devicesFound

  return DIENUM_CONTINUE

proc enumerateDevices() =
  ## Enumerates attached DirectInput game controllers.
  if directInput == nil:
    return

  var ctx = EnumContext(devicesFound: 0)
  discard directInput.lpVtbl.EnumDevices(
    directInput,
    DI8DEVCLASS_GAMECTRL,
    enumDevicesCallback,
    addr ctx,
    DIEDFL_ATTACHEDONLY
  )

proc initDirectInput*() =
  ## Initializes DirectInput 8 for gamepad support.
  if dinputInitialized:
    return

  # Initialize the data format
  initDfDIJoystick2()

  # Dynamically load dinput8.dll
  dinputLib = loadLib("dinput8.dll")
  if dinputLib == nil:
    dinputInitialized = true
    return

  directInput8Create = cast[DirectInput8CreateProc](
    symAddr(dinputLib, "DirectInput8Create")
  )
  if directInput8Create == nil:
    unloadLib(dinputLib)
    dinputLib = nil
    dinputInitialized = true
    return

  # Initialize COM
  let comHr = CoInitializeEx(nil, COINIT_MULTITHREADED)
  if comHr == S_OK:
    comOwned = true
  elif comHr == S_FALSE:
    comOwned = false
  elif comHr == RPC_E_CHANGED_MODE:
    comOwned = false
  else:
    unloadLib(dinputLib)
    dinputLib = nil
    dinputInitialized = true
    return

  # Create the DirectInput8 interface
  let hinst = GetModuleHandleW(nil)
  let hr = directInput8Create(
    hinst,
    DIRECTINPUT_VERSION,
    addr IID_IDirectInput8W,
    cast[ptr pointer](addr directInput),
    nil
  )
  if hr != DI_OK:
    if comOwned:
      CoUninitialize()
      comOwned = false
    unloadLib(dinputLib)
    dinputLib = nil
    dinputInitialized = true
    return

  dinputLoaded = true
  dinputInitialized = true

  # Do initial enumeration
  enumerateDevices()
  lastEnumerateTime = epochTime()

proc closeDirectInput*() =
  ## Closes DirectInput and releases all resources.
  if not dinputInitialized:
    return

  for i in 0 ..< MaxDinputDevices:
    releaseDevice(i)

  if directInput != nil:
    discard directInput.lpVtbl.Release(directInput)
    directInput = nil

  if comOwned:
    CoUninitialize()
    comOwned = false

  if dinputLib != nil:
    unloadLib(dinputLib)
    dinputLib = nil

  dinputLoaded = false
  dinputInitialized = false

proc mapPov(povValue: uint32, buttons: var uint64) =
  ## Maps a POV hat value to D-pad button bits.
  template setBtn(id: GamepadButton) =
    buttons = buttons or (1'u64 shl id.int)

  if povValue == DI_POV_CENTER or (povValue and 0xFFFF) == 0xFFFF:
    return  # Centered, no buttons

  # POV values are in hundredths of a degree (0 = up, 9000 = right, etc.)
  let angle = povValue mod 36000
  # Up: 31500-36000 or 0-4500
  if angle >= 31500 or angle <= 4500:
    setBtn(GamepadUp)
  # Right: 4500-13500
  if angle >= 4500 and angle <= 13500:
    setBtn(GamepadRight)
  # Down: 13500-22500
  if angle >= 13500 and angle <= 22500:
    setBtn(GamepadDown)
  # Left: 22500-31500
  if angle >= 22500 and angle <= 31500:
    setBtn(GamepadLeft)

proc pollDirectInput*(slotOffset: int): seq[Gamepad] =
  ## Polls DirectInput devices and returns connected gamepad snapshots.
  ## slotOffset is added to local indices to produce Gamepad.id values.
  if not dinputLoaded:
    return

  # Periodic re-enumeration for hot-plug detection
  let now = epochTime()
  if now - lastEnumerateTime >= EnumerateIntervalSec:
    enumerateDevices()
    lastEnumerateTime = now

  # Reset per-frame edge state
  for i in 0 ..< MaxDinputDevices:
    dinputStates[i].pressed = 0'u64
    dinputStates[i].released = 0'u64

  for i in 0 ..< MaxDinputDevices:
    if not dinputDevices[i].connected:
      continue

    let device = dinputDevices[i].device
    let devInfo = addr dinputDevices[i]

    # Poll the device (some devices require explicit polling)
    discard device.lpVtbl.Poll(device)

    # Read device state
    var joyState: DIJOYSTATE2
    var hr = device.lpVtbl.GetDeviceState(
      device,
      uint32 sizeof(DIJOYSTATE2),
      addr joyState
    )

    if hr == DIERR_INPUTLOST or hr == DIERR_NOTACQUIRED:
      # Try to reacquire
      hr = device.lpVtbl.Acquire(device)
      if hr == DI_OK or hr == S_FALSE:
        discard device.lpVtbl.Poll(device)
        hr = device.lpVtbl.GetDeviceState(
          device,
          uint32 sizeof(DIJOYSTATE2),
          addr joyState
        )

    if hr != DI_OK:
      releaseDevice(i)
      continue

    # Detect stable axis values and adopt them as the new rest center.
    # Some drivers (PS5 DualSense) return zeros on first poll, then switch
    # to different rest values. Once an axis holds the same value for
    # AxisSettlePolls consecutive reads, that becomes the new center.
    let rawAxes = [
      joyState.lX, joyState.lY, joyState.lZ,
      joyState.lRx, joyState.lRy, joyState.lRz,
      joyState.rglSlider[0], joyState.rglSlider[1]
    ]
    for a in 0 ..< 8:
      if not devInfo.hasAxis[a]:
        continue
      if rawAxes[a] == devInfo.axisPrev[a]:
        inc devInfo.axisStable[a]
        if devInfo.axisStable[a] == AxisSettlePolls and
            rawAxes[a] != devInfo.axisCenter[a]:
          devInfo.axisCenter[a] = rawAxes[a]
      else:
        devInfo.axisStable[a] = 0
      devInfo.axisPrev[a] = rawAxes[a]

    var state = addr dinputStates[i]
    var buttons = 0'u64

    template btn(pressed: bool, id: GamepadButton) =
      if pressed:
        buttons = buttons or (1'u64 shl id.int)

    # Map axes relative to rest center.
    # calibratedAxis scales each direction independently from center.
    # Triggers use abs() since they're unidirectional from rest.
    if devInfo.hasAxis[0]:  # X → left stick X
      state.axes[GamepadLStickX.int] = calibratedAxis(
        joyState.lX, devInfo.axisCenter[0],
        devInfo.axisRanges[0].min, devInfo.axisRanges[0].max
      )
    if devInfo.hasAxis[1]:  # Y → left stick Y
      state.axes[GamepadLStickY.int] = calibratedAxis(
        joyState.lY, devInfo.axisCenter[1],
        devInfo.axisRanges[1].min, devInfo.axisRanges[1].max
      )

    if devInfo.hasAxis[2]:  # Z → left trigger
      let lTrigger = abs(calibratedAxis(
        joyState.lZ, devInfo.axisCenter[2],
        devInfo.axisRanges[2].min, devInfo.axisRanges[2].max
      ))
      state.axes[GamepadLTrigger.int] = lTrigger
      state.pressures[GamepadL2.int] = lTrigger
      btn(lTrigger > 0.1'f, GamepadL2)

    if devInfo.hasAxis[3]:  # Rx → right stick X
      state.axes[GamepadRStickX.int] = calibratedAxis(
        joyState.lRx, devInfo.axisCenter[3],
        devInfo.axisRanges[3].min, devInfo.axisRanges[3].max
      )
    if devInfo.hasAxis[4]:  # Ry → right stick Y
      state.axes[GamepadRStickY.int] = calibratedAxis(
        joyState.lRy, devInfo.axisCenter[4],
        devInfo.axisRanges[4].min, devInfo.axisRanges[4].max
      )

    if devInfo.hasAxis[5]:  # Rz → right trigger
      let rTrigger = abs(calibratedAxis(
        joyState.lRz, devInfo.axisCenter[5],
        devInfo.axisRanges[5].min, devInfo.axisRanges[5].max
      ))
      state.axes[GamepadRTrigger.int] = rTrigger
      state.pressures[GamepadR2.int] = rTrigger
      btn(rTrigger > 0.1'f, GamepadR2)

    if devInfo.hasAxis[6]:  # Slider0 → throttle
      state.axes[GamepadThrottle.int] = calibratedAxis(
        joyState.rglSlider[0], devInfo.axisCenter[6],
        devInfo.axisRanges[6].min, devInfo.axisRanges[6].max
      )
    if devInfo.hasAxis[7]:  # Slider1 → rudder
      state.axes[GamepadRudder.int] = calibratedAxis(
        joyState.rglSlider[1], devInfo.axisCenter[7],
        devInfo.axisRanges[7].min, devInfo.axisRanges[7].max
      )

    # Map POV hat to D-pad buttons
    if devInfo.numPovs > 0:
      mapPov(joyState.rgdwPOV[0], buttons)

    # Map buttons (best-guess standard layout)
    let numBtns = min(devInfo.numButtons, 128)
    for j in 0 ..< numBtns:
      if (joyState.rgbButtons[j] and 0x80'u8) != 0:
        let mappedButton =
          case j
          of 0: GamepadA
          of 1: GamepadB
          of 2: GamepadX
          of 3: GamepadY
          of 4: GamepadL1
          of 5: GamepadR1
          of 6: GamepadL2
          of 7: GamepadR2
          of 8: GamepadSelect
          of 9: GamepadStart
          of 10: GamepadL3
          of 11: GamepadR3
          of 12: GamepadHome
          of 13: GamepadTouchpad
          of 14: GamepadMisc0
          of 15: GamepadMisc1
          of 16: GamepadMisc2
          of 17: GamepadMisc3
          of 18: GamepadMisc4
          of 19: GamepadMisc5
          of 20: GamepadMisc6
          of 21: GamepadMisc7
          of 22: GamepadMisc8
          of 23: GamepadMisc9
          else: continue
        buttons = buttons or (1'u64 shl mappedButton.int)

    gamepadUpdateButtons(state[], buttons)
    result.add state[].toGamepad(slotOffset + i)
