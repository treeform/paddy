type
  HRESULT* = int32
  HINSTANCE* = pointer
  HWND* = pointer
  WCHAR* = uint16
  LPVOID* = pointer
  REFGUID* = ptr GUID
  REFIID* = ptr GUID

  GUID* {.pure.} = object
    Data1*: uint32
    Data2*: uint16
    Data3*: uint16
    Data4*: array[8, uint8]

  # Forward declarations for COM interfaces
  IDirectInput8W* = object
    lpVtbl*: ptr IDirectInput8WVtbl

  IDirectInputDevice8W* = object
    lpVtbl*: ptr IDirectInputDevice8WVtbl

  # Callback type for EnumDevices
  LPDIENUMDEVICESCALLBACKW* = proc(
    lpddi: ptr DIDEVICEINSTANCEW,
    pvRef: pointer
  ): int32 {.stdcall.}

  # Callback type for EnumObjects
  LPDIENUMDEVICEOBJECTSCALLBACKW* = proc(
    lpddoi: ptr DIDEVICEOBJECTINSTANCEW,
    pvRef: pointer
  ): int32 {.stdcall.}

  ## IDirectInput8W vtable - must match COM layout exactly.
  ## IUnknown: QueryInterface(0), AddRef(1), Release(2)
  ## IDirectInput8W: CreateDevice(3), EnumDevices(4), GetDeviceStatus(5),
  ##   RunControlPanel(6), Initialize(7), FindDevice(8),
  ##   EnumDevicesBySemantics(9), ConfigureDevices(10)
  IDirectInput8WVtbl* {.pure.} = object
    # IUnknown
    QueryInterface*: pointer
    AddRef*: pointer
    Release*: proc(self: ptr IDirectInput8W): uint32 {.stdcall.}
    # IDirectInput8W
    CreateDevice*: proc(
      self: ptr IDirectInput8W,
      rguid: REFGUID,
      lplpDirectInputDevice: ptr ptr IDirectInputDevice8W,
      pUnkOuter: pointer
    ): HRESULT {.stdcall.}
    EnumDevices*: proc(
      self: ptr IDirectInput8W,
      dwDevType: uint32,
      lpCallback: LPDIENUMDEVICESCALLBACKW,
      pvRef: pointer,
      dwFlags: uint32
    ): HRESULT {.stdcall.}
    GetDeviceStatus*: pointer
    RunControlPanel*: pointer
    Initialize*: pointer
    FindDevice*: pointer
    EnumDevicesBySemantics*: pointer
    ConfigureDevices*: pointer

  ## IDirectInputDevice8W vtable - must match COM layout exactly.
  ## IUnknown: QueryInterface(0), AddRef(1), Release(2)
  ## IDirectInputDevice8W: GetCapabilities(3), EnumObjects(4),
  ##   GetProperty(5), SetProperty(6), Acquire(7), Unacquire(8),
  ##   GetDeviceState(9), GetDeviceData(10), SetDataFormat(11),
  ##   SetEventNotification(12), SetCooperativeLevel(13),
  ##   GetObjectInfo(14), GetDeviceInfo(15), RunControlPanel(16),
  ##   Initialize(17), CreateEffect(18), EnumEffects(19),
  ##   GetEffectInfo(20), GetForceFeedbackState(21),
  ##   SendForceFeedbackCommand(22), EnumCreatedEffectObjects(23),
  ##   Escape(24), Poll(25), SendDeviceData(26),
  ##   EnumEffectsInFile(27), WriteEffectToFile(28),
  ##   BuildActionMap(29), SetActionMap(30), GetImageInfo(31)
  IDirectInputDevice8WVtbl* {.pure.} = object
    # IUnknown (slots 0-2)
    QueryInterface*: pointer
    AddRef*: pointer
    Release*: proc(self: ptr IDirectInputDevice8W): uint32 {.stdcall.}
    # IDirectInputDevice8W (slots 3+)
    GetCapabilities*: proc(
      self: ptr IDirectInputDevice8W,
      lpDIDevCaps: ptr DIDEVCAPS
    ): HRESULT {.stdcall.}
    EnumObjects*: proc(
      self: ptr IDirectInputDevice8W,
      lpCallback: LPDIENUMDEVICEOBJECTSCALLBACKW,
      pvRef: pointer,
      dwFlags: uint32
    ): HRESULT {.stdcall.}
    GetProperty*: proc(
      self: ptr IDirectInputDevice8W,
      rguidProp: REFGUID,
      pdiph: ptr DIPROPHEADER
    ): HRESULT {.stdcall.}
    SetProperty*: proc(
      self: ptr IDirectInputDevice8W,
      rguidProp: REFGUID,
      pdiph: ptr DIPROPHEADER
    ): HRESULT {.stdcall.}
    Acquire*: proc(
      self: ptr IDirectInputDevice8W
    ): HRESULT {.stdcall.}
    Unacquire*: proc(
      self: ptr IDirectInputDevice8W
    ): HRESULT {.stdcall.}
    GetDeviceState*: proc(
      self: ptr IDirectInputDevice8W,
      cbData: uint32,
      lpvData: pointer
    ): HRESULT {.stdcall.}
    GetDeviceData*: pointer
    SetDataFormat*: proc(
      self: ptr IDirectInputDevice8W,
      lpdf: ptr DIDATAFORMAT
    ): HRESULT {.stdcall.}
    SetEventNotification*: pointer
    SetCooperativeLevel*: proc(
      self: ptr IDirectInputDevice8W,
      hwnd: HWND,
      dwFlags: uint32
    ): HRESULT {.stdcall.}
    GetObjectInfo*: pointer
    GetDeviceInfo*: pointer
    RunControlPanel*: pointer
    Initialize*: pointer
    CreateEffect*: pointer
    EnumEffects*: pointer
    GetEffectInfo*: pointer
    GetForceFeedbackState*: pointer
    SendForceFeedbackCommand*: pointer
    EnumCreatedEffectObjects*: pointer
    Escape*: pointer
    Poll*: proc(
      self: ptr IDirectInputDevice8W
    ): HRESULT {.stdcall.}
    SendDeviceData*: pointer
    EnumEffectsInFile*: pointer
    WriteEffectToFile*: pointer
    BuildActionMap*: pointer
    SetActionMap*: pointer
    GetImageInfo*: pointer

  DIDEVICEINSTANCEW* {.pure.} = object
    dwSize*: uint32
    guidInstance*: GUID
    guidProduct*: GUID
    dwDevType*: uint32
    tszInstanceName*: array[260, WCHAR]
    tszProductName*: array[260, WCHAR]
    guidFFDriver*: GUID
    wUsagePage*: uint16
    wUsage*: uint16

  DIDEVICEOBJECTINSTANCEW* {.pure.} = object
    dwSize*: uint32
    guidType*: GUID
    dwOfs*: uint32
    dwType*: uint32
    dwFlags*: uint32
    tszName*: array[260, WCHAR]
    dwFFMaxForce*: uint32
    dwFFForceResolution*: uint32
    wCollectionNumber*: uint16
    wDesignatorIndex*: uint16
    wUsagePage*: uint16
    wUsage*: uint16
    dwDimension*: uint32
    wExponent*: uint16
    wReserved*: uint16

  DIJOYSTATE2* {.pure.} = object
    lX*: int32
    lY*: int32
    lZ*: int32
    lRx*: int32
    lRy*: int32
    lRz*: int32
    rglSlider*: array[2, int32]
    rgdwPOV*: array[4, uint32]
    rgbButtons*: array[128, uint8]
    lVX*: int32
    lVY*: int32
    lVZ*: int32
    lVRx*: int32
    lVRy*: int32
    lVRz*: int32
    rglVSlider*: array[2, int32]
    lAX*: int32
    lAY*: int32
    lAZ*: int32
    lARx*: int32
    lARy*: int32
    lARz*: int32
    rglASlider*: array[2, int32]
    lFX*: int32
    lFY*: int32
    lFZ*: int32
    lFRx*: int32
    lFRy*: int32
    lFRz*: int32
    rglFSlider*: array[2, int32]

  DIDEVCAPS* {.pure.} = object
    dwSize*: uint32
    dwFlags*: uint32
    dwDevType*: uint32
    dwAxes*: uint32
    dwButtons*: uint32
    dwPOVs*: uint32
    dwFFSamplePeriod*: uint32
    dwFFMinTimeResolution*: uint32
    dwFirmwareRevision*: uint32
    dwHardwareRevision*: uint32
    dwFFDriverVersion*: uint32

  DIPROPHEADER* {.pure.} = object
    dwSize*: uint32
    dwHeaderSize*: uint32
    dwObj*: uint32
    dwHow*: uint32

  DIPROPRANGE* {.pure.} = object
    diph*: DIPROPHEADER
    lMin*: int32
    lMax*: int32

  # Data format structures for c_dfDIJoystick2.
  DIOBJECTDATAFORMAT* {.pure.} = object
    pguid*: ptr GUID
    dwOfs*: uint32
    dwType*: uint32
    dwFlags*: uint32

  DIDATAFORMAT* {.pure.} = object
    dwSize*: uint32
    dwObjSize*: uint32
    dwFlags*: uint32
    dwDataSize*: uint32
    dwNumObjs*: uint32
    rgodf*: ptr DIOBJECTDATAFORMAT

  ## DirectInput8Create function signature
  DirectInput8CreateProc* = proc(
    hinst: HINSTANCE,
    dwVersion: uint32,
    riidltf: REFIID,
    ppvOut: ptr pointer,
    punkOuter: pointer
  ): HRESULT {.stdcall.}

const
  # HRESULT values
  DI_OK* = 0'i32
  DI_POLLEDDEVICE* = 2'i32
  DIERR_INPUTLOST* = cast[int32](0x8007001E'u32)
  DIERR_NOTACQUIRED* = cast[int32](0x8007000C'u32)
  DIERR_NOTINITIALIZED* = cast[int32](0x80070015'u32)
  S_OK* = 0'i32
  S_FALSE* = 1'i32
  RPC_E_CHANGED_MODE* = cast[int32](0x80010106'u32)

  # COM initialization
  COINIT_MULTITHREADED* = 0x0'u32

  # DirectInput version
  DIRECTINPUT_VERSION* = 0x0800'u32

  # Device enumeration flags
  DI8DEVCLASS_GAMECTRL* = 4'u32
  DIEDFL_ATTACHEDONLY* = 0x00000001'u32

  # Cooperative level flags
  DISCL_EXCLUSIVE* = 0x00000001'u32
  DISCL_NONEXCLUSIVE* = 0x00000002'u32
  DISCL_FOREGROUND* = 0x00000004'u32
  DISCL_BACKGROUND* = 0x00000008'u32

  # Enumeration callback return values
  DIENUM_CONTINUE* = 1'i32
  DIENUM_STOP* = 0'i32

  # EnumObjects flags
  DIDFT_RELAXIS* = 0x00000001'u32
  DIDFT_ABSAXIS* = 0x00000002'u32
  DIDFT_AXIS* = 0x00000003'u32
  DIDFT_ALL* = 0x00000000'u32

  # DIPROPHEADER dwHow values
  DIPH_DEVICE* = 0'u32
  DIPH_BYOFFSET* = 1'u32
  DIPH_BYID* = 2'u32

  # POV center (no direction)
  DI_POV_CENTER* = 0xFFFFFFFF'u32

  # Data format flags
  DIDF_ABSAXIS* = 0x00000001'u32

  # DIPROP_RANGE: pseudo-GUID, actually the integer 4 cast to a GUID pointer.
  DIPROP_RANGE_VALUE* = 4'u

  # Object data format type flags used in c_dfDIJoystick2
  DIDFT_OPTIONAL* = 0x80000000'u32
  DIDFT_ANYINSTANCE* = 0x00FFFF00'u32
  DIDFT_BUTTON* = 0x0000000C'u32
  DIDFT_POV* = 0x00000010'u32

# IID needs to be addressable for COM calls.
let
  IID_IDirectInput8W* = GUID(
    Data1: 0xBF798031'u32,
    Data2: 0x483A'u16,
    Data3: 0x4DA2'u16,
    Data4: [0xAA'u8, 0x99'u8, 0x5D'u8, 0x64'u8, 0xED'u8, 0x36'u8, 0x97'u8, 0x00'u8]
  )

# Well-known GUIDs
const
  GUID_XAxis* = GUID(
    Data1: 0xA36D02E0'u32,
    Data2: 0xC9F3'u16,
    Data3: 0x11CE'u16,
    Data4: [0xBF'u8, 0xC7'u8, 0x44'u8, 0x45'u8, 0x53'u8, 0x54'u8, 0x00'u8, 0x00'u8]
  )

  GUID_YAxis* = GUID(
    Data1: 0xA36D02E1'u32,
    Data2: 0xC9F3'u16,
    Data3: 0x11CE'u16,
    Data4: [0xBF'u8, 0xC7'u8, 0x44'u8, 0x45'u8, 0x53'u8, 0x54'u8, 0x00'u8, 0x00'u8]
  )

  GUID_ZAxis* = GUID(
    Data1: 0xA36D02E2'u32,
    Data2: 0xC9F3'u16,
    Data3: 0x11CE'u16,
    Data4: [0xBF'u8, 0xC7'u8, 0x44'u8, 0x45'u8, 0x53'u8, 0x54'u8, 0x00'u8, 0x00'u8]
  )

  GUID_RxAxis* = GUID(
    Data1: 0xA36D02F4'u32,
    Data2: 0xC9F3'u16,
    Data3: 0x11CE'u16,
    Data4: [0xBF'u8, 0xC7'u8, 0x44'u8, 0x45'u8, 0x53'u8, 0x54'u8, 0x00'u8, 0x00'u8]
  )

  GUID_RyAxis* = GUID(
    Data1: 0xA36D02F5'u32,
    Data2: 0xC9F3'u16,
    Data3: 0x11CE'u16,
    Data4: [0xBF'u8, 0xC7'u8, 0x44'u8, 0x45'u8, 0x53'u8, 0x54'u8, 0x00'u8, 0x00'u8]
  )

  GUID_RzAxis* = GUID(
    Data1: 0xA36D02E3'u32,
    Data2: 0xC9F3'u16,
    Data3: 0x11CE'u16,
    Data4: [0xBF'u8, 0xC7'u8, 0x44'u8, 0x45'u8, 0x53'u8, 0x54'u8, 0x00'u8, 0x00'u8]
  )

  GUID_Slider* = GUID(
    Data1: 0xA36D02E4'u32,
    Data2: 0xC9F3'u16,
    Data3: 0x11CE'u16,
    Data4: [0xBF'u8, 0xC7'u8, 0x44'u8, 0x45'u8, 0x53'u8, 0x54'u8, 0x00'u8, 0x00'u8]
  )

  GUID_POV* = GUID(
    Data1: 0xA36D02F2'u32,
    Data2: 0xC9F3'u16,
    Data3: 0x11CE'u16,
    Data4: [0xBF'u8, 0xC7'u8, 0x44'u8, 0x45'u8, 0x53'u8, 0x54'u8, 0x00'u8, 0x00'u8]
  )

  GUID_Button* = GUID(
    Data1: 0xA36D02F0'u32,
    Data2: 0xC9F3'u16,
    Data3: 0x11CE'u16,
    Data4: [0xBF'u8, 0xC7'u8, 0x44'u8, 0x45'u8, 0x53'u8, 0x54'u8, 0x00'u8, 0x00'u8]
  )

  GUID_Unknown* = GUID(
    Data1: 0xA36D02F3'u32,
    Data2: 0xC9F3'u16,
    Data3: 0x11CE'u16,
    Data4: [0xBF'u8, 0xC7'u8, 0x44'u8, 0x45'u8, 0x53'u8, 0x54'u8, 0x00'u8, 0x00'u8]
  )

# Hardcoded c_dfDIJoystick2 data format.
# This replicates the predefined DIJOYSTATE2 format from dinput8.
# Offsets match the DIJOYSTATE2 struct layout.

proc dipropRange*(): REFGUID =
  ## Returns DIPROP_RANGE as a REFGUID (pointer cast from integer 4).
  cast[REFGUID](DIPROP_RANGE_VALUE)

# Helper to compute DIJOYSTATE2 field offsets
const
  OfsX* = 0'u32          # lX
  OfsY* = 4'u32          # lY
  OfsZ* = 8'u32          # lZ
  OfsRx* = 12'u32        # lRx
  OfsRy* = 16'u32        # lRy
  OfsRz* = 20'u32        # lRz
  OfsSlider0* = 24'u32   # rglSlider[0]
  OfsSlider1* = 28'u32   # rglSlider[1]
  OfsPov0* = 32'u32      # rgdwPOV[0]
  OfsPov1* = 36'u32      # rgdwPOV[1]
  OfsPov2* = 40'u32      # rgdwPOV[2]
  OfsPov3* = 44'u32      # rgdwPOV[3]
  OfsButtons* = 48'u32   # rgbButtons[0] starts here
  # Velocity, acceleration, force fields follow buttons at offset 48+128=176
  OfsVX* = 176'u32
  OfsVY* = 180'u32
  OfsVZ* = 184'u32
  OfsVRx* = 188'u32
  OfsVRy* = 192'u32
  OfsVRz* = 196'u32
  OfsVSlider0* = 200'u32
  OfsVSlider1* = 204'u32
  OfsAX* = 208'u32
  OfsAY* = 212'u32
  OfsAZ* = 216'u32
  OfsARx* = 220'u32
  OfsARy* = 224'u32
  OfsARz* = 228'u32
  OfsASlider0* = 232'u32
  OfsASlider1* = 236'u32
  OfsFX* = 240'u32
  OfsFY* = 244'u32
  OfsFZ* = 248'u32
  OfsFRx* = 252'u32
  OfsFRy* = 256'u32
  OfsFRz* = 260'u32
  OfsFSlider0* = 264'u32
  OfsFSlider1* = 268'u32

# The object data format array for c_dfDIJoystick2
# 164 entries total: 8 axes + 4 POVs + 128 buttons + 24 velocity/accel/force axes
var
  dfDIJoystick2Objects*: array[164, DIOBJECTDATAFORMAT]
  dfDIJoystick2*: DIDATAFORMAT

proc initDfDIJoystick2*() =
  ## Initializes the hardcoded c_dfDIJoystick2 data format.
  ## Must be called before using dfDIJoystick2.
  var idx = 0

  template addAxis(offset: uint32) =
    dfDIJoystick2Objects[idx] = DIOBJECTDATAFORMAT(
      pguid: nil,
      dwOfs: offset,
      dwType: DIDFT_AXIS or DIDFT_ANYINSTANCE or DIDFT_OPTIONAL,
      dwFlags: 0
    )
    inc idx

  template addPov(offset: uint32) =
    dfDIJoystick2Objects[idx] = DIOBJECTDATAFORMAT(
      pguid: nil,
      dwOfs: offset,
      dwType: DIDFT_POV or DIDFT_ANYINSTANCE or DIDFT_OPTIONAL,
      dwFlags: 0
    )
    inc idx

  template addButton(offset: uint32) =
    dfDIJoystick2Objects[idx] = DIOBJECTDATAFORMAT(
      pguid: nil,
      dwOfs: offset,
      dwType: DIDFT_BUTTON or DIDFT_ANYINSTANCE or DIDFT_OPTIONAL,
      dwFlags: 0
    )
    inc idx

  # Position axes (8)
  addAxis(OfsX)
  addAxis(OfsY)
  addAxis(OfsZ)
  addAxis(OfsRx)
  addAxis(OfsRy)
  addAxis(OfsRz)
  addAxis(OfsSlider0)
  addAxis(OfsSlider1)

  # POV hats (4)
  addPov(OfsPov0)
  addPov(OfsPov1)
  addPov(OfsPov2)
  addPov(OfsPov3)

  # Buttons (128)
  for i in 0'u32 ..< 128'u32:
    addButton(OfsButtons + i)

  # Velocity axes (8)
  addAxis(OfsVX)
  addAxis(OfsVY)
  addAxis(OfsVZ)
  addAxis(OfsVRx)
  addAxis(OfsVRy)
  addAxis(OfsVRz)
  addAxis(OfsVSlider0)
  addAxis(OfsVSlider1)

  # Acceleration axes (8)
  addAxis(OfsAX)
  addAxis(OfsAY)
  addAxis(OfsAZ)
  addAxis(OfsARx)
  addAxis(OfsARy)
  addAxis(OfsARz)
  addAxis(OfsASlider0)
  addAxis(OfsASlider1)

  # Force axes (8)
  addAxis(OfsFX)
  addAxis(OfsFY)
  addAxis(OfsFZ)
  addAxis(OfsFRx)
  addAxis(OfsFRy)
  addAxis(OfsFRz)
  addAxis(OfsFSlider0)
  addAxis(OfsFSlider1)

  dfDIJoystick2 = DIDATAFORMAT(
    dwSize: uint32 sizeof(DIDATAFORMAT),
    dwObjSize: uint32 sizeof(DIOBJECTDATAFORMAT),
    dwFlags: DIDF_ABSAXIS,
    dwDataSize: uint32 sizeof(DIJOYSTATE2),
    dwNumObjs: uint32 idx,
    rgodf: addr dfDIJoystick2Objects[0]
  )

# Windows API imports
proc GetModuleHandleW*(lpModuleName: pointer): HINSTANCE
  {.stdcall, dynlib: "kernel32", importc: "GetModuleHandleW".}

proc GetDesktopWindow*(): HWND
  {.stdcall, dynlib: "user32", importc: "GetDesktopWindow".}

proc CoInitializeEx*(pvReserved: pointer, dwCoInit: uint32): HRESULT
  {.stdcall, dynlib: "ole32", importc: "CoInitializeEx".}

proc CoUninitialize*()
  {.stdcall, dynlib: "ole32", importc: "CoUninitialize".}
