///|
test "from_type_json string" {
  let (reg, ty) = from_type_json("\"option<u32>\"")
  assert_eq(size32(reg, ty), 8)
}

///|
test "from_type_json object" {
  let (reg, ty) = from_type_json("{\"expr\":\"list<u8>\"}")
  assert_eq(flatten(reg, ty), [Pointer, Length])
}

///|
test "from_iface_json greet" {
  let src = "{\"package\":\"docs:hello\",\"funcs\":[{\"name\":\"greet\",\"params\":[\"string\"],\"result\":\"string\"}]}"
  let (reg, doc) = from_iface_json(src)
  assert_eq(doc.package_name, Some("docs:hello"))
  assert_eq(doc.funcs.length(), 1)
  let func = Func::new(doc.funcs[0].params, doc.funcs[0].result)
  let sig = wasm_signature(reg, func, GuestExport)
  assert_eq(sig.retptr, true)
}

///|
test "from_iface_json two params" {
  let src = "{\"funcs\":[{\"name\":\"add\",\"params\":[\"u32\",\"u32\"],\"result\":\"u32\"}]}"
  let (reg, doc) = from_iface_json(src)
  let func = Func::new(doc.funcs[0].params, doc.funcs[0].result)
  let sig = wasm_signature(reg, func, GuestExport)
  assert_eq(sig.params, [I32, I32])
  assert_eq(sig.results, [I32])
}

///|
test "from_iface_json types and worlds" {
  let src = "{\"types\":[{\"name\":\"id\",\"expr\":\"u32\"}],\"worlds\":[\"hello\"],\"funcs\":[]}"
  let (reg, doc) = from_iface_json(src)
  ignore(reg)
  assert_eq(doc.types.length(), 1)
  assert_eq(doc.worlds[0], "hello")
}

///|
test "from_iface_json missing params ok" {
  let src = "{\"funcs\":[{\"name\":\"ping\"}]}"
  let (reg, doc) = from_iface_json(src)
  ignore(reg)
  assert_eq(doc.funcs[0].params.length(), 0)
  assert_eq(doc.funcs[0].result, None)
}

///|
test "from_type_json bad shape" {
  let msg = try {
    ignore(from_type_json("1"))
    "ok"
  } catch {
    BadJson(s) => s
    Missing(s) => s
    Unexpected(s) => s
    _ => "other"
  }
  assert_true(msg.contains("expected string"))
}
