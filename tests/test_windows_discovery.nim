## Exercise the real polling path with a fake COM enumerator and no hardware.
when defined(windows):
  import std/os
  include ../src/paddy/platforms/windows_directinput

  var scanCount = 0
  proc countScan(self: ptr IDirectInput8W, kind: uint32,
      callback: LPDIENUMDEVICESCALLBACKW, context: pointer,
      flags: uint32): int32 {.stdcall.} =
    doAssert kind == DI8DEVCLASS_GAMECTRL
    doAssert flags == DIEDFL_ATTACHEDONLY
    inc scanCount
    DI_OK

  var vtable = IDirectInput8WVtbl(EnumDevices: countScan)
  var fakeInput = IDirectInput8W(lpVtbl: addr vtable)
  directInput = addr fakeInput
  dinputLoaded = true

  doAssert pollDirectInput(XUserMaxCount).len == 0
  doAssert scanCount == 0, "Empty controller slots must not trigger discovery"
  discoverDirectInput()
  doAssert scanCount == 1
  # Cross the former four-second timer; polling must still never enumerate.
  sleep(4100)
  for i in 0..<120:
    doAssert pollDirectInput(XUserMaxCount).len == 0
  doAssert scanCount == 1
  discoverDirectInput()
  doAssert scanCount == 2, "An explicit request must rescan even after a prior scan"
  directInput = nil
  dinputLoaded = false
  discoverDirectInput()
  doAssert scanCount == 2
  echo "Windows discovery regression passed"
