import macros, strutils, typetraits

type
  Class* = distinct int
  ID* = distinct int
  SEL* = distinct int
  Protocol* = distinct int
  IMP* = pointer
  objc_super* = object
    receiver*: ID
    super_class*: Class

{.push cdecl, dynlib: "libobjc.dylib".}

proc objc_msgSend*() {.importc.}
proc objc_msgSendSuper*() {.importc.}
when defined(amd64):
  proc objc_msgSend_fpret*() {.importc.}
  proc objc_msgSend_stret*() {.importc.}
else:
  proc objc_msgSend_fpret*() {.importc: "objc_msgSend".}
  proc objc_msgSend_stret*() {.importc: "objc_msgSend".}
proc objc_getClass*(name: cstring): Class {.importc.}
proc objc_getProtocol*(name: cstring): Protocol {.importc.}
proc objc_allocateClassPair*(
  super: Class,
  name: cstring,
  extraBytes = 0
): Class {.importc.}
proc objc_registerClassPair*(cls: Class) {.importc.}
proc class_getName*(cls: Class): cstring {.importc.}
proc class_addMethod*(
  cls: Class,
  name: SEL,
  imp: IMP,
  types: cstring
): bool {.importc.}
proc object_getClass*(id: ID): Class {.importc.}
proc sel_registerName*(s: cstring): SEL {.importc.}
proc sel_getName*(sel: SEL): cstring {.importc.}
proc class_addProtocol*(cls: Class, protocol: Protocol): bool {.importc.}

{.pop.}

var
  numClass {.compiletime.} = 1
  numSel {.compiletime.} = 2

macro objc*(body: untyped) =
  var header = newStmtList()

  for fn in body:
    var
      name = fn[0].repr
      retType = fn[3][0]
      sel = name
      numParams = 0

    sel.removeSuffix("*")
    sel = sel.strip(true, true, {'`'})
    fn[4] = quote do: {.inline.}

    let msgSend = ident("msgSend")
    var procBody = quote do:
      let `msgSend` = cast[proc(): `retType` {.cdecl, raises: [], gcsafe.}](
        objc_msgSend
      )
      `msgSend`()

    fn[6] = procBody

    if repr(retType) in ["float64"]:
      procBody[0][0][2][1] = ident("objc_msgSend_fpret")

    for defs in fn[3][1 .. ^1]:
      for arg in defs[0 .. ^3]:
        let
          argName = repr arg
          argType = defs[^2]

        if numParams == 0:
          if argName notin ["class", "self"]:
            error("First argument needs to be class or self.", arg)

          if argType.kind == nnkBracketExpr and
            argType[0].strVal == "typedesc":
              let
                classVar = ident("class" & $numClass)
                classStr = newStrLitNode(argType[1].strVal)
              header.add quote do:
                let `classVar` = objc_getClass(`classStr`.cstring)
              inc numClass
              procBody[1].add classVar

              let idenDefs = newIdentDefs(ident("cls"), ident("Class"))
              procBody[0][0][2][0][0].add idenDefs
          else:
            let idenDefs = newIdentDefs(ident("self"), argType)
            procBody[0][0][2][0][0].add idenDefs
            procBody[1].add ident(argName)

          let idenDefs = newIdentDefs(ident("cmd"), ident("SEL"))
          procBody[0][0][2][0][0].add idenDefs
          procBody[1].add ident("sel" & $numSel)
        else:
          if numParams != 1:
            var fixArg = argName
            fixArg.removeSuffix("_mangle")
            sel.add fixArg
          else:
            if argName != "x":
              error("Second argument needs to be x.", arg)
          sel.add ":"

          let idenDefs = newIdentDefs(ident(argName), argType)
          procBody[0][0][2][0][0].add idenDefs
          procBody[1].add ident(argName)

        inc numParams

    let
      selVar = ident("sel" & $numSel)
      selStr = newStrLitNode(sel)
    header.add quote do:
      let `selVar` = sel_registerName(`selStr`.cstring)

    inc numSel

  body.insert(0, header)
  body

type
  NSAutoreleasePool* = distinct int
  NSString* = distinct int

objc:
  proc UTF8String(self: NSString): cstring
  proc release*(self: NSAutoreleasePool)

template s*(s: string): SEL =
  sel_registerName(s.cstring)

proc getClass*(t: typedesc): Class =
  objc_getClass(t.name.cstring)

template autoreleasepool*(body: untyped) =
  let pool = NSAutoreleasePool.new()
  try:
    body
  finally:
    pool.release()

proc `@`*(s: string): NSString =
  let msgSend = cast[
    proc(self: ID, cmd: SEL, s: cstring): NSString {.cdecl, raises: [], gcsafe.}
  ](objc_msgSend)
  msgSend(
    NSString.getClass().ID,
    s"stringWithUTF8String:",
    s.cstring
  )

proc `$`*(s: NSString): string =
  $s.UTF8String

proc new*(cls: Class): ID =
  let msgSend = cast[
    proc(self: ID, cmd: SEL): ID {.cdecl, gcsafe, raises: [].}
  ](objc_msgSend)
  msgSend(cls.ID, s"new")

proc new*[T](class: typedesc[T]): T =
  class.getClass().new().T
