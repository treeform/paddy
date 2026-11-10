import
  std/[macros, os]

macro backendSource*(name: static[string]): untyped =
  ## Compiles production backend bodies against the test's native-call fakes.
  let path = currentSourcePath().parentDir.parentDir /
    "src/paddy/platforms" / name
  result = newStmtList()
  for statement in parseStmt(readFile(path), path):
    if statement.kind notin {nnkImportStmt, nnkExportStmt}:
      result.add statement
