///|
test "store load i32 little endian" {
  let mem = GuestMem::new(8)
  mem.store_i32(0, 0x04030201)
  assert_eq(mem.load_u8(0), 1)
  assert_eq(mem.load_u8(1), 2)
  assert_eq(mem.load_u8(2), 3)
  assert_eq(mem.load_u8(3), 4)
  assert_eq(mem.load_i32(0), 0x04030201)
}

///|
test "store load i64" {
  let mem = GuestMem::new(16)
  mem.store_i64(0, 0x0807060504030201L)
  assert_eq(mem.load_i32(0), 0x04030201)
  assert_eq(mem.load_i64(0), 0x0807060504030201L)
}

///|
test "string pair roundtrip" {
  let mem = GuestMem::new(32)
  mem.store_string(0, 16, "hi")
  assert_eq(mem.load_i32(0), 16)
  assert_eq(mem.load_i32(4), 2)
  assert_eq(mem.load_string(0), "hi")
}

///|
test "u32 roundtrip through lower steps" {
  let reg = Registry::new()
  let back = roundtrip_i32s(reg, U32, [42])
  assert_eq(back, [42])
}

///|
test "record u8 u32 roundtrip" {
  let (reg, ty) = parse_type_expr("(u8, u32)")
  let steps = lower(reg, ty)
  let mem = GuestMem::new(16)
  mem.store_u8(steps[0].offset32, 7)
  mem.store_i32(steps[1].offset32, 99)
  assert_eq(mem.load_u8(0), 7)
  assert_eq(mem.load_i32(4), 99)
}

///|
test "option u32 tag and payload" {
  let (reg, ty) = parse_type_expr("option<u32>")
  let steps = lower(reg, ty)
  let mem = GuestMem::new(16)
  mem.store_steps(steps, [1, 77])
  let back = mem.load_steps(steps)
  assert_eq(back[0], 1)
  assert_eq(back[1], 77)
}

///|
test "string layout slots" {
  let reg = Registry::new()
  let steps = lower(reg, String)
  let mem = GuestMem::new(32)
  mem.store_string(steps[0].offset32, 16, "ab")
  assert_eq(mem.load_string(0), "ab")
}

///|
test "flags 33 two i32 slots" {
  let reg = Registry::new()
  let ty = flags_type(reg, 33)
  let back = roundtrip_i32s(reg, ty, [1, 2])
  assert_eq(back, [1, 2])
}

///|
test "list pointer pair" {
  let (reg, ty) = parse_type_expr("list<u8>")
  let back = roundtrip_i32s(reg, ty, [100, 3])
  assert_eq(back, [100, 3])
}

///|
test "grow memory on demand" {
  let mem = GuestMem::new(1)
  mem.store_i32(8, 5)
  assert_eq(mem.load_i32(8), 5)
  assert_true(mem.len() >= 12)
}
