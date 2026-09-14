///|
test "align_to power of two" {
  assert_eq(align_to(0, 4), 0)
  assert_eq(align_to(1, 4), 4)
  assert_eq(align_to(4, 4), 4)
  assert_eq(align_to(5, 8), 8)
  assert_eq(align_to(16, 8), 16)
}

///|
test "align_to_arch matches wasm-tools sizealign tests" {
  assert_eq(
    align_to_arch(ArchSize::new(1, 0), Alignment::Pointer),
    ArchSize::new(0, 1),
  )
  assert_eq(
    align_to_arch(ArchSize::new(1, 0), Alignment::Bytes(8)),
    ArchSize::new(8, 0),
  )
  assert_eq(
    align_to_arch(ArchSize::new(1, 0), Alignment::Bytes(4)),
    ArchSize::new(4, 0),
  )
  assert_eq(
    align_to_arch(ArchSize::new(0, 1), Alignment::Bytes(8)),
    ArchSize::new(8, 0),
  )
  assert_eq(
    align_to_arch(ArchSize::new(4, 0), Alignment::Pointer),
    ArchSize::new(0, 1),
  )
  assert_eq(
    align_to_arch(ArchSize::new(0, 2), Alignment::Bytes(8)),
    ArchSize::new(0, 2),
  )
  assert_eq(
    align_to_arch(ArchSize::new(1, 1), Alignment::Bytes(8)),
    ArchSize::new(0, 2),
  )
  assert_eq(
    align_to_arch(ArchSize::new(1, 1), Alignment::Pointer),
    ArchSize::new(0, 2),
  )
  assert_eq(
    align_to_arch(ArchSize::new(1, 2), Alignment::Bytes(8)),
    ArchSize::new(8, 2),
  )
  assert_eq(
    align_to_arch(ArchSize::new(30, 3), Alignment::Bytes(8)),
    ArchSize::new(40, 2),
  )
  assert_eq(
    align_to_arch(ArchSize::new(2, 0), Alignment::Bytes(8)),
    ArchSize::new(8, 0),
  )
  assert_eq(
    align_to_arch(ArchSize::new(2, 0), Alignment::Pointer),
    ArchSize::new(0, 1),
  )
}

///|
test "ArchSize::max mixed 32/64" {
  assert_eq(ArchSize::new(12, 0).max(ArchSize::new(0, 2)), ArchSize::new(8, 1))
  assert_eq(ArchSize::new(10, 0).max(ArchSize::new(0, 2)), ArchSize::new(8, 1))
}

///|
test "Alignment ordering Pointer vs Bytes" {
  assert_true(Compare::compare(Alignment::Bytes(1), Alignment::Bytes(2)) < 0)
  assert_true(Compare::compare(Alignment::Bytes(4), Alignment::Pointer) < 0)
  assert_true(Compare::compare(Alignment::Pointer, Alignment::Bytes(8)) < 0)
  assert_eq(Alignment::Bytes(4).max(Alignment::Pointer), Alignment::Pointer)
  assert_eq(Alignment::Bytes(8).max(Alignment::Pointer), Alignment::Bytes(8))
}

///|
test "primitive sizes on wasm32" {
  let reg = Registry::new()
  assert_eq(size32(reg, Bool), 1)
  assert_eq(size32(reg, U8), 1)
  assert_eq(size32(reg, U16), 2)
  assert_eq(size32(reg, U32), 4)
  assert_eq(size32(reg, U64), 8)
  assert_eq(size32(reg, F32), 4)
  assert_eq(size32(reg, F64), 8)
  assert_eq(size32(reg, Char), 4)
  assert_eq(size32(reg, String), 8)
  assert_eq(align32(reg, String), 4)
  assert_eq(align32(reg, U64), 8)
}

///|
test "record {u8, u32} is 8 bytes aligned 4" {
  let reg = Registry::new()
  let ty = record_type(reg, [Field::new("a", U8), Field::new("b", U32)])
  assert_eq(size32(reg, ty), 8)
  assert_eq(align32(reg, ty), 4)
}

///|
test "tuple of five u16 is 10 bytes aligned 2" {
  let reg = Registry::new()
  let ty = tuple_type(reg, [U16, U16, U16, U16, U16])
  assert_eq(size32(reg, ty), 10)
  assert_eq(align32(reg, ty), 2)
}

///|
test "list and string are pointer+length" {
  let reg = Registry::new()
  let ty = list_type(reg, U8)
  assert_eq(size32(reg, ty), 8)
  assert_eq(align32(reg, ty), 4)
  let info = layout(reg, String)
  assert_eq(info.size.pointers, 2)
}

///|
test "option<u32> is 8 bytes" {
  let reg = Registry::new()
  let ty = option_type(reg, U32)
  assert_eq(size32(reg, ty), 8)
  assert_eq(align32(reg, ty), 4)
}

///|
test "result<u16, u64> follows variant layout" {
  let reg = Registry::new()
  let ty = result_type(reg, Some(U16), Some(U64))
  // discrim u8, payload max(u16=2, u64=8)=8 aligned 8, total 16
  assert_eq(size32(reg, ty), 16)
  assert_eq(align32(reg, ty), 8)
}

///|
test "flags repr" {
  assert_eq(flags_repr(0), FlagsRepr::U32(0))
  assert_eq(flags_repr(1), FlagsRepr::U8)
  assert_eq(flags_repr(8), FlagsRepr::U8)
  assert_eq(flags_repr(9), FlagsRepr::U16)
  assert_eq(flags_repr(16), FlagsRepr::U16)
  assert_eq(flags_repr(17), FlagsRepr::U32(1))
  assert_eq(flags_repr(32), FlagsRepr::U32(1))
  assert_eq(flags_repr(33), FlagsRepr::U32(2))
}

///|
test "flags layout" {
  let reg = Registry::new()
  assert_eq(size32(reg, flags_type(reg, 3)), 1)
  assert_eq(size32(reg, flags_type(reg, 12)), 2)
  assert_eq(size32(reg, flags_type(reg, 20)), 4)
  assert_eq(size32(reg, flags_type(reg, 40)), 8)
}

///|
test "enum discriminant" {
  assert_eq(discriminant_type(1), DiscInt::U8)
  assert_eq(discriminant_type(256), DiscInt::U8)
  assert_eq(discriminant_type(257), DiscInt::U16)
  let reg = Registry::new()
  assert_eq(size32(reg, enum_type(reg, 4)), 1)
}

///|
test "handle is u32" {
  let reg = Registry::new()
  let ty = handle_type(reg)
  assert_eq(size32(reg, ty), 4)
  assert_eq(align32(reg, ty), 4)
}

///|
test "alias preserves inner layout" {
  let reg = Registry::new()
  let ty = alias_type(reg, String)
  assert_eq(size32(reg, ty), 8)
  assert_eq(flatten(reg, ty), [Pointer, Length])
}

///|
test "flatten primitives" {
  let reg = Registry::new()
  assert_eq(flatten(reg, Bool), [I32])
  assert_eq(flatten(reg, U64), [I64])
  assert_eq(flatten(reg, F32), [F32])
  assert_eq(flatten(reg, F64), [F64])
  assert_eq(flatten(reg, String), [Pointer, Length])
}

///|
test "flatten option and result join" {
  let reg = Registry::new()
  let o = option_type(reg, U32)
  assert_eq(flatten(reg, o), [I32, I32])
  let r = result_type(reg, Some(U32), Some(F32))
  // tag + joined payload (i32 join f32 = i32)
  assert_eq(flatten(reg, r), [I32, I32])
  let r2 = result_type(reg, Some(U32), Some(F64))
  assert_eq(flatten(reg, r2), [I32, I64])
}

///|
test "flatten record concatenates fields" {
  let reg = Registry::new()
  let ty = record_type(reg, [
    Field::new("a", U8),
    Field::new("b", String),
    Field::new("c", F64),
  ])
  assert_eq(flatten(reg, ty), [I32, Pointer, Length, F64])
}

///|
test "wasm_signature small params stay flat" {
  let reg = Registry::new()
  let func = Func::new([U32, U32], Some(U32))
  let sig = wasm_signature(reg, func, GuestExport)
  assert_eq(sig.params, [I32, I32])
  assert_eq(sig.results, [I32])
  assert_eq(sig.indirect_params, false)
  assert_eq(sig.retptr, false)
}

///|
test "wasm_signature string result uses retptr on export" {
  let reg = Registry::new()
  let func = Func::new([], Some(String))
  let sig = wasm_signature(reg, func, GuestExport)
  assert_eq(sig.retptr, true)
  assert_eq(sig.results, [Pointer])
  let sigi = wasm_signature(reg, func, GuestImport)
  assert_eq(sigi.retptr, true)
  assert_eq(sigi.params, [Pointer])
  assert_eq(sigi.results, [])
}

///|
test "wasm_signature many params become indirect" {
  let reg = Registry::new()
  let params : Array[ValType] = []
  for _ in 0..<17 {
    params.push(U32)
  }
  let func = Func::new(params, None)
  let sig = wasm_signature(reg, func, GuestImport)
  assert_eq(sig.indirect_params, true)
  assert_eq(sig.params, [Pointer])
}

///|
test "payload_offset after u8 tag with u64 case" {
  let reg = Registry::new()
  let cases = [Some(ValType::U64), None]
  let sa = SizeAlign::fill(reg)
  let off = sa.payload_offset(DiscInt::U8, cases)
  assert_eq(off.size_wasm32(), 8)
}

///|
test "field_offsets of mixed record" {
  let reg = Registry::new()
  let tys = [ValType::U8, ValType::U32, ValType::U8]
  let rec = tuple_type(reg, tys)
  ignore(rec)
  let sa = SizeAlign::fill(reg)
  let offs = sa.field_offsets(tys)
  assert_eq(offs[0].size_wasm32(), 0)
  assert_eq(offs[1].size_wasm32(), 4)
  assert_eq(offs[2].size_wasm32(), 8)
}

///|
test "variant with unit and string" {
  let reg = Registry::new()
  let ty = variant_type(reg, [
    Case::new("none", None),
    Case::new("some", Some(String)),
  ])
  // tag u8 aligned to pointer, plus string (2 pointers)
  assert_eq(align32(reg, ty), 4)
  assert_eq(size32(reg, ty), 12)
  assert_eq(flatten(reg, ty), [I32, Pointer, Length])
}

///|
test "signed and remaining constructors" {
  let reg = Registry::new()
  assert_eq(size32(reg, S8), 1)
  assert_eq(size32(reg, S16), 2)
  assert_eq(size32(reg, S32), 4)
  assert_eq(size32(reg, S64), 8)
  assert_eq(size32(reg, Char), 4)
  assert_eq(size32(reg, ErrorContext), 4)
  let map = Named(reg.add(Map(U8, U16)))
  assert_eq(size32(reg, map), 8)
  let fl = Named(reg.add(FixedList(U16, 4)))
  assert_eq(size32(reg, fl), 8)
  let fut = Named(reg.add(Future))
  let st = Named(reg.add(Stream))
  assert_eq(size32(reg, fut), 4)
  assert_eq(size32(reg, st), 4)
  ignore(GuestImport)
  ignore(GuestExport)
}

///|
test "resource is not a guest value type" {
  let reg = Registry::new()
  let ty = Named(reg.add(Resource))
  let info = layout(reg, ty)
  assert_eq(info.size.bytes, 2147483647)
}
