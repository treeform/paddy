<img src="docs/paddy.png">

# Paddy - A gamepad API for Nim.

`nimby install paddy`

![Github Actions](https://github.com/treeform/paddy/workflows/Github%20Actions/badge.svg)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/treeform/paddy)
![GitHub Repo stars](https://img.shields.io/github/stars/treeform/paddy)
![GitHub](https://img.shields.io/github/license/treeform/paddy)
![GitHub issues](https://img.shields.io/github/issues/treeform/paddy)

[API reference](https://treeform.github.io/paddy)

## About

Paddy is a gamepad API for Nim.

It is designed to pair well with
[`windy`](https://github.com/treeform/windy), the window API.
If you are making a game that needs a gamepad, you can use `windy`
for window creation and frame flow, and use `paddy` for gamepad
discovery, polling, buttons, triggers, sticks, and controller
metadata.

Originally this was meant to be part of `windy`, but I did not want
to add all of that extra complexity to `windy` itself. Gamepad
support pulls in more platform-specific frameworks, APIs,
dependencies, and setup requirements, so it made more sense to keep
it as a separate library.

This keeps gamepad support as an explicit opt-in. Projects that do
not need controller input do not need to think about controller
backends, platform-specific APIs, or extra runtime requirements.

> **AI disclaimer: Much of this library was AI generated.**

### Documentation

The API reference is available here:
[https://treeform.github.io/paddy](https://treeform.github.io/paddy)

## Goals

- Provide a small, cross-platform Nim API for gamepads.
- Work naturally alongside `windy`.
- Poll controllers once per frame and read a consistent gamepad state.
- Expose common gamepad concepts.
- Expose connection status.
- Expose device names.
- Expose buttons.
- Expose button pressed and released edges.
- Expose trigger pressure.
- Expose analog stick axes.
- Use native platform backends where possible.

## Why A Separate Library?

Gamepad input is not really part of window management.

On each platform, controller support comes with different system APIs, frameworks, and setup requirements. Keeping that logic in a separate library makes the tradeoff explicit:

- `windy` stays focused on windows and app flow.
- `paddy` stays focused on gamepads.
- users only opt into controller complexity if they need it.

## Platform Backends

Paddy uses the native or standard controller API for each target platform.

| Platform | Backend | Notes |
| --- | --- | --- |
| Windows | `XInput` + `DirectInput` | Xbox-style controllers plus a DirectInput fallback. |
| macOS | `GameController.framework` / `GCController` | Native Apple gamepad/controller support. |
| Linux | `udev` + `evdev` | Native Linux device enumeration and input polling. |
| Emscripten / Web | HTML5 Gamepad API | Browser-provided gamepad support. |

The exact support level and packaging details may vary by platform, but the public Nim API should stay consistent.

## Requirements

Paddy uses native platform APIs.

On Linux, you need the `udev` and `evdev` development packages
installed in order to build the library:

```sh
sudo apt-get update
sudo apt-get install -y libudev-dev libevdev-dev
```

This is required on Ubuntu and other Debian-based systems.

Systems using mdev are supported through an automatic once-per-second scan
that also finds controllers without udev joystick metadata. Existing udev discovery and
hotplug notifications remain active. libudev and libevdev are still required;
applications need read access to the input device nodes.

## Intended Usage

The intended model is:

1. Initialize the gamepad system.
2. Once per frame, poll/update the gamepad system.
3. Read buttons, sticks, triggers, and metadata from the connected devices.
4. Explicitly scan when the application wants to discover newly connected controllers.

This fits naturally into a normal game loop.

## Example API Shape

The exact API may evolve, but the intended usage looks something like this:

```nim
import windy, paddy

let window = newWindow("Paddy Example", ivec2(1280, 720))

initGamepads()

while not window.closeRequested:
  pollEvents()
  if window.buttonPressed[KeyF5]:
    scanGamepads()
  for gamepad in pollGamepads():
    echo gamepad.name

    if gamepad.buttonPressed(GamepadA):
      echo "A pressed"

    let
      lx = gamepad.axis(GamepadLStickX)
      ly = gamepad.axis(GamepadLStickY)
      rt = gamepad.buttonPressure(GamepadR2)

    discard lx
    discard ly
    discard rt

closeGamepads()
```

The main idea is that gamepads are polled, not event-driven. Each frame, you update the controller state and then query the returned gamepad objects.

### Discovery and hot-plugging

The same discovery contract applies to Windows, Linux, macOS, and browsers:

| Function | Behavior |
| --- | --- |
| `initGamepads()` | Initialize and discover currently available controllers. Repeated calls do nothing. |
| `scanGamepads()` | Discover newly available controllers, preserving existing controller IDs and input state. |
| `pollGamepads()` | Read registered controllers and remove disconnected controllers, returning their input snapshots. |
| `closeGamepads()` | Release controller resources. |

Initialization and scanning may block. Call them at startup, on a controller
setup screen, or in response to an explicit rescan action. A menu can still
pause briefly during a scan; the application controls when that cost occurs.
Calling `scanGamepads()` before initialization initializes and scans once.
For compatibility, the first `pollGamepads()` call also initializes and scans
if needed. Subsequent polls never enumerate devices, probe disconnected
XInput slots, or open new controllers.

**Hot-plug migration:** applications that previously relied on automatic
discovery during polling must call `scanGamepads()` themselves. This includes
reconnecting an unplugged controller and adding another controller while one
is already connected. Disconnections still clear controller input during
normal polling. OS connection notifications do not bypass explicit discovery.

Linux discovery uses udev labels and a capability-filtered sysfs fallback for
mdev systems and unlabelled controllers. Input polling does not periodically
rescan sysfs or open unrelated input nodes. Browsers can require a controller
button press before exposing a device to a scan; scanning does not pair devices
or bypass the OS or browser's visibility restrictions.

## Common Data You Can Read

Paddy aims to expose a standard set of inputs:

- connection status
- controller name / device label
- digital button state
- pressed/released edge state
- trigger pressure
- left and right analog stick axes
- d-pad state

This should make it easy to implement game controls, menus, local multiplayer, and controller-driven UI.

## Planned Example

A graphical example is planned using `windy` and `silky`.

That example will show:

- connected controllers
- current button states
- trigger pressures
- analog stick positions
- a simple on-screen visualization of the controller state

The goal is to make it easy to verify that a controller is working correctly on each platform.

## Status

Paddy is intended to be a focused, standalone controller library for Nim applications, especially games built with `windy`.

More implementation details, examples, and installation notes will be added as the library takes shape.
