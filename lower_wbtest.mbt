///|
test "lower primitives have sequential offsets" {
  let reg = Registry::new()
  let steps = lower(reg, U32)
  assert_eq(steps.length(), 1)
  assert_eq(steps[0].offset32, 0)
  assert_eq(steps[0].op, LoadI32)
}

///|
test "lower string is pointer then length" {
  let reg = Registry::new()
  let s = lower_to_string(lower(reg, String))
  assert_eq(s, "pointer@0 length@4")
}

///|
test "lower option u32 has tag then payload" {
  let reg = Registry::new()
  let ty = option_type(reg, U32)
  let s = lower_to_string(lower(reg, ty))
  assert_true(s.contains("tag(i32)@0"))
}

///|
test "layout_json contains size32" {
  let (reg, ty) = parse_type_expr("option<u32>")
  let json = layout_json(reg, ty)
  assert_true(json.contains("\"size32\":8"))
  assert_true(json.contains("\"flat\":"))
}

///|
test "lower record pads u8 then u32" {
  let reg = Registry::new()
  let ty = record_type(reg, [Field::new("a", U8), Field::new("b", U32)])
  let steps = lower(reg, ty)
  assert_eq(steps[0].offset32, 0)
  assert_eq(steps[1].offset32, 4)
}
