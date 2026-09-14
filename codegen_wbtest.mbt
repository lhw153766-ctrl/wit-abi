///|
test "emit glue for u32 contains lift and lower" {
  let reg = Registry::new()
  let src = emit_moonbit_glue(reg, U32)
  assert_true(src.contains("pub fn lift_value"))
  assert_true(src.contains("pub fn lower_value"))
  assert_true(src.contains("load_i32(ptr + 0)"))
  assert_true(src.contains("store_i32(ptr + 0"))
  assert_true(src.contains("let v0 = 0"))
}

///|
test "emit glue for string uses pointer and length" {
  let reg = Registry::new()
  let src = emit_named_glue(reg, String, "name")
  assert_true(src.contains("lift_name"))
  assert_true(src.contains("load_i32(ptr + 0)"))
  assert_true(src.contains("load_i32(ptr + 4)"))
}

///|
test "emit glue for record pads second field" {
  let reg = Registry::new()
  let ty = record_type(reg, [Field::new("id", U8), Field::new("count", U32)])
  let src = emit_named_glue(reg, ty, "rec")
  assert_true(src.contains("lift_rec"))
  assert_true(src.contains("ptr + 4"))
}

///|
test "emit_func_glue mentions signature" {
  let reg = Registry::new()
  let func = Func::new([String, U32], Some(String))
  let src = emit_func_glue(reg, func, "greet")
  assert_true(src.contains("function `greet`"))
  assert_true(src.contains("retptr=true"))
  assert_true(src.contains("lift_greet_arg0"))
  assert_true(src.contains("lift_greet_ret"))
}

///|
test "abi_card lists size32" {
  let (reg, ty) = parse_type_expr("option<u32>")
  let card = abi_card(reg, ty, "opt")
  assert_true(card.contains("size32   8"))
  assert_true(card.contains("flat     i32 i32"))
}

///|
test "func_card has export and import lines" {
  let reg = Registry::new()
  let func = Func::new([U32], Some(U32))
  let card = func_card(reg, func, "inc")
  assert_true(card.contains("export"))
  assert_true(card.contains("import"))
  assert_true(card.contains("arg0"))
}

///|
test "sanitize ident replaces dashes" {
  let reg = Registry::new()
  let src = emit_named_glue(reg, U8, "input-stream")
  assert_true(src.contains("lift_input_stream"))
}

///|
test "layout_json of record is stable" {
  let (reg, ty) = parse_type_expr("(u8, u32)")
  let json = layout_json(reg, ty)
  assert_true(json.contains("\"size32\":8"))
  assert_true(json.contains("\"align32\":4"))
}
