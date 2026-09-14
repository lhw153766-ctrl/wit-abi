///|
/// Errors while parsing a compact WIT type expression such as `option<string>`.
pub(all) suberror TypeExprError {
  Unexpected(String)
}

///|
pub impl Show for TypeExprError with fn to_string(self) {
  match self {
    Unexpected(msg) => "type expression: \{msg}"
  }
}

///|
priv struct ExprParser {
  src : String
  mut i : Int
}

///|
fn ExprParser::new(src : String) -> ExprParser {
  { src, i: 0, }
}

///|
fn ExprParser::eof(self : ExprParser) -> Bool {
  self.i >= self.src.length()
}

///|
fn ExprParser::peek(self : ExprParser) -> Char? {
  self.src.get_char(self.i)
}

///|
fn ExprParser::bump(self : ExprParser) -> Unit {
  if !self.eof() {
    self.i = self.i + 1
  }
}

///|
fn ExprParser::skip(self : ExprParser) -> Unit {
  while self.peek() is Some(ch) &&
        (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
    self.bump()
  }
}

///|
fn ExprParser::expect(self : ExprParser, ch : Char) -> Unit raise TypeExprError {
  self.skip()
  match self.peek() {
    Some(c) =>
      if c == ch {
        self.bump()
      } else {
        raise Unexpected("expected '\{ch}', got '\{c}'")
      }
    None => raise Unexpected("expected '\{ch}', got end of input")
  }
}

///|
fn is_ident_start(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

///|
fn is_ident_cont(ch : Char) -> Bool {
  is_ident_start(ch) || (ch >= '0' && ch <= '9') || ch == '-'
}

///|
fn ExprParser::ident(self : ExprParser) -> String raise TypeExprError {
  self.skip()
  let start = self.i
  match self.peek() {
    Some(ch) =>
      if !is_ident_start(ch) {
        raise Unexpected("expected identifier")
      }
    None => raise Unexpected("expected identifier")
  }
  self.bump()
  while self.peek() is Some(ch) && is_ident_cont(ch) {
    self.bump()
  }
  self.src[start:self.i].to_owned()
}

///|
fn primitive_of(name : String) -> ValType? {
  match name {
    "bool" => Some(Bool)
    "u8" => Some(U8)
    "s8" => Some(S8)
    "u16" => Some(U16)
    "s16" => Some(S16)
    "u32" => Some(U32)
    "s32" => Some(S32)
    "u64" => Some(U64)
    "s64" => Some(S64)
    "f32" => Some(F32)
    "f64" => Some(F64)
    "char" => Some(Char)
    "string" => Some(String)
    "error-context" => Some(ErrorContext)
    _ => None
  }
}

///|
fn ExprParser::ty(
  self : ExprParser,
  reg : Registry,
) -> ValType raise TypeExprError {
  self.skip()
  if self.peek() is Some('(') {
    self.bump()
    let ts : Array[ValType] = []
    self.skip()
    if self.peek() is Some(')') {
      self.bump()
      return tuple_type(reg, ts)
    }
    ts.push(self.ty(reg))
    self.skip()
    while self.peek() is Some(',') {
      self.bump()
      ts.push(self.ty(reg))
      self.skip()
    }
    self.expect(')')
    return tuple_type(reg, ts)
  }
  let name = self.ident()
  match primitive_of(name) {
    Some(p) => p
    None =>
      match name {
        "list" => {
          self.expect('<')
          let inner = self.ty(reg)
          self.expect('>')
          list_type(reg, inner)
        }
        "option" => {
          self.expect('<')
          let inner = self.ty(reg)
          self.expect('>')
          option_type(reg, inner)
        }
        "result" => {
          self.expect('<')
          let ok = self.ty(reg)
          self.expect(',')
          let err = self.ty(reg)
          self.expect('>')
          result_type(reg, Some(ok), Some(err))
        }
        "handle" => handle_type(reg)
        "future" => Named(reg.add(Future))
        "stream" => Named(reg.add(Stream))
        other => raise Unexpected("unknown type '\{other}'")
      }
  }
}

///|
/// Parse a compact type expression into a registry + type.
///
/// Examples: `u32`, `option<string>`, `list<u8>`, `result<u32, f64>`, `(u8, u32)`.
pub fn parse_type_expr(src : String) -> (Registry, ValType) raise TypeExprError {
  let reg = Registry::new()
  let p = ExprParser::new(src)
  let ty = p.ty(reg)
  p.skip()
  if !p.eof() {
    raise Unexpected("trailing input")
  }
  (reg, ty)
}
