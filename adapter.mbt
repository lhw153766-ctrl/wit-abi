///|
/// A named WIT function extracted from a compact interface document.
pub(all) struct IfaceFunc {
  name : String
  params : Array[ValType]
  result : ValType?
} derive(Eq, Debug)

///|
/// A compact WIT document: optional package, types, functions, worlds.
pub(all) struct IfaceDoc {
  package_name : String?
  types : Array[(String, ValType)]
  funcs : Array[IfaceFunc]
  worlds : Array[String]
}

///|
pub fn IfaceDoc::empty() -> IfaceDoc {
  { package_name: None, types: [], funcs: [], worlds: [], }
}

///|
/// Parse a compact WIT-ish interface document into a Registry plus declarations.
///
/// Supported surface (intentionally small):
///
/// ```text
/// package ns:name;
///
/// interface greet {
///   type id = u32;
///   greet: func(name: string) -> string;
/// }
///
/// world hello {
///   export greet;
/// }
/// ```
pub fn parse_interface(
  src : String,
) -> (Registry, IfaceDoc) raise TypeExprError {
  let p = ExprParser::new(src)
  let reg = Registry::new()
  let mut package_name : String? = None
  let types : Array[(String, ValType)] = []
  let funcs : Array[IfaceFunc] = []
  let worlds : Array[String] = []
  p.skip()
  while !p.eof() {
    let kw = p.ident()
    match kw {
      "package" => {
        package_name = Some(p.parse_package_name())
        p.expect(';')
      }
      "interface" => {
        ignore(p.ident())
        p.expect('{')
        p.skip()
        while !(p.peek() is Some('}')) {
          p.parse_iface_item(reg, types, funcs)
          p.skip()
          if p.eof() {
            raise Unexpected("unterminated interface")
          }
        }
        p.expect('}')
      }
      "world" => {
        let wname = p.ident()
        worlds.push(wname)
        p.expect('{')
        p.skip_balanced('}')
      }
      other => raise Unexpected("unexpected top-level '" + other + "'")
    }
    p.skip()
  }
  (reg, { package_name, types, funcs, worlds, })
}

///|
fn ExprParser::parse_package_name(
  self : ExprParser,
) -> String raise TypeExprError {
  let a = self.ident()
  self.expect(':')
  let b = self.ident()
  a + ":" + b
}

///|
fn ExprParser::skip_balanced(
  self : ExprParser,
  closer : Char,
) -> Unit raise TypeExprError {
  let mut depth = 1
  while !self.eof() && depth > 0 {
    match self.peek() {
      None => raise Unexpected("unterminated block")
      Some(ch) => {
        if ch == '{' {
          depth = depth + 1
        } else if ch == closer {
          depth = depth - 1
        }
        self.bump()
      }
    }
  }
}

///|
fn ExprParser::parse_iface_item(
  self : ExprParser,
  reg : Registry,
  types : Array[(String, ValType)],
  funcs : Array[IfaceFunc],
) -> Unit raise TypeExprError {
  self.skip()
  let name = self.ident()
  if name == "type" {
    let tname = self.ident()
    self.expect('=')
    let ty = self.ty(reg)
    self.expect(';')
    types.push((tname, ty))
    return
  }
  self.skip()
  if self.peek() is Some(':') {
    self.bump()
    self.skip()
    let kw = self.ident()
    if kw != "func" {
      raise Unexpected("expected func")
    }
    let (params, result) = self.parse_func_sig(reg)
    self.expect(';')
    funcs.push({ name, params, result, })
    return
  }
  raise Unexpected("expected type or func item")
}

///|
fn ExprParser::parse_func_sig(
  self : ExprParser,
  reg : Registry,
) -> (Array[ValType], ValType?) raise TypeExprError {
  self.expect('(')
  let params : Array[ValType] = []
  self.skip()
  if !(self.peek() is Some(')')) {
    ignore(self.ident())
    self.expect(':')
    params.push(self.ty(reg))
    self.skip()
    while self.peek() is Some(',') {
      self.bump()
      ignore(self.ident())
      self.expect(':')
      params.push(self.ty(reg))
      self.skip()
    }
  }
  self.expect(')')
  self.skip()
  let result : ValType? = if self.peek() is Some('-') {
    self.bump()
    self.expect('>')
    Some(self.ty(reg))
  } else {
    None
  }
  (params, result)
}

///|
/// Print ABI cards for every function in a parsed interface.
pub fn interface_report(
  reg : Registry,
  doc : IfaceDoc,
) -> String raise AbiError {
  let mut s = ""
  match doc.package_name {
    None => ()
    Some(n) => s = s + "package " + n + "\n"
  }
  for pair in doc.types {
    let (name, ty) = pair
    s = s + abi_card(reg, ty, name)
  }
  for f in doc.funcs {
    let func = Func::new(f.params, f.result)
    s = s + func_card(reg, func, f.name)
    s = s + "\n"
  }
  for w in doc.worlds {
    s = s + "world " + w + "\n"
  }
  s
}

///|
/// JSON array of function signatures (export flavour).
pub fn interface_json(reg : Registry, doc : IfaceDoc) -> String raise AbiError {
  let mut s = "{\"funcs\":["
  for i, f in doc.funcs {
    if i > 0 {
      s = s + ","
    }
    let func = Func::new(f.params, f.result)
    let sig = wasm_signature(reg, func, GuestExport)
    s = s +
      "{\"name\":\"" +
      f.name +
      "\",\"export\":\"" +
      Show::to_string(sig) +
      "\"}"
  }
  s + "]}"
}
