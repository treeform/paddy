{.passL: "-ludev -levdev".}

type
  epoll_data_t* {.union.} = object
    `ptr`*: pointer
    fd*: cint
    u32*: uint32
    u64*: uint64

  epoll_event* = object
    events*: uint32
    data*: epoll_data_t

  timeval* = object
    tv_sec*: clong
    tv_usec*: clong

  input_event* = object
    time*: timeval
    `type`*: uint16
    code*: uint16
    value*: int32

  input_absinfo* = object
    value*: int32
    minimum*: int32
    maximum*: int32
    fuzz*: int32
    flat*: int32
    resolution*: int32

  dev_t* = uint64
  udev* = object
  udev_list_entry* = object
  udev_device* = object
  udev_monitor* = object
  udev_enumerate* = object
  libevdev* = object

const
  EPOLL_CTL_ADD* = 1
  EPOLL_CTL_DEL* = 2
  EPOLLIN* = 0x001

  EV_KEY* = 1
  EV_ABS* = 3

  BTN_0* = 0x100
  BTN_1* = 0x101
  BTN_2* = 0x102
  BTN_3* = 0x103
  BTN_4* = 0x104
  BTN_5* = 0x105
  BTN_6* = 0x106
  BTN_7* = 0x107
  BTN_8* = 0x108
  BTN_9* = 0x109

  BTN_TRIGGER* = 0x120
  BTN_THUMB* = 0x121
  BTN_THUMB2* = 0x122
  BTN_TOP* = 0x123
  BTN_TOP2* = 0x124
  BTN_PINKIE* = 0x125
  BTN_BASE* = 0x126
  BTN_BASE2* = 0x127
  BTN_BASE3* = 0x128
  BTN_BASE4* = 0x129
  BTN_BASE5* = 0x12a
  BTN_BASE6* = 0x12b

  BTN_A* = 0x130
  BTN_B* = 0x131
  BTN_X* = 0x133
  BTN_Y* = 0x134
  BTN_TL* = 0x136
  BTN_TR* = 0x137
  BTN_TL2* = 0x138
  BTN_TR2* = 0x139
  BTN_SELECT* = 0x13a
  BTN_START* = 0x13b
  BTN_MODE* = 0x13c
  BTN_THUMBL* = 0x13d
  BTN_THUMBR* = 0x13e

  BTN_C* = 0x132
  BTN_Z* = 0x135

  BTN_DPAD_UP* = 0x220
  BTN_DPAD_DOWN* = 0x221
  BTN_DPAD_LEFT* = 0x222
  BTN_DPAD_RIGHT* = 0x223

  BTN_GEAR_DOWN* = 0x150
  BTN_GEAR_UP* = 0x151

  BTN_GRIPL* = 0x224
  BTN_GRIPR* = 0x225
  BTN_GRIPL2* = 0x226
  BTN_GRIPR2* = 0x227

  BTN_TRIGGER_HAPPY1* = 0x2c0
  BTN_TRIGGER_HAPPY2* = 0x2c1
  BTN_TRIGGER_HAPPY3* = 0x2c2
  BTN_TRIGGER_HAPPY4* = 0x2c3
  BTN_TRIGGER_HAPPY5* = 0x2c4
  BTN_TRIGGER_HAPPY6* = 0x2c5
  BTN_TRIGGER_HAPPY7* = 0x2c6
  BTN_TRIGGER_HAPPY8* = 0x2c7
  BTN_TRIGGER_HAPPY9* = 0x2c8
  BTN_TRIGGER_HAPPY10* = 0x2c9
  BTN_TRIGGER_HAPPY11* = 0x2ca
  BTN_TRIGGER_HAPPY12* = 0x2cb
  BTN_TRIGGER_HAPPY13* = 0x2cc
  BTN_TRIGGER_HAPPY14* = 0x2cd
  BTN_TRIGGER_HAPPY15* = 0x2ce
  BTN_TRIGGER_HAPPY16* = 0x2cf
  BTN_TRIGGER_HAPPY17* = 0x2d0
  BTN_TRIGGER_HAPPY18* = 0x2d1
  BTN_TRIGGER_HAPPY19* = 0x2d2
  BTN_TRIGGER_HAPPY20* = 0x2d3
  BTN_TRIGGER_HAPPY21* = 0x2d4
  BTN_TRIGGER_HAPPY22* = 0x2d5
  BTN_TRIGGER_HAPPY23* = 0x2d6
  BTN_TRIGGER_HAPPY24* = 0x2d7
  BTN_TRIGGER_HAPPY25* = 0x2d8
  BTN_TRIGGER_HAPPY26* = 0x2d9
  BTN_TRIGGER_HAPPY27* = 0x2da
  BTN_TRIGGER_HAPPY28* = 0x2db

  ABS_X* = 0x00
  ABS_Y* = 0x01
  ABS_Z* = 0x02
  ABS_RX* = 0x03
  ABS_RY* = 0x04
  ABS_RZ* = 0x05
  ABS_THROTTLE* = 0x06
  ABS_RUDDER* = 0x07
  ABS_HAT0X* = 0x10
  ABS_HAT0Y* = 0x11

  LIBEVDEV_READ_FLAG_SYNC* = 1
  LIBEVDEV_READ_FLAG_NORMAL* = 2
  LIBEVDEV_READ_STATUS_SYNC* = -1

{.push importc, cdecl.}

proc epoll_create1*(flags: cint): cint
proc epoll_ctl*(epfd: cint, op: cint, fd: cint, event: ptr epoll_event): cint
proc epoll_wait*(
  epfd: cint,
  events: ptr epoll_event,
  maxevents: cint,
  timeout: cint
): cint

proc udev_new*(): ptr udev
proc udev_unref*(udev: ptr udev): ptr udev
proc udev_list_entry_get_next*(
  list_entry: ptr udev_list_entry
): ptr udev_list_entry
proc udev_list_entry_get_name*(list_entry: ptr udev_list_entry): cstring
proc udev_device_new_from_syspath*(
  udev: ptr udev,
  syspath: cstring
): ptr udev_device
proc udev_device_unref*(udev_device: ptr udev_device): ptr udev_device
proc udev_device_get_syspath*(udev_device: ptr udev_device): cstring
proc udev_device_get_devnode*(udev_device: ptr udev_device): cstring
proc udev_device_get_action*(udev_device: ptr udev_device): cstring
proc udev_device_get_property_value*(
  udev_device: ptr udev_device,
  key: cstring
): cstring
proc udev_monitor_new_from_netlink*(
  udev: ptr udev,
  name: cstring
): ptr udev_monitor
proc udev_monitor_unref*(udev_monitor: ptr udev_monitor): ptr udev_monitor
proc udev_monitor_filter_add_match_subsystem_devtype*(
  udev_monitor: ptr udev_monitor,
  subsystem: cstring,
  devtype: cstring
): cint
proc udev_monitor_enable_receiving*(udev_monitor: ptr udev_monitor): cint
proc udev_monitor_get_fd*(udev_monitor: ptr udev_monitor): cint
proc udev_monitor_receive_device*(udev_monitor: ptr udev_monitor): ptr udev_device
proc udev_enumerate_new*(udev: ptr udev): ptr udev_enumerate
proc udev_enumerate_unref*(udev_enumerate: ptr udev_enumerate): ptr udev_enumerate
proc udev_enumerate_add_match_subsystem*(
  udev_enumerate: ptr udev_enumerate,
  subsystem: cstring
): cint
proc udev_enumerate_add_match_property*(
  udev_enumerate: ptr udev_enumerate,
  property: cstring,
  value: cstring
): cint
proc udev_enumerate_scan_devices*(udev_enumerate: ptr udev_enumerate): cint
proc udev_enumerate_get_list_entry*(
  udev_enumerate: ptr udev_enumerate
): ptr udev_list_entry

proc libevdev_new_from_fd*(fd: cint, dev: ptr ptr libevdev): cint
proc libevdev_free*(dev: ptr libevdev)
proc libevdev_get_fd*(dev: ptr libevdev): cint
proc libevdev_get_name*(dev: ptr libevdev): cstring
proc libevdev_has_event_code*(
  dev: ptr libevdev,
  `type`: uint16,
  code: uint16
): bool
proc libevdev_get_abs_info*(
  dev: ptr libevdev,
  code: uint16
): ptr input_absinfo
proc libevdev_next_event*(
  dev: ptr libevdev,
  flags: cint,
  event: ptr input_event
): cint

{.pop.}

template udev_list_entry_foreach*(
  first_entry: ptr udev_list_entry,
  body: untyped
) =
  entry = first_entry
  while entry != nil:
    body
    entry = udev_list_entry_get_next(entry)
