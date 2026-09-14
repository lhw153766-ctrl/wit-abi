# local/wit-abi

Pure MoonBit **Canonical ABI** engine for WIT (Wasm Interface Types).

This is **not** a WIT parser. Parsers already exist (`mizchi/wit`, `pei0331/moon-wit`).
Those libraries stop at AST / stub codegen. This package fills the missing layer:
given a WIT type or function, compute size, alignment, field offsets, payload
offsets, flattened core-Wasm types, and wasm signatures exactly as
`bytecodealliance/wasm-tools` `wit-parser` does.

## Why this exists

MoonBit's Wasm Component Model story still has a hole: you can parse WIT, but you
cannot ask how many bytes `option<string>` occupies on wasm32, or whether
`func(s: string) -> string` uses a return pointer, without leaving MoonBit.

`wit-abi` is that calculator. It is 100% MoonBit, with no C / Rust / OpenSSL /
async, and it uses the same algorithms as `crates/wit-parser/src/sizealign.rs`
and `abi.rs`. It is intended to work on `wasm`, `wasm-gc`, `js`, and `native`.

```mbt check
///|
test "readme record layout" {
  let reg = @wit-abi.Registry::new()
  let ty = @wit-abi.record_type(reg, [
    @wit-abi.Field::new("id", @wit-abi.U8),
    @wit-abi.Field::new("count", @wit-abi.U32),
  ])
  inspect(@wit-abi.size32(reg, ty), content="8")
  inspect(@wit-abi.align32(reg, ty), content="4")
}
```

## Install

```bash
moon add local/wit-abi@0.1.0
```

Replace `local` with your mooncakes username after publish.

## Demo

```bash
moon run cmd/main -- demo
moon run cmd/main -- layout "option<string>"
moon run cmd/main -- json "result<u32, f64>"
moon run cmd/main -- glue "option<u32>"
moon run cmd/main -- iface "interface x { greet: func(name: string) -> string; }"
```

## What it computes

| API | Meaning |
|---|---|
| `size32` / `align32` | wasm32 size and alignment in bytes |
| `layout` | architecture-independent size (`bytes + N * ptrsz`) + alignment |
| `field_offsets` | record / tuple field starts |
| `payload_offset` | offset of a variant payload after the discriminant |
| `flatten` | Canonical ABI lowering to core Wasm types |
| `wasm_signature` | guest-import / guest-export function ABI, including indirect params and retptr |
| `emit_moonbit_glue` | MoonBit lift/lower sketches from computed offsets |
| `parse_interface` / `interface_report` | compact WIT interface → ABI report |

## Explicitly out of scope

- Parsing `.wit` text (use `mizchi/wit` or `pei0331/moon-wit`)
- Emitting `.wasm` binaries
- Running WASI / Component Model
- Generating bindings for languages other than MoonBit

## Porting source

Algorithms are a MoonBit port of https://github.com/bytecodealliance/wasm-tools
(`crates/wit-parser/src/sizealign.rs` and `abi.rs`). Upstream license:
Apache-2.0 WITH LLVM-exception. This package is Apache-2.0. See `THIRD_PARTY.md`.

## License

Apache-2.0
