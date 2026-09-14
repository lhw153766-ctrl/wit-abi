///|
/// Architecture-specific alignment. Pointer is 4 bytes on wasm32 and 8 on wasm64.
pub(all) enum Alignment {
  Pointer
  Bytes(Int)
} derive(Eq, Debug)

///|
pub impl Show for Alignment with fn to_string(self) {
  match self {
    Pointer => "ptr"
    Bytes(b) => b.to_string()
  }
}

///|
pub impl Compare for Alignment with fn compare(self, other) {
  match (self, other) {
    (Pointer, Pointer) => 0
    (Pointer, Bytes(b)) => if b > 4 { -1 } else { 1 }
    (Bytes(b), Pointer) => if b > 4 { 1 } else { -1 }
    (Bytes(a), Bytes(b)) => a.compare(b)
  }
}

///|
pub fn Alignment::align_wasm32(self : Alignment) -> Int {
  match self {
    Pointer => 4
    Bytes(b) => b
  }
}

///|
pub fn Alignment::align_wasm64(self : Alignment) -> Int {
  match self {
    Pointer => 8
    Bytes(b) => b
  }
}

///|
/// Architecture-independent size: `bytes + pointers * sizeof(pointer)`.
pub(all) struct ArchSize {
  bytes : Int
  pointers : Int
} derive(Eq, Debug)

///|
pub fn ArchSize::new(bytes : Int, pointers : Int) -> ArchSize {
  { bytes, pointers, }
}

///|
pub fn ArchSize::zero() -> ArchSize {
  { bytes: 0, pointers: 0, }
}

///|
pub fn ArchSize::is_empty(self : ArchSize) -> Bool {
  self.bytes == 0 && self.pointers == 0
}

///|
pub fn ArchSize::size_wasm32(self : ArchSize) -> Int {
  self.bytes + self.pointers * 4
}

///|
pub fn ArchSize::size_wasm64(self : ArchSize) -> Int {
  self.bytes + self.pointers * 8
}

///|
pub fn ArchSize::add(self : ArchSize, other : ArchSize) -> ArchSize {
  { bytes: self.bytes + other.bytes, pointers: self.pointers + other.pointers, }
}

///|
pub fn ArchSize::add_bytes(self : ArchSize, b : Int) -> ArchSize {
  { bytes: self.bytes + b, pointers: self.pointers, }
}

///|
pub impl Show for ArchSize with fn to_string(self) {
  if self.pointers == 0 {
    self.bytes.to_string()
  } else if self.bytes == 0 {
    if self.pointers == 1 {
      "ptrsz"
    } else {
      "\{self.pointers}*ptrsz"
    }
  } else {
    "\{self.bytes}+\{self.pointers}*ptrsz"
  }
}

///|
/// Increase `val` to a multiple of `align`. `align` must be a power of two.
pub fn align_to(val : Int, align : Int) -> Int {
  (val + align - 1) & (align - 1).lnot()
}

///|
/// Increase an architecture size to a multiple of `align`.
/// Port of `wit-parser::sizealign::align_to_arch`.
pub fn align_to_arch(val : ArchSize, align : Alignment) -> ArchSize {
  match align {
    Pointer => {
      let new32 = align_to(val.bytes, 4)
      if new32 != align_to(new32, 8) {
        { bytes: new32 - 4, pointers: val.pointers + 1, }
      } else {
        { bytes: new32, pointers: val.pointers, }
      }
    }
    Bytes(align_bytes) =>
      if align_bytes > 4 && (val.pointers & 1) != 0 {
        let new_bytes = align_to(val.bytes, align_bytes)
        if new_bytes - val.bytes >= 4 {
          { bytes: new_bytes - 8, pointers: val.pointers + 1, }
        } else {
          { bytes: new_bytes + 8, pointers: val.pointers - 1, }
        }
      } else {
        { bytes: align_to(val.bytes, align_bytes), pointers: val.pointers, }
      }
  }
}

///|
pub fn Alignment::to_size(self : Alignment) -> ArchSize {
  match self {
    Bytes(b) => { bytes: b, pointers: 0, }
    Pointer => { bytes: 0, pointers: 1, }
  }
}

///|
/// Max of two architecture sizes, matching `ArchitectureSize::max`.
pub fn ArchSize::max(self : ArchSize, other : ArchSize) -> ArchSize {
  let self32 = self.size_wasm32()
  let self64 = self.size_wasm64()
  let other32 = other.size_wasm32()
  let other64 = other.size_wasm64()
  if self32 >= other32 && self64 >= other64 {
    self
  } else if self32 <= other32 && self64 <= other64 {
    other
  } else {
    let new32 = align_to(if self32 > other32 { self32 } else { other32 }, 4)
    let new64 = align_to(if self64 > other64 { self64 } else { other64 }, 8)
    { bytes: new32 + new32 - new64, pointers: (new64 - new32) / 4, }
  }
}

///|
pub fn Alignment::max(self : Alignment, other : Alignment) -> Alignment {
  if Compare::compare(self, other) >= 0 {
    self
  } else {
    other
  }
}
