import paddy/common

when defined(emscripten):
  import paddy/platforms/emscripten
  export emscripten
elif defined(windows):
  import paddy/platforms/windows
  export windows
elif defined(macosx):
  import paddy/platforms/macos
  export macos
elif defined(linux):
  import paddy/platforms/linux
  export linux
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

when not defined(windows) or defined(emscripten):
  proc discoverGamepads*() =
    ## Ensures discovery is initialized. These backends detect new controllers
    ## automatically; only Windows DirectInput requires an explicit rescan.
    initGamepads()

export common
