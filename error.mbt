///|
/// Errors produced while measuring a WIT type under the Canonical ABI.
pub(all) suberror AbiError {
  Overflow(String)
  InvalidType(String)
  UnknownNamed(Int)
}

///|

///|
pub impl Show for AbiError with fn to_string(self) {
  AbiError::to_string(self)
}

///|
pub fn AbiError::to_string(self : AbiError) -> String {
  match self {
    Overflow(msg) => "overflow: \{msg}"
    InvalidType(msg) => "invalid type: \{msg}"
    UnknownNamed(id) => "unknown named type #\{id}"
  }
}
