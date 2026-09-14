///|
/// Public helpers for building a type registry without exposing internals.
pub fn named(id : Int) -> ValType {
  Named(id)
}

///|
pub fn record_type(reg : Registry, fields : Array[Field]) -> ValType {
  Named(reg.add(Record(fields)))
}

///|
pub fn tuple_type(reg : Registry, types : Array[ValType]) -> ValType {
  Named(reg.add(Tuple(types)))
}

///|
pub fn list_type(reg : Registry, elem : ValType) -> ValType {
  Named(reg.add(List(elem)))
}

///|
pub fn option_type(reg : Registry, inner : ValType) -> ValType {
  Named(reg.add(Option(inner)))
}

///|
pub fn result_type(reg : Registry, ok : ValType?, err : ValType?) -> ValType {
  Named(reg.add(Result(ok, err)))
}

///|
pub fn flags_type(reg : Registry, n : Int) -> ValType {
  Named(reg.add(Flags(n)))
}

///|
pub fn enum_type(reg : Registry, n : Int) -> ValType {
  Named(reg.add(Enum(n)))
}

///|
pub fn variant_type(reg : Registry, cases : Array[Case]) -> ValType {
  Named(reg.add(Variant(cases)))
}

///|
pub fn handle_type(reg : Registry) -> ValType {
  Named(reg.add(Handle))
}

///|
pub fn alias_type(reg : Registry, inner : ValType) -> ValType {
  Named(reg.add(Alias(inner)))
}

///|
pub fn format_layout(info : ElementInfo) -> String {
  "size32=\{info.size.size_wasm32()} size64=\{info.size.size_wasm64()} align32=\{info.align.align_wasm32()} align64=\{info.align.align_wasm64()} raw=\{info.size}"
}
