///|
/// A growable little-endian linear memory used to prove Canonical ABI offsets.
pub(all) struct GuestMem {
  bytes : Array[Byte]
}

///|
pub fn GuestMem::new(size : Int) -> GuestMem {
  let bytes : Array[Byte] = []
  for _ in 0..<size {
    bytes.push(b'\x00')
  }
  { bytes, }
}

///|
pub fn GuestMem::len(self : GuestMem) -> Int {
  self.bytes.length()
}

///|
fn GuestMem::ensure(self : GuestMem, offset : Int, n : Int) -> Unit {
  let need = offset + n
  while self.bytes.length() < need {
    self.bytes.push(b'\x00')
  }
}

///|
pub fn GuestMem::store_u8(self : GuestMem, offset : Int, value : Int) -> Unit {
  self.ensure(offset, 1)
  self.bytes[offset] = (value & 0xFF).to_byte()
}

///|
pub fn GuestMem::load_u8(self : GuestMem, offset : Int) -> Int {
  self.bytes[offset].to_int() & 0xFF
}

///|
pub fn GuestMem::store_i32(self : GuestMem, offset : Int, value : Int) -> Unit {
  self.ensure(offset, 4)
  self.store_u8(offset, value)
  self.store_u8(offset + 1, value >> 8)
  self.store_u8(offset + 2, value >> 16)
  self.store_u8(offset + 3, value >> 24)
}

///|
pub fn GuestMem::load_i32(self : GuestMem, offset : Int) -> Int {
  let b0 = self.load_u8(offset)
  let b1 = self.load_u8(offset + 1)
  let b2 = self.load_u8(offset + 2)
  let b3 = self.load_u8(offset + 3)
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
pub fn GuestMem::store_i64(
  self : GuestMem,
  offset : Int,
  value : Int64,
) -> Unit {
  self.store_i32(offset, value.to_int())
  self.store_i32(offset + 4, (value >> 32).to_int())
}

///|
pub fn GuestMem::load_i64(self : GuestMem, offset : Int) -> Int64 {
  let lo = self.load_i32(offset).to_int64() & 0xFFFFFFFFL
  let hi = self.load_i32(offset + 4).to_int64()
  lo | (hi << 32)
}

///|
pub fn GuestMem::store_bytes(
  self : GuestMem,
  offset : Int,
  data : Array[Byte],
) -> Unit {
  self.ensure(offset, data.length())
  for i, b in data {
    self.bytes[offset + i] = b
  }
}

///|
/// Store a Canonical ABI string pair (pointer, length) at `slot` and the
/// UTF-8-ish payload at `heap`.
pub fn GuestMem::store_string(
  self : GuestMem,
  slot : Int,
  heap : Int,
  text : String,
) -> Unit {
  let n = text.length()
  self.store_i32(slot, heap)
  self.store_i32(slot + 4, n)
  self.ensure(heap, n)
  for i in 0..<n {
    match text.get_char(i) {
      None => ()
      Some(ch) => self.store_u8(heap + i, ch.to_int())
    }
  }
}

///|
pub fn GuestMem::load_string(self : GuestMem, slot : Int) -> String {
  let heap = self.load_i32(slot)
  let n = self.load_i32(slot + 4)
  let mut s = ""
  for i in 0..<n {
    let c = self.load_u8(heap + i)
    s = s + c.unsafe_to_char().to_string()
  }
  s
}

///|
/// Write flattened i32 values into memory at each LowerStep offset.
pub fn GuestMem::store_steps(
  self : GuestMem,
  steps : Array[LowerStep],
  values : Array[Int],
) -> Unit {
  let n = if steps.length() < values.length() {
    steps.length()
  } else {
    values.length()
  }
  for i in 0..<n {
    let st = steps[i]
    match st.op {
      LoadI64 => self.store_i64(st.offset32, values[i].to_int64())
      _ => self.store_i32(st.offset32, values[i])
    }
  }
}

///|
pub fn GuestMem::load_steps(
  self : GuestMem,
  steps : Array[LowerStep],
) -> Array[Int] {
  let out : Array[Int] = []
  for st in steps {
    match st.op {
      LoadI64 => out.push(self.load_i64(st.offset32).to_int())
      _ => out.push(self.load_i32(st.offset32))
    }
  }
  out
}

///|
/// Round-trip i32 values through the Canonical ABI slots of `ty`.
pub fn roundtrip_i32s(
  reg : Registry,
  ty : ValType,
  values : Array[Int],
) -> Array[Int] raise AbiError {
  let steps = lower(reg, ty)
  let mem = GuestMem::new(64)
  mem.store_steps(steps, values)
  mem.load_steps(steps)
}
