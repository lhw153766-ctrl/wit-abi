///|
/// Additional Canonical ABI vectors inspired by wasm-tools sizealign tests.

///|
test "vector: u8+u8 packed" {
  let reg = Registry::new()
  let ty = tuple_type(reg, [U8, U8])
  assert_eq(size32(reg, ty), 2)
  assert_eq(align32(reg, ty), 1)
}

///|
test "vector: u8+u16 packed with pad" {
  let reg = Registry::new()
  let ty = tuple_type(reg, [U8, U16])
  assert_eq(size32(reg, ty), 4)
  assert_eq(align32(reg, ty), 2)
}

///|
test "vector: u16+u8+u16" {
  let reg = Registry::new()
  let ty = tuple_type(reg, [U16, U8, U16])
  assert_eq(size32(reg, ty), 6)
  assert_eq(align32(reg, ty), 2)
}

///|
test "vector: three u32" {
  let (reg, ty) = parse_type_expr("(u32, u32, u32)")
  assert_eq(size32(reg, ty), 12)
}

///|
test "vector: u32 then string" {
  let (reg, ty) = parse_type_expr("(u32, string)")
  assert_eq(size32(reg, ty), 12)
  assert_eq(flatten(reg, ty), [I32, Pointer, Length])
}

///|
test "vector: string then u32" {
  let (reg, ty) = parse_type_expr("(string, u32)")
  assert_eq(size32(reg, ty), 12)
}

///|
test "vector: option bool" {
  let (reg, ty) = parse_type_expr("option<bool>")
  assert_eq(size32(reg, ty), 2)
  assert_eq(flatten(reg, ty), [I32, I32])
}

///|
test "vector: option u8" {
  let (reg, ty) = parse_type_expr("option<u8>")
  assert_eq(size32(reg, ty), 2)
}

///|
test "vector: option u16" {
  let (reg, ty) = parse_type_expr("option<u16>")
  assert_eq(size32(reg, ty), 4)
}

///|
test "vector: option u64" {
  let (reg, ty) = parse_type_expr("option<u64>")
  assert_eq(size32(reg, ty), 16)
  assert_eq(align32(reg, ty), 8)
}

///|
test "vector: option f32" {
  let (reg, ty) = parse_type_expr("option<f32>")
  assert_eq(size32(reg, ty), 8)
}

///|
test "vector: option f64" {
  let (reg, ty) = parse_type_expr("option<f64>")
  assert_eq(size32(reg, ty), 16)
}

///|
test "vector: result string string" {
  let (reg, ty) = parse_type_expr("result<string, string>")
  assert_eq(size32(reg, ty), 12)
  assert_eq(flatten(reg, ty), [I32, Pointer, Length])
}

///|
test "vector: result u64 u8" {
  let (reg, ty) = parse_type_expr("result<u64, u8>")
  assert_eq(align32(reg, ty), 8)
  assert_eq(size32(reg, ty), 16)
}

///|
test "vector: flags 0 size 0" {
  let reg = Registry::new()
  assert_eq(size32(reg, flags_type(reg, 0)), 0)
}

///|
test "vector: flags 7 is u8" {
  let reg = Registry::new()
  assert_eq(size32(reg, flags_type(reg, 7)), 1)
}

///|
test "vector: flags 24 is u32" {
  let reg = Registry::new()
  assert_eq(size32(reg, flags_type(reg, 24)), 4)
}

///|
test "vector: flags 64 is two u32" {
  let reg = Registry::new()
  assert_eq(size32(reg, flags_type(reg, 64)), 8)
  assert_eq(flatten(reg, flags_type(reg, 64)), [I32, I32])
}

///|
test "vector: enum 2" {
  let reg = Registry::new()
  assert_eq(size32(reg, enum_type(reg, 2)), 1)
}

///|
test "vector: enum 1000 is u16" {
  let reg = Registry::new()
  assert_eq(size32(reg, enum_type(reg, 1000)), 2)
}

///|
test "vector: list of option u32" {
  let (reg, ty) = parse_type_expr("list<option<u32>>")
  assert_eq(size32(reg, ty), 8)
}

///|
test "vector: option of option string" {
  let (reg, inner) = parse_type_expr("option<string>")
  let ty = option_type(reg, inner)
  assert_eq(flatten(reg, ty)[0], I32)
  assert_eq(size32(reg, ty) % align32(reg, ty), 0)
}

///|
test "vector: record named fields mixed" {
  let reg = Registry::new()
  let ty = record_type(reg, [
    Field::new("flag", Bool),
    Field::new("id", U32),
    Field::new("note", String),
  ])
  assert_eq(align32(reg, ty), 4)
  assert_eq(size32(reg, ty), 16)
}

///|
test "vector: variant u8 vs string" {
  let reg = Registry::new()
  let ty = variant_type(reg, [
    Case::new("byte", Some(U8)),
    Case::new("text", Some(String)),
  ])
  assert_eq(align32(reg, ty), 4)
  assert_eq(size32(reg, ty), 12)
}

///|
test "vector: variant two u32 payloads" {
  let reg = Registry::new()
  let ty = variant_type(reg, [
    Case::new("a", Some(U32)),
    Case::new("b", Some(U32)),
  ])
  assert_eq(size32(reg, ty), 8)
  assert_eq(flatten(reg, ty), [I32, I32])
}

///|
test "glue for flags 33 has two stores" {
  let reg = Registry::new()
  let src = emit_named_glue(reg, flags_type(reg, 33), "bits")
  assert_true(src.contains("ptr + 4"))
  assert_true(src.contains("lift_bits"))
}

///|
test "func card of greet-like" {
  let reg = Registry::new()
  let func = Func::new([String], Some(String))
  let card = func_card(reg, func, "greet")
  assert_true(card.contains("retptr=true"))
}

///|
test "abi card of list" {
  let (reg, ty) = parse_type_expr("list<f64>")
  let card = abi_card(reg, ty, "nums")
  assert_true(card.contains("size32   8"))
}

///|
test "interface add report contains u32" {
  let src = "interface math { add: func(a: u32, b: u32) -> u32; }"
  let (reg, doc) = parse_interface(src)
  let r = interface_report(reg, doc)
  assert_true(r.contains("func add"))
  assert_true(r.contains("arg0"))
}

///|
test "parse world only" {
  let (reg, doc) = parse_interface("world empty { }")
  ignore(reg)
  assert_eq(doc.worlds[0], "empty")
  assert_eq(doc.funcs.length(), 0)
}

///|
test "parse type alias in interface" {
  let src = "interface i { type t = option<u32>; f: func(x: u32); }"
  let (reg, doc) = parse_interface(src)
  assert_eq(doc.types.length(), 1)
  assert_eq(doc.funcs.length(), 1)
  ignore(reg)
}

///|
test "codegen option includes tag load" {
  let (reg, ty) = parse_type_expr("option<string>")
  let src = emit_moonbit_glue(reg, ty)
  assert_true(src.contains("tag(i32)@0"))
}

///|
test "lower option string offsets" {
  let (reg, ty) = parse_type_expr("option<string>")
  let s = lower_to_string(lower(reg, ty))
  assert_true(s.contains("tag(i32)@0"))
  assert_true(s.contains("pointer@"))
}

///|
test "tuple empty" {
  let (reg, ty) = parse_type_expr("()")
  assert_eq(size32(reg, ty), 0)
  assert_eq(flatten(reg, ty).length(), 0)
}

///|
test "char flatten i32" {
  let reg = Registry::new()
  assert_eq(flatten(reg, Char), [I32])
}

///|
test "error-context flatten i32" {
  let reg = Registry::new()
  assert_eq(flatten(reg, ErrorContext), [I32])
}

///|
test "s8 flatten i32" {
  let reg = Registry::new()
  assert_eq(flatten(reg, S8), [I32])
  assert_eq(size32(reg, S8), 1)
}

///|
test "f64 flatten" {
  let reg = Registry::new()
  assert_eq(flatten(reg, F64), [F64])
}

///|
test "indirect 16 strings" {
  let reg = Registry::new()
  let ps : Array[ValType] = []
  for _ in 0..<9 {
    ps.push(String)
  }
  let sig = wasm_signature(reg, Func::new(ps, None), GuestExport)
  assert_eq(sig.indirect_params, true)
}

///|
test "method export first param pointer" {
  let reg = Registry::new()
  let h = handle_type(reg)
  let sig = wasm_signature(
    reg,
    Func::new([h], Some(U32), is_method=true),
    GuestExport,
  )
  assert_eq(sig.params[0], Pointer)
}

///|
test "non-method export handle stays i32" {
  let reg = Registry::new()
  let h = handle_type(reg)
  let sig = wasm_signature(reg, Func::new([h], Some(U32)), GuestExport)
  assert_eq(sig.params[0], I32)
}
