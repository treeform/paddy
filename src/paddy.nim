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

when not declared(discoverGamepads):
  when declared(scanGamepads):
    proc discoverGamepads*() =
      ## Discovers available controllers at an application-selected time; may block.
      scanGamepads()
  else:
    proc discoverGamepads*() =
      ## Initializes backends that still discover controllers automatically.
      initGamepads()

when not declared(scanGamepads):
  proc scanGamepads*() =
    ## Requests discovery through the backend's existing API; may block.
    discoverGamepads()

export common
