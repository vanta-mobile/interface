# Vanta

基于 Flutter 的 Android / iOS 永续合约交易客户端，支持 Aster 实时行情、K 线图表、钱包登录和中英文切换。

## 本地运行

使用 Flutter 3.47.4。Android 需要 Android SDK 和 JDK 17；iOS 需要 macOS 和 Xcode。

```sh
cp .env.example .env
# 在 .env 中填写 PRIVY_APP_ID、PRIVY_CLIENT_ID、REOWN_PROJECT_ID
flutter pub get
make env-check
make run FLUTTER_ARGS='-d <device-id>'
```

`.env` 仅存放公开应用配置，不提交到 Git。

## 检查与构建

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
dart analyze --fatal-infos
flutter test
make build-apk
make build-ios  # macOS / Xcode，未签名构建
```

本地演示账户使用模拟资金；实盘功能需要有效的钱包授权，仍待真实账户验收。

## 文档

- [CI 与发布配置](docs/ci.md)
- [实现说明](docs/implementation.md)
- [功能进度](docs/prd-progress.md)
