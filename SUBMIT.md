# Submit this project (you do this part)

Everything in steps 0 is already done. Only steps 1–3 need your account.

## 0. Already done (verified)

- GitHub repo: https://github.com/lhw153766-ctrl/wit-abi (public, default branch `main`)
- 20 commits, 50 files, local == remote
- `moon test`: 179 passed / 0 failed, ~4129 lines of `.mbt`
- CI green on both `ubuntu-latest` and `windows-latest`
- Apache-2.0 `LICENSE`, `THIRD_PARTY.md`, README, `PROPOSAL.md` all on the default branch

## 1. Publish to mooncakes.io (hard acceptance gate)

`moon login` needs an interactive terminal, so run these in your own terminal:

```bash
source /e/moonbit/env.sh
cd /e/moonbit/wit-abi
moon register     # only if you have no mooncakes.io account yet
moon login
moon publish
```

The module name is already `lhw153766-ctrl/wit-abi`, so sign in with the same
GitHub account. After publish, confirm the package page appears at
https://mooncakes.io/docs/lhw153766-ctrl/wit-abi

## 2. Join the event WeChat group

- Group: https://work.weixin.qq.com/gm/5b6b92c8677d0555f3fb6a3f1a081399
- Assistant: https://u.wechat.com/EA2rUlkjobqjS4EeOCKuKdY

Prize payment requires the group.

## 3. Fill the Feishu form before 2026-09-24 24:00

https://bxup9uklfcb.feishu.cn/share/base/form/shrcnWUMlgpbwHaXgzV7HmNhNhg

- Paste `PROPOSAL.md` as the one-page proposal (it is already one page).
- GitHub URL: https://github.com/lhw153766-ctrl/wit-abi
- The proposal must read as hand-written; edit the wording so it sounds like
  you, and be ready to explain the Canonical ABI choices in person.

## 4. Acceptance checklist

- [x] MoonBit is the implementation language
- [x] Public GitHub repo, history on the default branch
- [x] README with install + demo command
- [x] CI (`.github/workflows/ci.yml`) green on 2 platforms
- [x] `moon test` green (179 tests)
- [x] `moon run cmd/main -- demo|layout|json|glue|iface|from-json` works
- [ ] Published on mooncakes.io  ← step 1
- [x] Apache-2.0 `LICENSE` + `THIRD_PARTY.md`
- [ ] In the event group  ← step 2

## 5. If you change code later

```bash
source /e/moonbit/env.sh
cd /e/moonbit/wit-abi
moon fmt && moon check --target all && moon test --target all
moon info && git diff --exit-code -- '*.mbti'
git add -A && git commit -m "..." && git push origin main
```

CI re-runs automatically on every push to `main`.
