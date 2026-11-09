<p align="center">
  <img src="../../assets/branding/mark.webp" width="96" alt="Vanta 标志">
</p>

<h1 align="center">Vanta</h1>

<p align="center">
  基于 Flutter 的移动端永续合约交易客户端，行情数据来自 Aster。
</p>

<p align="center">
  <a href="../../README.md">English</a> |
  <a href="README.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/vanta-mobile/interface/actions/workflows/ci.yml"><img src="https://github.com/vanta-mobile/interface/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/vanta-mobile/interface/actions/workflows/performance.yml"><img src="https://github.com/vanta-mobile/interface/actions/workflows/performance.yml/badge.svg" alt="原生性能测试"></a>
  <img src="https://img.shields.io/badge/Flutter-3.47.4-02569B?logo=flutter" alt="Flutter 3.47.4">
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="GPL-3.0 许可证"></a>
</p>

## 项目简介

Vanta 通过同一套 Flutter 代码，为 Android 和 iOS 提供行情发现、K 线图表、账户查看与下单流程。

- Aster 实时行情、行情搜索和本地自选。
- 支持技术指标的 K 线图、深度图和可交互盘口。
- 通过 Privy 和 Reown 实现邮箱、Google、X 和外部 EVM 钱包登录。
- 现货与合约账户查看、订单管理和资金操作流程。
- 使用模拟资金的本地演示账户，与钱包活动分离。
- 应用内英文与简体中文本地化。

实盘流程需要有效的钱包授权和 Aster 账户权限。真实账户验收仍待完成，部分功能尚未实现。
当前范围详见[功能进度](../prd-progress.md)、[剩余工作](../remaining-work.md)和
[原生验收清单](../native-verification-pending.md)。

## 平台支持

| 平台 | 状态 | 要求 |
| --- | --- | --- |
| Android | 支持 | Android API 28 及以上；开发需要 Android SDK 和 JDK 17 |
| iOS | 支持 | iOS 17 及以上；iPhone 设备族；构建需要 macOS 和 Xcode |
| Web 和桌面端 | 不支持 | 不在构建与验收范围内 |

布局适配可用空间、横屏、安全区、键盘和放大文字。iOS 当前声明 iPhone 原生支持，详见
[iOS 设备与发行配置](../ci.md#ios-设备支持与发行地区)。

## 快速开始

### 环境要求

- Flutter **3.47.4** / Dart **3.13.3**，与 CI 保持一致。
- Python 3，用于配置校验和发布工具。
- 与目标平台对应的 Android 或 iOS 工具链。
- Node.js 24，用于原生性能工具。

### 安装与配置

```sh
git clone https://github.com/vanta-mobile/interface.git
cd interface
flutter pub get
cp -n .env.example .env
```

在 `.env` 中填写 `PRIVY_APP_ID`、`PRIVY_CLIENT_ID` 和 `REOWN_PROJECT_ID`。
`WALLET_LOGIN_ORIGIN` 默认为 `https://app.vanta.exchange`。
在 Privy 允许的 URL scheme 中配置 OAuth 回调 `vanta://`；
外部钱包回调为 `vanta://wallet`。

Android 和 iOS 已包含 Firebase Cloud Messaging 客户端配置。
设备要求、iOS APNs 配置及推送验收见 [Firebase 配置](../firebase.md)。

已被 Git 忽略的 `.env` 仅存放公开应用配置。私钥、API 密钥、访问令牌和签名凭据不得写入
源码或 Dart 构建参数。

### 运行

```sh
make env-check
flutter devices
make run FLUTTER_ARGS='-d <device-id>'
```

使用其他配置文件：

```sh
make run ENV_FILE=.env.staging FLUTTER_ARGS='-d <device-id>'
```

## 常用命令

| 命令 | 用途 |
| --- | --- |
| `make env-check` | 校验公开应用配置 |
| `make run` | 校验配置并启动 Flutter |
| `flutter test` | 运行单元与 Widget 测试 |
| `make build-apk-debug` | 构建 Android Debug APK |
| `make build-apk` | 构建 Android arm64 Release APK |
| `make build-appbundle` | 构建 Android arm64/x64 App Bundle |
| `make build-ios` | 在 macOS / Xcode 上构建未签名 iOS 应用 |

所有 `make` 运行和构建命令均接受 `ENV_FILE` 与 `FLUTTER_ARGS`。
本地 Android 构建未配置发布签名时使用开发签名，签名与分发详见 [CI 与发布配置](../ci.md)。

## 架构

应用数据请求遵循以下依赖方向：

```text
Widget / 页面
    -> Riverpod provider 或 notifier
    -> repository
    -> service
    -> HTTP / WebSocket 传输或身份 SDK
```

Widget 负责渲染状态和收集意图；Repository 校验传输数据并暴露不可变领域模型。
Riverpod 管理应用状态，`k_chart_plus` 绘制 K 线图，`decimal` 保持金融计算精度。
传输基础设施提供取消、后端连接复用、限流预算和公开行情订阅共享。

## 仓库结构

```text
lib/core/                 主题、格式化、动效与共享基础设施
lib/features/             按功能组织的表现层、应用层、领域层与数据层
lib/l10n/                 英文与简体中文本地化目录
assets/                   品牌、图标和字体资源
third_party/k_chart_plus/ 包含手势修复的本地图表包
test/                     单元与 Widget 测试
integration_test/         原生集成与性能测试入口
test_driver/              集成测试驱动
scripts/                  配置、发布与性能工具
docs/                     实现说明与验收证据
```

## 质量与 CI

完成修改前运行：

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
dart analyze --fatal-infos
flutter test
make build-apk
make build-ios  # 需要 macOS 和 Xcode；未签名构建
```

GitHub Actions 运行质量检查和 Android Release 构建；原生性能 CI 在 Android 模拟器上使用
测试数据。完整配置 iOS 所需参数后，启用 iOS CI 与签名 IPA 发布。移动端发布支持 Android
APK/AAB 分发、可选的 Google Play 内部测试和 TestFlight 上传。
配置与产物详见 [CI 文档](../ci.md)。

## 相关文档

以下工程文档目前以中文提供。

- [CI 与发布配置](../ci.md)
- [实现与验证说明](../implementation.md)
- [功能进度](../prd-progress.md)
- [剩余工作与协议边界](../remaining-work.md)
- [原生待验收清单](../native-verification-pending.md)
- [Flutter 文档](https://docs.flutter.dev/)

## 许可证

Vanta 使用 [GNU General Public License v3.0](../../LICENSE) 授权。
第三方组件与字体保留各自的许可证，包括
[`k_chart_plus`](../../third_party/k_chart_plus/LICENSE)、
[Inter](../../assets/fonts/Inter-LICENSE.txt) 和
[Noto Sans SC](../../assets/fonts/NotoSansSC-LICENSE.txt)。
