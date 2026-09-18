# 项目申报书

## 1. 项目名称

wit-abi：纯 MoonBit 的 WIT Canonical ABI 计算与胶水代码生成库

## 2. 项目简介

MoonBit 已经能写 Wasm 组件，但生态里少一层东西：把一个 WIT 类型算成真实内存布局的能力。

先说现状。mooncakes 上现有的两个 WIT 包分工是清楚的：mizchi/wit 做词法、语法解析和符号消解；pei0331/moon-wit 能把文本转成 MoonBit 桩代码。后者在自己 README 里写明了，0.1.1 没有实现 Component Model Canonical ABI，生成的函数只是能编过的空壳，不是可调用的 Wasm 绑定。于是从「这个类型在 wasm32 上占多少字节」到「这个函数要不要返回指针」这一段，MoonBit 侧是空的。想拿到这些数字，目前只能去开一个 Rust 的 wasm-tools。

wit-abi 补的就是这一段。它不做 WIT 文本解析，输入一个类型注册表，输出 size、alignment、字段偏移、variant payload 偏移、扁平化后的 core Wasm 类型序列，以及 guest import / export 两个方向下的函数签名。算法对照 bytecodealliance/wasm-tools 的 crates/wit-parser（sizealign.rs 与 abi.rs），包括 pointer 与 bytes 混合的 ArchitectureSize 表示、variant 判别式位宽选择、以及 result\<u32, f32\> 这类需要做类型 join 的扁平化情形。

## 3. 项目方向，通用性说明

属于「语言与开发工具」方向里的工具链基础设施，具体是 Wasm 生态的 ABI 计算层。

通用性在于它不绑定上层用法。bindgen 可以拿它判断参数是否走间接传递；CI 可以拿它当 AI 生成 WIT 的静态校验关卡；跑在 wasm 环境里的工具也能直接用它，不需要本地装 wasm-tools。整个库只依赖 moonbitlang/core，没有 C 绑定、没有异步、没有平台 FFI，所以 wasm、wasm-gc、js、native 四个后端共用同一份代码，`moon check --target all` 能直接过。

## 4. 预期使用场景

**写 bindgen 时决定 ABI 形态。** 生成器展开一个函数前先问 wit-abi：参数扁平化后有几个 core 类型、有没有超过 16 个、结果是否必须走返回指针。这些判断现在散落在生成器的手写逻辑里，wit-abi 把它们收成一个可单测的纯函数。

**CI 里拦截 AI 写错的 WIT。** 让模型生成组件接口时，类型对齐和内存布局是最容易出错的地方。把 wit-abi 接进流水线，对每个 interface 打印整套函数签名和布局，跟 wasm-tools 的输出对不上就直接失败。

**在 wasm 环境里做接口版本校验。** 库本身能编到 wasm-gc，所以一个跑在边缘节点的 MoonBit 网关可以在没有原生工具链的情况下解析组件契约、检查版本兼容性。

## 5. 拟实现的核心功能

已完成：

- 类型 IR，覆盖基础类型、record、tuple、list、map、定长 list、flags、enum、variant、option、result、handle、future、stream、alias
- 布局计算，含 ArchitectureSize 运算、字段偏移、variant payload 偏移；对齐向量直接取自 wasm-tools 的测试
- 扁平化与 wasm 签名，含 indirect params 与 retptr 判定
- 紧凑类型表达式解析（`option<string>`、`result<u32, f64>`、`(u8, u32)`）
- 紧凑 interface / world 文档解析，批量输出 ABI 报表
- 从 LowerStep 生成 MoonBit lift / lower 胶水代码骨架
- 线性内存模拟器，按算出的偏移做小端读写和字符串对往返，用来验证偏移不只是纸面正确
- CLI：demo / layout / json / glue / iface / from-json

明确不做：WIT 文本解析（交给已有解析器）、组件二进制编码、WASI 运行时、async ABI 变体、其他语言的代码生成。

## 6. 是否为原创、移植或参考已有项目

移植项目。算法来自 Bytecode Alliance 的 wasm-tools，属于规范级移植加 MoonBit 化改写，不是逐行翻译。

## 7. 参考项目信息

- 原项目名称：wasm-tools（Bytecode Alliance）
- 原项目链接：https://github.com/bytecodealliance/wasm-tools
- 参考文件：crates/wit-parser/src/sizealign.rs、crates/wit-parser/src/abi.rs
- 原项目许可证：Apache-2.0 WITH LLVM-exception
- 本项目许可证：Apache-2.0
- 移植范围：同步 ABI 的 size / align、flags 表示、variant 判别式、flatten、wasm 签名
- 未移植：WIT 文本解析、组件二进制编码、async ABI 变体、多语言代码生成

来源与范围同时写在仓库的 THIRD_PARTY.md 中。

## 8. GitHub 仓库链接

https://github.com/lhw153766-ctrl/wit-abi

20 个以上有效 commit，Apache-2.0。GitHub Actions 在 ubuntu 和 windows 上跑 `moon check --target all`、`moon test --target all`、`moon fmt --check` 以及 6 个 CLI 冒烟测试，当前 179 个测试通过，约 4100 行 MoonBit 代码。
