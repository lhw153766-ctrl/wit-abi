# CLI snapshots

Regenerate with:

```bash
moon run cmd/main -- json "option<string>" > examples/option-string.json
moon run cmd/main -- json "(u8, u32)" > examples/tuple-u8-u32.json
moon run cmd/main -- layout "list<u8>" > examples/list-u8.txt
```
