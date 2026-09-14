///|
/// Layout of one type: architecture-independent size plus alignment.
pub(all) struct ElementInfo {
  size : ArchSize
  align : Alignment
} derive(Eq)

///|
pub fn ElementInfo::new(size : ArchSize, align : Alignment) -> ElementInfo {
  { size, align, }
}

///|
pub fn ElementInfo::from_align(align : Alignment) -> ElementInfo {
  { size: align.to_size(), align, }
}

///|
pub impl Show for ElementInfo with fn to_string(self) {
  "size=\{self.size} align=\{self.align}"
}

///|
fn int_size_align(i : DiscInt) -> ElementInfo {
  match i {
    U8 => ElementInfo::from_align(Bytes(1))
    U16 => ElementInfo::from_align(Bytes(2))
    U32 => ElementInfo::from_align(Bytes(4))
    U64 => ElementInfo::from_align(Bytes(8))
  }
}

///|
/// Cached layout table for a `Registry`.
pub(all) struct SizeAlign {
  map : Array[ElementInfo]
}

///|
pub fn SizeAlign::fill(reg : Registry) -> SizeAlign raise AbiError {
  let map : Array[ElementInfo] = []
  let sa = { map, }
  for i in 0..<reg.types.length() {
    let info = sa.calculate(reg, reg.types[i])
    sa.map.push(info)
  }
  sa
}

///|
fn SizeAlign::calculate(
  self : SizeAlign,
  _reg : Registry,
  def : TypeDef,
) -> ElementInfo raise AbiError {
  match def {
    Alias(t) => ElementInfo::new(self.size(t), self.align(t))
    FixedList(t, n) => {
      if n < 0 {
        raise Overflow("negative fixed-list length")
      }
      let field_align = self.align(t)
      let field_size = self.size(t)
      let bytes = field_size.bytes * n
      let pointers = field_size.pointers * n
      if n != 0 &&
        (bytes / n != field_size.bytes || pointers / n != field_size.pointers) {
        raise Overflow(
          "size of fixed-length list of \{n} elements overflows the target architecture's address space",
        )
      }
      ElementInfo::new(ArchSize::new(bytes, pointers), field_align)
    }
    List(_) => ElementInfo::new(ArchSize::new(0, 2), Pointer)
    Map(_, _) => ElementInfo::new(ArchSize::new(0, 2), Pointer)
    Record(fields) => {
      let tys : Array[ValType] = []
      for f in fields {
        tys.push(f.ty)
      }
      self.record(tys)
    }
    Tuple(ts) => self.record(ts)
    Flags(n) =>
      match flags_repr(n) {
        U8 => int_size_align(U8)
        U16 => int_size_align(U16)
        U32(k) => ElementInfo::new(ArchSize::new(k * 4, 0), Bytes(4))
      }
    Variant(cases) => {
      let payloads : Array[ValType?] = []
      for c in cases {
        payloads.push(c.ty)
      }
      self.variant(discriminant_type(cases.length()), payloads)
    }
    Enum(n) => {
      let empty : Array[ValType?] = []
      self.variant(discriminant_type(n), empty)
    }
    Option(t) => self.variant(U8, [Some(t)])
    Result(ok, err) => self.variant(U8, [ok, err])
    Handle | Future | Stream => int_size_align(U32)
    Resource =>
      ElementInfo::new(ArchSize::new(2147483647, 0), Bytes(2147483647))
  }
}

///|
pub fn SizeAlign::size(self : SizeAlign, ty : ValType) -> ArchSize {
  match ty {
    Bool | U8 | S8 => ArchSize::new(1, 0)
    U16 | S16 => ArchSize::new(2, 0)
    U32 | S32 | F32 | Char | ErrorContext => ArchSize::new(4, 0)
    U64 | S64 | F64 => ArchSize::new(8, 0)
    String => ArchSize::new(0, 2)
    Named(id) => self.map[id].size
  }
}

///|
pub fn SizeAlign::align(self : SizeAlign, ty : ValType) -> Alignment {
  match ty {
    Bool | U8 | S8 => Bytes(1)
    U16 | S16 => Bytes(2)
    U32 | S32 | F32 | Char | ErrorContext => Bytes(4)
    U64 | S64 | F64 => Bytes(8)
    String => Pointer
    Named(id) => self.map[id].align
  }
}

///|
pub fn SizeAlign::record(
  self : SizeAlign,
  types : Array[ValType],
) -> ElementInfo {
  let mut size = ArchSize::zero()
  let mut align = Bytes(1)
  for ty in types {
    let field_size = self.size(ty)
    let field_align = self.align(ty)
    size = align_to_arch(size, field_align).add(field_size)
    align = align.max(field_align)
  }
  ElementInfo::new(align_to_arch(size, align), align)
}

///|
fn SizeAlign::variant(
  self : SizeAlign,
  tag : DiscInt,
  types : Array[ValType?],
) -> ElementInfo {
  let disc = int_size_align(tag)
  let mut case_size = ArchSize::zero()
  let mut case_align = Bytes(1)
  for ty in types {
    match ty {
      None => ()
      Some(t) => {
        case_size = case_size.max(self.size(t))
        case_align = case_align.max(self.align(t))
      }
    }
  }
  let align = disc.align.max(case_align)
  let discrim_aligned = align_to_arch(disc.size, case_align)
  let size_sum = discrim_aligned.add(case_size)
  ElementInfo::new(align_to_arch(size_sum, align), align)
}

///|
/// Field offsets for a record/tuple, matching `SizeAlign::field_offsets`.
pub fn SizeAlign::field_offsets(
  self : SizeAlign,
  types : Array[ValType],
) -> Array[ArchSize] {
  let mut cur = ArchSize::zero()
  let out : Array[ArchSize] = []
  for ty in types {
    let ret = align_to_arch(cur, self.align(ty))
    cur = ret.add(self.size(ty))
    out.push(ret)
  }
  out
}

///|
/// Payload offset after a variant discriminant.
pub fn SizeAlign::payload_offset(
  self : SizeAlign,
  tag : DiscInt,
  cases : Array[ValType?],
) -> ArchSize {
  let mut max_align = Bytes(1)
  for ty in cases {
    match ty {
      None => ()
      Some(t) => max_align = max_align.max(self.align(t))
    }
  }
  let tag_size = int_size_align(tag).size
  align_to_arch(tag_size, max_align)
}

///|
/// Convenience: layout of a single (possibly named) type.
pub fn layout(reg : Registry, ty : ValType) -> ElementInfo raise AbiError {
  let sa = SizeAlign::fill(reg)
  ElementInfo::new(sa.size(ty), sa.align(ty))
}

///|
pub fn size32(reg : Registry, ty : ValType) -> Int raise AbiError {
  layout(reg, ty).size.size_wasm32()
}

///|
pub fn align32(reg : Registry, ty : ValType) -> Int raise AbiError {
  layout(reg, ty).align.align_wasm32()
}
