# 互传助手 (l78z)

跨平台的局域网互传与实用工具合集，Flutter + Rust 实现。

**仓库**：[GitHub](https://github.com/ee19971/l78z) · [Gitee](https://gitee.com/ee19971/l78z)（双托管，内容同步）

## 功能

**局域网传输**
- 手机与电脑互传文本、文件，无需外部服务器
- 扫二维码配对，配对后双向可发
- 接收端服务常驻，退出页面不影响对方继续连接
- 自动排除 Hyper-V / WSL / VPN 等虚拟网卡，避免选中手机根本连不到的地址
- 安卓端收到的文件存入系统「下载」目录，文件管理器里直接可见

**扫一扫**
- 拍照或从相册选图，识别二维码 / 条形码
- 图片文字 OCR（PaddleOCR v6）：识别本身完全离线；首次使用时需联网下载模型，见下节

**日历与工具**
- 农历、24 节气、节日、干支生肖；道历、佛历
- 其他历法：伊斯兰历（Umm al-Qura）、希伯来、波斯、印度 Saka、日本年号——日历设置里逐项开关，默认全关
- 二维码生成、日期计算、计算器、历史上的今天、倒数日、世界时钟

## OCR 模型说明

安装包**不含** OCR 大模型（两个 onnx 合计约 132MB）。首次使用「识别文字」时，
应用内自动下载（ModelScope 官方直链，国内可直连），带实时进度、断点续传与
SHA-256 校验，下载一次之后终身离线使用。

应用内下载不可用时，可手动下载（蓝奏云）：

> **蓝奏云**：https://wwbqn.lanzouw.com/b0mcw5fxa　密码：`beho`

手动下载得到两个 onnx 文件，放入模型目录即可（应用会自动识别）：

| 平台 | 目录 |
|---|---|
| Windows | `%USERPROFILE%\Documents\l78z_ocr\` |
| Android | 应用私有目录，无法直接放入——请用应用内下载 |

文件校验（与 RapidOCR 官方 / ModelScope 发布一致）：

| 文件 | 大小 | SHA-256 |
|---|---|---|
| `PP-OCRv6_det_medium.onnx` | 59.2MB | `92078b7355007ccfffcd4c8cd441a3afd4538904d06881b29a155e1e679907c2` |
| `PP-OCRv6_rec_medium.onnx` | 73.1MB | `eef444829dbbe18d7fea59a3f6eb75647518d2b3a9568d27c92e42940204894b` |

其余小文件（识别字典、方向分类模型，约 660KB）随安装包附带，无需下载。

## 技术栈

| 层 | 技术 |
|---|---|
| UI | Flutter (Material 3) |
| 逻辑 | Rust，经 [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) 调用 |
| 传输 | axum (HTTP server) + reqwest (client) |
| 识别 | rxing（二维码/条形码）、rapidocr-core（OCR） |
| 历法 | lunar（农历/节气/道历/佛历）、[icu_kit](https://github.com/whuppi/icu_kit)（ICU4X：伊斯兰/希伯来/波斯/印度/日本历） |

## 构建

```bash
# 1. 生成 FRB 绑定（改动 Rust 公开接口后必须执行）
flutter_rust_bridge_codegen generate

# 2. 生成多语言文案（改动 lib/l10n/*.arb 后必须执行）
flutter gen-l10n

# 3. 构建
flutter build apk --release     # Android，产物见下

# Windows MSIX 需要签名证书（自签、不入库，首次生成一次即可）
powershell -File tool/new_dev_cert.ps1
dart run msix:create
```

- Android 只打包 `arm64-v8a`：OCR 引擎没有 32 位与 x86_64 的预编译产物，打进去必然崩溃。
- OCR 大模型不进安装包（见上），应用体积与模型无关；icu_kit 首次构建时由
  build hook 自动下载 ICU4X 预编译二进制（约 21MB，自带哈希校验）。
- CI：打 tag（形如 `v4.0.0`）推到 GitHub 会自动构建 APK 与 MSIX 并挂到 Releases。

## 许可

本项目采用 [Apache License 2.0](LICENSE)。

允许商业使用、修改与再分发。**分发本软件副本时请保留仓库中的 `LICENSE` 与 `NOTICE` 文件**——`NOTICE` 中列出了所使用的第三方开源组件及其许可。

第三方组件的完整清单（含版本号与许可证）可在应用内「工具 → 设置 → 关于」查看。
