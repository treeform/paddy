{.passC: "-Wno-incompatible-function-pointer-types".}

type
  EM_BOOL* = cint

  EmscriptenGamepadEvent* {.
    importc: "EmscriptenGamepadEvent",
    header: "<emscripten/html5.h>"
  .} = object
    timestamp*: cdouble
    numAxes*: cint
    numButtons*: cint
    axis*: array[64, cdouble]
    analogButton*: array[64, cdouble]
    digitalButton*: array[64, bool]
    connected*: bool
    index*: cint
    id*: array[64, char]
    mapping*: array[64, char]

const
  EM_CALLBACK_THREAD_CONTEXT* = cast[pointer](1)

proc strcmp*(a: cstring, b: cstring): cint {.importc, header: "<string.h>".}
proc emscripten_sample_gamepad_data*(): cint {.
  importc,
  header: "<emscripten/html5.h>"
.}
proc emscripten_get_gamepad_status*(
  index: cint,
  gamepadState: ptr EmscriptenGamepadEvent
): cint {.importc, header: "<emscripten/html5.h>".}
proc emscripten_set_gamepadconnected_callback_on_thread*(
  userData: pointer,
  useCapture: cint,
  callback: proc(
    eventType: cint,
    gamepadEvent: ptr EmscriptenGamepadEvent,
    userData: pointer
  ): EM_BOOL {.cdecl.},
  targetThread: pointer
): cint {.importc, header: "<emscripten/html5.h>".}
proc emscripten_set_gamepaddisconnected_callback_on_thread*(
  userData: pointer,
  useCapture: cint,
  callback: proc(
    eventType: cint,
    gamepadEvent: ptr EmscriptenGamepadEvent,
    userData: pointer
  ): EM_BOOL {.cdecl.},
  targetThread: pointer
): cint {.importc, header: "<emscripten/html5.h>".}
