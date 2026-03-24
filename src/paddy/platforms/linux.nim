import
  std/[os, posix],
  ../[common, internal],
  linux_defs

var
  initialized: bool
  epollFd: cint
  udevCtx: ptr udev
  udevMonitor: ptr udev_monitor
  udevMonitorFd: cint
  devices: array[MaxGamepads, ptr libevdev]
  devicePaths: array[MaxGamepads, cstring]
  deviceAbsInfo: array[MaxGamepads, array[6, ptr input_absinfo]]
  gamepadStates: array[MaxGamepads, GamepadState]
  defaultAbsInfo =
    input_absinfo(minimum: -32768, maximum: 32767)

proc raiseLinuxError(message: string) {.noreturn.} =
  ## Raises a Paddy error with the current OS error message.
  raise newException(
    PaddyError,
    message & ": " & osErrorMsg(osLastError())
  )

proc resetAbsInfo(gamepadId: int) =
  ## Resets cached absolute axis metadata for a slot.
  for j in 0 ..< 6:
    deviceAbsInfo[gamepadId][j] = addr defaultAbsInfo

proc strncmp(a: cstring, b: cstring, n: cint): cint {.importc, header: "<string.h>".}

proc handleDeviceEvent(device: ptr udev_device, added: bool) =
  ## Registers or unregisters a Linux gamepad device.
  let devnode = udev_device_get_devnode(device)
  if devnode == nil or strncmp(devnode, "/dev/input/event", 16) != 0:
    return

  let syspath = udev_device_get_syspath(device)
  if syspath == nil:
    return

  if added:
    for i in 0 ..< MaxGamepads:
      if devices[i] != nil:
        continue

      let fd = open(devnode, O_RDONLY or O_NONBLOCK)
      if fd < 0:
        return

      var inputDevice: ptr libevdev
      if libevdev_new_from_fd(fd, addr inputDevice) != 0:
        discard close(fd)
        return

      var event = epoll_event(
        events: EPOLLIN,
        data: epoll_data_t(u32: uint32 i)
      )
      if epoll_ctl(epollFd, EPOLL_CTL_ADD, fd, addr event) != 0:
        libevdev_free(inputDevice)
        discard close(fd)
        return

      devices[i] = inputDevice
      devicePaths[i] = syspath
      gamepadStates[i].name = $libevdev_get_name(inputDevice)

      for j in 0 ..< 6:
        if not libevdev_has_event_code(inputDevice, EV_ABS, uint16 j):
          continue

        let info = libevdev_get_abs_info(inputDevice, uint16 j)
        if info != nil and info.maximum > info.minimum:
          deviceAbsInfo[i][j] = info
      break
  else:
    for i in 0 ..< MaxGamepads:
      if devicePaths[i] != syspath:
        continue

      resetAbsInfo(i)

      let fd = libevdev_get_fd(devices[i])
      discard epoll_ctl(epollFd, EPOLL_CTL_DEL, fd, nil)
      libevdev_free(devices[i])
      discard close(fd)

      devices[i] = nil
      devicePaths[i] = nil
      gamepadResetState(gamepadStates[i])
      break

proc initGamepads*() =
  ## Initializes Linux gamepad support.
  if initialized:
    return

  for i in 0 ..< MaxGamepads:
    resetAbsInfo(i)

  epollFd = epoll_create1(O_CLOEXEC)
  if epollFd < 0:
    raiseLinuxError("Error creating epoll")

  udevCtx = udev_new()
  if udevCtx == nil:
    raiseLinuxError("Error creating udev")

  udevMonitor = udev_monitor_new_from_netlink(udevCtx, "udev")
  if udevMonitor == nil:
    raiseLinuxError("Error creating udev monitor")

  discard udev_monitor_filter_add_match_subsystem_devtype(
    udevMonitor,
    "input",
    nil
  )
  discard udev_monitor_enable_receiving(udevMonitor)

  udevMonitorFd = udev_monitor_get_fd(udevMonitor)
  let fl = fcntl(udevMonitorFd, F_GETFL)
  if fl < 0:
    raiseLinuxError("Error reading monitor flags")
  discard fcntl(udevMonitorFd, F_SETFL, fl or O_NONBLOCK)

  var event = epoll_event(
    events: EPOLLIN,
    data: epoll_data_t(u32: 0xFFFFFFFF'u32)
  )
  if epoll_ctl(
    epollFd,
    EPOLL_CTL_ADD,
    udevMonitorFd,
    addr event
  ) < 0:
    raiseLinuxError("Error adding monitor to epoll")

  let enumerate = udev_enumerate_new(udevCtx)
  discard udev_enumerate_add_match_subsystem(enumerate, "input")
  discard udev_enumerate_add_match_property(
    enumerate,
    "ID_INPUT_JOYSTICK",
    "1"
  )
  discard udev_enumerate_scan_devices(enumerate)

  var entry: ptr udev_list_entry
  udev_list_entry_foreach(udev_enumerate_get_list_entry(enumerate)):
    let name = udev_list_entry_get_name(entry)
    let device = udev_device_new_from_syspath(udevCtx, name)
    handleDeviceEvent(device, true)
    discard udev_device_unref(device)

  discard udev_enumerate_unref(enumerate)
  initialized = true

proc closeGamepads*() =
  ## Closes Linux gamepad support and releases resources.
  if not initialized:
    return

  for i in 0 ..< MaxGamepads:
    if devices[i] == nil:
      continue
    let fd = libevdev_get_fd(devices[i])
    discard epoll_ctl(epollFd, EPOLL_CTL_DEL, fd, nil)
    libevdev_free(devices[i])
    discard close(fd)
    devices[i] = nil
    devicePaths[i] = nil
    gamepadResetState(gamepadStates[i])
    resetAbsInfo(i)

  if udevMonitor != nil:
    discard udev_monitor_unref(udevMonitor)
    udevMonitor = nil

  if udevCtx != nil:
    discard udev_unref(udevCtx)
    udevCtx = nil

  if epollFd > 0:
    discard close(epollFd)
    epollFd = 0

  initialized = false

proc pollGamepads*(): seq[Gamepad] =
  ## Polls Linux gamepads and returns connected snapshots.
  if not initialized:
    initGamepads()

  for i in 0 ..< MaxGamepads:
    let state = addr gamepadStates[i]
    state.pressed = 0'u32
    state.released = 0'u32

  const maxEvents = MaxGamepads + 1
  var
    events: array[maxEvents, epoll_event]
    inputEvent: input_event
  let eventCount = epoll_wait(epollFd, addr events[0], maxEvents, 0)

  for i in 0 ..< eventCount:
    if (events[i].events and EPOLLIN) == 0:
      continue

    let index = events[i].data.u32
    if index == 0xFFFFFFFF'u32:
      let device = udev_monitor_receive_device(udevMonitor)
      let action = udev_device_get_action(device)
      if action != nil and
        udev_device_get_property_value(device, "ID_INPUT_JOYSTICK") == "1":
          if action == "add":
            handleDeviceEvent(device, true)
          elif action == "remove":
            handleDeviceEvent(device, false)
      discard udev_device_unref(device)
      continue

    let device = devices[index]
    if device == nil:
      continue

    var
      state = addr gamepadStates[index]
      buttons = state.buttons
      readFlag: cint = LIBEVDEV_READ_FLAG_NORMAL

    template btn(value: bool, id: GamepadButton) =
      let bit = 1'u64 shl id.int
      if value:
        buttons = buttons or bit
      else:
        buttons = buttons and (not bit)

    while true:
      case libevdev_next_event(device, readFlag, addr inputEvent)
      of LIBEVDEV_READ_STATUS_SYNC:
        readFlag = LIBEVDEV_READ_FLAG_SYNC
      of -EAGAIN:
        if readFlag == LIBEVDEV_READ_FLAG_SYNC:
          readFlag = LIBEVDEV_READ_FLAG_NORMAL
        else:
          break
      else:
        discard

      case inputEvent.`type`
      of EV_KEY:
        btn(
          inputEvent.value != 0,
          case inputEvent.code
          # BTN_GAMEPAD range
          of BTN_A: GamepadA
          of BTN_B: GamepadB
          of BTN_C: GamepadC
          of BTN_X: GamepadY
          of BTN_Y: GamepadX
          of BTN_Z: GamepadZ
          of BTN_TL: GamepadL1
          of BTN_TR: GamepadR1
          of BTN_TL2: GamepadL2
          of BTN_TR2: GamepadR2
          of BTN_SELECT: GamepadSelect
          of BTN_START: GamepadStart
          of BTN_MODE: GamepadHome
          of BTN_THUMBL: GamepadL3
          of BTN_THUMBR: GamepadR3
          # BTN_JOYSTICK range
          of BTN_TRIGGER: GamepadA
          of BTN_THUMB: GamepadB
          of BTN_THUMB2: GamepadX
          of BTN_TOP: GamepadY
          of BTN_TOP2: GamepadL1
          of BTN_PINKIE: GamepadR1
          of BTN_BASE: GamepadL2
          of BTN_BASE2: GamepadR2
          of BTN_BASE3: GamepadSelect
          of BTN_BASE4: GamepadStart
          of BTN_BASE5: GamepadHome
          of BTN_BASE6: GamepadL3
          # BTN_DPAD range
          of BTN_DPAD_UP: GamepadUp
          of BTN_DPAD_DOWN: GamepadDown
          of BTN_DPAD_LEFT: GamepadLeft
          of BTN_DPAD_RIGHT: GamepadRight
          # BTN_GEAR range
          of BTN_GEAR_DOWN: GamepadGearDown
          of BTN_GEAR_UP: GamepadGearUp
          # BTN_GRIP range
          of BTN_GRIPL: GamepadGripL
          of BTN_GRIPR: GamepadGripR
          of BTN_GRIPL2: GamepadGripL2
          of BTN_GRIPR2: GamepadGripR2
          # BTN_MISC range
          of BTN_0: GamepadMisc0
          of BTN_1: GamepadMisc1
          of BTN_2: GamepadMisc2
          of BTN_3: GamepadMisc3
          of BTN_4: GamepadMisc4
          of BTN_5: GamepadMisc5
          of BTN_6: GamepadMisc6
          of BTN_7: GamepadMisc7
          of BTN_8: GamepadMisc8
          of BTN_9: GamepadMisc9
          # BTN_TRIGGER_HAPPY range
          of BTN_TRIGGER_HAPPY1: GamepadHappy1
          of BTN_TRIGGER_HAPPY2: GamepadHappy2
          of BTN_TRIGGER_HAPPY3: GamepadHappy3
          of BTN_TRIGGER_HAPPY4: GamepadHappy4
          of BTN_TRIGGER_HAPPY5: GamepadHappy5
          of BTN_TRIGGER_HAPPY6: GamepadHappy6
          of BTN_TRIGGER_HAPPY7: GamepadHappy7
          of BTN_TRIGGER_HAPPY8: GamepadHappy8
          of BTN_TRIGGER_HAPPY9: GamepadHappy9
          of BTN_TRIGGER_HAPPY10: GamepadHappy10
          of BTN_TRIGGER_HAPPY11: GamepadHappy11
          of BTN_TRIGGER_HAPPY12: GamepadHappy12
          of BTN_TRIGGER_HAPPY13: GamepadHappy13
          of BTN_TRIGGER_HAPPY14: GamepadHappy14
          of BTN_TRIGGER_HAPPY15: GamepadHappy15
          of BTN_TRIGGER_HAPPY16: GamepadHappy16
          of BTN_TRIGGER_HAPPY17: GamepadHappy17
          of BTN_TRIGGER_HAPPY18: GamepadHappy18
          of BTN_TRIGGER_HAPPY19: GamepadHappy19
          of BTN_TRIGGER_HAPPY20: GamepadHappy20
          of BTN_TRIGGER_HAPPY21: GamepadHappy21
          of BTN_TRIGGER_HAPPY22: GamepadHappy22
          of BTN_TRIGGER_HAPPY23: GamepadHappy23
          of BTN_TRIGGER_HAPPY24: GamepadHappy24
          of BTN_TRIGGER_HAPPY25: GamepadHappy25
          of BTN_TRIGGER_HAPPY26: GamepadHappy26
          of BTN_TRIGGER_HAPPY27: GamepadHappy27
          of BTN_TRIGGER_HAPPY28: GamepadHappy28
          else:
            continue
        )
      of EV_ABS:
        template axis(): float32 =
          let info = deviceAbsInfo[index][inputEvent.code]
          let normalized =
            2.0'f *
            float32(inputEvent.value - info.minimum) /
            float32(info.maximum - info.minimum) -
            1.0'f
          gamepadFilterDeadZone(normalized)

        template pressure(id: GamepadButton) =
          state.pressures[id.int] = axis()
          btn(inputEvent.value != 0, id)

        template dpad(neg: GamepadButton, pos: GamepadButton) =
          btn(inputEvent.value < 0, neg)
          btn(inputEvent.value > 0, pos)

        case inputEvent.code
        of ABS_X:
          state.axes[GamepadLStickX.int] = axis()
        of ABS_Y:
          state.axes[GamepadLStickY.int] = axis()
        of ABS_RX:
          state.axes[GamepadRStickX.int] = axis()
        of ABS_RY:
          state.axes[GamepadRStickY.int] = axis()
        of ABS_Z:
          pressure(GamepadL2)
        of ABS_RZ:
          pressure(GamepadR2)
        of ABS_HAT0X:
          dpad(GamepadLeft, GamepadRight)
        of ABS_HAT0Y:
          dpad(GamepadUp, GamepadDown)
        else:
          discard
      else:
        discard

    gamepadUpdateButtons(state[], buttons)

  for i in 0 ..< MaxGamepads:
    if devices[i] != nil:
      result.add gamepadStates[i].toGamepad(i)
