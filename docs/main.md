# Apple 平台 WAMR 构建说明

## 目标

本仓库只负责 Apple 平台的 WAMR 构建发布，将 [bytecodealliance/wasm-micro-runtime](https://github.com/bytecodealliance/wasm-micro-runtime) 作为子仓库放在 `third_party/wasm-micro-runtime`，并固定到 tag `WAMR-2.4.4`。

最终产物是：

- `dist/apple/wamr.xcframework`
- `dist/apple/wamr.xcframework.zip`

XCFramework 包含三个 ARM64 slice：

- iOS 真机：`arm64`
- iOS 模拟器：`arm64`
- macOS：`arm64`

脚本会在 `wamr.xcframework/include` 额外放置一份公共头文件，便于宿主工程直接配置 Header Search Paths。各 slice 内仍保留 `xcodebuild -create-xcframework -headers` 生成的标准 Headers 信息。

## 构建模式

Apple 平台默认使用解释器模式：

```cmake
WAMR_BUILD_PLATFORM=darwin
WAMR_BUILD_TARGET=AARCH64
WAMR_BUILD_INTERP=1
WAMR_BUILD_FAST_INTERP=1
WAMR_BUILD_AOT=0
WAMR_BUILD_JIT=0
WAMR_BUILD_FAST_JIT=0
WAMR_BUILD_LIBC_BUILTIN=1
WAMR_BUILD_LIBC_WASI=1
WAMR_BUILD_LIB_PTHREAD=0
WAMR_BUILD_LIB_WASI_THREADS=0
WAMR_BUILD_SIMD=0
WAMR_BUILD_DEBUG_INTERP=0
```

iOS 和 iOS 模拟器不启用 AOT、LLVM JIT、Fast JIT 或 Multi-tier JIT。

## fast interpreter 评估

结论：iOS 可以使用 WAMR fast interpreter，但不要把它和 Fast JIT 混淆。

依据：

- WAMR `WAMR-2.4.4` 的 iOS CMake 入口默认启用 `WAMR_BUILD_INTERP=1`，关闭 `WAMR_BUILD_AOT=0`，并默认启用 `WAMR_BUILD_FAST_INTERP=1`。
- fast interpreter 是解释器，不在运行时生成 native 机器码。
- WAMR 官方文档说明 fast interpreter 比 classic interpreter 更快，但会消耗更多内存保存预编译代码。
- Fast JIT 是另一个运行模式，官方文档说明当前只覆盖少数架构，不能作为 Apple ARM64/iOS 首版方案。

风险：

- WAMR 的 iOS 支持在官方分级中不是最高等级，release 产物需要后续用宿主 App 或最小样例做模拟器/真机验证。
- fast interpreter 内存占用高于 classic interpreter。若宿主 App 对内存敏感，应增加一个 `WAMR_BUILD_FAST_INTERP=0` 的 classic interpreter 变体。
- 需要 wasm 源码级调试时，WAMR debug interpreter 会切换到 classic interpreter，不适合和 fast interpreter 同时作为默认包。

## 本地构建

本地构建必须在 macOS 上执行，并需要安装 Xcode、CMake 和 Git。

```bash
git submodule update --init --recursive
bash ./scripts/build_wamr_apple.sh
```

脚本会自动确认子模块 tag 为 `WAMR-2.4.4`，然后构建三个 slice 并打包 XCFramework。

可用环境变量：

```bash
WAMR_TAG=WAMR-2.4.4
WAMR_ROOT=/path/to/wasm-micro-runtime
BUILD_ROOT=/path/to/build/apple
DIST_DIR=/path/to/dist/apple
IOS_DEPLOYMENT_TARGET=11.0
MACOS_DEPLOYMENT_TARGET=11.0
```

## GitHub Actions 发布

工作流文件：`.github/workflows/release-apple.yml`

触发方式：

- push 到 `main`
- 手动 `workflow_dispatch`

每次构建会：

1. checkout 仓库和子模块。
2. 执行 `bash ./scripts/build_wamr_apple.sh`。
3. 上传 `dist/apple/wamr.xcframework.zip` 为 artifact。
4. 创建 GitHub Release，tag 格式为 `apple-wamr-<short-sha>`。

发布 release 需要仓库 Actions 具备 `contents: write` 权限，工作流已显式声明。

## 关键文件

- `.gitmodules`：声明 `third_party/wasm-micro-runtime` 子模块。
- `cmake/wamr-runtime/CMakeLists.txt`：把 WAMR vmcore 包装成静态库 `libiwasm.a`。
- `scripts/build_wamr_apple.sh`：Apple 平台构建入口。
- `.github/workflows/release-apple.yml`：push 后自动构建并发布 release。
- `tests/validate_repository.ps1`：仓库结构和关键配置的静态验证脚本。

## 验证

在 Windows 或 macOS 上可运行静态验证：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\validate_repository.ps1
```

在 macOS 上还应运行真实构建：

```bash
bash ./scripts/build_wamr_apple.sh
```
