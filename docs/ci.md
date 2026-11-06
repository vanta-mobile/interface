# GitHub Actions

工作流改编自 `/data/dodo/rwa-interface/.github/workflows`，Flutter 固定为当前项目已验证的 **3.47.4 stable / Dart 3.13.3**，应用标识为 `exchange.vanta.app`，钱包回跳为 `vanta://wallet`。

## 迁移范围

| 工作流 | 触发 | 行为 |
| --- | --- | --- |
| `ci.yml` / CI | main push、所有 PR、手动 | 发布工具测试、性能报告测试、格式、静态分析、全部单元／Widget 测试；Android arm64 Release 开发签名构建；仅 iOS 签名配置齐全时运行 macOS iOS 无签名 Release archive、真实 Keychain 兼容测试和失败日志 |
| `performance.yml` / Native Performance | main push、所有 PR、手动 | Android API 35 Pixel 6 x86_64 模拟器 Profile 性能测试；30 次采样、2 次预热；下载最近成功 main 基线；交互式 HTML、JSON、Markdown、报告 PNG 与原始帧数据；同仓库 PR 更新报告评论 |
| `pr-agent.yml` / PR Agent Review | 同仓库非 Bot PR 的 opened/reopened/ready_for_review/synchronize | 沿用源项目固定版本 PR Agent 的自动审查和建议配置 |
| `release.yml` / Release Mobile | main push 的 CI 成功后、手动 | 按 pubspec 版本判断发布；正式签名 Android 分 ABI APK、AAB，可选 Google Play 内部测试上传；仅 iOS 签名配置齐全时打包签名 iOS IPA、可选 TestFlight；所有启用的平台成功后生成提交说明并发布 GitHub Release |

不迁入 `build-web.yml`、`deploy-web.yml`：不构建／部署 Flutter Web，也不部署私钥导出站点。原项目专用的 API 合约、App Review、Android 认证 Activity 回归、Rive FFI 导出和 Sentry 上传没有对应的 Vanta 实现，不保留这些无效检查，也不为它们新增产品依赖。签名凭据仅用于原生发布，不是钱包私钥导出功能。

## 本地 make 与 .env

本地使用 `cp -n .env.example .env` 后填写公开 ID，运行 `make env-check`、`make run FLUTTER_ARGS='-d <device-id>'`；构建入口为 `make build-apk-debug`、`make build-apk`、`make build-appbundle`、`make build-ios`（macOS／Xcode，无签名）。可用 `ENV_FILE=.env.staging` 切换配置。所有入口先校验 `.env`，仅允许四个公开应用配置项，不执行文件内容或插值，也不输出配置值。签名环境变量仍由 shell／CI 单独提供，不能放入编译用 `.env`。参考项目的 URL scheme 同步不需要迁入：Vanta 使用固定 `vanta://wallet`。

本地 `.env` 不自动上传为 GitHub Variables／Secrets；CI 继续从下表的仓库配置读取，不依赖开发机文件。

## 仓库配置

在 `vanta-mobile/interface` 的 **Settings → Secrets and variables → Actions** 中配置；不会读取开发机上的签名文件或 `config/privy.local.json`。质量检查、Android 开发签名构建和性能测试不需要发布凭据；iOS 无签名 CI 本身不使用签名密钥，但仅在检测到完整 iOS 签名配置时启用。

iOS CI 和 IPA 发布通过共用的 `ios-configuration.yml` 自动检测，无需额外开关。以下四项全部未填时跳过 macOS 构建和 IPA，Android 可独立发布；全部填齐时自动启用；只填部分会明确列出缺项并使检查失败，避免误以为已发布 iOS：`APPLE_TEAM_ID`、`IOS_DISTRIBUTION_CERTIFICATE_BASE64`、`IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`、`IOS_PROVISIONING_PROFILE_BASE64`。空白字符视为未填，检测日志只显示配置名，不输出值，也不解码或保存凭据。检测任务不 checkout／执行 PR 代码，fork／Dependabot PR 跳过检测与 iOS 构建。

`APP_STORE_CONNECT_*` 三项仅控制 TestFlight 上传，全部不填仍可打包 IPA；部分配置则在发布时失败。本地 `make build-ios` 保留显式手动无签名入口，不依赖这些仓库签名配置。

| 类型 | 名称 | 用途 |
| --- | --- | --- |
| Variable | `PRIVY_APP_ID`、`PRIVY_CLIENT_ID`、`REOWN_PROJECT_ID` | Release Mobile 必填，当前应用实际使用的公开编译参数 |
| Variable | `WALLET_LOGIN_ORIGIN` | 可选，默认 `https://app.vanta.exchange`；仅允许无凭据的 HTTPS origin |
| Variable | `APPLE_TEAM_ID` | 仅启用 iOS 发布时必填，10 位 Team ID |
| Variable | `OPENAI_API_BASE` | PR Agent 的模型接口地址，按所用服务配置 |
| Secret | `OPENAI_KEY` | PR Agent 接口密钥 |
| Secret | `ANDROID_KEYSTORE_BASE64` | Android 发布 keystore 的 Base64 |
| Secret | `ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD` | 对应 keystore 的密码、别名和密钥密码 |
| Secret | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | 可选 Google Play 内部测试上传：服务账号密钥文件的完整原始 JSON 文本，不是 Base64。未填／只有空白时跳过；非空但格式不合法或上传失败时发布失败 |
| Secret | `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | 仅启用 iOS 发布时必填，含匹配私钥的 Apple Distribution `.p12` 的 Base64 |
| Secret | `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | 仅启用 iOS 发布时必填，`.p12` 导出密码 |
| Secret | `IOS_PROVISIONING_PROFILE_BASE64` | 仅启用 iOS 发布时必填，明确授权 `exchange.vanta.app` 的 App Store Connect distribution profile 的 Base64 |
| Secret | `APP_STORE_CONNECT_KEY_ID`、`APP_STORE_CONNECT_ISSUER_ID`、`APP_STORE_CONNECT_PRIVATE_KEY_BASE64` | 可选 TestFlight 团队 API Key；最后一项为下载的 `.p8` 的 Base64。三项全部不配置时跳过上传，部分配置则失败 |

发布缺少必填配置会明确失败，不会以调试签名替代正式发布。CI 的 Android 验证 APK 使用开发签名且无钱包配置，产物名明确标记 `development-signed`。本地未提供任何签名环境变量时仍可做开发签名构建；只提供部分变量会在 Gradle 配置阶段失败。

Android 凭据从 Secrets 解码至 runner 临时目录并在 `always()` 步骤删除。iOS 使用临时 Keychain，规范化 OpenSSL 3 PKCS12 编码；校验证书与描述文件身份、Bundle ID、Team ID、有效期、分发类型及禁用调试权限；成功或失败均清理密钥并恢复 Keychain 列表。Vanta 当前不要求源项目的 Apple 登录／Passkey 域名／APNs entitlement。

GitHub Release 含 `vanta-android-arm64-v8a.apk`、`vanta-android-x86_64.apk`、`vanta-android.aab`、`vanta-android-mapping.txt`；启用 iOS 且构建成功时另附 `vanta-ios.ipa`。Dart 混淆符号和 iOS dSYM 单独保留为 `debug-symbols-*` Actions artifacts（30 天）；安装产物为 7 天。AAB 必须通过签名非 Debug、bundletool 结构、64 位 ELF 段及生成 APK 的 16 KB 对齐校验；bundletool 下载固定版本和 SHA256。

## iOS 设备支持与发行地区

iOS 的 Debug／Profile／Release 构建均使用 `TARGETED_DEVICE_FAMILY = 1`，仅声明 iPhone 原生支持，不提供 iPad 原生适配；保留 iPhone 竖屏和两个横屏方向。iPhone 应用仍可能在 iPad 上以兼容模式运行，设备族设置不等于禁止所有 iPad 安装。

`Info.plist` 与参考项目保持一致，设置 `ITSAppUsesNonExemptEncryption = false`，声明不使用非豁免加密。这不是地区限制；如果以后变更加密能力，应重新核对声明。

发行要求：**不在法国上架**。实际销售范围必须在 App Store Connect 设置，Xcode／Info.plist／IPA 导出配置和 TestFlight 上传都不会自动排除法国。本仓库当前没有修改商店地区的自动化。

发布前进入 App Store Connect → Apps → Vanta → Pricing and Availability（定价与销售范围）→ App Availability。首次设置时点击 Set Up Availability，选择 Specific Countries or Regions，仅勾选所需地区并排除 France（法国）；已有地区设置时点击 Manage → Manage Availability，取消 France 并保存。确认页面的可用地区不含法国，之后调整范围时继续排除。本地源码配置和构建通过不代表该远端设置已生效。

参考：[Apple：管理 App 的可用地区](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store)。

## Google Play 内部测试

首次配置：

1. 在 Play Console 创建包名为 `exchange.vanta.app` 的应用，启用 Play App Signing，并先手动上传一个正式签名 AAB，完成 Console 要求的应用／测试发布设置。现有 `ANDROID_*` Secrets 必须对应 Play 登记的上传密钥。
2. 在 Google Cloud 项目启用 **Google Play Android Developer API**，创建服务账号并下载 JSON 密钥。在 Play Console 的 **用户和权限** 中邀请服务账号的 `client_email`，授权此应用的查看信息及向测试轨道发布版本权限。
3. 将下载文件的完整 JSON 内容保存到仓库 **Settings → Secrets and variables → Actions → New repository secret**，名称为 `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`。不要提交 JSON 文件或将其放入编译用 `.env`。
4. 在 Play Console 的 **测试 → 内部测试** 配置测试人员名单／Google 群组，并向测试人员提供加入测试的链接。

配置后不需要额外开关。仅当 `Release Mobile` 判断需要发布**新 Tag**，且目标分支为 `main` 时，Android 构建、签名／结构／16 KB 校验及 artifact 保存成功后，才检查凭据并上传 `vanta-android.aab` 和 `vanta-android-mapping.txt`。手动触发仍遵守相同条件；非 main 预发布及仅工作流变更的重建不上传。可以在 main 使用 `1.0.1-rc.1+2` 这样的预发布版本。

上传 Action 固定 commit，包名固定为 `exchange.vanta.app`，轨道固定为 `internal`（内部测试，不是内部应用分享），状态为 `completed`，`changesNotSentForReview=false`。上传被接受后仍需等待 Google 处理，首次版本或其他变更可能需要审核；不自动回退成草稿或绕过审核。若 Console 要求先手动完成应用设置，工作流会失败并保留已生成的 artifacts。

每次上传都必须使用高于既往上传值的 `versionCode`，即 `pubspec.yaml` 中 `+` 后的正整数；同时要更新 `+` 前的版本名以生成新 Tag。例如从 `1.0.0+1` 改为 `1.0.1+2`；只改成 `1.0.0+2` 会因 `v1.0.0` 已存在而跳过发布。Google Play 拒绝重复 versionCode；若上传已被接受、后续 GitHub Release 发布失败，重跑前先核对 Console，必要时递增版本重新发布。

凭据结构验证失败只显示固定错误及字段名，不回显密钥。JSON 仅以目录 `0700`／文件 `0600` 保存到 runner 临时目录，`always()` 步骤负责清理，不进入安装包、仓库或 artifacts。未配置凭据时仍可正常发布 GitHub 安装包；配置后上传失败会使 Android 任务失败并阻止 GitHub Release，已保存的 Android artifacts 可用于排查。

参考：[服务账号与 API 配置](https://developers.google.com/android-publisher/getting_started)、[内部测试设置](https://support.google.com/googleplay/android-developer/answer/9845334)。本地测试只验证配置、文件权限、清理及工作流定义；实际凭据权限、签名身份、Google 审核和测试人员安装须在仓库配置后验收。

## 版本与权限

- 版本采用 `1.0.0+1` 或 `1.0.1-rc.1+2`；Tag 为 `v1.0.0`，增加 build number 本身不会创建新 Tag。正式版只允许 main；其他分支手动发布必须带预发布后缀。已存在 Tag 不重复发布；仅发布工作流变更时允许重建产物。
- 自动发布只接受本仓库 main 的 **push CI 成功**事件，PR 检查完成不触发带凭据的构建。发布固定 checkout 该次 CI 的 SHA。
- 质量和构建默认只读。性能评论仅同仓库 PR 获得写权限；PR Agent 排除 Fork 与 Bot，固定 Action commit。这里只迁入工作流定义，未执行外部评论或发布。
- Actions 需允许 PR 评论；PR Agent 需要上述模型配置。首次 push 这些文件后才能在 GitHub 运行，不能把本地验证当作远程 Actions 已通过。

## 性能测试边界

复用真实 Vanta 界面，固定 100 个行情列表项和 200 根 K 线，测试交易页、列表加载／滚动、切币，以及市价／限价买卖的表单访问、输入估值、确认、演示提交和限价取消，共 26 项。表单常驻页面，因此 form access 测量滚动到可操作输入及滚动完成，不假定存在原项目的交易弹层。使用全新 Riverpod 容器、本地演示账户和内存通知；访问真实行情 transport 会导致场景失败，钱包配置固定为空，不初始化 SDK、签名或真实订单。

结果只描述受控数据下的原生渲染和本地操作，不代表网络延迟、真实交易执行或真机性能。报告只有设备／SDK／视口／采样／场景版本等兼容时才比较基线；软件 GPU 的 raster 时间只作诊断。相对退化超过 20% 且超出对应绝对阈值、慢帧率增加超过 5 个百分点时显示警告，默认不使工作流失败；可用 `--fail-on-regression` 启用报告门禁。首次没有基线会明确显示无法比较。

本地运行（仅在准备好并允许使用原生设备时）：

```sh
flutter pub get
flutter test test/performance/performance_scenarios_test.dart
node scripts/run-performance.mjs --device <android-or-physical-ios-device-id>
node scripts/performance-report.mjs
node scripts/performance-screenshot.mjs
```

最后一条命令需要 Chrome／Chromium，只打开生成的独立 HTML 报告，不运行或部署 Flutter Web。iOS Profile 需要真机，拒绝 simulator。当前阶段继续遵循项目文档的安排，不启动本地设备工具或安装 APK；实际原生采样与报告截图留待 CI 验证。

## 本地检查

```sh
python3 -m unittest discover -s scripts -p '*_test.py'
node --test scripts/performance-report.test.mjs
# 安装了 actionlint 与 shellcheck 时
# actionlint
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
dart analyze --fatal-infos
flutter test
flutter build apk --release --target-platform android-arm64
```

Nix 的 Flutter SDK 在只读 `/nix/store` 内，Gradle 9 要求插件工程目录可写。`android/settings.gradle.kts` 沿用参考项目的适配，仅在此环境将 SDK 自带 `integration_test/android` 复制到被忽略的 `android/.gradle/flutter-sdk-plugins/<SDK hash>/`；普通 CI SDK 不触发该分支，不修改全局 SDK 或 Pub 缓存。

本次本地 AAB 验证还遇到 Nix `apkanalyzer` 的工具根目录指向拆分 SDK、无法找到 Build Tools 的问题。验证命令临时设置 `APKANALYZER_OPTS="-Dcom.android.sdklib.toolsdir=$ANDROID_HOME/cmdline-tools/22.0"` 后完整构建成功；未修改 SDK、全局配置或为正常 GitHub runner 增加绕过检查。
