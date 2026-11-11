import
  paddy

proc runScript(script: cstring) {.importc: "emscripten_run_script", header: "<emscripten/emscripten.h>".}
  ## Controls browser-visible controller fixtures through the real JS bindings.

proc testBrowser() =
  ## Checks the production WASM backend against a browser's native event machinery.
  runScript("""
    window.paddyPads = [];
    Object.defineProperty(navigator, 'getGamepads', {value: () => window.paddyPads});
    window.attachPaddyPad = function(index) {
      window.paddyPads[index] = {
        index, connected: true, id: 'Fixture ' + index, mapping: 'standard',
        timestamp: 1, axes: [0, 0, 0, 0],
        buttons: Array.from({length: 16}, () => ({pressed: false, touched: false, value: 0}))
      };
      let event = new Event('gamepadconnected');
      Object.defineProperty(event, 'gamepad', {value: window.paddyPads[index]});
      window.dispatchEvent(event);
    };
    document.body.setAttribute('data-paddy-result', 'running');
  """)
  scanGamepads()
  doAssert pollGamepads().len == 0
  runScript("attachPaddyPad(0); paddyPads[0].buttons[0] = {pressed: true, touched: true, value: 1};")
  doAssert pollGamepads().len == 0
  scanGamepads()
  var pads = pollGamepads()
  doAssert pads.len == 1 and pads[0].id == 0
  doAssert pads[0].buttonPressed(GamepadA)
  scanGamepads()
  pads = pollGamepads()
  doAssert pads[0].button(GamepadA) and not pads[0].buttonPressed(GamepadA)
  runScript("attachPaddyPad(1);")
  doAssert pollGamepads().len == 1
  scanGamepads()
  doAssert pollGamepads().len == 2
  runScript("""
    let pad = paddyPads[0];
    pad.connected = false;
    paddyPads[0] = null;
    let event = new Event('gamepaddisconnected');
    Object.defineProperty(event, 'gamepad', {value: pad});
    window.dispatchEvent(event);
  """)
  doAssert pollGamepads().len == 1
  runScript("attachPaddyPad(0);")
  doAssert pollGamepads().len == 1
  scanGamepads()
  doAssert pollGamepads().len == 2
  closeGamepads()
  doAssert pollGamepads().len == 2
  closeGamepads()
  runScript("document.body.setAttribute('data-paddy-result', 'passed');")

testBrowser()
