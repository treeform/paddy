import
  std/[dynlib, strutils],
  paddy/[common, internal],
  paddy/platforms/[windows_defs, windows_directinput_defs],
  backend_source

var
  attached: array[4, bool]
  held: array[4, bool]
  reads: array[4, int]
  clock: float
  enumerations, created, acquired, releases: int
  directAttached: bool
  directHeld: bool
  directDevice: IDirectInputDevice8W
  directTable: IDirectInputDevice8WVtbl
  directApi: IDirectInput8W
  directApiTable: IDirectInput8WVtbl

proc epochTime(): float =
  ## Advances independently of wall time to catch periodic discovery regressions.
  clock

proc fakeGetState(index: DWORD, state: ptr XInputState): DWORD {.stdcall.} =
  ## Counts XInput probes and reports the fixture's current state.
  inc reads[index]
  if not attached[index]:
    return ErrorDeviceNotConnected
  state[] = XInputState()
  if held[index]: state.gamepad.wButtons = XInputGamepadA
  ErrorSuccess

proc fakePoll(self: ptr IDirectInputDevice8W): HRESULT {.stdcall.} =
  ## Polls an already acquired fixture controller.
  DI_OK

proc fakeRead(self: ptr IDirectInputDevice8W, size: uint32,
    state: pointer): HRESULT {.stdcall.} =
  ## Returns button state or reports a disconnected DirectInput device.
  if not directAttached: return -1
  cast[ptr DIJOYSTATE2](state)[] = DIJOYSTATE2()
  if directHeld: cast[ptr DIJOYSTATE2](state).rgbButtons[0] = 0x80
  DI_OK

proc fakeAcquire(self: ptr IDirectInputDevice8W): HRESULT {.stdcall.} =
  ## Records device acquisition.
  inc acquired
  DI_OK

proc fakeRelease(self: ptr IDirectInputDevice8W): uint32 {.stdcall.} =
  ## Records device disposal.
  inc releases

proc fakeFormat(self: ptr IDirectInputDevice8W,
    format: ptr DIDATAFORMAT): HRESULT {.stdcall.} =
  ## Accepts the production joystick data format.
  DI_OK

proc fakeCooperative(self: ptr IDirectInputDevice8W, window: HWND,
    flags: uint32): HRESULT {.stdcall.} =
  ## Accepts the production cooperative level.
  DI_OK

proc fakeCaps(self: ptr IDirectInputDevice8W,
    caps: ptr DIDEVCAPS): HRESULT {.stdcall.} =
  ## Supplies one button and no axes.
  caps.dwButtons = 1
  DI_OK

proc fakeObjects(self: ptr IDirectInputDevice8W,
    callback: LPDIENUMDEVICEOBJECTSCALLBACKW, context: pointer,
    flags: uint32): HRESULT {.stdcall.} =
  ## Supplies no axis objects.
  DI_OK

proc fakeCreate(self: ptr IDirectInput8W, guid: REFGUID,
    device: ptr ptr IDirectInputDevice8W, outer: pointer): HRESULT {.stdcall.} =
  ## Opens the fixture controller.
  inc created
  device[] = addr directDevice
  DI_OK

proc fakeEnumerate(self: ptr IDirectInput8W, kind: uint32,
    callback: LPDIENUMDEVICESCALLBACKW, context: pointer,
    flags: uint32): HRESULT {.stdcall.} =
  ## Delivers an attached controller through the real enumeration callback.
  inc enumerations
  if directAttached:
    var device = DIDEVICEINSTANCEW(guidInstance: GUID(Data1: 123))
    device.tszProductName[0] = 'P'.WCHAR
    discard callback(addr device, context)
  DI_OK

proc fakeApiRelease(self: ptr IDirectInput8W): uint32 {.stdcall.} =
  ## Releases the fixture interface.
  discard

proc fakeCreateApi(instance: HINSTANCE, version: uint32, iid: REFIID,
    output: ptr pointer, outer: pointer): HRESULT {.stdcall.} =
  ## Supplies the DirectInput interface without loading a Windows DLL.
  output[] = addr directApi
  DI_OK

proc loadLib(path: string, globalSymbols = false): LibHandle =
  ## Replaces native library loading for the backend under test.
  cast[LibHandle](1)

proc symAddr(lib: LibHandle, name: cstring): pointer =
  ## Resolves the two native entry points used by initialization.
  if $name == "DirectInput8Create": cast[pointer](fakeCreateApi)
  else: cast[pointer](fakeGetState)

proc unloadLib(lib: LibHandle) =
  ## Avoids passing the fixture library handle to the OS.
  discard

proc GetModuleHandleW(name: pointer): HINSTANCE =
  ## Supplies a fixture process handle.
  cast[HINSTANCE](1)

proc GetDesktopWindow(): HWND =
  ## Supplies a fixture window handle.
  cast[HWND](1)

proc CoInitializeEx(reserved: pointer, flags: uint32): HRESULT =
  ## Initializes the fixture COM context.
  S_OK

proc CoUninitialize() =
  ## Closes the fixture COM context.
  discard

backendSource("windows_directinput.nim")
backendSource("windows.nim")

proc testDiscovery() =
  ## Checks discovery boundaries using the real Windows backend procedures.
  directTable = IDirectInputDevice8WVtbl(
    Poll: fakePoll, GetDeviceState: fakeRead, Acquire: fakeAcquire,
    Unacquire: fakePoll, Release: fakeRelease, SetDataFormat: fakeFormat,
    SetCooperativeLevel: fakeCooperative, GetCapabilities: fakeCaps,
    EnumObjects: fakeObjects
  )
  directDevice.lpVtbl = addr directTable
  directApiTable = IDirectInput8WVtbl(
    CreateDevice: fakeCreate, EnumDevices: fakeEnumerate, Release: fakeApiRelease
  )
  directApi.lpVtbl = addr directApiTable

  scanGamepads()
  doAssert reads == [1, 1, 1, 1]
  doAssert enumerations == 1
  initGamepads()
  doAssert enumerations == 1
  for i in 0 ..< 100:
    clock += 5.0
    doAssert pollGamepads().len == 0
  doAssert reads == [1, 1, 1, 1]
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

  directAttached = true
  directHeld = true
  doAssert pollGamepads().len == 1
  scanGamepads()
  pads = pollGamepads()
  doAssert pads.len == 2 and pads[1].id == 4
  doAssert pads[1].button(GamepadA)
  doAssert created == 1 and acquired == 1
  scanGamepads()
  doAssert created == 1 and acquired == 1
  let readsBefore = reads
  let scansBefore = enumerations
  discard pollGamepads()
  doAssert reads[1 .. 3] == readsBefore[1 .. 3]
  doAssert enumerations == scansBefore

  attached[0] = false
  directAttached = false
  doAssert pollGamepads().len == 0
  doAssert releases == 1
  let readsDisconnected = reads
  attached[0] = true
  directAttached = true
  doAssert pollGamepads().len == 0
  doAssert reads == readsDisconnected
  scanGamepads()
  doAssert pollGamepads().len == 2
  closeGamepads()
  doAssert not initialized and not dinputInitialized
  let scansClosed = enumerations
  doAssert pollGamepads().len == 2
  doAssert enumerations == scansClosed + 1
  closeGamepads()

testDiscovery()
