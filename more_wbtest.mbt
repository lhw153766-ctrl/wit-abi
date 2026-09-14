///|
/// Extra Canonical ABI cases covering flags flattening, method ABI,
/// option/result join, and guest-import return pointers.
test "flatten flags by bit count" {
  let reg = Registry::new()
  assert_eq(flatten(reg, flags_type(reg, 3)), [I32])
  assert_eq(flatten(reg, flags_type(reg, 16)), [I32])
  assert_eq(flatten(reg, flags_type(reg, 17)), [I32])
  assert_eq(flatten(reg, flags_type(reg, 33)), [I32, I32])
}

///|
test "flatten list is pointer and length" {
  let reg = Registry::new()
  assert_eq(flatten(reg, list_type(reg, U32)), [Pointer, Length])
}

///|
test "flatten enum is just the tag" {
  let reg = Registry::new()
  assert_eq(flatten(reg, enum_type(reg, 4)), [I32])
}

///|
test "guest import string result takes a return pointer param" {
  let reg = Registry::new()
  let func = Func::new([U32], Some(String))
  let sig = wasm_signature(reg, func, GuestImport)
  assert_eq(sig.retptr, true)
  assert_eq(sig.params, [I32, Pointer])
  assert_eq(sig.results, [])
}

///|
test "guest export method first i32 becomes pointer" {
  let reg = Registry::new()
  let handle = handle_type(reg)
  let func = Func::new([handle, U32], Some(U32), is_method=true)
  let sig = wasm_signature(reg, func, GuestExport)
  assert_eq(sig.params[0], Pointer)
  assert_eq(sig.params[1], I32)
  assert_eq(sig.results, [I32])
}

///|
test "tuple of two strings flattens to four core types" {
  let reg = Registry::new()
  let ty = tuple_type(reg, [String, String])
  assert_eq(flatten(reg, ty), [Pointer, Length, Pointer, Length])
  assert_eq(size32(reg, ty), 16)
}

///|
test "option<string> layout" {
  let reg = Registry::new()
  let ty = option_type(reg, String)
  assert_eq(align32(reg, ty), 4)
  assert_eq(size32(reg, ty), 12)
  assert_eq(flatten(reg, ty), [I32, Pointer, Length])
}

///|
test "empty record is zero size align 1" {
  let reg = Registry::new()
  let ty = record_type(reg, [])
  assert_eq(size32(reg, ty), 0)
  assert_eq(align32(reg, ty), 1)
}

///|
test "bool then u64 record pads to 8" {
  let reg = Registry::new()
  let ty = record_type(reg, [Field::new("flag", Bool), Field::new("n", U64)])
  assert_eq(size32(reg, ty), 16)
  assert_eq(align32(reg, ty), 8)
}

///|
test "result with no payloads is just a tag" {
  let reg = Registry::new()
  let ty = result_type(reg, None, None)
  assert_eq(size32(reg, ty), 1)
  assert_eq(flatten(reg, ty), [I32])
}

///|
test "format_layout mentions wasm32 size" {
  let reg = Registry::new()
  let info = layout(reg, U32)
  let s = format_layout(info)
  assert_true(s.contains("size32=4"))
  assert_true(s.contains("align32=4"))
}

///|
test "named unknown type raises" {
  let reg = Registry::new()
  let raised = try {
    ignore(reg.get(7))
    "ok"
  } catch {
    UnknownNamed(id) => "unknown \{id}"
    Overflow(_) => "overflow"
    InvalidType(_) => "invalid"
  }
  assert_eq(raised, "unknown 7")
}

///|
test "demo_registry is non-empty" {
  let reg = demo_registry()
  assert_true(reg.types.length() > 8)
}

///|
test "wasm_types_to_string joins with spaces" {
  assert_eq(wasm_types_to_string([I32, Pointer, Length]), "i32 pointer length")
}

///|
test "AbiError display" {
  assert_eq(Overflow("x").to_string(), "overflow: x")
  assert_eq(InvalidType("y").to_string(), "invalid type: y")
  assert_eq(UnknownNamed(3).to_string(), "unknown named type #3")
}

///|
test "ValType and TypeDef Show" {
  assert_eq(Show::to_string(Bool), "bool")
  assert_eq(Show::to_string(Named(2)), "type#2")
  assert_eq(Show::to_string(List(U8)), "list<u8>")
  assert_eq(Show::to_string(Handle), "handle")
}

///|
test "DiscInt and FlagsRepr Show" {
  assert_eq(Show::to_string(DiscInt::U16), "u16")
  assert_eq(Show::to_string(FlagsRepr::U32(2)), "u32x2")
}

///|
test "Alignment wasm32 vs wasm64" {
  assert_eq(Alignment::Pointer.align_wasm32(), 4)
  assert_eq(Alignment::Pointer.align_wasm64(), 8)
  assert_eq(Alignment::Bytes(8).align_wasm32(), 8)
}

///|
test "ArchSize empty and format" {
  assert_true(ArchSize::zero().is_empty())
  assert_eq(Show::to_string(ArchSize::new(4, 0)), "4")
  assert_eq(Show::to_string(ArchSize::new(0, 1)), "ptrsz")
  assert_eq(Show::to_string(ArchSize::new(2, 3)), "2+3*ptrsz")
}

///|
test "fixed list of four u32 is 16 bytes" {
  let reg = Registry::new()
  let ty = Named(reg.add(FixedList(U32, 4)))
  assert_eq(size32(reg, ty), 16)
  assert_eq(flatten(reg, ty), [I32, I32, I32, I32])
}

///|
test "map is pointer pair" {
  let reg = Registry::new()
  let ty = Named(reg.add(Map(String, U32)))
  assert_eq(size32(reg, ty), 8)
  assert_eq(flatten(reg, ty), [Pointer, Length])
}

///|
test "future and stream are i32 handles" {
  let reg = Registry::new()
  assert_eq(flatten(reg, Named(reg.add(Future))), [I32])
  assert_eq(flatten(reg, Named(reg.add(Stream))), [I32])
}
