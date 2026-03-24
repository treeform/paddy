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
| Windows | `XInput` | Standard Xbox-style controller API on Windows. |
| macOS | `GameController.framework` / `GCController` | Native Apple gamepad/controller support. |
| Linux | `udev` + `evdev` | Native Linux device enumeration and input polling. |
| Emscripten / Web | HTML5 Gamepad API | Browser-provided gamepad support. |

The exact support level and packaging details may vary by platform, but the public Nim API should stay consistent.

## Intended Usage

The intended model is:

1. Initialize the gamepad system.
2. Once per frame, poll/update the gamepad system.
3. Read buttons, sticks, triggers, and metadata from the connected devices.

This fits naturally into a normal game loop.

## Example API Shape

The exact API may evolve, but the intended usage looks something like this:

```nim
import windy, paddy

let window = newWindow("Paddy Example", ivec2(1280, 720))

initGamepads()

while not window.closeRequested:
  pollEvents()
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
```

The main idea is that gamepads are polled, not event-driven. Each frame, you update the controller state and then query the returned gamepad objects.

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
