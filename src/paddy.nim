import paddy/common

when defined(windows):
  import paddy/platforms/windows
  export windows
elif defined(macosx):
  import paddy/platforms/macos
  export macos
elif defined(linux):
  import paddy/platforms/linux
  export linux
elif defined(emscripten):
  import paddy/platforms/emscripten
  export emscripten
else:
  proc initGamepads*() =
    ## Initializes gamepad support on unsupported targets.
    discard

  proc closeGamepads*() =
    ## Closes gamepad support on unsupported targets.
    discard

  proc pollGamepads*(): seq[Gamepad] =
    ## Returns an empty set of gamepads on unsupported targets.
    @[]

export common
