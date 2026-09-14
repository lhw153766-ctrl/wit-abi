///|
/// Primitive and named WIT value types used by the Canonical ABI.
pub(all) enum ValType {
  Bool
  U8
  S8
  U16
  S16
  U32
  S32
  U64
  S64
  F32
  F64
  Char
  String
  ErrorContext
  Named(Int)
} derive(Eq, Debug)

///|
pub impl Show for ValType with fn to_string(self) {
  match self {
    Bool => "bool"
    U8 => "u8"
    S8 => "s8"
    U16 => "u16"
    S16 => "s16"
    U32 => "u32"
    S32 => "s32"
    U64 => "u64"
    S64 => "s64"
    F32 => "f32"
    F64 => "f64"
    Char => "char"
    String => "string"
    ErrorContext => "error-context"
    Named(id) => "type#\{id}"
  }
}

///|
/// A named field inside a record.
pub(all) struct Field {
  name : String
  ty : ValType
} derive(Eq, Debug)

///|
pub fn Field::new(name : String, ty : ValType) -> Field {
  { name, ty, }
}

///|
/// A variant case; payload is optional.
pub(all) struct Case {
  name : String
  ty : ValType?
} derive(Eq, Debug)

///|
pub fn Case::new(name : String, ty : ValType?) -> Case {
  { name, ty, }
}

///|
/// Discriminant integer used for enums, variants, option and result.
pub(all) enum DiscInt {
  U8
  U16
  U32
  U64
} derive(Eq, Debug)

///|
pub impl Show for DiscInt with fn to_string(self) {
  match self {
    U8 => "u8"
    U16 => "u16"
    U32 => "u32"
    U64 => "u64"
  }
}

///|
/// Flags representation from the Canonical ABI.
pub(all) enum FlagsRepr {
  U8
  U16
  U32(Int)
} derive(Eq, Debug)

///|
pub impl Show for FlagsRepr with fn to_string(self) {
  match self {
    U8 => "u8"
    U16 => "u16"
    U32(n) => "u32x\{n}"
  }
}

///|
/// Named type definition stored in a `Registry`.
pub(all) enum TypeDef {
  Alias(ValType)
  List(ValType)
  Map(ValType, ValType)
  FixedList(ValType, Int)
  Record(Array[Field])
  Tuple(Array[ValType])
  Flags(Int)
  Variant(Array[Case])
  Enum(Int)
  Option(ValType)
  Result(ValType?, ValType?)
  Handle
  Future
  Stream
  Resource
} derive(Eq, Debug)

///|
pub impl Show for TypeDef with fn to_string(self) {
  match self {
    Alias(t) => "type \{t}"
    List(t) => "list<\{t}>"
    Map(k, v) => "map<\{k}, \{v}>"
    FixedList(t, n) => "list<\{t}, \{n}>"
    Record(fields) => "record(\{fields.length()})"
    Tuple(ts) => "tuple(\{ts.length()})"
    Flags(n) => "flags(\{n})"
    Variant(cs) => "variant(\{cs.length()})"
    Enum(n) => "enum(\{n})"
    Option(t) => "option<\{t}>"
    Result(ok, err) => {
      let o = match ok {
        None => "_"
        Some(t) => Show::to_string(t)
      }
      let e = match err {
        None => "_"
        Some(t) => Show::to_string(t)
      }
      "result<\{o}, \{e}>"
    }
    Handle => "handle"
    Future => "future"
    Stream => "stream"
    Resource => "resource"
  }
}

///|
/// A WIT function viewed from the Canonical ABI.
pub(all) struct Func {
  params : Array[ValType]
  result : ValType?
  is_method : Bool
} derive(Eq, Debug)

///|
pub fn Func::new(
  params : Array[ValType],
  result : ValType?,
  is_method? : Bool = false,
) -> Func {
  { params, result, is_method, }
}

///|
/// Guest import vs guest export ABI flavour (sync only).
pub(all) enum AbiVariant {
  GuestImport
  GuestExport
} derive(Eq, Debug)

///|
/// Ordered list of named type definitions. `ValType::Named(i)` indexes this list.
pub(all) struct Registry {
  types : Array[TypeDef]
}

///|
pub fn Registry::new() -> Registry {
  { types: [], }
}

///|
/// Append a definition and return its `Named` index.
pub fn Registry::add(self : Registry, def : TypeDef) -> Int {
  let id = self.types.length()
  self.types.push(def)
  id
}

///|
pub fn Registry::get(self : Registry, id : Int) -> TypeDef raise AbiError {
  if id < 0 || id >= self.types.length() {
    raise UnknownNamed(id)
  }
  self.types[id]
}

///|
/// Discriminant integer for `n` cases. Matches `wit-parser::discriminant_type`.
pub fn discriminant_type(num_cases : Int) -> DiscInt {
  if num_cases <= 0 || num_cases - 1 <= 255 {
    U8
  } else if num_cases - 1 <= 65535 {
    U16
  } else {
    U32
  }
}

///|
/// Flags representation for `n` flag bits. Matches `wit-parser::Flags::repr`.
pub fn flags_repr(n : Int) -> FlagsRepr {
  if n <= 0 {
    U32(0)
  } else if n <= 8 {
    U8
  } else if n <= 16 {
    U16
  } else {
    U32(align_to(n, 32) / 32)
  }
}

///|
pub fn FlagsRepr::count(self : FlagsRepr) -> Int {
  match self {
    U8 => 1
    U16 => 1
    U32(n) => n
  }
}

///|
pub fn DiscInt::to_valtype(self : DiscInt) -> ValType {
  match self {
    U8 => U8
    U16 => U16
    U32 => U32
    U64 => U64
  }
}
