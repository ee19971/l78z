# 互传助手 (l78z)

跨平台的局域网互传与实用工具合集，Flutter + Rust 实现。

## 功能

**局域网传输**
- 手机与电脑互传文本、文件，无需外部服务器
- 扫二维码配对，配对后双向可发
- 接收端服务常驻，退出页面不影响对方继续连接
- 自动排除 Hyper-V / WSL / VPN 等虚拟网卡，避免选中手机根本连不到的地址
- 安卓端收到的文件存入系统「下载」目录，文件管理器里直接可见

**扫一扫**
- 拍照或从相册选图，识别二维码 / 条形码
- 图片文字 OCR（PaddleOCR v6，离线识别，不联网）

**其他**
- 二维码生成、农历节气节日、日期计算、计算器

## 技术栈

| 层 | 技术 |
|---|---|
| UI | Flutter (Material 3) |
| 逻辑 | Rust，经 [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) 调用 |
| 传输 | axum (HTTP server) + reqwest (client) |
| 识别 | rxing（二维码/条形码）、rapidocr-core（OCR） |

## 构建

```bash
# 生成 FRB 绑定（改动 Rust 公开接口后必须执行）
flutter_rust_bridge_codegen generate

flutter build apk --release
```

Android 目前只打包 `arm64-v8a`：OCR 引擎没有 32 位与 x86_64 的预编译产物，打进去必然崩溃。

## 许可

本项目采用 [Apache License 2.0](LICENSE)。

允许商业使用、修改与再分发。**分发本软件副本时请保留仓库中的 `LICENSE` 与 `NOTICE` 文件**——`NOTICE` 中列出了所使用的第三方开源组件及其许可。

第三方组件的完整清单（含版本号与许可证）可在应用内「工具 → 设置 → 关于」查看。
