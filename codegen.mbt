///|
/// Emit MoonBit source that lifts and lowers a Canonical ABI value.
///
/// The generated functions are *glue sketches*: they assume a linear memory
/// accessor `load_i32(ptr)`, `store_i32(ptr, v)`, `load_i64`, `store_i64`,
/// `load_f32`, `store_f32`, `load_f64`, `store_f64`. Bindgen authors replace
/// those names with their runtime. Offsets come from `lower()`.
pub fn emit_moonbit_glue(reg : Registry, ty : ValType) -> String raise AbiError {
  emit_named_glue(reg, ty, "value")
}

///|
pub fn emit_named_glue(
  reg : Registry,
  ty : ValType,
  name : String,
) -> String raise AbiError {
  let info = layout(reg, ty)
  let flats = flatten(reg, ty)
  let steps = lower(reg, ty)
  let ident = sanitize_ident(name)
  let mut s = ""
  s = s + "/// Canonical ABI glue for `" + Show::to_string(ty) + "`\n"
  s = s + "/// size32=" + info.size.size_wasm32().to_string()
  s = s + " align32=" + info.align.align_wasm32().to_string() + "\n"
  s = s + "/// flat=[" + wasm_types_to_string(flats) + "]\n"
  s = s + "/// lower=[" + lower_to_string(steps) + "]\n\n"
  s = s + emit_lift_fn(ident, ty, steps)
  s = s + "\n"
  s = s + emit_lower_fn(ident, ty, steps)
  s
}

///|
fn sanitize_ident(name : String) -> String {
  if name.length() == 0 {
    "value"
  } else {
    let mut out = ""
    for i in 0..<name.length() {
      match name.get_char(i) {
        None => ()
        Some(ch) =>
          if (ch >= 'a' && ch <= 'z') ||
            (ch >= 'A' && ch <= 'Z') ||
            (ch >= '0' && ch <= '9') ||
            ch == '_' {
            out = out + ch.to_string()
          } else {
            out = out + "_"
          }
      }
    }
    if out.length() == 0 {
      "value"
    } else {
      out
    }
  }
}

///|
fn moonbit_result_type(ty : ValType) -> String {
  match ty {
    Bool => "Bool"
    U8 | S8 | U16 | S16 | U32 | S32 | Char | ErrorContext => "Int"
    U64 | S64 => "Int64"
    F32 | F64 => "Double"
    String => "(Int, Int)"
    Named(_) => "Int"
  }
}

///|
fn emit_lift_fn(
  ident : String,
  ty : ValType,
  steps : Array[LowerStep],
) -> String {
  let ret = moonbit_result_type(ty)
  let mut s = "pub fn lift_" + ident + "(ptr : Int) -> " + ret + " {\n"
  if steps.length() == 0 {
    s = s + "  ignore(ptr)\n"
    s = s + "  0\n"
  } else {
    for i, st in steps {
      s = s + "  let v" + i.to_string() + " = " + load_call(st) + "\n"
    }
    s = s + "  ignore(v0)\n"
    match ty {
      String =>
        if steps.length() >= 2 {
          s = s + "  (v0, v1)\n"
        } else {
          s = s + "  (v0, 0)\n"
        }
      F32 | F64 => s = s + "  v0\n"
      U64 | S64 => s = s + "  v0\n"
      _ => s = s + "  v0\n"
    }
  }
  s + "}\n"
}

///|
fn emit_lower_fn(
  ident : String,
  ty : ValType,
  steps : Array[LowerStep],
) -> String {
  let arg = moonbit_result_type(ty)
  let mut s = "pub fn lower_" +
    ident +
    "(ptr : Int, value : " +
    arg +
    ") -> Unit {\n"
  if steps.length() == 0 {
    s = s + "  ignore(ptr)\n"
    s = s + "  ignore(value)\n"
  } else {
    s = s + "  ignore(value)\n"
    for i, st in steps {
      let zero = match st.op {
        LoadI64 | LoadF64 => "0L"
        LoadF32 => "0.0"
        _ => "0"
      }
      s = s + "  let v" + i.to_string() + " = " + zero + "\n"
      s = s + "  " + store_call(st, "v" + i.to_string()) + "\n"
    }
  }
  s + "}\n"
}

///|
fn load_call(st : LowerStep) -> String {
  let p = "ptr + " + st.offset32.to_string()
  match st.op {
    LoadI32 | LoadTag(_) => "load_i32(" + p + ")"
    LoadI64 => "load_i64(" + p + ")"
    LoadF32 => "load_f32(" + p + ")"
    LoadF64 => "load_f64(" + p + ")"
    LoadPointer | LoadLength => "load_i32(" + p + ")"
  }
}

///|
fn store_call(st : LowerStep, var_name : String) -> String {
  let p = "ptr + " + st.offset32.to_string()
  match st.op {
    LoadI32 | LoadTag(_) => "store_i32(" + p + ", " + var_name + ")"
    LoadI64 => "store_i64(" + p + ", " + var_name + ")"
    LoadF32 => "store_f32(" + p + ", " + var_name + ")"
    LoadF64 => "store_f64(" + p + ", " + var_name + ")"
    LoadPointer | LoadLength => "store_i32(" + p + ", " + var_name + ")"
  }
}

///|
/// Glue for a WIT function: comment block with the wasm signature plus
/// lift/lower helpers for every parameter and the result.
pub fn emit_func_glue(
  reg : Registry,
  func : Func,
  name : String,
) -> String raise AbiError {
  let sig = wasm_signature(reg, func, GuestExport)
  let ident = sanitize_ident(name)
  let mut s = "/// function `" +
    ident +
    "` wasm signature: " +
    Show::to_string(sig) +
    "\n"
  s = s + "/// indirect_params=" + sig.indirect_params.to_string()
  s = s + " retptr=" + sig.retptr.to_string() + "\n\n"
  let mut i = 0
  for p in func.params {
    s = s + emit_named_glue(reg, p, ident + "_arg" + i.to_string())
    s = s + "\n"
    i = i + 1
  }
  match func.result {
    None => ()
    Some(r) => s = s + emit_named_glue(reg, r, ident + "_ret")
  }
  s
}

///|
/// Report one type as a multi-line ABI card.
pub fn abi_card(
  reg : Registry,
  ty : ValType,
  name : String,
) -> String raise AbiError {
  let info = layout(reg, ty)
  let flats = flatten(reg, ty)
  let steps = lower(reg, ty)
  let mut s = "type " + name + " : " + Show::to_string(ty) + "\n"
  s = s + "  size32   " + info.size.size_wasm32().to_string() + "\n"
  s = s + "  size64   " + info.size.size_wasm64().to_string() + "\n"
  s = s + "  align32  " + info.align.align_wasm32().to_string() + "\n"
  s = s + "  align64  " + info.align.align_wasm64().to_string() + "\n"
  s = s + "  flat     " + wasm_types_to_string(flats) + "\n"
  s = s + "  lower    " + lower_to_string(steps) + "\n"
  s
}

///|
/// Report a function as a multi-line ABI card.
pub fn func_card(
  reg : Registry,
  func : Func,
  name : String,
) -> String raise AbiError {
  let sig_ex = wasm_signature(reg, func, GuestExport)
  let sig_im = wasm_signature(reg, func, GuestImport)
  let mut s = "func " + name + "\n"
  s = s + "  export  " + Show::to_string(sig_ex) + "\n"
  s = s + "  import  " + Show::to_string(sig_im) + "\n"
  let mut i = 0
  for p in func.params {
    s = s + "  arg" + i.to_string() + "   " + Show::to_string(p)
    s = s + " size32=" + size32(reg, p).to_string() + "\n"
    i = i + 1
  }
  match func.result {
    None => s = s + "  result  (none)\n"
    Some(r) =>
      s = s +
        "  result  " +
        Show::to_string(r) +
        " size32=" +
        size32(reg, r).to_string() +
        "\n"
  }
  s
}
