///|
/// Property-style invariants over Canonical ABI layout.
/// These must hold for any well-formed type in the registry.

///|
fn assert_size_multiple_of_align(reg : Registry, ty : ValType) -> Unit raise {
  let info = layout(reg, ty)
  let size = info.size.size_wasm32()
  let align = info.align.align_wasm32()
  if align == 0 {
    abort("align 0")
  }
  assert_eq(size % align, 0)
}

///|
test "invariant: primitive sizes are multiples of alignment" {
  let reg = Registry::new()
  let tys = [
    Bool,
    U8,
    U16,
    ValType::U32,
    ValType::U64,
    F32,
    F64,
    Char,
    String,
    S8,
    S16,
    S32,
    S64,
  ]
  for ty in tys {
    assert_size_multiple_of_align(reg, ty)
  }
}

///|
test "invariant: composed types stay aligned" {
  let reg = Registry::new()
  let rec = record_type(reg, [Field::new("a", U8), Field::new("b", U64)])
  let opt = option_type(reg, String)
  let res = result_type(reg, Some(U32), Some(F64))
  let lst = list_type(reg, U8)
  let tup = tuple_type(reg, [U16, U16, U16, U16, U16])
  let flg = flags_type(reg, 33)
  let en = enum_type(reg, 300)
  let tys = [rec, opt, res, lst, tup, flg, en]
  for ty in tys {
    assert_size_multiple_of_align(reg, ty)
  }
}

///|
test "invariant: flatten length never exceeds MAX_FLAT_PARAMS for one type" {
  let reg = Registry::new()
  let tys = [
    Bool,
    String,
    option_type(reg, U32),
    list_type(reg, U64),
    flags_type(reg, 40),
  ]
  for ty in tys {
    let flats = flatten(reg, ty)
    assert_true(flats.length() <= 64)
  }
}

///|
test "invariant: option payload offset is at least tag size" {
  let reg = Registry::new()
  let inner = ValType::U64
  let sa = SizeAlign::fill(reg)
  let off = sa.payload_offset(U8, [Some(inner)]).size_wasm32()
  assert_true(off >= 1)
  assert_eq(off % 8, 0)
}

///|
test "invariant: wasm32 string is 8 bytes align 4" {
  let reg = Registry::new()
  assert_eq(size32(reg, String), 8)
  assert_eq(align32(reg, String), 4)
  assert_eq(size32(reg, list_type(reg, Bool)), 8)
}

///|
test "invariant: empty record size 0 align 1" {
  let reg = Registry::new()
  let ty = record_type(reg, [])
  assert_eq(size32(reg, ty), 0)
  assert_eq(align32(reg, ty), 1)
}

///|
test "invariant: flags 0..40 repr count matches layout" {
  let ns = [0, 1, 8, 9, 16, 17, 32, 33, 40]
  for n in ns {
    let r = flags_repr(n)
    let expected = match r {
      FlagsRepr::U8 => 1
      FlagsRepr::U16 => 2
      FlagsRepr::U32(k) => k * 4
    }
    let reg = Registry::new()
    assert_eq(size32(reg, flags_type(reg, n)), expected)
  }
}

///|
test "invariant: enum 1 and 256 are u8, 257 is u16" {
  assert_eq(discriminant_type(1), DiscInt::U8)
  assert_eq(discriminant_type(256), DiscInt::U8)
  assert_eq(discriminant_type(257), DiscInt::U16)
  let reg = Registry::new()
  assert_eq(size32(reg, enum_type(reg, 256)), 1)
  assert_eq(size32(reg, enum_type(reg, 257)), 2)
}

///|
test "invariant: result join never shorter than either payload flatten" {
  let reg = Registry::new()
  let ty = result_type(reg, Some(String), Some(U32))
  let flats = flatten(reg, ty)
  // tag + joined payload: string flatten is 2, so at least 3
  assert_true(flats.length() >= 3)
}

///|
test "invariant: ArchSize wasm32 vs wasm64 monotonic in pointers" {
  let a = ArchSize::new(0, 1)
  assert_eq(a.size_wasm32(), 4)
  assert_eq(a.size_wasm64(), 8)
  let b = ArchSize::new(4, 1)
  assert_true(b.size_wasm64() > b.size_wasm32())
}

///|
test "invariant: align_to is idempotent" {
  for v in 0..<32 {
    for a in [1, 2, 4, 8] {
      let x = align_to(v, a)
      assert_eq(align_to(x, a), x)
      assert_eq(x % a, 0)
      assert_true(x >= v)
    }
  }
}

///|
test "wasm-tools vector: five u16 tuple" {
  let reg = Registry::new()
  let ty = tuple_type(reg, [U16, U16, U16, U16, U16])
  assert_eq(size32(reg, ty), 10)
  assert_eq(align32(reg, ty), 2)
}

///|
test "wasm-tools vector: u8 then pointer-like string" {
  let reg = Registry::new()
  let ty = record_type(reg, [Field::new("a", U8), Field::new("b", String)])
  assert_eq(align32(reg, ty), 4)
  assert_eq(size32(reg, ty), 12)
}

///|
test "wasm-tools vector: bool then u64" {
  let reg = Registry::new()
  let ty = record_type(reg, [Field::new("a", Bool), Field::new("b", U64)])
  assert_eq(size32(reg, ty), 16)
  assert_eq(align32(reg, ty), 8)
}

///|
test "wasm-tools vector: option string" {
  let (reg, ty) = parse_type_expr("option<string>")
  assert_eq(size32(reg, ty), 12)
  assert_eq(flatten(reg, ty), [I32, Pointer, Length])
}

///|
test "wasm-tools vector: result u32 f64" {
  let (reg, ty) = parse_type_expr("result<u32, f64>")
  assert_eq(size32(reg, ty), 16)
  assert_eq(flatten(reg, ty), [I32, I64])
}

///|
test "wasm-tools vector: flags 31 32 33" {
  let reg = Registry::new()
  assert_eq(size32(reg, flags_type(reg, 31)), 4)
  assert_eq(size32(reg, flags_type(reg, 32)), 4)
  assert_eq(size32(reg, flags_type(reg, 33)), 8)
}

///|
test "wasm-tools vector: nested option of record" {
  let reg = Registry::new()
  let inner = record_type(reg, [Field::new("x", U32), Field::new("y", U32)])
  let ty = option_type(reg, inner)
  assert_size_multiple_of_align(reg, ty)
  assert_eq(flatten(reg, ty)[0], I32)
}

///|
test "wasm-tools vector: list of records" {
  let reg = Registry::new()
  let rec = record_type(reg, [Field::new("a", U8), Field::new("b", U32)])
  let ty = list_type(reg, rec)
  assert_eq(size32(reg, ty), 8)
  assert_eq(flatten(reg, ty), [Pointer, Length])
}

///|
test "wasm-tools vector: variant unit vs u64" {
  let reg = Registry::new()
  let ty = variant_type(reg, [
    Case::new("none", None),
    Case::new("num", Some(U64)),
  ])
  assert_eq(align32(reg, ty), 8)
  assert_eq(size32(reg, ty), 16)
}

///|
test "deep nest record of option of list" {
  let (reg, ty) = parse_type_expr("option<list<u8>>")
  assert_eq(size32(reg, ty), 12)
  assert_eq(flatten(reg, ty), [I32, Pointer, Length])
}

///|
test "tuple of two strings is 16 bytes on wasm32" {
  let (reg, ty) = parse_type_expr("(string, string)")
  assert_eq(size32(reg, ty), 16)
  assert_eq(flatten(reg, ty).length(), 4)
}

///|
test "handle flatten is i32" {
  let (reg, ty) = parse_type_expr("handle")
  assert_eq(flatten(reg, ty), [I32])
  assert_eq(size32(reg, ty), 4)
}

///|
test "char and error-context match u32" {
  let reg = Registry::new()
  assert_eq(size32(reg, Char), size32(reg, U32))
  assert_eq(size32(reg, ErrorContext), 4)
}

///|
test "fixed list four f64 is 32 bytes" {
  let reg = Registry::new()
  let ty = Named(reg.add(FixedList(F64, 4)))
  assert_eq(size32(reg, ty), 32)
  assert_eq(flatten(reg, ty).length(), 4)
}

///|
test "many-param signature becomes indirect" {
  let reg = Registry::new()
  let ps : Array[ValType] = []
  for _ in 0..<16 {
    ps.push(U32)
  }
  let flat_ok = wasm_signature(reg, Func::new(ps, None), GuestImport)
  assert_eq(flat_ok.indirect_params, false)
  ps.push(U32)
  let indirect = wasm_signature(reg, Func::new(ps, None), GuestImport)
  assert_eq(indirect.indirect_params, true)
}

///|
test "export string result is retptr" {
  let reg = Registry::new()
  let sig = wasm_signature(reg, Func::new([], Some(String)), GuestExport)
  assert_eq(sig.retptr, true)
  assert_eq(sig.results, [Pointer])
}

///|
test "import string result is extra pointer param" {
  let reg = Registry::new()
  let sig = wasm_signature(reg, Func::new([], Some(String)), GuestImport)
  assert_eq(sig.retptr, true)
  assert_eq(sig.params, [Pointer])
}

///|
test "nested tuple alignment" {
  let (reg, ty) = parse_type_expr("((u8, u32), u64)")
  assert_size_multiple_of_align(reg, ty)
  assert_eq(align32(reg, ty), 8)
}

///|
test "map size equals list size" {
  let reg = Registry::new()
  assert_eq(
    size32(reg, Named(reg.add(Map(U8, U8)))),
    size32(reg, list_type(reg, U8)),
  )
}

///|
test "future and stream equal handle" {
  let reg = Registry::new()
  assert_eq(size32(reg, Named(reg.add(Future))), 4)
  assert_eq(size32(reg, Named(reg.add(Stream))), 4)
  assert_eq(size32(reg, handle_type(reg)), 4)
}

///|
test "alias does not change flatten" {
  let reg = Registry::new()
  let a = alias_type(reg, String)
  assert_eq(flatten(reg, a), flatten(reg, String))
  assert_eq(size32(reg, a), size32(reg, String))
}

///|
test "bool is not padded inside flags" {
  assert_eq(flags_repr(1), FlagsRepr::U8)
}

///|
test "payload offset of unit-only variant is tag size" {
  let reg = Registry::new()
  let sa = SizeAlign::fill(reg)
  let off = sa.payload_offset(U8, [None, None])
  assert_eq(off.size_wasm32(), 1)
}

///|
test "field offsets u8 u32 u8" {
  let reg = Registry::new()
  let sa = SizeAlign::fill(reg)
  let offs = sa.field_offsets([ValType::U8, ValType::U32, ValType::U8])
  assert_eq(offs[0].size_wasm32(), 0)
  assert_eq(offs[1].size_wasm32(), 4)
  assert_eq(offs[2].size_wasm32(), 8)
}

///|
test "option of empty record" {
  let reg = Registry::new()
  let empty = record_type(reg, [])
  let ty = option_type(reg, empty)
  assert_eq(size32(reg, ty), 1)
  assert_eq(flatten(reg, ty), [I32])
}

///|
test "result none none flatten is tag only" {
  let reg = Registry::new()
  let ty = result_type(reg, None, None)
  assert_eq(flatten(reg, ty), [I32])
}

///|
test "list of strings still pointer pair" {
  let (reg, ty) = parse_type_expr("list<string>")
  assert_eq(flatten(reg, ty), [Pointer, Length])
}

///|
test "record of four u64 is 32 bytes" {
  let (reg, ty) = parse_type_expr("(u64, u64, u64, u64)")
  assert_eq(size32(reg, ty), 32)
  assert_eq(align32(reg, ty), 8)
}

///|
test "s64 matches u64 layout" {
  let reg = Registry::new()
  assert_eq(size32(reg, S64), size32(reg, U64))
  assert_eq(flatten(reg, S64), flatten(reg, U64))
}

///|
test "f32 joins with i32 in result" {
  let reg = Registry::new()
  let ty = result_type(reg, Some(U32), Some(F32))
  assert_eq(flatten(reg, ty), [I32, I32])
}

///|
test "codegen lift contains size comment" {
  let (reg, ty) = parse_type_expr("u64")
  let src = emit_moonbit_glue(reg, ty)
  assert_true(src.contains("size32=8"))
}

///|
test "nested option option u32" {
  let (reg, inner) = parse_type_expr("option<u32>")
  let ty = option_type(reg, inner)
  assert_size_multiple_of_align(reg, ty)
  assert_eq(flatten(reg, ty)[0], I32)
}

///|
test "variant three unit cases is one byte" {
  let reg = Registry::new()
  let ty = variant_type(reg, [
    Case::new("a", None),
    Case::new("b", None),
    Case::new("c", None),
  ])
  assert_eq(size32(reg, ty), 1)
}

///|
test "json dump round-trip keys" {
  let (reg, ty) = parse_type_expr("list<u32>")
  let json = layout_json(reg, ty)
  assert_true(json.contains("\"lower\""))
  assert_true(json.contains("\"flat\""))
  assert_true(json.contains("\"align64\""))
}
