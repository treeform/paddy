import std/os

switch("define", "emscripten")
switch("os", "linux")
switch("cpu", "wasm32")
switch("cc", "clang")
switch("clang.exe", "emcc")
switch("clang.linkerexe", "emcc")
switch("threads", "off")
switch("mm", "arc")
switch("define", "noSignalHandler")
switch("out", thisDir() / "test_scan_browser.html")
switch("passL", "-sSINGLE_FILE=1 -sENVIRONMENT=web -sALLOW_MEMORY_GROWTH=1")
