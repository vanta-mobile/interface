<p align="center">
  <img src="assets/branding/mark.webp" width="96" alt="Vanta logo">
</p>

<h1 align="center">Vanta</h1>

<p align="center">
  A Flutter mobile client for perpetual trading, powered by Aster market data.
</p>

<p align="center">
  <a href="README.md">English</a> |
  <a href="docs/zh/README.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/vanta-mobile/interface/actions/workflows/ci.yml"><img src="https://github.com/vanta-mobile/interface/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/vanta-mobile/interface/actions/workflows/performance.yml"><img src="https://github.com/vanta-mobile/interface/actions/workflows/performance.yml/badge.svg" alt="Native performance"></a>
  <img src="https://img.shields.io/badge/Flutter-3.47.4-02569B?logo=flutter" alt="Flutter 3.47.4">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="GPL-3.0 license"></a>
</p>

## Overview

Vanta brings market discovery, candlestick charts, account views, and order
workflows to Android and iOS from one Flutter codebase.

- Live Aster market data, market search, and local favorites.
- Candlestick charts with indicators, depth views, and an interactive order book.
- Email, Google, X, and external EVM wallet sign-in through Privy and Reown.
- Spot and futures account views, order management, and funding workflows.
- A local demo account with simulated funds, separate from wallet activity.
- English and Simplified Chinese application localization.

Live workflows require valid wallet authorization and Aster account permissions.
Real-account acceptance is still pending, and some workflows remain incomplete.
See [feature progress](docs/prd-progress.md),
[remaining work](docs/remaining-work.md), and
[native acceptance checks](docs/native-verification-pending.md) for the current scope.

## Platform Support

| Platform | Support | Requirements |
| --- | --- | --- |
| Android | Supported | Android API 28 or later; Android SDK and JDK 17 for development |
| iOS | Supported | iOS 17 or later; iPhone device family; macOS and Xcode for builds |
| Web and desktop | Unsupported | Outside the build and acceptance scope |

Layouts adapt to available space, landscape, safe areas, the keyboard, and
enlarged text. iOS currently declares native iPhone support; see
[iOS device and distribution configuration](docs/ci.md#ios-设备支持与发行地区).

## Getting Started

### Prerequisites

- Flutter **3.47.4** with Dart **3.13.3**, matching CI.
- Python 3 for configuration validation and release tools.
- The Android or iOS toolchain for your target platform.
- Node.js 24 for native performance tooling.

### Install and Configure

```sh
git clone https://github.com/vanta-mobile/interface.git
cd interface
flutter pub get
cp -n .env.example .env
```

Fill in `PRIVY_APP_ID`, `PRIVY_CLIENT_ID`, and `REOWN_PROJECT_ID` in `.env`.
`WALLET_LOGIN_ORIGIN` defaults to `https://app.vanta.exchange` and supplies Reown app metadata.
External EOA connections do not request a Privy/SIWE login signature; Enable Trading
remains a separate signature. Privy is used for email and social embedded wallets.
Configure Privy's allowed URL schemes for the OAuth callback `vanta://`;
the external wallet callback is `vanta://wallet`.

Firebase Cloud Messaging client configuration is included for Android and iOS.
See [Firebase setup](docs/firebase.md) for device requirements, iOS APNs setup,
and push delivery checks.

The ignored `.env` file contains public application configuration only.
Keep private keys, API secrets, access tokens, and signing credentials out of
source files and Dart build arguments.

### Run

```sh
make env-check
flutter devices
make run FLUTTER_ARGS='-d <device-id>'
```

To use another configuration file:

```sh
make run ENV_FILE=.env.staging FLUTTER_ARGS='-d <device-id>'
```

## Common Commands

| Command | Purpose |
| --- | --- |
| `make env-check` | Validate public application configuration |
| `make run` | Validate configuration and launch Flutter |
| `flutter test` | Run unit and widget tests |
| `make build-apk-debug` | Build an Android debug APK |
| `make build-apk` | Build an Android arm64 release APK |
| `make build-appbundle` | Build an Android arm64/x64 App Bundle |
| `make build-ios` | Build iOS without signing on macOS with Xcode |

All `make` run/build commands accept `ENV_FILE` and `FLUTTER_ARGS`.
Local Android builds use development signing unless release signing is configured.
See [CI and release setup](docs/ci.md) for signing and distribution.

## Architecture

Application data requests follow this direction:

```text
Widget / screen
    -> Riverpod provider or notifier
    -> repository
    -> service
    -> HTTP / WebSocket transport or identity SDK
```

Widgets render state and collect intent. Repositories validate transport payloads
and expose immutable domain models. Riverpod owns application state, `k_chart_plus`
renders candlestick charts, and `decimal` preserves financial arithmetic.
Transport infrastructure provides cancellation, backend connection reuse,
rate-limit budgets, and shared public market subscriptions.

## Repository Layout

```text
lib/core/                 Theme, formatters, motion, and shared infrastructure
lib/features/             Feature presentation, application, domain, and data layers
lib/l10n/                 English and Simplified Chinese localization catalogs
assets/                   Branding, icons, and fonts
third_party/k_chart_plus/ Local chart package with gesture fixes
test/                     Unit and widget tests
integration_test/         Native integration and performance entry points
test_driver/              Integration test driver
scripts/                  Configuration, release, and performance tooling
docs/                     Implementation notes and acceptance evidence
```

## Quality and CI

Run these checks before completing a change:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
dart analyze --fatal-infos
flutter test
make build-apk
make build-ios  # Requires macOS and Xcode; unsigned build
```

GitHub Actions runs quality checks and an Android release build. Native performance
CI uses fixture data on an Android emulator. iOS CI and signed IPA releases are
enabled when the required iOS configuration is complete. Mobile releases support
Android APK/AAB distribution, optional Google Play internal testing, and optional
TestFlight uploads. See [CI documentation](docs/ci.md) for configuration and artifacts.

## Documentation

The detailed engineering documents below are currently in Chinese.

- [CI and release configuration](docs/ci.md)
- [Implementation and verification notes](docs/implementation.md)
- [Feature progress](docs/prd-progress.md)
- [Remaining work and protocol boundaries](docs/remaining-work.md)
- [Pending native acceptance checks](docs/native-verification-pending.md)
- [Flutter documentation](https://docs.flutter.dev/)

## License

Vanta is licensed under the [GNU General Public License v3.0](LICENSE).
Third-party components and fonts retain their respective licenses, including
[`k_chart_plus`](third_party/k_chart_plus/LICENSE),
[Inter](assets/fonts/Inter-LICENSE.txt), and
[Noto Sans SC](assets/fonts/NotoSansSC-LICENSE.txt).
