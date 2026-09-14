# Project declaration — local/wit-abi

One-page Markdown for the 2026 MoonBit September Hackathon.

## Project value and ecosystem position

WIT parsers already exist on mooncakes.io (`mizchi/wit` 0.3.3, `pei0331/moon-wit`
0.1.1). `pei0331/moon-wit` states in its README that it does **not** implement
the Component Model Canonical ABI and that generated functions are compile-time
stubs. `mizchi/wit` parses and resolves; it never mentions size, alignment, or
flattening.

That is the hole. Bindgen, FFI stubs, and any "AI wrote a WIT file, is the
memory layout legal?" check all need Canonical ABI numbers. Without them, a
MoonBit program still has to shell out to Rust `wasm-tools`.

`wit-abi` is a **pure MoonBit Canonical ABI calculator**. It does not compete
with the parsers. It sits under them: you feed it a type registry (either built
by hand or later adapted from a parser AST) and you get wasm32/wasm64 sizes,
alignments, field offsets, flattened core types, and guest import/export
signatures. Algorithms are a port of `bytecodealliance/wasm-tools`
`wit-parser` `sizealign.rs` / `abi.rs`, so results can be compared 1:1.

Three uses:

1. A bindgen or `wit-bindgen`-style generator asks "does this function need a
   return pointer?" before emitting MoonBit FFI.
2. CI for AI-generated WIT: flatten `result<u32, f64>` and reject layouts that
   do not match `wasm-tools`.
3. An in-browser or wasm-gc tool inspects component interfaces without a native
   `wasm-tools` binary.

## Delivery and non-goals

Delivered:

- Type IR covering primitives, records, tuples, lists, maps, fixed lists,
  flags, enums, variants, option, result, handles, future, stream, alias
- Size / alignment / architecture-size arithmetic matching wasm-tools tests
- Flattening and wasm signatures for sync GuestImport / GuestExport
- Compact type expressions and compact `interface`/`world` documents
- MoonBit lift/lower glue sketches from computed offsets
- CLI: `demo`, `layout`, `json`, `glue`, `iface`
- 162 tests; `moon check --target all`
- Apache-2.0, CI, README with a runnable `mbt check` example

Not this round:

- A `.wit` text parser (would duplicate `mizchi/wit`)
- `.wasm` encoding / WASI runtime
- Async ABI variants (`GuestImportAsync` and friends)
- Multi-language codegen

## Path and technical choices

Two paths: write a new IDL, or port the industrial calculator and keep the
parser out of scope. The second path is the only one that is both original
enough (nobody published Canonical ABI in MoonBit) and finishable in days.

MoonBit algebraic types map cleanly onto `TypeDefKind`. There is no async and
no FFI, so `moon check --target all` is expected to pass. The interesting
engineering is not lexing: it is pointer-aware `ArchitectureSize` arithmetic
(`bytes + N * ptrsz`) and variant flattening joins (`result<u32, f32>` becomes
`[i32, i32]`). Those are the parts AI bindgen gets wrong, and the parts this
library makes deterministic.
