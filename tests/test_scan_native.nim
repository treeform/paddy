import
  paddy

proc testLifecycle() =
  ## Exercises real backend initialization, scanning, polling, and reinitialization.
  for iteration in 0 ..< 2:
    scanGamepads()
    initGamepads()
    for frame in 0 ..< 3:
      var seen: set[0 .. MaxGamepads - 1]
      for pad in pollGamepads():
        doAssert pad.id in 0 ..< MaxGamepads
        doAssert pad.id notin seen
        seen.incl pad.id
    scanGamepads()
    closeGamepads()
    closeGamepads()
  discard pollGamepads()
  closeGamepads()

testLifecycle()
