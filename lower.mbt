///|
/// One core-Wasm load/store step produced by Canonical ABI lowering.
pub(all) enum LowerOp {
  LoadI32
  LoadI64
  LoadF32
  LoadF64
  LoadPointer
  LoadLength
  LoadTag(WasmType)
} derive(Eq, Debug)

///|
pub impl Show for LowerOp with fn to_string(self) {
  match self {
    LoadI32 => "i32"
    LoadI64 => "i64"
    LoadF32 => "f32"
    LoadF64 => "f64"
    LoadPointer => "pointer"
    LoadLength => "length"
    LoadTag(t) => "tag(" + Show::to_string(t) + ")"
  }
}

///|
/// A flattening step plus the memory offset it occupies in an indirect
/// parameter block (wasm32 bytes).
pub(all) struct LowerStep {
  op : LowerOp
  offset32 : Int
} derive(Eq, Debug)

///|
pub impl Show for LowerStep with fn to_string(self) {
  Show::to_string(self.op) + "@" + self.offset32.to_string()
}

///|
fn wasm_to_op(t : WasmType) -> LowerOp {
  match t {
    I32 => LoadI32
    I64 => LoadI64
    F32 => LoadF32
    F64 => LoadF64
    Pointer | PointerOrI64 => LoadPointer
    Length => LoadLength
  }
}

///|
fn core_size(t : WasmType) -> Int {
  match t {
    I64 | F64 | PointerOrI64 => 8
    I32 | F32 | Pointer | Length => 4
  }
}

///|
fn push_flats_as_steps(
  flats : Array[WasmType],
  start : Int,
  offset : Int,
  out : Array[LowerStep],
) -> Unit {
  let mut i = start
  let mut off = offset
  while i < flats.length() {
    let t = flats[i]
    out.push({ op: wasm_to_op(t), offset32: off, })
    off = off + core_size(t)
    i = i + 1
  }
}

///|
fn SizeAlign::lower_into(
  self : SizeAlign,
  reg : Registry,
  ty : ValType,
  offset : Int,
  out : Array[LowerStep],
) -> Int raise AbiError {
  match ty {
    Bool | S8 | U8 | S16 | U16 | S32 | U32 | Char | ErrorContext => {
      out.push({ op: LoadI32, offset32: offset, })
      offset + 4
    }
    U64 | S64 => {
      out.push({ op: LoadI64, offset32: offset, })
      offset + 8
    }
    F32 => {
      out.push({ op: LoadF32, offset32: offset, })
      offset + 4
    }
    F64 => {
      out.push({ op: LoadF64, offset32: offset, })
      offset + 8
    }
    String => {
      out.push({ op: LoadPointer, offset32: offset, })
      out.push({ op: LoadLength, offset32: offset + 4, })
      offset + 8
    }
    Named(id) => self.lower_named(reg, id, ty, offset, out)
  }
}

///|
fn SizeAlign::lower_named(
  self : SizeAlign,
  reg : Registry,
  id : Int,
  ty : ValType,
  offset : Int,
  out : Array[LowerStep],
) -> Int raise AbiError {
  match reg.get(id) {
    Alias(inner) => self.lower_into(reg, inner, offset, out)
    Handle | Future | Stream => {
      out.push({ op: LoadI32, offset32: offset, })
      offset + 4
    }
    Resource => raise InvalidType("raw resources are not part of the ABI")
    Record(fields) => {
      let mut cur = offset
      for f in fields {
        cur = align_to(cur, self.align(f.ty).align_wasm32())
        cur = self.lower_into(reg, f.ty, cur, out)
      }
      align_to(cur, self.align(ty).align_wasm32())
    }
    Tuple(ts) => {
      let mut cur = offset
      for t in ts {
        cur = align_to(cur, self.align(t).align_wasm32())
        cur = self.lower_into(reg, t, cur, out)
      }
      align_to(cur, self.align(ty).align_wasm32())
    }
    Flags(n) => {
      let count = flags_repr(n).count()
      let mut cur = offset
      for _ in 0..<count {
        out.push({ op: LoadI32, offset32: cur, })
        cur = cur + 4
      }
      cur
    }
    List(_) | Map(_, _) => {
      out.push({ op: LoadPointer, offset32: offset, })
      out.push({ op: LoadLength, offset32: offset + 4, })
      offset + 8
    }
    FixedList(inner, n) => {
      let mut cur = offset
      for _ in 0..<n {
        cur = self.lower_into(reg, inner, cur, out)
      }
      cur
    }
    Variant(cases) => {
      let tag = discriminant_type(cases.length())
      let tag_ty = match tag {
        U8 | U16 | U32 => WasmType::I32
        U64 => WasmType::I64
      }
      out.push({ op: LoadTag(tag_ty), offset32: offset, })
      let payloads : Array[ValType?] = []
      for c in cases {
        payloads.push(c.ty)
      }
      let payload_at = self.payload_offset(tag, payloads).size_wasm32()
      let flats = flatten(reg, ty)
      push_flats_as_steps(flats, 1, offset + payload_at, out)
      offset + self.size(ty).size_wasm32()
    }
    Enum(_) => {
      out.push({ op: LoadTag(WasmType::I32), offset32: offset, })
      offset + 4
    }
    Option(inner) => {
      out.push({ op: LoadTag(WasmType::I32), offset32: offset, })
      let payload_at = self.payload_offset(U8, [Some(inner)]).size_wasm32()
      let flats = flatten(reg, ty)
      push_flats_as_steps(flats, 1, offset + payload_at, out)
      offset + self.size(ty).size_wasm32()
    }
    Result(ok, err) => {
      out.push({ op: LoadTag(WasmType::I32), offset32: offset, })
      let payload_at = self.payload_offset(U8, [ok, err]).size_wasm32()
      let flats = flatten(reg, ty)
      push_flats_as_steps(flats, 1, offset + payload_at, out)
      offset + self.size(ty).size_wasm32()
    }
  }
}

///|
/// Lower a type into an ordered list of core loads with wasm32 offsets.
pub fn lower(reg : Registry, ty : ValType) -> Array[LowerStep] raise AbiError {
  let sa = SizeAlign::fill(reg)
  let out : Array[LowerStep] = []
  ignore(sa.lower_into(reg, ty, 0, out))
  out
}

///|
pub fn lower_to_string(steps : Array[LowerStep]) -> String {
  let mut s = ""
  for i, st in steps {
    if i > 0 {
      s = s + " "
    }
    s = s + Show::to_string(st)
  }
  s
}

///|
/// JSON object describing a type's Canonical ABI layout. Stable for snapshots.
pub fn layout_json(reg : Registry, ty : ValType) -> String raise AbiError {
  let info = layout(reg, ty)
  let flats = flatten(reg, ty)
  let steps = lower(reg, ty)
  let mut json = "{\"size32\":" +
    info.size.size_wasm32().to_string() +
    ",\"size64\":" +
    info.size.size_wasm64().to_string() +
    ",\"align32\":" +
    info.align.align_wasm32().to_string() +
    ",\"align64\":" +
    info.align.align_wasm64().to_string() +
    ",\"flat\":["
  for i, t in flats {
    if i > 0 {
      json = json + ","
    }
    json = json + "\"" + Show::to_string(t) + "\""
  }
  json = json + "],\"lower\":["
  for i, st in steps {
    if i > 0 {
      json = json + ","
    }
    json = json +
      "{\"op\":\"" +
      Show::to_string(st.op) +
      "\",\"offset32\":" +
      st.offset32.to_string() +
      "}"
  }
  json + "]}"
}
