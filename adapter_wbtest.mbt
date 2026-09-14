///|
const HELLO_WIT =
  #|package docs:hello;
  #|
  #|interface greet {
  #|  type id = u32;
  #|  greet: func(name: string) -> string;
  #|  ping: func();
  #|}
  #|
  #|world hello {
  #|  export greet;
  #|}

///|
test "parse hello interface" {
  let (reg, doc) = parse_interface(HELLO_WIT)
  assert_eq(doc.package_name, Some("docs:hello"))
  assert_eq(doc.funcs.length(), 2)
  assert_eq(doc.funcs[0].name, "greet")
  assert_eq(doc.funcs[0].params.length(), 1)
  assert_eq(doc.funcs[1].name, "ping")
  assert_eq(doc.types.length(), 1)
  assert_eq(doc.worlds[0], "hello")
  let report = interface_report(reg, doc)
  assert_true(report.contains("func greet"))
  assert_true(report.contains("export"))
}

///|
test "interface json lists greet" {
  let (reg, doc) = parse_interface(HELLO_WIT)
  let json = interface_json(reg, doc)
  assert_true(json.contains("greet"))
  assert_true(json.contains("export"))
}

///|
test "parse interface rejects junk" {
  let msg = try {
    ignore(parse_interface("widget foo;"))
    "ok"
  } catch {
    Unexpected(s) => s
  }
  assert_true(msg.contains("unexpected top-level"))
}

///|
test "parse interface empty ping has no result" {
  let src = "interface x { n: func(); }"
  let (reg, doc) = parse_interface(src)
  ignore(reg)
  assert_eq(doc.funcs[0].result, None)
}

///|
test "parse interface two params" {
  let src = "interface x { add: func(a: u32, b: u32) -> u32; }"
  let (reg, doc) = parse_interface(src)
  assert_eq(doc.funcs[0].params.length(), 2)
  let func = Func::new(doc.funcs[0].params, doc.funcs[0].result)
  let sig = wasm_signature(reg, func, GuestExport)
  assert_eq(sig.params, [I32, I32])
  assert_eq(sig.results, [I32])
}
