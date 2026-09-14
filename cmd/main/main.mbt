///|
/// wit-abi CLI — print Canonical ABI layouts for built-in demo types.
///
/// Usage:
///   moon run cmd/main -- demo
///   moon run cmd/main -- version
///   moon run cmd/main -- help
fn main {
  let args = @env.args()
  let cmd = if args.length() >= 2 { args[1] } else { "demo" }
  match cmd {
    "layout" =>
      run_layout(args) catch {
        e => {
          println("error: \{e.to_string()}")
          abort("layout error")
        }
      }
    "json" =>
      run_json(args) catch {
        e => {
          println("error: \{e.to_string()}")
          abort("json error")
        }
      }
    "iface" | "check-interface" =>
      run_iface(args) catch {
        e => {
          println("error: \{e.to_string()}")
          abort("iface error")
        }
      }
    "glue" =>
      run_glue(args) catch {
        e => {
          println("error: \{e.to_string()}")
          abort("glue error")
        }
      }
    "demo" | "" =>
      run_demo() catch {
        e => {
          println("error: \{e}")
          abort("abi error")
        }
      }
    "version" => println("wit-abi 0.1.0")
    "help" | "-h" | "--help" => print_help()
    _ => {
      println("error: unknown subcommand '\{cmd}'")
      print_help()
      abort("usage error")
    }
  }
}

///|
fn print_help() -> Unit {
  println("wit-abi — Canonical ABI layout engine for WIT types")
  println("")
  println("Usage:")
  println(
    "  moon run cmd/main -- layout <type>   Print layout of a type expression",
  )
  println(
    "  moon run cmd/main -- demo            Print layouts of the built-in demo types",
  )
  println(
    "  moon run cmd/main -- json <type>     Print JSON layout of a type expression",
  )
  println("  moon run cmd/main -- glue <type>     Emit MoonBit lift/lower glue")
  println(
    "  moon run cmd/main -- iface <wit-src>  ABI report for a compact interface",
  )
  println("  moon run cmd/main -- version           Print the version")
  println("  moon run cmd/main -- help      Show this help")
}

///|

///|
fn run_glue(args : Array[String]) -> Unit raise {
  if args.length() < 3 {
    abort("usage: moon run cmd/main -- glue <type-expr>")
  }
  let expr = args[2]
  let (reg, ty) = @abi.parse_type_expr(expr)
  println(@abi.emit_moonbit_glue(reg, ty))
}

///|
fn run_iface(args : Array[String]) -> Unit raise {
  if args.length() < 3 {
    abort("usage: moon run cmd/main -- iface <wit-src-or-inline>")
  }
  let src = args[2]
  let (reg, doc) = @abi.parse_interface(src)
  println(@abi.interface_report(reg, doc))
}

///|
fn run_json(args : Array[String]) -> Unit raise {
  if args.length() < 3 {
    abort("usage: moon run cmd/main -- json <type-expr>")
  }
  let expr = args[2]
  let (reg, ty) = @abi.parse_type_expr(expr)
  println(@abi.layout_json(reg, ty))
}

///|
fn run_layout(args : Array[String]) -> Unit raise {
  if args.length() < 3 {
    abort("usage: moon run cmd/main -- layout <type-expr>")
  }
  let expr = args[2]
  let (reg, ty) = @abi.parse_type_expr(expr)
  println("\{expr}  \{format_one(reg, ty)}")
}

///|
fn run_demo() -> Unit raise @abi.AbiError {
  let reg = @abi.Registry::new()
  println("primitive bool     \{format_one(reg, @abi.Bool)}")
  println("primitive u64      \{format_one(reg, @abi.U64)}")
  println("primitive string   \{format_one(reg, @abi.String)}")
  let rec = @abi.record_type(reg, [
    @abi.Field::new("id", @abi.U8),
    @abi.Field::new("count", @abi.U32),
  ])
  println("record id:u8,count:u32     \{format_one(reg, rec)}")
  let opt = @abi.option_type(reg, @abi.U32)
  println("option<u32>        \{format_one(reg, opt)}")
  let res = @abi.result_type(reg, Some(@abi.U32), Some(@abi.F64))
  println("result<u32, f64>   \{format_one(reg, res)}")
  let lst = @abi.list_type(reg, @abi.U8)
  println("list<u8>           \{format_one(reg, lst)}")
  let flg = @abi.flags_type(reg, 20)
  println("flags(20)          \{format_one(reg, flg)}")
  let func = @abi.Func::new([@abi.String, @abi.U32], Some(@abi.String))
  let sig = @abi.wasm_signature(reg, func, @abi.GuestExport)
  println("func(string, u32) -> string  \{sig}")
}

///|
fn format_one(
  reg : @abi.Registry,
  ty : @abi.ValType,
) -> String raise @abi.AbiError {
  let info = @abi.layout(reg, ty)
  let flat = @abi.flatten(reg, ty)
  "\{@abi.format_layout(info)} flat=[\{@abi.wasm_types_to_string(flat)}]"
}
