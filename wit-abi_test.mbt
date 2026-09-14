///|
/// Black-box tests against the public Canonical ABI API.
test "public primitive sizes" {
  let reg = @wit-abi.Registry::new()
  assert_eq(@wit-abi.size32(reg, @wit-abi.Bool), 1)
  assert_eq(@wit-abi.size32(reg, @wit-abi.U32), 4)
  assert_eq(@wit-abi.size32(reg, @wit-abi.String), 8)
}

///|
test "public record and flatten" {
  let reg = @wit-abi.Registry::new()
  let ty = @wit-abi.record_type(reg, [
    @wit-abi.Field::new("a", @wit-abi.U8),
    @wit-abi.Field::new("b", @wit-abi.U32),
  ])
  assert_eq(@wit-abi.size32(reg, ty), 8)
  assert_eq(@wit-abi.flatten(reg, ty), [@wit-abi.I32, @wit-abi.I32])
}

///|
test "public wasm signature" {
  let reg = @wit-abi.Registry::new()
  let func = @wit-abi.Func::new([@wit-abi.U32], Some(@wit-abi.U32))
  let sig = @wit-abi.wasm_signature(reg, func, @wit-abi.GuestImport)
  assert_eq(sig.params, [@wit-abi.I32])
  assert_eq(sig.results, [@wit-abi.I32])
  assert_eq(sig.indirect_params, false)
}
