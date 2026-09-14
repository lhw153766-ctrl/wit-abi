///|
/// Core WebAssembly types used when lowering Canonical ABI values.
pub(all) enum WasmType {
  I32
  I64
  F32
  F64
  Pointer
  PointerOrI64
  Length
} derive(Eq, Debug)

///|
pub impl Show for WasmType with fn to_string(self) {
  match self {
    I32 => "i32"
    I64 => "i64"
    F32 => "f32"
    F64 => "f64"
    Pointer => "pointer"
    PointerOrI64 => "pointer-or-i64"
    Length => "length"
  }
}

///|
fn join(a : WasmType, b : WasmType) -> WasmType {
  match (a, b) {
    (I32, I32)
    | (I64, I64)
    | (F32, F32)
    | (F64, F64)
    | (Pointer, Pointer)
    | (PointerOrI64, PointerOrI64)
    | (Length, Length) => a
    (I32, F32) | (F32, I32) => I32
    (Length, I32) | (Length, F32) | (I32, Length) | (F32, Length) => Length
    (Length, I64) | (Length, F64) | (I64, Length) | (F64, Length) => I64
    (Pointer, I32)
    | (Pointer, F32)
    | (Pointer, Length)
    | (I32, Pointer)
    | (F32, Pointer)
    | (Length, Pointer) => Pointer
    (Pointer, I64) | (Pointer, F64) | (I64, Pointer) | (F64, Pointer) =>
      PointerOrI64
    (PointerOrI64, _) | (_, PointerOrI64) => PointerOrI64
    (_, I64) | (_, F64) | (I64, _) | (F64, _) => I64
  }
}

///|
pub const MAX_FLAT_PARAMS : Int = 16

///|
pub const MAX_FLAT_RESULTS : Int = 1

///|
/// Flattened core-Wasm signature of a WIT function.
pub(all) struct WasmSignature {
  params : Array[WasmType]
  results : Array[WasmType]
  indirect_params : Bool
  retptr : Bool
} derive(Eq, Debug)

///|
pub impl Show for WasmSignature with fn to_string(self) {
  let mut ps = ""
  for i, t in self.params {
    if i > 0 {
      ps = ps + ","
    }
    ps = ps + Show::to_string(t)
  }
  let mut rs = ""
  for i, t in self.results {
    if i > 0 {
      rs = rs + ","
    }
    rs = rs + Show::to_string(t)
  }
  "params=[" +
  ps +
  "] results=[" +
  rs +
  "] indirect=" +
  self.indirect_params.to_string() +
  " retptr=" +
  self.retptr.to_string()
}

///|
fn push_one(out : Array[WasmType], limit : Int, ty : WasmType) -> Bool {
  if out.length() >= limit {
    false
  } else {
    out.push(ty)
    true
  }
}

///|
fn SizeAlign::push_flat(
  self : SizeAlign,
  reg : Registry,
  ty : ValType,
  out : Array[WasmType],
  limit : Int,
) -> Bool raise AbiError {
  match ty {
    Bool | S8 | U8 | S16 | U16 | S32 | U32 | Char | ErrorContext =>
      push_one(out, limit, I32)
    U64 | S64 => push_one(out, limit, I64)
    F32 => push_one(out, limit, F32)
    F64 => push_one(out, limit, F64)
    String => push_one(out, limit, Pointer) && push_one(out, limit, Length)
    Named(id) => {
      let def = reg.get(id)
      match def {
        Alias(t) => self.push_flat(reg, t, out, limit)
        Handle => push_one(out, limit, I32)
        Resource => raise InvalidType("raw resources are not part of the ABI")
        Record(fields) => {
          for f in fields {
            if !self.push_flat(reg, f.ty, out, limit) {
              return false
            }
          }
          true
        }
        Tuple(ts) => {
          for t in ts {
            if !self.push_flat(reg, t, out, limit) {
              return false
            }
          }
          true
        }
        Flags(n) => {
          let count = flags_repr(n).count()
          for _ in 0..<count {
            if !push_one(out, limit, I32) {
              return false
            }
          }
          true
        }
        List(_) | Map(_, _) =>
          push_one(out, limit, Pointer) && push_one(out, limit, Length)
        FixedList(inner, n) => {
          for _ in 0..<n {
            if !self.push_flat(reg, inner, out, limit) {
              return false
            }
          }
          true
        }
        Variant(cases) => {
          let tag = discriminant_type(cases.length())
          let tag_ty = match tag {
            U8 | U16 | U32 => WasmType::I32
            U64 => WasmType::I64
          }
          if !push_one(out, limit, tag_ty) {
            return false
          }
          let payloads : Array[ValType?] = []
          for c in cases {
            payloads.push(c.ty)
          }
          self.push_flat_variants(reg, payloads, out, limit)
        }
        Enum(n) => {
          let tag = discriminant_type(n)
          let tag_ty = match tag {
            U8 | U16 | U32 => WasmType::I32
            U64 => WasmType::I64
          }
          push_one(out, limit, tag_ty)
        }
        Option(t) => {
          if !push_one(out, limit, I32) {
            return false
          }
          self.push_flat_variants(reg, [None, Some(t)], out, limit)
        }
        Result(ok, err) => {
          if !push_one(out, limit, I32) {
            return false
          }
          self.push_flat_variants(reg, [ok, err], out, limit)
        }
        Future | Stream => push_one(out, limit, I32)
      }
    }
  }
}

///|
fn SizeAlign::push_flat_variants(
  self : SizeAlign,
  reg : Registry,
  tys : Array[ValType?],
  out : Array[WasmType],
  limit : Int,
) -> Bool raise AbiError {
  let start = out.length()
  for ty in tys {
    match ty {
      None => ()
      Some(t) => {
        let temp : Array[WasmType] = []
        if !self.push_flat(reg, t, temp, limit - start) {
          return false
        }
        for i, ft in temp {
          let idx = start + i
          if idx < out.length() {
            out[idx] = join(out[idx], ft)
          } else if out.length() >= limit {
            return false
          } else {
            out.push(ft)
          }
        }
      }
    }
  }
  true
}

///|
/// Flatten a single WIT type into core Wasm types.
pub fn flatten(reg : Registry, ty : ValType) -> Array[WasmType] raise AbiError {
  let sa = SizeAlign::fill(reg)
  let out : Array[WasmType] = []
  ignore(sa.push_flat(reg, ty, out, 64))
  out
}

///|
/// Core Wasm signature of a WIT function under `variant`.
pub fn wasm_signature(
  reg : Registry,
  func : Func,
  variant : AbiVariant,
) -> WasmSignature raise AbiError {
  let sa = SizeAlign::fill(reg)
  let params : Array[WasmType] = []
  let mut overflow = false
  for p in func.params {
    if !sa.push_flat(reg, p, params, MAX_FLAT_PARAMS + 1) {
      overflow = true
      break
    }
  }
  let max = MAX_FLAT_PARAMS
  let indirect = overflow || params.length() > max
  if indirect {
    params.clear()
    params.push(Pointer)
  } else if func.is_method && variant is GuestExport {
    if params.length() > 0 && params[0] is I32 {
      params[0] = Pointer
    }
  }
  let results : Array[WasmType] = []
  let mut retptr = false
  match func.result {
    None => ()
    Some(ty) => {
      let ok = sa.push_flat(reg, ty, results, MAX_FLAT_RESULTS)
      retptr = !ok
      if retptr {
        results.clear()
        match variant {
          GuestImport => params.push(Pointer)
          GuestExport => results.push(Pointer)
        }
      }
    }
  }
  { params, results, indirect_params: indirect, retptr, }
}

///|
/// Render a flattened type list as a compact string for CLI / snapshots.
pub fn wasm_types_to_string(types : Array[WasmType]) -> String {
  let mut s = ""
  for i, t in types {
    if i > 0 {
      s = s + " "
    }
    s = s + Show::to_string(t)
  }
  s
}
