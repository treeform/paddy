import
  std/[monotimes, os, posix, strutils, times],
  paddy/[common, internal],
  paddy/platforms/linux_defs,
  backend_source

var
  attached: array[3, bool] = [true, false, false]
  held: array[3, bool]
  registered: array[MaxGamepads, cint]
  enumerationCount, sysfsCount, openCount, closeCount: int
  notification, activeNotification: string
  notificationIndex: int
  pendingInput = -1
  inputReady: bool
  clockNs: int64

proc getMonoTime(): MonoTime =
  ## Advances independently of wall time to catch periodic discovery regressions.
  cast[MonoTime](clockNs)

proc devicePath(index: int): string =
  ## Supplies a stable sysfs identity for each fixture device.
  "/devices/event" & $index

iterator walkDirs(pattern: string): string =
  ## Enumerates a keyboard and the attached fixture controllers.
  inc sysfsCount
  for i in 0 ..< attached.len:
    if attached[i]: yield "/sys/class/input/event" & $i

proc expandFilename(path: string): string =
  ## Resolves fixture sysfs links without touching host input devices.
  "/devices/" & path.extractFilename()

proc dirExists(path: string): bool =
  ## Reports whether a previously registered device remains attached.
  for i in 0 ..< attached.len:
    if path == devicePath(i): return attached[i]

proc readFile(path: string): string =
  ## Exposes controller capability bits only for the gamepad fixtures.
  if "/event0/" in path: "1"
  else: "1000000000000 0 0 0 0"

proc open(path: cstring, flags: cint): cint =
  ## Counts device opens and supplies a synthetic descriptor.
  inc openCount
  for i in 1 ..< attached.len:
    if $path == "/dev/input/event" & $i: return (100 + i).cint
  raise newException(AssertionDefect, "Discovery opened a non-controller")

proc close(fd: cint): cint =
  ## Counts descriptor cleanup without closing host descriptors.
  inc closeCount

proc fcntl(fd, command: cint, value: cint = 0): cint =
  ## Accepts nonblocking monitor setup.
  0

proc epoll_create1(flags: cint): cint =
  ## Supplies an isolated event-loop descriptor.
  10

proc epoll_ctl(epfd, op, fd: cint, event: ptr epoll_event): cint =
  ## Tracks which gamepad slots own fixture descriptors.
  if op == EPOLL_CTL_ADD and event.data.u32 < MaxGamepads:
    registered[event.data.u32] = fd
  elif op == EPOLL_CTL_DEL:
    for slot in 0 ..< MaxGamepads:
      if registered[slot] == fd: registered[slot] = 0

proc epoll_wait(epfd: cint, events: ptr epoll_event,
    maxevents, timeout: cint): cint =
  ## Delivers one queued notification or controller input event.
  doAssert timeout == 0
  if notification.len > 0:
    events[] = epoll_event(events: EPOLLIN,
      data: epoll_data_t(u32: 0xFFFFFFFF'u32))
    return 1
  if pendingInput >= 0:
    for slot, fd in registered:
      if fd == (100 + pendingInput).cint:
        events[] = epoll_event(events: EPOLLIN, data: epoll_data_t(u32: slot.uint32))
        inputReady = true
        pendingInput = -1
        return 1

proc udev_new(): ptr udev =
  ## Supplies a fixture udev context.
  cast[ptr udev](1)

proc udev_unref(context: ptr udev): ptr udev =
  ## Releases the fixture context.
  nil

proc udev_monitor_new_from_netlink(context: ptr udev,
    name: cstring): ptr udev_monitor =
  ## Supplies a fixture monitor.
  cast[ptr udev_monitor](1)

proc udev_monitor_unref(monitor: ptr udev_monitor): ptr udev_monitor =
  ## Releases the fixture monitor.
  nil

proc udev_monitor_filter_add_match_subsystem_devtype(monitor: ptr udev_monitor,
    subsystem, devtype: cstring): cint =
  ## Accepts the input notification filter.
  0

proc udev_monitor_enable_receiving(monitor: ptr udev_monitor): cint =
  ## Enables fixture notifications.
  0

proc udev_monitor_get_fd(monitor: ptr udev_monitor): cint =
  ## Supplies a monitor descriptor distinct from gamepads.
  11

proc udev_monitor_receive_device(monitor: ptr udev_monitor): ptr udev_device =
  ## Drains queued add/remove notifications.
  if notification.len == 0: return nil
  activeNotification = notification
  notification = ""
  cast[ptr udev_device](1)

proc udev_device_get_action(device: ptr udev_device): cstring =
  ## Returns the delivered notification's action.
  activeNotification.cstring

proc udev_device_get_devnode(device: ptr udev_device): cstring =
  ## Returns a stable fixture event node.
  if notificationIndex == 1: "/dev/input/event1" else: "/dev/input/event2"

proc udev_device_get_syspath(device: ptr udev_device): cstring =
  ## Returns the matching fixture sysfs path.
  if notificationIndex == 1: "/devices/event1" else: "/devices/event2"

proc udev_device_unref(device: ptr udev_device): ptr udev_device =
  ## Releases a fixture notification.
  nil

proc udev_enumerate_new(context: ptr udev): ptr udev_enumerate =
  ## Supplies a fixture enumeration handle.
  cast[ptr udev_enumerate](1)

proc udev_enumerate_add_match_subsystem(enumeration: ptr udev_enumerate,
    subsystem: cstring): cint =
  ## Accepts the input enumeration filter.
  0

proc udev_enumerate_add_match_property(enumeration: ptr udev_enumerate,
    property, value: cstring): cint =
  ## Accepts the joystick-label filter.
  0

proc udev_enumerate_scan_devices(enumeration: ptr udev_enumerate): cint =
  ## Counts native discovery independently of sysfs discovery.
  inc enumerationCount

proc udev_enumerate_get_list_entry(enumeration: ptr udev_enumerate): ptr udev_list_entry =
  ## Emulates mdev, which supplies no udev-labelled controllers.
  nil

proc udev_enumerate_unref(enumeration: ptr udev_enumerate): ptr udev_enumerate =
  ## Releases the fixture enumeration.
  nil

proc libevdev_new_from_fd(fd: cint, device: ptr ptr libevdev): cint =
  ## Creates an input handle carrying its fixture descriptor.
  device[] = cast[ptr libevdev](fd)

proc libevdev_free(device: ptr libevdev) =
  ## Releases an input handle without native allocation.
  discard

proc libevdev_get_fd(device: ptr libevdev): cint =
  ## Recovers a fixture handle's descriptor.
  cast[int](device).cint

proc libevdev_get_name(device: ptr libevdev): cstring =
  ## Supplies a stable controller name.
  "Fixture Gamepad"

proc libevdev_has_event_code(device: ptr libevdev, kind, code: uint16): bool =
  ## Reports a gamepad button without any analog axes.
  kind == EV_KEY and code == BTN_A

proc libevdev_get_abs_info(device: ptr libevdev, code: uint16): ptr input_absinfo =
  ## Reports no analog metadata.
  nil

proc libevdev_next_event(device: ptr libevdev, flags: cint,
    event: ptr input_event): cint =
  ## Supplies input or ENODEV, followed by the normal nonblocking EAGAIN.
  let index = cast[int](device) - 100
  if not attached[index]: return -ENODEV
  if not inputReady: return -EAGAIN
  inputReady = false
  event[] = input_event(`type`: EV_KEY, code: BTN_A, value: held[index].int32)

backendSource("linux.nim")

proc testDiscovery() =
  ## Checks mdev discovery, notification gating, and evdev disconnections.
  scanGamepads()
  doAssert enumerationCount == 1 and sysfsCount == 1
  doAssert openCount == 0
  initGamepads()
  for i in 0 ..< 100:
    clockNs += 5_000_000_000'i64
    doAssert pollGamepads().len == 0
  doAssert enumerationCount == 1 and sysfsCount == 1

  attached[1] = true
  notification = "add"
  notificationIndex = 1
  doAssert pollGamepads().len == 0
  doAssert openCount == 0
  scanGamepads()
  held[1] = true
  pendingInput = 1
  var pads = pollGamepads()
  doAssert pads.len == 1 and pads[0].id == 0
  doAssert pads[0].buttonPressed(GamepadA)
  scanGamepads()
  pads = pollGamepads()
  doAssert openCount == 1
  doAssert pads[0].button(GamepadA) and not pads[0].buttonPressed(GamepadA)

  attached[2] = true
  doAssert pollGamepads().len == 1
  scanGamepads()
  pads = pollGamepads()
  doAssert pads.len == 2 and pads[0].id == 0 and pads[1].id == 1
  doAssert openCount == 2
  let scansBefore = enumerationCount
  for i in 0 ..< 100: discard pollGamepads()
  doAssert enumerationCount == scansBefore and openCount == 2

  attached[1] = false
  notification = "remove"
  notificationIndex = 1
  doAssert pollGamepads().len == 1
  doAssert gamepadStates[0].buttons == 0
  attached[1] = true
  doAssert pollGamepads().len == 1
  scanGamepads()
  doAssert pollGamepads().len == 2
  attached[2] = false
  pendingInput = 2
  doAssert pollGamepads().len == 1
  closeGamepads()
  doAssert not initialized and registered == default(typeof(registered))
  doAssert closeCount > 0
  let scansClosed = enumerationCount
  doAssert pollGamepads().len == 1
  doAssert enumerationCount == scansClosed + 1
  closeGamepads()

testDiscovery()
