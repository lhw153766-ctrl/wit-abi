///|
/// Errors while importing a layout JSON document.
pub(all) suberror JsonAstError {
  BadJson(String)
  Missing(String)
}

///|
pub impl Show for JsonAstError with fn to_string(self) {
  match self {
    BadJson(s) => "json: \{s}"
    Missing(s) => "missing \{s}"
  }
}

///|
fn json_string(j : Json) -> String raise JsonAstError {
  match j {
    String(s) => s
    _ => raise BadJson("expected string")
  }
}

///|
fn json_array(j : Json) -> Array[Json] raise JsonAstError {
  match j {
    Array(a) => a
    _ => raise BadJson("expected array")
  }
}

///|
fn json_object(j : Json) -> Map[String, Json] raise JsonAstError {
  match j {
    Object(m) => m
    _ => raise BadJson("expected object")
  }
}

///|
fn json_field(obj : Map[String, Json], key : String) -> Json raise JsonAstError {
  match obj.get(key) {
    None => raise Missing(key)
    Some(v) => v
  }
}

///|
fn parse_expr_into(
  reg : Registry,
  expr : String,
) -> ValType raise TypeExprError {
  let (tmp, ty) = parse_type_expr(expr)
  rebase_type(tmp, reg, ty)
}

///|
fn rebase_type(src : Registry, dst : Registry, ty : ValType) -> ValType {
  match ty {
    Named(id) => {
      let def = match src.types.get(id) {
        None => Alias(U32)
        Some(d) => rebase_def(src, dst, d)
      }
      Named(dst.add(def))
    }
    other => other
  }
}

///|
fn rebase_def(src : Registry, dst : Registry, def : TypeDef) -> TypeDef {
  match def {
    Alias(t) => Alias(rebase_type(src, dst, t))
    List(t) => List(rebase_type(src, dst, t))
    Map(k, v) => Map(rebase_type(src, dst, k), rebase_type(src, dst, v))
    FixedList(t, n) => FixedList(rebase_type(src, dst, t), n)
    Record(fs) => {
      let out : Array[Field] = []
      for f in fs {
        out.push(Field::new(f.name, rebase_type(src, dst, f.ty)))
      }
      Record(out)
    }
    Tuple(ts) => {
      let out : Array[ValType] = []
      for t in ts {
        out.push(rebase_type(src, dst, t))
      }
      Tuple(out)
    }
    Flags(n) => Flags(n)
    Variant(cs) => {
      let out : Array[Case] = []
      for c in cs {
        let payload = match c.ty {
          None => None
          Some(t) => Some(rebase_type(src, dst, t))
        }
        out.push(Case::new(c.name, payload))
      }
      Variant(out)
    }
    Enum(n) => Enum(n)
    Option(t) => Option(rebase_type(src, dst, t))
    Result(ok, err) => {
      let o = match ok {
        None => None
        Some(t) => Some(rebase_type(src, dst, t))
      }
      let e = match err {
        None => None
        Some(t) => Some(rebase_type(src, dst, t))
      }
      Result(o, e)
    }
    Handle => Handle
    Future => Future
    Stream => Stream
    Resource => Resource
  }
}

///|
/// Import functions from a compact JSON document:
///
/// ```json
/// {
///   "funcs": [
///     {"name":"greet","params":["string"],"result":"string"}
///   ]
/// }
/// ```
pub fn from_iface_json(src : String) -> (Registry, IfaceDoc) raise {
  let parsed = @json.parse(src)
  let obj = json_object(parsed)
  let funcs_j = match obj.get("funcs") {
    None => []
    Some(v) => json_array(v)
  }
  let types : Array[(String, ValType)] = []
  let funcs : Array[IfaceFunc] = []
  let worlds : Array[String] = []
  let mut package_name : String? = None
  match obj.get("package") {
    None => ()
    Some(v) => package_name = Some(json_string(v))
  }
  match obj.get("worlds") {
    None => ()
    Some(v) =>
      for w in json_array(v) {
        worlds.push(json_string(w))
      }
  }
  let acc = Registry::new()
  for f in funcs_j {
    let fo = json_object(f)
    let name = json_string(json_field(fo, "name"))
    let params : Array[ValType] = []
    match fo.get("params") {
      None => ()
      Some(ps) =>
        for p in json_array(ps) {
          params.push(parse_expr_into(acc, json_string(p)))
        }
    }
    let result : ValType? = match fo.get("result") {
      None => None
      Some(Null) => None
      Some(v) => Some(parse_expr_into(acc, json_string(v)))
    }
    funcs.push({ name, params, result, })
  }
  match obj.get("types") {
    None => ()
    Some(ts) =>
      for t in json_array(ts) {
        let to = json_object(t)
        let name = json_string(json_field(to, "name"))
        let expr = json_string(json_field(to, "expr"))
        types.push((name, parse_expr_into(acc, expr)))
      }
  }
  (acc, { package_name, types, funcs, worlds, })
}

///|
/// Import a single type expression wrapped as JSON string or `{ "expr": "..." }`.
pub fn from_type_json(src : String) -> (Registry, ValType) raise {
  let parsed = @json.parse(src)
  match parsed {
    String(s) => parse_type_expr(s)
    Object(m) => parse_type_expr(json_string(json_field(m, "expr")))
    _ => raise BadJson("expected string or {expr}")
  }
}
