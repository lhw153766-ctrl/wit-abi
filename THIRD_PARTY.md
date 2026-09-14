# Third-party notices

`local/wit-abi` reimplements Canonical ABI layout and flattening algorithms
from Bytecode Alliance `wasm-tools`, specifically:

- Repository: https://github.com/bytecodealliance/wasm-tools
- Files: `crates/wit-parser/src/sizealign.rs`, `crates/wit-parser/src/abi.rs`
- License: Apache-2.0 WITH LLVM-exception
- Scope of the port: size, alignment, architecture-size arithmetic,
  flags representation, variant discriminants, flattening, and wasm signatures
  for the **sync** guest-import / guest-export ABI.
- Not ported: WIT text parsing, component encoding, async ABI variants,
  live resolution of `.wit` packages.

This is an independent MoonBit implementation. It is not affiliated with
the Bytecode Alliance. Bug-for-bug behaviour of the listed algorithms is
intentional so bindgen authors can compare results against `wasm-tools`.
