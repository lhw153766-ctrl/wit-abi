///|
test "parse primitive type expressions" {
  let (reg, ty) = parse_type_expr("u32")
  assert_eq(size32(reg, ty), 4)
  let (r2, t2) = parse_type_expr("string")
  assert_eq(size32(r2, t2), 8)
}

///|
test "parse option and list" {
  let (reg, ty) = parse_type_expr("option<u32>")
  assert_eq(size32(reg, ty), 8)
  let (r2, t2) = parse_type_expr("list<u8>")
  assert_eq(flatten(r2, t2), [Pointer, Length])
}

///|
test "parse result and tuple" {
  let (reg, ty) = parse_type_expr("result<u32, f64>")
  assert_eq(flatten(reg, ty), [I32, I64])
  let (r2, t2) = parse_type_expr("(u8, u32)")
  assert_eq(size32(r2, t2), 8)
}

///|
test "parse unknown type errors" {
  let msg = try {
    ignore(parse_type_expr("widget"))
    "ok"
  } catch {
    Unexpected(s) => s
  }
  assert_true(msg.contains("unknown type"))
}

///|
test "parse trailing junk errors" {
  let msg = try {
    ignore(parse_type_expr("u32 extra"))
    "ok"
  } catch {
    Unexpected(s) => s
  }
  assert_eq(msg, "trailing input")
}

///|
test "parse handle and future" {
  let (reg, ty) = parse_type_expr("handle")
  assert_eq(size32(reg, ty), 4)
  let (r2, t2) = parse_type_expr("future")
  assert_eq(flatten(r2, t2), [I32])
}
