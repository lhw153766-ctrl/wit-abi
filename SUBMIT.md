# Submit this project (you do this part)

Everything below is already in `E:\moonbit\wit-abi`. You only need an account,
the event group, and the form.

## 1. Create a public GitHub repo

Suggested name: `wit-abi`. Default branch: `master` (or rename to `main` after push).

```bash
source /e/moonbit/env.sh
cd /e/moonbit/wit-abi
# after creating the empty GitHub repo:
git remote add origin https://github.com/<YOUR_GITHUB_ID>/wit-abi.git
git push -u origin master
```

Then edit `moon.mod`:

- `name = "<YOUR_GITHUB_ID>/wit-abi"`
- `repository = "https://github.com/<YOUR_GITHUB_ID>/wit-abi"`

and `cmd/main/moon.pkg` import path from `"lhw153766-ctrl/wit-abi"` to
`"<YOUR_GITHUB_ID>/wit-abi"`. Re-run `moon check && moon test && moon info`.

## 2. Join the event WeChat group

- Group: https://work.weixin.qq.com/gm/5b6b92c8677d0555f3fb6a3f1a081399
- Assistant: https://u.wechat.com/EA2rUlkjobqjS4EeOCKuKdY

Prize payment requires the group.

## 3. Publish to mooncakes.io

```bash
moon register    # if needed
moon login
moon publish
```

Module name must match `moon.mod` `name`.

## 4. Fill the Feishu form before 2026-09-24 24:00

https://bxup9uklfcb.feishu.cn/share/base/form/shrcnWUMlgpbwHaXgzV7HmNhNhg

Paste `PROPOSAL.md` as the one-page proposal. Attach the public GitHub URL.
The repo already has 17 real commits.

## 5. Acceptance checklist

- [ ] MoonBit is the implementation language
- [ ] Public GitHub repo, history on the default branch
- [ ] README with install + demo command
- [ ] CI (`.github/workflows/ci.yml`)
- [ ] `moon test` green (179 tests at freeze)
- [ ] `moon run cmd/main -- demo|layout|json|glue|iface|from-json` works
- [ ] Published on mooncakes.io
- [ ] Apache-2.0 `LICENSE` + `THIRD_PARTY.md`
- [ ] In the event group
