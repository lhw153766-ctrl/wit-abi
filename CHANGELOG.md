# Changelog

## 0.1.0

- Canonical ABI size / alignment / architecture-size arithmetic
- Flattening and guest-import / guest-export wasm signatures
- Compact WIT type-expression parser (`option<string>`, `result<u32, f64>`, tuples)
- Lowering steps with wasm32 offsets and JSON layout dump
- Compact WIT interface documents (`parse_interface`) and `iface` CLI
- MoonBit lift/lower glue emitter (`emit_moonbit_glue`)
- Property invariants and extra wasm-tools-style layout vectors
- Guest linear-memory simulator with little-endian round-trips
- Compact iface JSON import (`from_iface_json`) and `from-json` CLI
