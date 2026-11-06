## 当前验收安排

## 2026-11-06 iOS 仅支持 iPhone 与法国发行范围说明

对照`/data/dodo/rwa-interface`最近的`38d2da6`（`fix(ios): target iPhone only and declare encryption exemption`），Xcode项目的Debug／Profile／Release均将`TARGETED_DEVICE_FAMILY`从`1,2`改为`1`，由Runner继承，仅声明iPhone原生支持。移除`Info.plist`的iPad专用方向配置，保留iPhone竖屏及左右横屏；未通过锁定方向实现设备限制，也未改动现有响应式界面。iPhone应用仍可能在iPad上以兼容模式运行，不声明iPad原生适配不等于禁止所有iPad安装。

与参考项目保持一致，增加`ITSAppUsesNonExemptEncryption=false`，声明不使用非豁免加密。该字段不是地域限制，不会使法国商店自动不可用。法国不上架是本项目的发行要求，必须在App Store Connect的Pricing and Availability → App Availability中设置具体国家／地区并排除France；首次设置与修改已有范围的路径已写入[发布文档](ci.md#ios-设备支持与发行地区)。本次只修改仓库配置，没有操作App Store Connect，远端地区限制仍待发布方保存并核对。

配置校验已通过：Info.plist可解析，加密字段为布尔false，三个构建配置均为设备族1，无iPad方向覆盖，保留原有iPhone方向。现有Python发布／构建工具48项测试中47项通过，1项macOS Keychain专项因Linux跳过；没有新增重复配置内容的测试。本次无Dart或UI变更；Linux无macOS／Xcode，不能构建或查看iOS原生布局。原工作区存在同时开发的主下单代码，初次格式检查发现其中1个文件需格式化，静态分析与Android构建因`MainOrderPercentageControl`尚未接收表单传入的`unit`／`manualCheck`参数失败；本轮未修改这些文件。使用已提交版本`f26b305`加本次iOS改动的隔离副本验证，853个Dart文件格式检查零改动，`dart analyze --fatal-infos`通过；Android Release构建尝试及重试均因SDK自带CMake Ninja执行`--version`时发生Segmentation fault失败，未修改全局SDK或项目Android配置，不能声称本轮Android构建通过。

## 2026-11-06 数字变化动画与数值格式化组件迁移

从 `/data/dodo/rwa-interface` 迁入以下公共能力，保持原类名、方法参数和默认展示规则，无新增依赖：

- `lib/core/motion/animated_number_text.dart`：`AnimatedNumberText`、`NumberTrend`、`compareFormattedAmounts`。只滚动变化的字符，默认700ms，使用等宽数字并在结束后恢复普通Text；支持自定义方向、比较值、时长、跳过首次变化、自动换行及系统减少动态效果设置。列表应按业务实体设置Key。
- `lib/core/formatters/token_amount_formatter.dart`：自适应小数、千分位、USD、固定USD位数、百分比、K/M/B/T、代币单位、最小单位BigInt换算、固定输入精度及USD求和；保留源项目逗号分组与小数点规则。小于1的非零值从首个非零小数位起保留最多六位，展示舍入采用绝对值四舍五入。百分比输入本身为百分点，不自动乘100。
- `lib/core/formatters/decimal_text_input_formatter.dart`：无符号十进制输入限制，拒绝非法字符与会覆盖未编辑尾数的溢出插入，粘贴时截断超出小数位并保持光标有效。
- `lib/core/domain/decimal_value.dart`：格式化器依赖的不可变精确小数字符串模型，保留资产、单位和scale校验。传入普通十进制字符串，不接受科学计数法、NaN或Infinity。展示与求和使用字符串／BigInt，不经过double；现有订单金融计算继续使用decimal包。

迁移时修复格式化值比较的边界：统一K/M/B/T倍率后比较，保证`1000K`与`1M`相等、负零与零相等且超出double精度的变化方向正确；同时识别USD输出的`$-1.20`和compact输出的`-$1.2K`。显示文本相同而comparisonValue更新时保留最新比较基准。滚动期间对读屏提供一个完整新数值，隐藏各轮的旧／新字符。

使用示例：

```dart
import 'package:vanta/core/domain/decimal_value.dart';
import 'package:vanta/core/formatters/token_amount_formatter.dart';
import 'package:vanta/core/motion/animated_number_text.dart';

AnimatedNumberText(
  TokenAmountFormatter.formatUsdFixed(DecimalValue('182.45')),
);
```

本次提供可直接导入的组件与工具，没有将现有业务页面的格式规则批量替换；固定金融输入格式`formatFixed`遇到非零超限小数仍拒绝，不会静默舍入订单数量。原组件与工具测试已同步迁入`test/core`，并增加跨后缀倍率、USD负号、读屏、零时长、比较基准更新及窄屏放大文字回归覆盖。55项专项单元／Widget测试通过，8个新增Dart文件格式检查零改动，新增文件静态分析无问题。

已在Android 15 x64模拟器用独立预览检查静止／滚动状态、放大文字和横屏，截图位于本地`build/verification/numeric-components/`；预览程序不接入账户或网络，验收后已卸载，未安装主应用。最终全项目`dart analyze --fatal-infos`通过。原工作目录Android构建遇到生成的插件注册代码引用未参与Release编译的integration_test；使用隔离工作区快照重新生成构建文件后，`make build-apk`通过，未修改原生配置。arm64 Release APK存于本地`build/verification/numeric-components/app-release.apk`，SHA256为`b21b46359680d82a532b928f60c2f078db277d18e52c50c92e24b63c1788507b`。Linux无macOS／Xcode，iOS构建未验证。

## 2026-11-05 README 精简与 Actions 失败修复

README 仅保留项目简介、本地运行、检查构建和文档入口，移除参考项目来源、逐轮进度及历史验收流水账。

检查 GitHub 的 CI `42013630852` 与 Native Performance `42013630787` 失败日志：前者因 `live_order_capacity.dart`、`live_order_opening_cost.dart` 未格式化退出，后者因 `rational` 未声明为直接依赖触发 `depend_on_referenced_packages`。源码使用统一格式，`pubspec.yaml` 和 lockfile 将已锁定的 rational 2.2.3 声明为直接依赖，无依赖版本升级。本轮提交仅包含格式和 CI 修复，其他正在开发的额度计算改动保持未提交。性能工作流的格式检查扩展到 `lib test integration_test test_driver`，与 CI 一致，不放宽任何质量检查。

本地工作区（含未提交的额度开发改动）已通过全目录格式检查（859 个 Dart 文件零改动）、`dart analyze --fatal-infos`、全量 4272 项 Flutter 测试、Python 工具测试（47 项通过、1 项 macOS 专项在 Linux 跳过）、12 项性能报告测试、actionlint 1.7.12 全工作流检查及 Android arm64 Release APK 构建。

本次没有 UI 变更，未安装 APK 或进行真机操作。当前为 Linux，无 macOS／Xcode，未重新构建 iOS；上述旧 CI 中 Android Release 与 iOS 未签名归档均已成功，Release Mobile 因质量检查失败跳过。本地通过不代表远程工作流已经重跑成功。

## 2026-11-05 Google Play 内部测试自动上传

`Release Mobile` 在 main 新版本的 Android AAB 正式签名、结构／16 KB 校验及 artifacts 保存成功后，按 `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` Secret 自动启用 Google Play 上传。未填／只有空白时明确跳过；非 main 预发布、既有 Tag 或仅发布工作流重建不上传。固定包名 `exchange.vanta.vanta`、轨道 `internal`、状态 `completed`，一并上传 R8 mapping，Action 固定到 v1.1.3 对应 commit。配置错误或上传失败使 Android 发布失败并阻止 GitHub Release；已保存的安装产物仍可下载。

新增标准库脚本校验原始服务账号 JSON 的类型、必填字段、Google OAuth endpoint 及 PEM 边界，不输出凭据值；不在本地验证真实密钥／权限。目录 `0700`／文件 `0600` 仅位于 runner 临时目录，成功、失败均由 `always()` 清理，不进入应用、仓库或 artifacts。README 及 `docs/ci.md` 记录 Play Console 首包／签名设置、API／服务账号授权、测试人员名单、Secret 配置及版本规则：versionCode 递增，版本名前缀也需变化以触发新的 Tag。Google 接受上传不代表处理／审核或测试人员安装已完成。

新增5项凭据工具测试，覆盖缺失／空白、有效原始 JSON／文件权限、不合法 JSON／Base64／缺字段／错误账户类型／endpoint／PEM 拦截且不泄露值、输出失败后的清理及已有文件保护。Python 工具48项中47项通过，1项 macOS Keychain 专项因 Linux 跳过；release／CI／iOS 配置三个工作流通过 actionlint 1.7.12，Python 编译通过。Dart 全目录842个文件格式零改动，静态分析无问题，全量4088项 Flutter 测试通过。

使用现有 `.env` 执行 `make build-appbundle`，Android arm64／x64 Release AAB 构建成功（69.7 MB）；沿用 `docs/ci.md` 已记录的本地 Nix `APKANALYZER_OPTS` 工具根目录兼容配置，不修改 SDK 或凭据。固定 SHA256 的 bundletool 1.18.2 验证 AAB 结构、PAGE_ALIGNMENT_16K 及8个原生库 ELF 段通过；生成的两个 ABI APK 通过 ELF／zipalign 16 KB 检查。本地产物校验不代表 CI 正式签名或 Google 接受上传。

本轮仅新增发布工具与文档，没有原生 UI 变更，未启动设备工具或安装应用，未请求钱包签名／金融接口。未配置或使用真实 Google 凭据，也未触发远程 Actions／Play／GitHub 发布；真实授权与测试人员安装留待仓库配置后验收。Linux 无 macOS／Xcode，iOS 未构建。

## 2026-11-05 实盘下单模式入口

按[Futures PRD](https://app.notion.com/p/409080d974e780188a4fedfdcf29e655)的3.2／3.4接入统一模式入口，可在登录或显式读取账户之前浏览。首访限价，更多收起，记忆限价止盈止损；限价／市价用可换行选项，其余七项在SafeArea可滚动菜单中列出。六种普通模式复用原表单，Scaled进入独立确认／日志流程；Chase缺原策略恢复及订单关联协议、TWAP按用户要求本阶段跳过，显示双语不可用原因并禁用，绝不回退成普通LIMIT。

开仓页移除原来分散的条件／跟踪开关及重复市价／限价选择，展示所选模式的必需字段。独立仓位平仓和仓位条件单保留原专用控制。Post Only固定GTX且不可改有效方式；刷新后不支持GTX则保留输入并阻止确认，用户须明确选择另一模式，不静默改为GTC。初访数量／触发／跟踪输入仍空、USDT单位、Last限价预填、Mark依据、保护关闭沿用已验证规则。切换保留用户已编辑的共享原始输入与休眠可选值，现有draft规则排除不适用字段；离开Post Only按新模式用GTC，其他限价策略的市价往返保留。

模式及更多记忆只在当前页面会话保存；刷新、取消菜单和语言切换不重置。身份id／地址／钱包类型／签名能力变化回到Limit／Stop Limit，原表单继续清空输入。菜单结果由拥有页面重新检查mounted、认证忙碌、下单忙碌／未知、设置锁及恢复阻塞；ListView回收入口不丢失选择，离页旧回调无效。选择本身不读取私有账户、签名、创建钱包或提交。当前EOA／已有Privy及原有财务Decimal逻辑不变。

新增domain模式分类及独立本地化入口组件，无新依赖／传输／财务浮点。现有长screen／form build已复核：价格、触发、跟踪、附加保护与新入口组件独立，表单文件仍小于400行，保留既有草稿编排。新增49项（领域18、Widget31），专项156项／全量4088项通过；842个Dart文件格式零改动、静态分析无问题，中英文各1669条。覆盖六模式×EN／ZH窄屏放大／横屏／平板的实际选取、默认值、独立确认和精确提交参数；未登录九项菜单／禁用行为、Scaled独立路由、刷新／语言／身份、忙碌旧回调、入口回收与离页。原有协议／恢复断言保留，只将开仓操作迁移到实际新入口；GTX不可用后改为显式切模式，平仓控件不改。

`make env-check`／正常`make build-apk`通过，不输出配置值、不创建替代配置、不使用--no-pub或手改插件registrant。Android arm64 Release为45840644字节，SHA256 `2d5b9e9c24c8ed34e4f7cc2f1cd38ed6a50e36355ff11b01aa3ca45851c24a32`，包内菜单标识及实际双语文案已核对。见 [来源与边界](reference/order-mode-entry-public-contract.json) 与 [验证记录](reference/order-mode-entry-verification.json)。未安装APK，未用设备工具或请求真实签名／私有／资金／聊天／带地址RPC；Linux无macOS／Xcode，iOS未构建。开仓比例滑杆、BBO关闭时的预设控件及自定义滑点仍未完整对齐，完整策略管理、Chase、跨产品Portfolio和Swap继续推进。

## 2026-11-05 Privy 子账户创建限制

最新[账户PRD](https://app.notion.com/p/408080d974e7803f8710f5e688c0d103)（编辑于2026-11-05T07:56:29.767Z）明确只有外部EOA登录可创建子账户，Privy托管登录不得创建。按当前认证身份的walletKind判断，绑定邮箱不影响外部EOA资格，单纯连接另一钱包也不改变托管登录资格。页面保留禁用的创建选项并展示双语原因，不自动选中冻结／划转；应用层准备／确认及仓库准备／提交均在签名、HTTP或日志写入前独立拦截。

其他操作继续由Aster核验主账户与签名资格，不扩大禁止范围。切换使用独立地址输入及原有确认／重登流程，避免禁用创建字段后阻碍切换。身份id／地址／钱包类型／签名能力及认证忙碌变化使旧代次失效，停止等待或切回相同EOA也不能复活旧回调；输入／子签名清空、旧创建挑战及确认隐藏。保留原有子EOA外部签名、最多10个、签名前后新读master资格及45秒有效期、发送前日志和未知阻塞。创建不生成／返回私钥，此PRD要求与官方响应的冲突仍按既有边界记录。

沿用Widget→Riverpod→repository→service，提取动作选择组件和domain资格函数，既有长管理页build经复核保留表单编排；无新增HTTP／财务逻辑或依赖。新增40项（协议16、控制器16、Widget8），专项121项／全量4039项通过，837个Dart文件格式零改动、静态分析无问题，中英文各1661条。测试覆盖不触发签名／网络／日志的拦截、伪造托管review与有效子证明、带邮箱EOA、恢复但未连接的EOA、托管冻结／解冻与8种划转组合，以及两阶段身份变化和EN／ZH320宽放大文字／横屏／平板、列表读取／独立切换入口。

使用现有.env验证及正常`make build-apk`，未读取／输出配置值，不创建替代配置、不手改插件registrant。Android arm64 Release为45840644字节，SHA256 `efc261dd3ca52a6112b9aaa6c47245905d3a27360a28c93a0781a75665e390c6`；包内限制文案及新切换标识已核对。见 [来源与边界](reference/subaccount-creation-access-public-contract.json) 和 [验证记录](reference/subaccount-creation-access-verification.json)。

APK未安装，未使用设备工具、真实钱包签名、私有／资金／聊天或带地址RPC。按用户要求只记录真机待测；Linux无macOS／Xcode，iOS未构建。真实Aster同EOA signer资格、创建／冻结／划转接受性及原生回跳／布局仍未验收。完整策略管理、九模式入口／部分设置、Chase、完整Portfolio及Swap继续推进，整体PRD未完成。

## 2026-11-05 iOS CI 与发布按需启用

按用户要求自动依据配置决定是否打包，不使用额外开关。`ci.yml` 和 `release.yml` 共用 `ios-configuration.yml`，在 Ubuntu 检测 `APPLE_TEAM_ID`、`IOS_DISTRIBUTION_CERTIFICATE_BASE64`、`IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`、`IOS_PROVISIONING_PROFILE_BASE64`：全部空／空白时跳过 iOS；四项齐全自动启用 macOS 无签名 CI 和签名 IPA；部分填写则只显示缺少的配置名并使检查失败。检测不 checkout／执行 PR 代码、不解码或落盘凭据；fork／Dependabot PR 不运行检测和 iOS 构建。TestFlight 三项仍可全部留空，IPA 不受影响；部分填写沿用发布时失败的检查。Android 发布仍要求原有公开应用 ID 和正式签名配置；本地 `make build-ios` 保留显式手动入口，Privy Android 客户端校验保持。

GitHub Release 条件显式接受 iOS skipped，要求版本判断、配置检测和 Android 成功、工作流未取消；iOS 一旦启用，失败仍阻止发布。发布附件按 iOS 任务结果添加 IPA，跳过时只提交 Android APK／AAB／mapping；不生成占位 IPA，不以开发签名替代正式签名。README 与 `docs/ci.md` 已同步配置说明。

自动检测版本验收：三个工作流 actionlint 通过；直接执行共用 Bash 检测的32种配置情况（16种字段组合分别使用空值和空白字符）通过，覆盖全部不填、填齐、每一种部分填写及日志不泄露值；1024组发布依赖结果组合通过。43项 Python 工具测试42项通过、1项 macOS 专项跳过，26项认证 Flutter 测试通过；837个 Dart 文件格式零改动、静态分析无问题、`make build-apk` Android arm64 Release（45.8 MB）成功。未调用远程 Actions／发布、设备工具、APK 安装或真实钱包操作；iOS 仍受 Linux 无 macOS／Xcode 限制，实际签名校验继续由 macOS 构建任务执行。

此前显式开关版本验证：actionlint 通过；256 组取消／版本／平台结果组合及4组替身 gh 参数检查通过，未进行远程发布；43项 Python 发布工具测试中42项通过、macOS Keychain 专项1项因 Linux 跳过；44项认证相关 Flutter 测试通过；静态分析无问题；`make build-apk` Android arm64 Release 构建成功。lib／integration_test／test_driver 共493个 Dart 文件格式检查零改动。全目录格式检查另发现现有 `test/features/subaccounts/subaccount_management_repository_test.dart` 需要格式化，本轮未修改该无关文件。Linux 无法验证 iOS 构建，未启动设备工具、安装 APK 或进行真实钱包操作。

## 2026-11-05 首屏导航与快捷面板默认值

依据 Futures PRD §3.4，未指定合约、没有历史偏好或草稿时，从主导航首次进入 Futures／K 线／BTCUSDT，展示快捷市价面板。明确选择的合约不会被首访初值重置。以 Riverpod 分别保存主导航和 Futures 页签；底部导航切出／返回、Markets 选币返回和语言切换保留本次页签与交易对，新应用容器恢复初值。其他主目的地只在选中时挂载；Chart／Trade 之间保留各自组件状态，不新增磁盘导航偏好或持久化草稿承诺。

快捷数量首次为空，基础币单位优先用匹配 symbol 的已签名合约规则，否则用已加载的公开合约元数据。缺失／未匹配时显示 —，不通过交易对字符串猜单位。元数据加载与重试不会创建钱包或签名。25%／50%／75%／100% 初始均未选；无有效账户上下文或数量时两个方向均不可提交。快捷数量与主表单／本地演示输入继续独立，现有 MARKET／OPEN、实际账户模式、确认偏好及原编号恢复协议保持。

提取 QuickOrderAccountSettings，杠杆、保证金模式、持仓模式、资产模式及可用 USDT 未读取时均显示 —，显式读取后展示真实值及原有陈旧提醒，余额保留精确 Decimal。PRD 的新户单资产／单向／全仓／10× 不是 Aster 实际账户的证据，页面不会伪造快照或自动修改已有配置。测试使用真实界面读取意图和替身返回的37×、双向、逐仓单资产／全仓多资产及长小数余额，断言无配置写入。私有读取仍由用户显式发起，不因打开导航或切语言弹钱包。

行情头部尚无行情时资金费率倒计时显示 —。快捷买卖参考分别来自当前连接盘口的卖一／买一；加载、失败、离线或断开时显示 —，不使用 Riverpod 保留的旧盘口报价；新事件到来后恢复。自动测试直接构造“切交易对时保留旧值”和“流错误保留旧值”的状态验证，报价只作参考，不作为市价单指定成交价。

提取 FuturesWorkspace、FuturesWorkspaceTabs、底部导航及快捷设置组件；生产文件均低于400行，新 build 方法低于80行。MarketHeader 现有较长组合 build 已复核，本轮只修改其独立 funding 渲染的未知占位；传输仍在服务／repository，财务逻辑仍在 domain／provider。不新增依赖。五个导航标签进入本地化目录，保留选中／按钮语义及至少48高的触控区域。EN／ZH 首访覆盖320宽／1.5倍文字、844×390横屏、768平板与登录／未登录分支。

本轮新增33项 Widget（首访／单位／真实设置21项、导航7项、行情占位5项），相关69项、全量3999项通过。首次全量暴露三项盘口测试仍假定Trade初值、两项认证断言误计背景快捷地址：已改为通过实际页签切换进入盘口，或限定到IdentityPanel，原行为断言保留。新读取测试显式销毁container，清理30秒上下文定时器。格式检查834个Dart文件零改动，静态分析无问题，中英文各1660条消息。

Android使用项目现有 `make env-check`／`make build-apk`，普通Flutter Release命令包含依赖解析，不使用 `--no-pub`，不手改插件registrant。旧 `config/privy.local.json` 已不存在，采用现有 `.env`，没有读取或输出配置值。arm64 APK为45840644字节，SHA256 `08c9a98e6a3de63f53b1dce8253bea88d40a427a0b9dea1aada04c527609cd3a`，包内新增导航／快捷设置标识与双语标签已核对。见 [来源与边界](reference/futures-navigation-public-contract.json) 和 [验证记录](reference/futures-navigation-verification.json)。

按用户要求不使用设备工具、不安装APK、不请求真实钱包签名、私有／资金／聊天或带地址RPC；iOS因Linux无macOS／Xcode未构建。真机切页／回跳／大字体／键盘／读屏与真实设置仍待验收，见 [待验收清单](native-verification-pending.md)。本轮重读最新账户PRD另确认Privy托管登录不得创建子账户，该限制已由上方后续增量补齐并完成自动验证，真实／原生仍待验收。九种模式入口／部分设置、完整策略管理、Chase恢复、跨产品Portfolio及Swap仍未完成；仅历史统计／Summary／TWAP按用户要求跳过，完整PRD目标保持。


## 2026-11-05 Scaled 总金额、分布与首次默认值

本轮对齐 Futures PRD 的分段表单、专用确认与首次输入要求，最新公开产品说明确认最多110笔及Equal／Increasing／Decreasing／Random。匿名官网公开源码确认Difference为1:2:3…、Ratio为1:2:4…数量权重，递减反向，计价币按各实际子单价格加权换算。公开源码的随机幅度、浮点、最低量上调及一处递减权重存在与产品说明或基础币分支不同的行为；Vanta不复制隐性超额或静默丢量，明确客户端取整和尾差规则。来源、SHA256及差异见 [合同](reference/scaled-order-alignment-public-contract.json)。

首次低／高价、总金额和子单数均空，默认BUY／计价币／等量，Difference预设在等量时隐藏。基础币与计价币各自保留原输入；递增／递减显示等差／等比，随机显示0%–10%偏差（默认10%）与显式重新分配。PRD未规定随机算法，本地草稿保存由application生成的公开32位seed，以纯整数采样、配对零和偏差和确定性打乱生成权重；重建、语言切换、prepare、确认校验、逐笔提交和未决恢复均不重抽。最终按LOT取整后的每笔实际数量仍须在实际均值±所选百分比内，否则提示调整总量／偏差／重新分配，不放宽边界。

价格保持含端点、按tick尽量等距且互不重复。基础币按total×weight／sum(weight)计算有理数理想量，在minimum＋k×step网格向下取整；总量必须可表示，剩余步长按小数余量降序、同余量按低价优先分配，精确保留输入总量。计价币按amount×weight／sum(price×weight)计算后逐笔向下对齐，精确名义总额不超过输入，未分配金额单独展示。理想量低于最小量、真实子单最大量／最低名义价值／百分比／资金／权限／LIMIT或GTC能力不满足即拒绝，不通过上调数量或降低最大值来凑单。不乘杠杆，不把委托金额当保证金或最终成交支出上限；gross notional／leverage仍是未扣净额和手续费的参考。

专用确认固定交易对／合约市场、方向、区间、子单数、原输入及单位、实际总量／名义金额、分布及适用常数／偏差。每笔显示LIMIT／GTC、价格、基础币数量、占比、名义金额和独立可复制编号。预览／确认／结果每页10笔，最多110笔均可遍历；结果页跟随新进入执行的子单，但分页不裁剪冻结计划。确认保持必需且没有“不再显示”，打开时切换语言即时更新。模型／纯planner、输入选项、摘要／分页与结果组件分别提取，文件均低于400行、build方法已检查；不新增依赖。

沿用当前EOA或已有Privy，不创建钱包；仍为逐笔独立普通LIMIT/GTC，提交参数只有固定基础币数量／价格／原clientOrderId，不传伪造Scaled字段。每笔新读资金／配置、签名POST及独立原编号GET；价格从低到高，失败／未知／停止／离页／配置变化阻止未发送订单，允许部分成功，不宣称官网同时或原子策略。发前持久化每个子单，重启只查原已发送未决编号，不恢复未发队列；提交和回调同时核对钱包类型／身份／地址／签名能力。确认意图额外拒绝peg篡改，原减仓／条件／trailing／attachment／快捷／非GTC排除保留。

本轮新增97项（领域52、provider6、签名HTTP与持久化恢复24、Widget15），专项165项、完整3966项通过；格式检查824个Dart文件零改动，静态分析无问题，中英文各1659条消息。Android arm64 Release常规命令构建成功，APK45840644字节，SHA256 `7e0bf8146afe72b60db5dbe8c4dad8760154d0ae7d595a8e8e485330f947cf96`，包内双语新增关键文案已核对。完整证据见 [验证记录](reference/scaled-order-alignment-verification.json)。

按用户要求没有真机工具／APK安装／真实钱包签名、私有／资金／聊天或带地址RPC请求；只匿名读取Notion及官网公开文档／静态源码和合成验证。iOS仍需macOS／Xcode。真实Scaled执行、长队列钱包返回及原生布局／存储另记 [待验收](native-verification-pending.md)。完整Portfolio、Swap、Chase恢复、完整策略列表／管理及部分设置仍未完成；首屏导航见上方后续增量，原始PRD目标继续保持。


按用户要求，本阶段不做真机实测，不启动设备工具或安装 APK；继续开发并维护 [原生待验收清单](native-verification-pending.md)。功能变更仍执行格式检查、静态分析、相关自动测试和 Android 构建。iOS 构建因 Linux 无 macOS／Xcode 保留未验证状态。以下历史真机记录仅适用于各次记录的版本和范围，不能作为后续改动的真机验收结果。

## 2026-11-05 make 与本地 .env

参考 `/data/dodo/rwa-interface/Makefile` 增加 `ENV_FILE ?= .env`、`FLUTTER_ARGS` 和 `make run`；增加 Android debug APK、arm64 Release APK、arm64／x64 AAB 和 iOS 无签名编译入口，`make`／`make help` 显示命令。所有运行／构建入口先执行 `make env-check`，随后用 Flutter `--dart-define-from-file` 显式读取选定文件。iOS 仍需 macOS／Xcode，不增加 Web 或私钥导出入口，固定 `vanta://wallet` 不需要同步 URL scheme。

新增 `.env.example`，必填 Privy App ID／Client ID 和 Reown Project ID，钱包 origin 默认 `https://app.vanta.exchange`。标准库校验器复用 CI 的公开配置验证，支持注释、单／双引号、CRLF 和带空格的文件路径；拒绝缺失／空 ID、重复／未知键、畸形行及非 HTTPS origin。文件内容不作为 shell 执行，不做变量插值，错误只输出配置名／行号，不回显值。只允许四个公开应用配置项，签名或 API Secrets 仍使用独立 shell／CI 环境，不编译到应用。`.env` 已忽略，模板允许提交；本次仅在不存在 `.env` 时由已有本地 JSON 的四个公开项初始化，配置值未输出。旧 JSON 调用兼容，GitHub Actions 的仓库 Variables／Secrets 输入方式保持可用。

验收：6 项新增 dotenv 校验回归与既有 CI 脚本测试共 43 项（42 通过，Linux 跳过 1 项 macOS Keychain）；五个 Make Flutter 入口、替代配置路径及额外参数传递、三类无效配置阻止启动的烟测通过。825 个 Dart 文件格式检查零改动、静态分析无问题，身份／认证与性能场景相关 27 项 Flutter 测试通过；实际 `make build-apk` 读取本地 `.env` 后成功生成 Android arm64 Release APK。最初并行执行测试和构建干扰了自动生成的插件注册文件，待测试结束后顺序构建通过，未手工改写生成代码。未运行设备工具、安装 APK、登录、签名或请求真实账户；Linux 无 macOS／Xcode，iOS 入口只验证参数传递，未编译。完整记录见 [验证记录](reference/make-env-verification.json)。


## 2026-11-05 按下单模式保存确认偏好

按 Futures PRD 的确认页及首访配置补齐五类已实现开仓模式：限价（含 Post Only／IOC／Hidden／BBO）、普通市价、条件限价（STOP／TAKE_PROFIT）、条件市价及 Trailing。限价与 Post Only 共用设置，普通市价与 K线快捷开仓共用同一 provider 和存储键。触发方向、买卖、计价／基础币输入或附加 TP/SL 不创建独立偏好；附加保护沿用所属主单模式。专用减仓／全部平仓仍保留独立确认，Scaled 仍保留无“不再显示”的专用确认；尚未实现的 Chase 和用户跳过的 TWAP 未增加空壳偏好或提交能力。

每类缺失设置默认开启确认，保留旧版 `vanta.confirmMarketOrders` 的明确选择，但不扩散到新增模式。页面可关闭或重新开启当前模式确认；每次弹窗的“不再显示”初始未勾选，取消／关闭不保存，只有确认并勾选才关闭该模式后续确认。偏好是当前安装的本地设置，不是交易所权限或钱包绑定。设置按模式独立存储、同模式写入串行；旧读取或旧写入完成不能覆盖新选择，不同模式互不阻塞，销毁后不更新视图。

只有明确关闭、加载完成且无错误时才跳过应用内确认，按钮相应改为签名提交文案。不会省略当前钱包签名、原订单／账户快照校验、30秒期限、原基础币数量／编号冻结、发送前日志或未知结果阻塞。读取／保存失败保留最后已保存的设置并提示，当前会话恢复确认；本次已明确确认的订单在偏好保存失败后仍可按原条款提交一次，继续受原 controller 复核。保存期间刷新账户使旧 intent 无效；确认框打开期间切身份不保存或提交旧选择。未知结果只能按原编号核对。

新 `OrderConfirmationKind` 仅分类模式；Widget → Riverpod 持久偏好 controller → preferences repository → SharedPreferencesAsync，不在组件创建传输客户端，未新增依赖。主表单确认／提交控件已提取，文件362行；确认内容再按账户条款与金额条款拆分，build 方法低于80行。所有新文案来自中英文 ARB。修复主单及快捷确认框打开后切换语言仍保留旧标签的问题；重建文案时保留已勾选状态和冻结 intent。

新增50项（模式／存储／provider29、Widget21），完整3869项测试通过。原有4个附加 TP/SL 确认场景改用默认开启的偏好，保留原金融与恢复断言，另补2项明确关闭时附加保护跟随主模式的验证。818个 Dart 文件格式检查零改动、静态分析无问题，中英文各1632条消息。Android arm64 Release 构建通过，包内五类偏好／不再显示／钱包边界／错误文案双语已核对，未安装。APK45840644字节，SHA256为 `b38f874db639b5aa1d0fe54279b93e4b6b712ed522224d60ec24f18330a468d8`。见 [来源与边界](reference/order-confirmation-public-contract.json)、[验证记录](reference/order-confirmation-verification.json) 和 [进度表](prd-progress.md)。

没有设备工具、APK安装、真实钱包／私有／资金／聊天或带地址RPC请求。按用户要求只记录原生待测；iOS因Linux缺macOS／Xcode未构建。该增量不代表Scaled总金额／分布／初值、首屏导航、完整策略列表、Portfolio／Swap或Chase恢复已完成，整体PRD继续推进。

## 2026-11-05 Futures 订单、逐笔成交和资金流水历史

补齐独立合约历史入口，可从 Portfolio 合约账户和交易页挂单面板打开。三类读取使用官方签名 GET `/fapi/v3/allOrders`、`/fapi/v3/userTrades`、`/fapi/v3/income`，与 Spot 历史、充提历史及用户跳过的私有 BAPI 统计／Summary／TWAP 分开。这里的具体字段与查询约束来自官方 V3 合同，不宣称每个字段都对应 PRD 的明确行。沿用当前 EOA／已有 Privy 钱包的 user=signer、chain1666、共享微秒 nonce，不创建钱包或替代 API signer；实际交易所接受性仍待验收。

页面打开、筛选、语言切换、日期选择和本地翻页均不自动签名。订单及流水允许不填交易对，逐笔成交必须输入精确交易对；流水提供全部及17种官方类型。UTC 日／周／自定义范围在签名前校验，结束不超当前时刻；单次只读取最新一个小于7天的范围。返回1000条时不宣称完整，按含首尾毫秒的范围细分、由用户继续；单毫秒仍满额标明截断。最多保留10000条，超限保留已有数据和待读范围并提示缩小查询。本地每页10条不触发读取；显示交易所保留规则、非原子快照和未查完范围，不能承诺平台未返回或已清理的历史。

不可变模型在 repository 数据边界严格解析 Decimal、编号、时间、方向及状态。撤单后的部分成交仍显示实际执行量和返回金额；Entire close 的计划数量0不掩盖实际成交。缺失金额／均价／单位保持未知，不按显示价乘数量补造。逐笔成交以 fill ID 独立展示，手续费按 commissionAsset、已实现盈亏按原合约 marginAsset 分别显示，不混合净额。流水按 incomeType＋tranId 去重，保留符号和币种，不展示原始 info。订单原类型／当前类型分开，Trailing 忽略 stopPrice，只展示返回的激活价／回调率。引用编号和钱包可复制，时间明确 UTC。公开合约元数据允许非活跃合约，失败不丢签名金额。

跨批合并拒绝不可变金融冲突、同版本矛盾、已成交量下降和终态回退；已知原订单类型不能改变，缺失原类型可由后续返回补齐。有效新版订单按 updateTime 选取。错误保留此前成功数据与查询，身份／地址／钱包种类／签名能力变化清空私有视图；停止、返回和销毁丢弃迟到结果。私有响应返回时即记录时间，不能在慢元数据后重新计时；30秒、账户事件及前后台变化标记陈旧，继续读取不把旧批次刷新为最新。未增加历史持久化、自动重试或后台私有轮询。

链路为 Widget → FuturesHistoryController → SignedFuturesHistoryRepository → AsterAccountService；筛选、结果、卡片和标签分开，抽出共享 HistoryWindow 供原 Spot 历史兼容使用。新增生产文件均低于400行，build 方法及现有服务／夹具的改动已检查边界；未新增依赖，全部文案进入中英文 ARB。

新增139项（映射／领域66、签名repository17、provider24、Widget32），完整3819项测试通过，包含原 Spot 历史、账户／挂单入口和用户流回归。812个 Dart 文件格式检查零改动、静态分析无问题，中英文各1625条消息。Android arm64 Release 常规命令构建通过，包内双语标题／交易对要求／盈亏与保留规则已核对，未安装。APK45840644字节，SHA256为 `ca9320ca7617148f72e37b4f142e81fcad39bd2303d2d0791f4997a911131262`。见 [来源与边界](reference/futures-history-public-contract.json)、[验证记录](reference/futures-history-verification.json) 和 [进度表](prd-progress.md)。

按用户要求继续仅记录真机待测，没有设备工具、APK安装、真实钱包／私有／资金／聊天或带地址RPC请求。Linux无macOS／Xcode，iOS未构建。整体PRD仍未完成，完整Portfolio、Swap、Chase恢复、完整策略列表及部分表单／Scaled／导航细节继续跟踪。

## 2026-11-05 主表单 USDT 委托金额与默认输入

依据最新 Futures PRD 的“开仓数量单位选择”和首访表单，普通实盘开仓默认按计价币 USDT 输入委托金额，数量留空；可切换基础币。两个单位各自保留原始输入，不把金额当保证金，也不乘杠杆。限价使用手填限价换算，普通市价买入使用已读卖一、卖出使用已读买一；所需报价缺失时禁用确认，不用 Mark、Last 或对侧报价代替。纯领域逻辑以有理数保留除法，再按已有数量过滤器的 minimum／step 向下取整；范围、最小名义价值、资金、仓位及交易权限继续由现有校验器检查，不通过截断最大数量绕过限制。

PRD 样例使用合成数据复核：70 USDT ÷ 0.69890，按0.01步长得到100.15 ASTER，参考名义金额69.994835 USDT。普通 LIMIT／MARKET 最终仍只签名提交基础币 `quantity`，不增加 `quantityUnit` 或 `quoteOrderQty`。确认弹窗捕获当时的基础币数量及换算预览；未决日志只保存原编号和冻结的基础币条款，不保存会被后来报价重新解释的预算。未知结果仅查询原编号，禁止改单位或重发；确认期间重读账户快照会使旧确认失效。拒签和取消保留输入。附加 TP/SL 的 PnL／ROI 换算与全主单保护使用换算后的基础币数量。

已有其他模式提供明确标注的本地参考换算：条件市价和条件 BBO 使用触发价，固定条件限价使用手填限价，普通 BBO 使用标记价参考，Trailing 使用用户所选 Mark／Last 快照。沿用已有条件／Trailing 数量过滤器边界。这些是 Vanta 的估算规则，不是 Aster 保证按计价币预算执行的合同；界面与确认展示输入金额、具名参考来源、基础币数量、参考名义金额和 UTC 快照，并说明实际执行金额可能超过输入，不构成支出上限。

首次有效且符合价格过滤器的 Last 只预填限价一次，不用 Mark 或自动修正为另一个价格；先前没有有效 Last 且用户未编辑时，后续首次有效读取可以预填。用户编辑或清空后刷新不覆盖。开仓保留 BUY／LIMIT／GTC；条件与 Trailing 默认 Mark，Trailing 回调／激活留空。专用平仓仍默认基础币，选择平仓比例切回基础币，Entire close 忽略隐藏的金额且不传数量。读取到的真实资产模式、持仓模式、保证金模式和杠杆保持原账户值，不写入产品新用户预设。

新增独立金额领域模型、金额输入／预览和价格输入组件；主表单已检查拆分边界，状态、草稿及附件协调留在表单，传输仍由 Riverpod／repository／service 处理。用户文案加入中英文 ARB。自动测试覆盖精度边界、杠杆独立、缺失报价、独立输入保留、主单／附件数量、冻结签名和日志恢复、过期确认、失败／未知状态及双语320宽／1.5倍文字、横屏和平板。来源与边界见 [合同](reference/order-amount-public-contract.json)。全部九种模式、限价与 Post Only 共用确认偏好、Scaled 分布／首访和导航默认值仍需进一步对齐；自定义滑点还缺执行参数合同，不能宣称已完成。

本轮新增63项（领域43、签名repository5、Widget15），完整3680项测试通过；九个现有Widget测试文件显式选择基础币以保持旧场景含义，缺Last场景显式选择Last。794个 Dart 文件格式检查零改动、静态分析无问题，中英文各1608条消息。Android arm64 Release常规命令构建通过，包内双语金额／基础币／估算边界文案已核对，未安装。APK为45775084字节，SHA256为 `1279e098176b9bc51f19e7be78c383ab3be3e5bc8bdb8dc2acf7240f133eb17f`。完整证据见 [验证记录](reference/order-amount-verification.json)。没有设备工具、真实钱包／私有接口／资金／聊天或带地址RPC请求，iOS仍受Linux环境限制；整体PRD继续推进。

## 2026-11-05 附加策略逐腿成交详情

按最新 Futures PRD（2026-11-05T02:53:35.835Z）补齐“按订单回报显示实际已成交数量、退出单状态和数量”。已知实盘策略状态及恢复结果提供独立详情入口，打开不读取私有数据；用户显式签名后先核对原 clientStrategyId／strategyType，只有 -2013 才转查策略历史，且必须匹配已知 strategyId 及原数量、触发／限价／peg、有效方式和联动关系。随后仅对实际 exchange orderId 逐腿签名查询 `/fapi/v3/order`；无编号保持未知，不查询0，不把原计划数量当成交量。进入路由时固定查询对象，切换语言不丢快照或重新签名。

领域模型区分策略快照与普通订单回报、策略查询时间与逐腿更新时间／查询时间。严格核对 orderId、原 clientOrderId、symbol、side、positionSide、原类型、有效方式及减仓／全平标记；Decimal 解析数量／成交量／cumQuote／avgPrice，校验状态和时间一致性。撤单后的部分成交仍完整展示；可选成交金额／均价缺失时未知，不用数量×显示价补造；未成交均价显示不可用。公开合约元数据包含非活跃合约，用真实基础／计价币显示单位，失败仍保留数值并标明单位未知。当前数量／固定委托价／触发价与原策略不同会提示差异，不当作自动增补证明；条件类型转换或真实成交只作为该腿触发证据，不推断对侧取消。

首个子单拒签、查询失败或数据无效立即停止后续钱包提示，保留已成功的腿并明确标记未读项；重试由用户发起，全部操作只读，不修改余额／仓位、不完成任何未决日志、不撤单或重发策略。沿用连接 EOA／已有 Privy、user=signer、chain1666、共享递增微秒 nonce 和单次50秒签名期限。Riverpod family 按原查询隔离，跨操作租约防并发；停止／销毁只释放自己的租约，旧请求结束不释放新请求。原未决／未知写入及损坏存储的阻塞仍保留。身份、地址、钱包类型或签名能力改变清空私有视图并丢弃迟到结果。

快照从策略读取时起30秒标陈旧，而非从最后一腿读完计时；账户事件、配置提交、时钟倒退及前后台变化都要求重新读取，读取期间进入后台也不返回“最新”。页面不后台轮询／签名。控件与结果拆成独立组件，文案均来自 ARB；编号可复制，含安全错误、部分读取、停止／重试与历史提示。

新增88项（映射41、签名repository18、provider17、Widget12）；完整3617项通过，包含独立CI增量原有1项及此前3528项基线。实盘和旧／新恢复页8项现有用例增加实际导航与原数量保持断言。787个 Dart 文件格式检查零改动、静态分析无问题，中英文各1593条消息。Android arm64 Release 构建成功，包内双语详情和实际成交文案已核对；未安装。先前 Profile 构建残留测试插件注册文件导致 `--no-pub` 构建失败，改用常规 Release 命令重新生成平台注册文件后通过，不手改生成代码或增加生产依赖。

来源与验收见 [合同](reference/strategy-execution-public-contract.json) 和 [验证记录](reference/strategy-execution-verification.json)。仅公开 Notion／缓存文档与合成HTTP／钱包／Widget验证；没有真实钱包、私有／金融／聊天、地址RPC或设备操作，iOS仍需macOS／Xcode。完整策略列表／编辑／整体撤销、合约历史、完整Portfolio、Swap及最新表单单位／默认值等仍未补齐，真实分批增补／互撤与原生继续待验收，整体PRD未完成。

## 2026-11-05 CI 迁移与原生发布

参考 `/data/dodo/rwa-interface` 迁入并适配质量检查、原生性能测试、PR Agent 和移动端发布四个工作流；排除 Flutter Web 构建／部署及私钥导出站点部署。Flutter 固定为本项目 3.47.4；公开编译参数仅使用 Privy／Reown 和钱包 origin，不依赖原项目的 API、App Review、Sentry 或 Passkey 配置。完整触发、版本、权限、产物和凭据说明见 [CI 文档](ci.md)。

Android 增加环境变量生产签名，缺少部分签名变量时明确拒绝；本地无变量与 CI 验证 APK 使用明确标识的开发签名。发布产出 arm64／x64 APK、AAB 和 R8 mapping；校验签名非 Debug、bundletool 结构、ELF 和生成 APK 的 16 KB 对齐。iOS 迁入临时 Keychain／PKCS12 兼容处理、App Store 分发 profile／Bundle ID／Team／身份验证、可选 TestFlight 与凭据清理，移除本项目不存在的 Apple 登录／Passkey／APNs／Rive 专用要求。Dart 符号与 iOS dSYM 单独保留；本地签名文件加入忽略列表，不读取或迁移本地真实凭据。自动发布仅接受本仓库 main push 的成功 CI，并 checkout 该次 SHA；正式版只允许 main，现有 Tag 不重复发布。

原生性能测试增加 SDK `integration_test` 开发依赖及独立测试入口，不修改生产入口。固定 100 合约、200 根 K 线、内存通知及空钱包配置，覆盖真实页面加载、列表滚动／切币，以及四种演示买卖表单／估值／确认／提交、限价取消共 26 项；禁止真实行情 transport 初始化。帧数据仅由原生 Profile 运行采集，Widget 测试只验证场景完整性和预热排除，不能代替性能测量。CI 使用 Android 模拟器，软件 GPU raster 仅作诊断；兼容 main 基线比较、HTML／PNG 报告和 PR 评论沿用参考项目。Nix 只读 SDK 下沿用参考项目的 Gradle 9 插件目录复制适配，常规 runner 不触发。

本地验收：格式检查（最终 789 个 Dart 文件，无改动）、静态分析（无问题）、3,617 项全量 Flutter 测试、26 场景预热／采样回归、12 项性能报告测试及发布／配置／AAB 工具的 37 项 Python 测试（36 通过，macOS Keychain 实测 1 项因 Linux 跳过）通过；Actions 工作流与内嵌 shell 经 actionlint／shellcheck 校验。Android arm64 Release、临时测试证书签名的 arm64／x64 分包及混淆 AAB 构建成功，实际 AAB 通过签名身份、结构、8 个 64 位原生库 ELF 与生成 APK 的 16 KB ZIP 对齐检查。独立性能入口的 x64 Profile APK 也已编译通过，未安装或采样。临时测试签名密钥已删除，未使用生产证书。Nix apkanalyzer 根目录问题通过本次命令环境变量修正，未关闭任何产物校验。

工作区并行功能更新全部保留；补跑时停止了加载旧版策略 Widget 测试的过时进程，当前该文件单独 10 项及最终全量 3,617 项通过。额外仅机械修正新增测试中的两个多余导入和两处缺少大括号的 if，未改变测试行为。构建产物按验证记录中的各自哈希标识，不替代之后功能改动的构建验收。

实际设备采样、性能报告截图、macOS iOS archive／IPA／Keychain 与远程 GitHub Actions、正式凭据和 TestFlight／GitHub Release 均未执行验收。继续遵循当前阶段不启动本地设备工具、不安装 APK 的安排。详细机器可读结果见 [验证记录](reference/ci-migration-verification.json)。


## 2026-11-05 附加 TP/SL 输入、退出方式、数量与联动

按最新 Futures PRD（2026-11-05T01:34:20.212Z）对齐主单附加保护。两腿默认 PnL／Mark，各自保存 PnL、触发价及 ROI 的原始输入；止盈正数、止损负数，空值或必要数据缺失显示未知并阻止确认。修改主单数量、方向、参考价或杠杆后重新解析，不把上一次换算价当作输入。专业模式默认关闭／市价，开启后两腿独立选择市价、手动限价或触发价等价的自动限价；关闭后保留隐藏输入，但不让其进入提交。取消确认、读取刷新、明确失败或未决均保留表单；未决仍锁定。价格关系提示标明对应腿、比较符和入场参考价。中英文新增各23条消息。

`AttachedExitInput` 为不可变领域输入，Widget 只收集状态和展示解析结果；下单仍遵循 Riverpod → repository → service。普通限价使用所填主单价；普通市价使用买 ask／卖 bid，缺少报价不悄悄换成 Mark；条件市价使用主单触发价，BBO 使用明确的参考值并保留交易所最终方向核查。PnL 触发价为 `E+d×P/Q`，ROI 百分数为 `E×(1+d×ROI/(100×L))`；除法保持有理数，派生触发价按 PRICE_FILTER 最近步长对齐后校验，手填触发／退出限价不改写。毛盈亏预览使用手动退出限价，否则使用触发价；不计费用、滑点或未成交风险。

新策略每腿保护本次主单基础币全量，不再先抵消已有反向仓位；`estimatedOpeningQuantity` 仅继续供新增开仓保证金估算使用。退出限价使用 STOP／TAKE_PROFIT、原 stopPrice、正 price 和文档化 GTC；市价使用对应 MARKET 类型。自动限价 price 等于 stopPrice。单向退出仍 reduceOnly，双向仍固定 LONG／SHORT 且省略 reduceOnly；主单与每腿 workingType 相互独立。新挂单和同组互撤均以 `PARTIALLY_FILLED_OR_FILLED` 驱动，不在前端推断交易所已激活或已撤销。官网公开实现使用 GTE_GTC，本客户端使用公开 V3 文档支持的 GTC，不声称内部策略有效方式已等价验收。

未决日志 schema4 保持原 canonical 文件位置，读取版本1–4。新增退出方式、限价和驱动事件；旧记录明确保留原净保护数量、MARKET 与 FILLED 事件，重写文件也不改变条款。恢复卡展示原保护数量、各腿触发依据／价格、限价及旧／新联动说明。查询必须匹配原类型、触发价、委托价、GTC、方向／持仓侧和两个驱动动作；触发后的 LIMIT 只有原条件类型也匹配才能核对成功。未知只查原编号，不重发；当前 EOA／已有 Privy 签名路径未改变，无新钱包。

新增82项，全量3528项通过，773个 Dart 文件格式检查无改动、静态分析无问题。Android arm64 Release 构建成功且已检索包内双语专业设置、限价字段与新驱动事件；未安装。来源哈希、边界和验证见 [合同](reference/attached-exit-alignment-public-contract.json) 与 [记录](reference/attached-exit-alignment-verification.json)。仅匿名读取 Notion、公开 API 文档和官网 JS；没有真实钱包签名、地址 RPC、私有／金融／聊天请求或设备操作。Linux 无 macOS／Xcode，iOS 未构建。逐腿实际成交量／金额展示、完整策略管理列表仍未补齐；真实部分成交后数量增补、联动／撮合与原生验收继续记录，不能用策略状态证明余额／成交。合约历史、完整 Portfolio、Swap 及其他 PRD 缺口仍见进度表，整体未完成。

## 2026-11-04 逐仓保证金追加／移除

最新 Futures PRD 明确新增 `add/remove margin`，覆盖下方历史记录中“入口待产品确认”的旧判断。非零线性逐仓仓位提供独立入口，锁定 symbol／positionSide；默认追加、空输入，切换方向／取消确认／失败保留数量。当前保证金取 `isolatedWallet`，不混入 `isolatedMargin` 或浮动盈亏。Max 向下取到两位小数，超限显示具体提示；手动输入最多八位小数是本客户端限制，最终精度由 Aster 校验。中英文及窄屏／横屏／平板已纳入自动测试。协议与来源哈希见 [合同](reference/position-margin-adjustment-public-contract.json)。

追加上限取 `max(0,min(同资产 availableBalance,crossWalletBalance − 同资产逐仓 positionInitialMargin 合计 − 全仓 maintMargin 合计))`。移除上限同时受“逐仓钱包余额 − 本仓签名 maintMargin”及“逐仓钱包余额 + 带方向数量 ×（标记价 − 入场价）− 标记价 × 数量绝对值 ÷ 杠杆”约束。全部金额用 Decimal／有理数；循环除法的初始保证金向上取到 32 位，避免抬高可移除额度，缺失字段不当作零。强平预估逐档求解调整后权益等于维持保证金的价格，并在有理数精度下核对档位范围；数量和开仓均价不变，无有效解显示未知。逐仓保证金率来自同一签名账户记录的 `maintMargin / (isolatedWallet + unrealizedProfit)`，最终保留两位百分比，非正权益单独提示风险。

页面进入及启动恢复均不自动签名。显式读取账户、目标仓位及风险档位；第一份签名读取前开始 30 秒有效期。独立确认后重新读取全部条款，持仓／均价／钱包保证金／杠杆／风险档位变化要求重新确认，签名后及日志写入后再次检查身份、期限和事件版本。当前 EOA 或已有 Privy 钱包同时作为 user／signer，不创建钱包；使用 Aster EIP712 Message、chain1666、共享微秒 nonce，POST 参数为原 symbol／positionSide、正 amount、type 1／2 及 128 位随机 `clientTranId`。

正式 main 在首屏前载入独立 `position-margin-operations-v1.json`。发送前 flush／同目录替换保存公开条款，不保存签名或凭据；存储错误阻止提交。与下单／配置／内部划转共享提交锁，未决记录阻止新操作，停止／退出／切钱包后原记录继续保留，重启只手动查询。HTTP 响应及余额变化不证明执行：签名读取调整历史，必须精确匹配原编号、symbol、positionSide、asset、type、amount、USER_ADJUST 和时间，冲突或重复记录不予确认。明确文档拒绝码单独持久化为拒绝，保留具体安全理由并尽可能刷新 Max；其他异常继续未决，不重发。

历史核对成功后签名读取全账户仓位和账户余额，再读取目标风险档位。新快照更新主账户及仓位列表，并作废旧的进行中读取；独立读取仍保留陈旧提醒，不冒充持续同步。刷新完整成功后关闭调整页，实际强平价在主仓位卡显示。仓位已平则移除调整表单；后续刷新失败时保留“历史已核对／刷新失败”的部分成功状态，防止重复提交。保证金记录入口在无仓位时仍可用于原编号恢复。新增枚举不会进入子账户菜单，子账户仓库会在签名和网络之前拒绝此操作。

本轮新增 98 项测试（保证金专项 97 项及子账户操作隔离回归 1 项），全量 3446 项通过；766 个 Dart 文件格式检查无改动、静态分析无问题，中英文各 1547 条消息。Android arm64 Release 构建成功（45,646,676 字节），AOT 已检索到双语标题、提交／历史路径及独立日志文件名；未安装 APK。最终证据见 [验证记录](reference/position-margin-adjustment-verification.json)。真实权限、签名、实际保证金变化、手机存储／回跳／布局及 iOS 均未验收；按用户要求不使用设备工具或安装 APK。历史最多查询 500 条，未查到原记录或结果不完整会继续保留未决；本地最多 100 条记录且不自动清除，尚无归档界面。Linux 无 macOS／Xcode。Swap、完整跨产品 Portfolio 及其他 PRD 缺口继续跟踪；私有 BAPI 历史统计与 TWAP 按用户要求跳过。

## 2026-11-04 Futures 抵押贡献与公开标记价重算

Futures 资产卡新增独立抵押贡献与可展开计算明细。按官网公开源码的乘积取小值公式计算 `min(equity × bidRate, equity × askRate)`；全仓权益使用 `crossWalletBalance + crossed PnL`，两项价格率单位均为 USD／资产。与钱包或保证金的指数估值分开；负权益先乘后取小值，不取绝对值或截为零。`marginAvailable` 仅代表抵押资格，不确认当前保证金模式。协议、来源哈希与边界见 [合同](reference/asset-collateral-public-contract.json)。

已加载账户中的同资产线性全仓仓位字段完整时，使用匿名 premiumIndex／公开标记价流重算 `Σ signedQuantity × (mark − entry)`。全部相关仓位的模式、单位、正入场价和标记价必须完整；缺失或畸形时整体回退到签名资产 `crossUnPnl`，显示明确来源，不混合部分实时与旧浮盈亏。不把空仓列表或缺失浮盈亏当作零，也不以总钱包／可用余额代替全仓余额。任一已应用账户事件都会阻止贡献计算，直到重新签名读取。

Widget → Riverpod family → 现有 MarkPricesRepository → 共享公开 service。作用域由页面已有的地址及排序去重的账户全仓交易对组成，多个资产卡共享；不会因此初始化认证、私有账户读取、钱包或签名。数量变化保留订阅，切钱包丢弃旧数据；后台暂停、前台恢复、最后消费者退出关闭订阅和计时器。不支持的仓位模式／非线性单位、零数量、逐仓和无抵押资格资产不启用对应行情消费。逐交易对标记价超过十秒或断线时保留带陈旧提示的参考值；不完整行情回退签名快照。账户六十秒／指数原有期限同样控制陈旧状态；展开显示账户接收时间、指数时间和最旧实际使用标记价时间，均明确 UTC。

新增 80 项测试覆盖负权益、极小精度、缺失／畸形字段、全量回退、实时更新、断线／过期、事件使数据失效、共享订阅、钱包隔离、前后台及释放；中英文 320 宽／1.5 倍文字、横屏和平板展开布局通过。全量 3348 项测试通过，749 个 Dart 文件格式检查无改动、静态分析无问题，中英文各 1507 条消息。Android arm64 Release 构建成功（45,515,604 字节），AOT 可检索新增英中文案，未安装；验证见 [记录](reference/asset-collateral-verification.json)。现有三个插件仍有未来 KGP 迁移提示，不影响本轮构建。没有真实钱包签名、账户／资金 API、地址 RPC 或设备操作；iOS 因 Linux 无 Xcode 未构建。原生待测继续记录，Swap 和完整跨产品 Portfolio 仍未完成。以下保留此前增量时的状态。

## 2026-11-04 Swap 官网协议核查

公开资产组件和其依赖 JS 确认 USDT→USDF、BNB／slisBNB→asBNB 使用私有 BAPI `swapAsset`，另依赖私有 `swapBalance` 和 `getMaxWithdrawAmount`；这与已实现的多资产 `assetExchange` Rebalance 不同。所查 21 份官方开放 API 文档未找到等价 V3 路由，现有 Privy／EOA 签名不能直接变成 BAPI 登录态。没有访问这些私有接口或发送任何兑换；[核查记录](reference/swap-protocol-review.json) 保存公开源码哈希、调用字段及缺失条件。

此前已确认没有可用 BAPI 鉴权后端。除移动端鉴权外，仍需确认资产／链／换算／费用／两侧额度单位和提交编号／未知结果查询合同；不以官网 JS 表单校验替代权威资金协议。官网反向流程引导先提现至钱包，再 Trade & Earn 赎回，不视为对称账户兑换。Swap 保留未完成项，继续跟踪原始需求；用户明确跳过的历史统计／TWAP 状态不变。

## 2026-11-04 AI 原生页面与应用状态层

底部 AI 入口现打开 `AssistantPage`，替代占位页。Widget → Riverpod → 仓库 → HTTP／原生安全存储，初次进入不读取 AI 凭据、不恢复会话、不签名或发个人请求。用户可显式获取挑战，核对完整可选择文本后再次确认；沿用当前 EOA 或已有 Privy 钱包，不新建钱包。显式恢复核对服务器身份及 verified wallet binding 后读取对应历史。协议与边界见 [合同](reference/assistant-ui-public-contract.json)，自动验证见 [记录](reference/assistant-ui-verification.json)。

钱包跳转期间只保留签名等待，回到前台才继续认证 POST；取消、过期、离屏或换钱包后不提交迟到签名。其他请求后台即停止且不自动恢复。身份、地址、钱包类型或签名能力变化清空私人视图；令牌保存在仓库私有会话中，不进入公开 UI 状态。发送前重新验证会话／相同用户并保存待发对话，存储失败或预检查停止不发聊天；停止覆盖整条请求及补全路径，保留部分回复及新草稿。

每 400ms 保存最新历史快照，最多一份写入和一份待写，关闭时写回原钱包／用户。历史损坏不覆盖成空，保持只读直到明确重读或确认清空。清空先作废待写快照再串行删除，退出时不会复活旧消息；旧钱包弹窗确认不能清新钱包数据。本地遗忘仅删当前钱包 AI 凭据，保留历史，不撤销服务器会话／Privy 登录。存储异常提供安全提示与重试。

中英文多行输入、UTF-16 字符计数、发送／停止、原生可选择 Markdown／GFM 表格、消息复制及默认折叠的返回解释已接入。新增 `flutter_markdown 0.7.7+1` 用于原生 Markdown，所有图片替换成本地文案，避免自动网络加载；外链仅点击后打开合法 HTTPS，不用 WebView。长文用同一个滚动面支持窄屏、横屏、平板、键盘压缩与放大文字；流更新只重建对应消息，阅读历史时不自动拉到底部。用量显式读取且不以网页默认五次推算剩余；五分钟、UTC 换日、时钟回拨、新发送或读取失败标为陈旧。回复不会自动附带余额／仓位或执行金融动作。

新增 57 项（状态／生命周期 32、历史写入 7、Widget 18），全量 3268 项测试通过；742 个 Dart 文件格式检查无改动，静态分析无问题，中英文各 1490 条消息。覆盖独立挑战签名、钱包后台／前台与停止、切账户丢弃、预写失败不 POST、部分回复／新输入保留、损坏历史只读／重读、清空中退出、旧弹窗、UTC／额度未知、远程图片屏蔽、复制及 320 宽度／1.5 倍文字、844×390 横屏、768×1024 平板、键盘压缩布局。组件测试混合泵帧与真实异步事件，避免替身 HTTP 流的事件循环被假时钟阻塞。

Android arm64 Release 构建通过（45,515,604 字节），AOT `libapp.so` 可检索 AI 中英文文案，已存在实际导航引用；这比此前未引用数据层的相同 APK 多出了可到达功能，但不证明服务器／真机验收。APK 未安装；真实挑战格式、认证／聊天／用量、补全去重／扣额、原生存储／回跳／布局仍按用户要求记录待测。Linux 无 macOS／Xcode，iOS 未构建。整体原始 PRD 仍有 Portfolio、抵押贡献／Swap 等缺口，见 [需求进度](prd-progress.md)。以下保留此前增量时的状态。

## 2026-11-04 AI 钱包认证与安全会话底层

继聊天传输后补入当前钱包挑战、签名、本地 EIP-191 验签、Supabase 身份与 verified wallet binding 核对、显式会话恢复／刷新、隔离安全存储和个人用量查询。仍未接入 Riverpod、导航或聊天页面；不能把这批数据层测试称为可用的 App AI 功能。协议及范围见 [合同](reference/assistant-session-public-contract.json)，检查记录见 [验证记录](reference/assistant-session-verification.json)。

准备只取公开挑战，不签名；后续页面必须展示原文并独立确认。保留原始 UTF-8，核对地址／大小写敏感 nonce／固定域名及可选标准 URI 行，限制文本和本地五分钟期限，拒绝时不盲签或自动重新签名。官网没有公开 nonce 消息生成器，实际正文格式、可选 chainId 和移动端 relying party 尚待验收；当前 AuthIdentity 不提供链，因此沿用官网可省略 chainId 的分支，不猜链、不切链或创建钱包。确认仅接受本 repository 准备的单次挑战，EOA 由当前连接钱包签名，邮箱身份沿用已有 Privy 钱包。

签名只在内存，恢复地址并检查 EIP-191、UTF-8 字节数、r/s／low-s 与 v；之后才提交 verify-wallet。本地解析 JWT 仅取得预期 subject／expiry，不是认证证据。还需服务器 `/auth/v1/user` 确认 subject，并在 `vanta.wallet_bindings` 找到恰好一个当前地址的已核实绑定，才返回会话。未验证、重复、错地址／用户、畸形或超过本地 100 行的绑定均不授权。作用域在公开配置返回、各个人响应、下一请求及排队存储前重复检查。

外部钱包的正常 App 切换不能直接当退出。repository 提供签名返回后的前台等待回调，在原挑战期限内等控制器通知恢复；停止、关闭、切身份、过期或迟到签名都不能继续验证。该回调及真实生命周期仍待下一步 controller 接线；当前测试以合成前台 gate 验证。网络或钱包拒绝不自动重试，新挑战需新的显式操作。

恢复仅在显式操作调用，未存凭证时不发任何网络；剩余时间不满 30 秒时走 Supabase refresh grant，subject 不能改变。轮换先保存，再核对服务器身份／绑定；后续读取失败不给会话，允许下次显式恢复使用新凭证重新核对。凭证按 App 身份＋钱包类型＋规范地址隔离，历史再加服务器 user UUID；本地不保存 authenticated 标志或可充当权威的 verifiedAt。

将已存在的传递依赖 `flutter_secure_storage 10.3.4` 声明为直接依赖，专用于 AI 令牌和私人历史。Android 独立 namespace、禁用 resetOnError；iOS 独立 accountName、仅本机解锁可读且不云同步。读写删除串行，键用作用域哈希，内容校验版本／作用域／用户；损坏保留，原生错误不泄露凭证／堆栈；不调用 deleteAll 或删除 Privy 的值。此处仅本地遗忘凭证，不声称远程撤销 Supabase 会话。

历史保留最近 200 条／512 KiB UTF-8 与最多 12000 字符草稿，逐条校验角色、编号、状态、时间及长度；恢复 streaming 为 interrupted，不自动发送或继续生成。保存只编码能容纳的后缀，不反复编码整份历史；超大的单条回复不截断，返回容量失败供页面保留内存内容并提示。个人用量由明确查询读取当前 user／UTC 日的 `request_count`，空行表示已用零次；不凭官网默认五次推断剩余额度。

新增 133 项、AI 专项 214 项／全量 3211 项测试通过，722 个 Dart 文件格式检查无改动、静态分析无问题；中英文仍各 1419 条消息。Android arm64 Release 构建成功、未安装；无入口引用，新 AI 数据层未证明进入 AOT，APK 与此前基线一致。

全为替身 HTTP／钱包、内存存储、合成 native MethodChannel 和原生参数验证，没有实际认证、聊天、个人用量、钱包签名、RPC／资金请求或设备操作。安全存储密文／Keychain 容量、锁屏／强杀／备份及卸载恢复不能由这些测试证明；继续记录 [原生待验收](native-verification-pending.md)。尚无入口引用这些类，APK 构建也不证明 AI 已可用。

## 2026-11-04 AI 助手协议与聊天底层

本增量新增 AI 域模型、公开运行时配置解析、HTTP／SSE 传输和单次聊天 repository；尚未接入 Riverpod、钱包认证、安全存储或页面，因此 AI 的 App 功能仍未完成。完整官网调用链和剩余工作见 [协议记录](reference/assistant-chat-public-contract.json)，自动验证见 [验证记录](reference/assistant-chat-verification.json)。没有用演示回复代替服务。

公开 `config.js` 仅作为 JSON 赋值数据解析，不执行脚本；固定官网和 Supabase origin、禁止重定向，公钥仅内存缓存，验证 anon／项目 ref，拒绝 service_role，不提交真实公钥。实例构造不发请求。聊天必须由后续认证层提供 Supabase 会话；Privy 令牌不能替代，局部 JWT 解码不能证明用户或钱包已认证。官网认证还有 verified wallet_bindings、独立 nonce／当前钱包签名／verify-wallet；实际挑战格式及移动端 relying party 仍待接入核对。

流式解析支持跨字节中文／Emoji、分片 CRLF、多行 data、reasoning_content／thinking_delta、stop／end_turn／[DONE] 与 length。单行／帧限 65536 字符，总 SSE 限 2 MiB，合计答案／解释限 131072 字符；总超时五分钟、空闲两分钟，请求头和正文共用取消期限。HTTP／异常 JSON 及非流式响应有界，原始服务错误和堆栈不越过数据边界；额度字段未知不补成官网默认的五次。

单次回答保持一个 UUID；中断／空回复／截断及可恢复失败按官网用同编号非流式补全，只有解释时最多再用同编号请求最终答案。停止覆盖请求头、流、补全及后续重试，保留已有文本并标中断；4xx／额度错误不自动补全。部分失败回复不会再次作为成功助手上下文发送；只发送最近 12000 字符的完整 role／content，不附加解释、资金或订单数据。同编号的服务端去重与扣额仍待真实验收。

新增 81 项、全量 3078 项测试通过，708 个 Dart 文件格式检查无改动、静态分析无问题；中英文仍各 1419 条消息。Android arm64 Release 构建通过、未安装。

本次仅以替身 HTTP／流及匿名缓存验证生产配置解析；没有 auth-nonce／verify-wallet／starchild-chat／个人用量真实请求，没有签名、RPC、资金请求、设备工具或 APK 安装。当前没有入口引用这批类，Android 构建通过不证明其已进入 AOT 或已有可用 AI 页面。iOS 仍受 Linux 无 macOS／Xcode 限制；后续原生网络／流和实际认证记录在 [待验收表](native-verification-pending.md)。

## 2026-11-04 CHANNEL 活动与任务

积分页的活动列表新增普通／频道切换；两种目录独立读、独立失败，详情按 ID 新读。CHANNEL 保留频道名、公布白名单数量、原生规则与奖励，排名独立请求 channel-volume 前 10 条，保留服务器顺序／并列，不按本人量重排或猜测榜外名次。官网公开接口观测 7 个频道活动，其中 3 个提供新用户／签到／里程碑；生产映射器已处理匿名缓存。一个活动虽标 ACTIVE，但结束于 2026-11-03，列表按时间显示结束、动作按时间及状态阻塞；详情仍展示公布状态与结束时间。

任务包含注册／钱包连接／净充值三步及公布奖励、每日 UTC 日期／交易量目标／签到日期历史、按公布阈值关联的里程碑、本人＋推荐网络交易量、邀请人数、网络活跃人数、频道总量与逐链币种充值。Decimal 与整数保存原始精度；缺失字段显示未知，不补零、猜链或根据余额推断完成；不根据客户端阈值推断奖励发放。Vanta 活动属 Orderly：充值、交易及推荐打开原官网，不接到 Aster 资金或交易。源文案保留原语言；应用标签中英文。

任务进度是显式查询当前地址的 participants/{address}/tasks，没有进入页面或前后台自动披露地址。任务读取复用状态生命周期：五分钟过期、停止／迟到／后台隔离、换身份／地址／钱包类型清空；该新路径另有限 2 MiB JSON、禁止重定向、12 秒超时中止与关闭中止。个人端点的真实返回仍未请求；字段证据来自官网源码，测试全为合成。

签到和钱包连接奖励任务使用当前已有 EOA／Privy personal_sign，独立原生确认，不创建钱包。新读活动、参与及任务后签名，再次新读资格／完整公布条款；匹配 UTC 日、身份及活动有效期，签名在本地最多两分钟，日志写入后发送前再次检查。签到必须有服务器明确未签到、当日日期匹配、已知当日量达到已知目标；连接任务必须有服务器明确注册完成且连接任务未完成。正文及 JSON 与官网一致，只有一次 POST；12 秒超时或释放中止传输，HTTP 2xx 仅受理，另读原任务完成才核实。

发送前 SharedPreferencesAsync 序列化保存公开 eventId／address／action／原 UTC 日，禁止保存签名、凭证、响应。最多 100 条／65536 字符，损坏／超限／写入失败停止，不驱逐未知。未决条目阻塞同一活动／钱包的两种动作；重新打开后在手动核对或再次确认的本地检查恢复。只在服务器确认 walletCompleted 或原签到日仍在历史中后删除，false／缺失不能证明未发送；原日历史缺失可能无限保留阻塞。已知未发且发送前失效可删除，删除失败继续未知。卸载／清数据不能保证恢复，偏好存储确认不是强杀／断电验收。

新增 93 项、全量 2997 项测试通过，701 个 Dart 文件格式／静态分析通过，中英文各 1419 条消息；Android arm64 Release 构建通过（45,056,792 字节）。公开协议、观察哈希和边界见 [合同](reference/channel-events-public-contract.json)，最终自动测试／构建见 [验证记录](reference/channel-events-verification.json)。没有实际个人查询／签名／动作 POST／RPC／私有／资金调用，不启动设备或安装 APK；原生与 iOS 按 [待验收表](native-verification-pending.md) 跟踪。AI 及其他 PRD 缺口继续保留。

## 2026-11-04 资产名称与图标

Spot／Futures 余额卡按原资产代码读取匿名官方名称与 PNG 图标，提供中英文名称、名称搜索、原代码复制和独立手动刷新／失败重试。代码按大小写规范化精确匹配（asBNB → ASBNB），不推断别名。来源当前仅有 18 项名称，图标 817 行中 807 行可映射为账户标识；USDF／asBNB 有图标但无官方名称时保留原代码。展示信息不改变签名标识、Decimal 数量、余额精度、价格、抵押或权限。

依然使用 Widget → Riverpod → repository → service；两个目录独立加载和失败保留，Spot／Futures 共享，15 分钟标记过期，无轮询和自动失败重试，后台丢弃迟到结果。名称源 GET，图标目录是匿名只读 POST `{}`，不是金融操作。目录 JSON 限 2 MiB／5000 条，传输超时 12 秒并中止；PNG 只允许固定 HTTPS CDN 路径，禁止重定向，限 512 KiB 和 2048×2048、解码目标 96×96。图片至多四个并发，同 URL 合并，成功 LRU 至多 64 项／4 MiB，失败可显式重试；服务释放终止传输，排队任务不再启动网络。

新增 79 项测试（映射／传输／控制器／双语 Widget），全量 2904 项通过，688 个 Dart 文件格式／静态分析通过，中英文各 1379 条消息。自动验证包括真实生产映射器处理匿名缓存、超时中止、释放时四运行／两排队、名称搜索及 320 宽／放大文字／横屏／平板；不代表真实手机解码或网络已验收。公开来源、PNG 观测及边界见 [合同](reference/asset-metadata-public-contract.json)，Android arm64 Release 构建通过（44,991,256 字节），校验见 [验证记录](reference/asset-metadata-verification.json)。本轮没有安装 APK、启动设备或请求真实钱包／RPC／私有／账户／资金接口；iOS 受 Linux 环境限制。

## 2026-11-04 交易授权、子账户管理与实际充提

本增量为三条流程的代码接入；真实 Aster 接受、签名、资金执行和原生页面尚未验收。公开协议见 [合同记录](reference/account-funding-operations-public-contract.json)，自动检查及 APK 见 [验证记录](reference/account-funding-operations-verification.json)。不创建备用／代理钱包，EOA 始终由当前连接钱包签名；邮箱身份沿用已有 Privy 钱包。

- 交易授权：账户菜单进入独立确认页；当前地址同时作为 user 和 agentAddress，30 天有效、Spot／Perp 交易权限、chainId 56 注册签名。默认不授予提现；用户可单独勾选提现并填写 1–16 个 IP／CIDR，空白、主机名、端口、重复项及无效前缀均拒绝。签名在本地恢复地址，10 秒协议窗口前预留 1 秒，失败不自动重签。可分别签名读 Futures／Spot，显示合约 canTrade／可选 canWithdraw；读取成功、账户标志与 agent 授权分开，Spot 读取不证明下单权限。官方仍未明确保证同一 EOA 可以自注册为 agent，当前实现不会在拒绝时新建钱包替代。
- 子账户：从签名列表进入管理；新读 master-only 目录及主标记，创建时限制最多 10 个，确认前再检查。绑定已有、独立控制的子 EOA：复制无签名的 EIP-712 挑战，在子钱包签名后粘贴遮蔽的 childSignature，本地验签，再由主钱包签名。45 秒确认期限包含外部签名交接，可能需要重来，不保存签名或私钥。冻结／解冻为明确命令，受理不冒充实时冻结状态；主↔子支持四种 Spot／Futures 方向，Decimal 校验，实际关联、冻结、余额、精度和限额由服务器最终检查，目前没有子余额预读来源。可输入已有地址切换，已受理创建可保留公开主／子地址；切换先退出并重新 SIWE 核对目标地址，不按 ID／名称猜地址，不仅改本地 activeAccount。邮箱内嵌主账户返回可用普通邮箱登录。
- 充值：三条 EVM 链普通 depositFor 路径，保留独立 ERC-20 授权／清零。用户必须确认已在 Aster 核实可用性和剩余额度；公开目录缺少最低额时另填外部核实的最低额，明确官方无正最低额才填 0；不会将缺失视为无限额／零。新读目录、余额／allowance／Gas／nonce，确认前再次读取并核对完整交易，变化要求新确认。授权与充值共享发送互斥和待处理日志检查，停止 UI 后仍持锁直到实际请求返回。发送前落盘 `pending-deposits-v1.json`，保留原钱包交易哈希，未知不能重发。原哈希或同意图加速哈希只读核对规范回执，至少两个确认；链上成功仍保留记录，必须签名历史按哈希＋市场＋链＋币种＋精确数量唯一匹配 SUCCESS 才视为到账并解除。回滚／不同意图替换仅结束该链上尝试。没有自动轮询、重签或续跑，原生币 Max 继续禁用。
- 提现：资产页逐项进入，仅提现到当前注册钱包自身地址，先签名主账户资格及提现信息、公开目录和最新费用，30 秒复核／再次读取，额度未知阻止，费用变化重新确认。业务 Action 与 API Message 双重签名并本地验签，先持久化再一次提交；Spot／Futures 使用各自官方端点。返回 withdrawId 用于独立签名历史唯一匹配；响应 hash 是签名摘要，绝不作为链上交易哈希。当前全额加费用保守检查币种、链数量上限及美元日额度。
- 子账户和提现共用 `wallet-operations-v1.json`，只存公开无签名条款；落盘失败不发送，停止／退出后的受理响应仍归原钱包。未知结果保留且阻塞该钱包新操作，不自动重发或以余额猜成功；无返回提现编号的未知请求、未知子账户划转暂缺官方原 nonce 查询协议，需要平台核实。日志最多 100 条且不静默驱逐，达到上限会停止新提交；无归档界面。清应用数据或卸载无法保证恢复。

协议选择：注册使用 `Message` 域 chainId 56，普通账户／管理签名 1666；参数按 URI form 编码的原始字节签名并发送（空格为 +、IPv6/CIDR 转义），测试核对一致性；特定示例的原始拼接和总体 V3 URL 编码表述不完全一致，非 ASCII 名称／IP 白名单的服务器接受仍待实测。提现业务 userNonce 选 ms×1000，依据 Action 参数表、官方 EVM 数值示例及当前官网前端；V3 外层 userNonce 表文字写纳秒，与其示例存在冲突，单独 API nonce 使用纳秒，真实兼容性必须验收。

架构复核：维持 Widget → Riverpod controller → repository/service，财务用 Decimal／BigInt，HTTP／RPC 不在 Widget 构造。提取子账户确认组件、授权权限展示、充值回执／到账恢复 mixin；超过 80 行的组合 build 经复核保留同一页面表单与操作状态，传输及资格判定在数据／业务层。`web3dart 3.0.3` 从现有传递依赖升为直接依赖，仅用于本地 EIP-712 摘要及地址恢复；独立 ethers 6.16.0 测试向量包含公开固定测试键对应签名，无生产密钥。

自动验收包含精确协议签名／独立向量、子签名错误／数量上限／过期与身份变化、两次费用／限额复核、POST 前日志／异常与并发、充值回执／替换／到账各字段不匹配、host 文件重开／损坏／失败、账户切换及双语 320 宽／1.5 倍文字、横屏和平板。最终全量 2825 项通过（新增 162 项）；677 个 Dart 文件格式检查及静态分析无问题，中英文各 1370 条消息；Android arm64 Release 44,860,056 字节，APK 校验见验证记录。本轮无设备工具、APK 安装、真实钱包／RPC／私有／金融请求；iOS 因 Linux 无 macOS／Xcode 未构建。其余 PRD 继续见 [进度](prd-progress.md)，BAPI 统计／TWAP 按用户要求跳过。

## 2026-11-04 RETAIL 活动列表、详情及报名

- 重新读取 points&campaigns PRD，按原网站普通 RETAIL 活动实现积分页入口、20 条分页列表及独立刷新详情。保留服务端状态／顺序，展示名称／图片、UTC 起止和秒级倒计时、broker／精确编号、报名人数／活动 USDC 总量、任务及精确目标／个人进度、奖励表、活动规则与细则、个人报名／成绩和首 30 条成交量榜单（10 条分页）。无上榜记录不推断 30+ 排名；四场当前公开活动均已结束，不伪造开放报名。原始源码／匿名接口哈希及字段见 [活动合同](reference/trading-events-public-contract.json)。
- 扩展既有 PointsRepository，保持 Widget → Riverpod → repository → service。活动／排名公开 GET，无地址或凭据；个人参与状态仅显式刷新，按当前 EVM 地址请求，缺失与零分开。严格 RETAIL／事件编号／地址范围，Decimal 保留原始数字精度，int64 计数／编号，日期／集合有界；后台、停止／离页、切身份／钱包类型的迟到结果隔离及五分钟陈旧提示延续积分基础设施，不自动签名或刷新个人接口。
- 新增 `html` 仅用于将公布规则解析为原生标题／段落／列表／表格／链接／图片模型，不执行 HTML/CSS/JS。保留实体与文本边界，移除脚本／样式／iframe／表单／SVG；文档字节、深度、节点／块／表格均有界。图片限定公开 Supabase 活动目录、光栅 MIME 与 5 MiB 流大小，不重定向／带凭据／自动重试，失败可手动恢复。已有传递依赖 `url_launcher` 改为直接依赖，任务／规则的 HTTPS 链接打开原目标；无效任务链接报数据错误，不替换另一交易目标。图片／链接服务和客户端均在 data/application 层，Widget 只呈现和收集意图。
- 活动针对 Vanta Orderly，明确与 Aster 交易／余额独立；任务交易按钮前往指定 Vanta 网站，绝不映射至当前 Aster 交易。公布任务目标达到不代表奖励已获得；无来源成绩保持未知。页面状态包含 loading／空／成功／部分图片／榜单失败／陈旧／安全错误与保留旧值重试，地址及规则可选择复制。UI 文字中英本地化，服务端发布内容保留原文。
- 报名先显式读取参与状态再独立确认活动／地址和签名用途。EOA 直接使用当前连接的 `personal_sign`，已有 Privy 钱包按原地址唯一匹配，UTF8 编码为 hex，均不创建额外钱包。仅添加钱包消息签名能力接口，不更改金融发送或 typed-data 语义。共享 Privy 签名 helper 承担嵌入钱包编码；现有较长身份 repository 经复核，保留会话代次检查和外部连接所有权，提取可独立验证的编码逻辑。
- 确认后、钱包签名后分别新读活动及报名，核对事件／地址、资格／结束时间、规则／任务／奖励指纹；已报名不签／不重发，规则改变要求重审。每次 await 后及 POST 前检查身份作用域，钱包切换后不继续发送个人地址。消息与 JSON 字段完全沿用官网，签名本地限 0–120 秒（仅客户端策略，不声称官方 TTL），一次 POST，无自动重试／重定向，12 秒覆盖连接及响应全过程。
- 2xx 仅视为平台受理，只有后续个人读取 registered=true 才报告核实报名。非 2xx／断网／超时均未知，不展示原始错误；未知／受理状态禁用再报名，必须显式查询参与状态。未持久化报名日志，新页面／重启再次操作也先新读报名；不声称资金／奖励执行。普通 RETAIL 没有启用官网 CHANNEL 专属 newUserTasks／dailyCheckIn／milestoneRewards，签到／钱包连接等扩展此轮不伪装已完成。
- 新增 **103** 项（映射／文档 30、读取协议 3、报名协议 25、控制器 16、媒体 7、Widget 12、既有认证套件新增 10），全量 **2663** 项通过；635 个 Dart 文件格式无改动，静态分析无问题，中英文各 1261 条消息。Widget 覆盖 320 宽／1.5 倍文字的中英报名确认、横屏／平板、榜单分页／原网站跳转、切钱包旧确认失效、未知锁／显式查询、图片失败／恢复及原生文档。测试修复了连接阶段未受超时覆盖，以及 Riverpod 默认重试图片导致后台多次请求的问题。
- Android arm64 Release 已构建、未安装；APK AOT 核对包含活动／报名代码，哈希及日志见 [验证记录](reference/trading-events-verification.json)。无设备工具、真实个人端点／钱包签名／报名 POST／RPC／私有／资金请求；手机网络／外链／签名回跳、真实参与字段／权限及 iOS 仅记录 [原生待验收](native-verification-pending.md)。Linux 无 macOS／Xcode。AI 助手与整体 PRD 继续未完成。

## 2026-11-04 积分主页

- 补核 Vanta 公开运行时 `VITE_POINTS_API_BASE_URL`，确认 `https://api.vanta.exchange/api/` 为实际 API；此前同源 points-api 的 HTML 是 SPA 回退。匿名实读当前周期、周期列表、总榜及第 17／1 期榜单，核对官网 points chunk 和请求包装。来源哈希／字段见 [积分合同](reference/points-public-contract.json)。活动列表／详情的 RETAIL 服务也已找到，尚未实现；不把缺少接口回复当成开发阻塞。
- 新积分页替换原无数据入口：当前周期名称、编号、公布状态、积分池、UTC 起止、broker／说明；总榜与分期榜保持服务端顺序和排名，每页 20 条、最多 100 条，EVM 地址忽略大小写匹配，Solana 标识保持大小写。地址可选择复制，未上榜不推断 100+ 排名或零积分。明确 Vanta Orderly 计划与 Aster 余额／交易独立，不能承诺 Aster 交易获得此积分。
- 个人总／当前／可选结算／特殊积分及分期历史使用当前登录 EVM 地址；点击前告知地址发送给 Vanta，只有显式查询／刷新才请求，无令牌、签名、钱包创建或交易账户切换。个人响应字段仅经公开源码／替身核对，没有向真实地址接口发请求；真实响应／权限仍待验收。退出、身份 ID／地址／钱包类型改变清空数据和历史选择，签名能力变化不影响无签名地址读取。
- Widget → Riverpod → repository → 固定来源 service；精确 JSON 数字与 Decimal、有界 int64／文本／列表、时区／日历及周期一致性校验，原生 double 不进入积分量。空列表、无当前周期、未知分项／缺少历史行均与零值区分；重复 ID／地址、错周期／错地址、HTML／畸形响应拒绝。仅 GET，无重定向或自动重试，错误转为安全双语提示。
- 公开读取在进入页面／恢复前台时触发；个人不自动读取。五分钟标旧，不轮询；刷新失败保留旧快照。停止／后台／离页丢弃迟到响应并释放计时器／客户端，前台只恢复公开读取。选中周期被刷新移除仍保留原 ID 与未知值，避免替换范围；长页滚动保持个人读取和选择直到离页。
- 新增 **92** 项测试（映射 43、HTTP 协议 17、控制器 16、Widget 16），全量 **2560** 项通过；611 个 Dart 文件格式检查无改动、静态分析无问题，中英文各 1206 条消息。EN／ZH 320 宽／1.5 倍文字、844×390 横屏、768×1024 平板的长名称、已登录积分、分页和页面滚动均通过 Widget 测试。Android arm64 Release 构建成功、未安装，APK AOT 核对新增代码存在，结果／哈希见 [验证记录](reference/points-verification.json)。
- 无设备工具、APK 安装、个人真实接口／钱包／RPC／私有／资金请求。手机网络／复制／前后台／真实个人响应与 iOS 均只记录 [原生待验收清单](native-verification-pending.md)；Linux 无 macOS／Xcode。活动列表／详情及签名参与动作、AI 助手与整体 PRD 仍未完成。

## 2026-11-04 USDF／asBNB 公开收益率及遗漏子页面补核

- Portfolio PRD 明确要求资产 APY。现于 Spot／Futures 的 USDF／ASBNB 资产卡加入可展开收益条目：USDF 为 `baseApyList[0].apy + tradeApyList[0].apy`，两者本身已是百分数；asBNB 采用 Lista 的 `comprehensiveApy × 100`。核对官网实际徽标组件与 hooks 后确认口径，不使用独立 APR、Launchpool 单项或固定百分比。原始数字经有界精确 JSON 解析后用 Decimal 运算，仅展示取两位；不改变余额、保证金、参考估值或个人收益。
- 收益域模型、映射、固定来源 HTTP service、repository、Riverpod family controller 与资产卡分层。只为当前显示的精确资产符号读取；同币跨 Spot／Futures 共用请求，两种来源独立失败。均是匿名公开 GET，不读取地址、登录令牌或余额，不签名，不创建钱包或执行 Swap。缺失、畸形、失败响应、空列表、USDF 两组成分日期不一致均保留未知／旧值，不补零。
- 默认收起，点击展开查看来源日期、USDF 分项、可选来源更新时间、UTC 读取时间及刷新按钮。明确这是有条件／估算的公开收益率，不是个人已赚收益或保证收益。当前公开 USDF 数据日期为 2026-10-22，不能因 HTTP 刚返回就标成当前收益；来源日期超过两个日历日、晚于 UTC 当日、读取满五分钟、未来时间异常或刷新失败均标历史／未核实。日期仅是来源的日历标签，不猜精确发生时刻。
- 首次显示／手动刷新／五分钟前台更新；并发去重、读取期间旧值过期和 UTC 换日仍会更新提示。后台取消计时器并丢弃迟到结果，恢复前台重新公开读取；最后消费者释放后关闭客户端。加载、部分失败、旧数据、后台暂停及安全错误／重试均有中英文，不向 UI 泄露原始响应、错误或调用栈。展开条目使用独立 Material，保证资产面板内点击反馈可见。
- 新增 78 项测试（映射 45、HTTP 协议 12、控制器 12、Widget 9），全量 **2468** 项通过；597 个 Dart 文件格式检查无改动，静态分析无问题，中英文各 1154 条消息。Android arm64 Release 构建成功、未安装，检查 APK AOT 包含新增收益组件。来源、精度、时效及兼容边界见 [公开收益合同](reference/asset-yield-public-contract.json)，完整结果／APK 哈希见 [验证记录](reference/asset-yield-verification.json)。没有设备工具、真实钱包／RPC／私有／资金请求；手机网络／展开交互／前后台及 iOS 继续记录 [待验收](native-verification-pending.md)。
- 本次补核原始 PRD 的另外两个直接子页面：活动列表／详情／积分主页与 AI 助手也属于原目标，之前剩余项清单未覆盖，现已补入 [需求进度](prd-progress.md)。当时公开 Vanta JS 有 points-api 和流式助手线索，三个同源匿名 points-api 探测返回 SPA HTML；后续积分增量已确认真实 origin 并成功公开读取，见上方最新章节。已异步向用户索取接口信息，独立开发继续。来源与下一步证据见 [补充子页面合同](reference/additional-prd-pages-public-contract.json)。不把缺少接口文档视为已证明无路可走，也不以模拟活动／聊天替代。

## 2026-11-04 现货当前挂单及事件合并

- 重新读取 Portfolio PRD 的 Spot → Open Orders 表后，确认现有订单历史不能替代当前挂单，之前顶层剩余项清单遗漏了这一明确需求。现新增 Spot 资产独立入口；进入页面不自动签名，显式读取 `GET https://sapi.asterdex.com/api/v3/openOrders`。不传 symbol 取得完整账户基准（文档权重 40），本地按现货交易对／订单原编号筛选，计数始终等于同范围显示行数，不借用 Perp 当前交易对或计数。
- 复用 EIP‑712 chain1666、共享微秒单调 nonce、当前 EOA／已有 Privy 钱包的原地址签名流程，不创建额外钱包。严格映射有界列表、字符串 Decimal、状态／方向／编号／时间；完全相同重复记录合并、同交易对及编号的冲突行拒绝。非当前状态或畸形响应不能伪装成空账户；单位仅来自 Spot exchangeInfo，元数据失败保留签名记录并明确标未知，不解析交易对后缀或借用合约元数据。
- 展示 Buy／Sell、类型／有效方式、基础币原始／成交／剩余数量、计价币累计成交额／平均价／条件价和可复制原始订单／客户端编号；所有数量直接保留 Decimal 精度。按计价币金额下的 MARKET 若基础币原始数量为零，明确显示基础币总量／剩余未知及原计价币金额，绝不猜数量。事件 O 缺失／零不使用 E 或 T 代替创建时间；时间字段明确 UTC。无合约 Long／Short、杠杆、保证金或 reduceOnly 套用。
- 既有 Spot listenKey／sstream 的 executionReport 在独立 Spot 验证后同时生成现货订单更新与通知，互不替代且不进入合约合并逻辑。需要完整签名基准才展示列表；按 symbol＋orderId 去重，核对服务端 E／T 与累计成交量，读取期间到达的新事件再合并；历史 active 事件不能重新加入新基准中缺失的订单。终态 tombstone 阻止延迟 NEW 及旧 REST 复活；创建时间／单位可继承已验证原行，事件不能证明全账户列表完整。
- 页面保持加载／停止、初始／空／无匹配、成功、单位缺失、事件局部更新／陈旧与失败保留等状态；三十秒只标陈旧，不自动签名。断网、重连、后台、过期或未知事件使基准陈旧；缺口仍需显式完整读取。最多保留 10000 个内存订单事件键，不静默丢弃终态；容量错误停止监听，显式查询仍可检查当前基准，切换身份重置事件簿。事件未持久化，不声称断线自动完整回放。
- 停止／离页使迟到读取失效；退出、切地址或签名类型变化清除私有行及事件簿。失败保留筛选、旧快照和可理解错误，签名读取重试仍由用户触发。没有新增现货下单、逐笔或全部撤单请求。
- 新增 81 项（映射 39、事件合并 10、签名协议 10、控制器 13、Widget 9），全量 2390 项测试通过；587 个 Dart 文件格式及静态分析通过，中英文各 1139 条消息，Android arm64 Release 构建成功、未安装。现有 loopback WebSocket 测试补充验证 Spot 更新不会进入 Perp 通道。完整证据／APK 哈希见 [验证记录](reference/spot-open-orders-verification.json)，重新读取的官方文档哈希及条款见 [合同](reference/spot-open-orders-public-contract.json)。
- 无设备工具、APK 安装或真实钱包／RPC／私有／资金请求。本阶段真机权限／回跳／真实事件、手机后台／断网和中英文窄屏／横屏／平板／键盘／安全区只记录在 [原生待验收清单](native-verification-pending.md)，Linux 无 macOS／Xcode，iOS 未构建。整体 PRD、交易授权、子账户及对外充提等仍未完成。

## 2026-11-04 Spot ↔ Futures 内部划转

- Spot 与 Futures 资产面板均有独立入口；页面不自动签名。显式读取支持资产、输入精度、资产模式及双方完整账户；正常初读三签，确认前再次三签、一签 POST，结果后三签复读，典型全程十签。直接使用当前连接 EOA，邮箱身份沿用已有 Privy 钱包，不创建额外钱包。
- 匿名公开支持资产与输入精度接口已确认；逐资产精度按官网最大八位、缺失／零回退两位的输入规则，不等于链上代币精度。保留确切资产 ID；允许相同精度重复行、拒绝冲突。金额用 Decimal，普通正十进制及精度／上限严格校验，Max 按步长向下取整。来源上限为 Spot `free` 或 Futures 所选资产 `maxWithdrawAmount`，绝不替换为 locked、钱包／保证金／available 余额或根级 USDT 值；未知上限及缺失权限均禁用提交。
- 独立确认冻结钱包、方向、币种、确切数量、额度与原 clientTranId；确认后重新读取并比对当前余额、权限、模式和输入精度。第一项公开／私有读取前起算三十秒；钱包／签名能力、任一市场账户事件（含相同时间戳重放）、共享提交 epoch 及过期会使确认失效。持久化后再次核对才按 `SPOT_FUTURE`／`FUTURE_SPOT` 发送一次表单 POST；没有自动重试。
- 启动首屏前加载独立 v1 恢复文件。记录仅含公开钱包、方向／数量、原 clientTranId／nonce／时间及可选服务器 tranId；严格有界 JSON／重复键／字段／整数检查，串行更新、临时文件 flush 后同目录替换。磁盘原条款被改动或丢失不能静默清掉内存记录；无签名／凭据／执行队列。返回成功但目录／读写失败时先保留内存响应，重试核对原条款后合并。
- 只把文档化 `SUCCESS` 与正 int64 `tranId` 视为已报告结果。停止、离页、退出、切钱包或 provider 释放后仍保存到原钱包；另行读取双方完整账户与模式，更新共享账户快照，再移除对应记录并清空输入。读数失败保留数量及已知响应，恢复只读不重发；选项变化清空旧输入并重读，其他失败保留输入。
- 真正未知的 POST 永久保留原记录并阻塞该钱包新的划转、订单、设置及 Rebalance；原客户端编号查询／服务器编号关联尚未文档化，不能用余额变化或 Spot transactionHistory 猜测执行成功，也没有删除、重发或自动后续。共享锁不覆盖撤单，不能称作阻止所有账户写入。现有对外充提历史不是内部划转历史；本轮不宣称完整内部划转历史或链上回执。清除应用数据／卸载、响应写盘失败后立即杀进程的恢复限制仍保留。
- 新增 141 项（领域／映射 37、日志 24、签名协议 38、控制器 33、Widget 9），全量 2309 项测试通过；574 个 Dart 文件格式及静态分析通过，中英文各 1126 条消息；Android arm64 Release 构建成功、未安装。完整验证和构建哈希见 [验证记录](reference/internal-transfer-verification.json)，公开来源／协议边界见 [划转合同](reference/internal-transfer-public-contract.json)。测试仅使用签名／HTTP 替身、host 文件及 Widget；不请求真实钱包／RPC／私有／资金接口，不启动设备工具或安装 APK。
- 真实权限与平台行为、钱包回跳、原生文件／强杀恢复、中英文窄屏／横屏／平板／键盘／安全区及 iOS 均记录在 [原生待验收](native-verification-pending.md)。Linux 无 macOS／Xcode。实际对外充值／提现、主子账户划转、交易授权和整体 PRD 仍未完成；旧记录中“支持资产／合约划出上限待确认”的边界由本增量替代，原客户端编号恢复缺口继续保留。

## 2026-11-04 普通下单与单仓平仓 BBO

- 按 Futures trading PRD 的限价类型表，普通下单及专用单仓平仓新增手填价格／对手方买卖一档／同侧买卖一档的选择；LIMIT／STOP／TAKE_PROFIT 支持 BBO，保留原数量、方向、条件价、Last／Mark、触发保护及交易对支持的有效方式。单向减仓保留 reduceOnly，双向平仓保留原 LONG／SHORT 并省略 reduceOnly；不变成触发时全仓平仓。
- 本轮合并复核官方 New Order 的 `pegPriceType=COUNTERPARTY_1/QUEUE_1` 字段和同一 V3 文档的 `-5035 INVALID_PEG_PRICE`（BBO 要求 price 为 0），解决此前只看参数表时保留的价格约束缺口。普通类型使用独立两值枚举，不套用复合策略的 3／5／10／20 深档。公开文档重读哈希与之前相同，依据及完整合同见 [普通 BBO 合同](reference/ordinary-bbo-public-contract.json)。
- 业务 draft 的价格为空，只在 transport 参数中引入字符串零；不会把 0 填入用户价格框。禁止将普通 peg 混入市价、跟踪、触发时全部平仓、快捷市价或附加策略请求。普通与复合定价分别保留，切换市价／附加保护时不泄漏隐藏参数；滚动／刷新保留条款，恢复固定价保留手填输入。确认、提交后状态和未决恢复卡都展示冻结选择及参考价提示。
- 按所选档位在提交时或条件触发时定价一次，不持续追价。金额／保证金／BBO 平仓盈亏仅使用 Decimal 标记价／触发价参考预估，不假设实际盘口价或成交价；平台最终校验价格／风险／撮合。继续执行原有数量、条件价步长、触发方向、模式／仓位、时效和钱包作用域检查；平仓确认后先签名新读原仓位。EOA 直接签名，已有 Privy 钱包沿用，均不创建额外钱包。
- POST 前冻结并持久化原客户端编号及 peg，独立签名 GET 按原编号核对；响应需保留精确 peg、订单范围、数量／执行数量、有效方式及条件条款，缺失／不同／深档 peg 均未知。允许有效非负十进制的引擎定价，不能拿标记价作相等校验；固定价和市价响应若出现额外非空 peg 也拒绝。只有查询能报告状态与执行数量，POST 受理不代表成交，未知只查询且不重发。
- 未决日志升级 schema3，继续使用原 canonical 文件名以找到旧记录；严格兼容 schema1／2，普通 peg 字段仅 schema3 接受，旧记录不补造 peg。新版本写盘后降级旧应用不支持；磁盘损坏／不兼容保留并阻塞，不自动续跑。另修复普通下单监听只比事件时间的遗漏：同一时间戳事件重放同样使旧确认失效，签名期间无法继续 POST。
- 新增 60 项（domain／mapper／codec 40、签名及 host 恢复 12、Widget 6、控制器 2），全量 2168 项测试通过；556 个 Dart 文件格式检查及静态分析通过，中英文各 1088 条消息，Android arm64 Release 成功且未安装，哈希与验证见 [验证记录](reference/ordinary-bbo-verification.json)。本轮没有设备工具、APK 安装、真实钱包／RPC／私有或资金请求；只匿名读取 Notion／官方文档。真实权限、定价／条件触发／撮合、手机回跳／日志升级／强杀／布局和 iOS 全部列入 [原生待验收清单](native-verification-pending.md)。完整需求仍未完成，Chase、授权、资金及子账户等继续跟踪。

## 2026-11-04 负 USDT 的 Rebalance

- 对应 Portfolio PRD「USDT 出现负余额」：多资产模式下的负 USDT 需由用户先 Rebalance，才能提现或切回单资产。新增资产模式设置、Futures 提现信息页和未决通知入口；本轮只接通 Rebalance，实际提现仍无提交能力。当前多资产模式额外签名读取完整账户，USDT 缺失或负值均禁用切回单资产，不能把缺失当作零。
- Widget → Riverpod controller → repository → AsterAccountService，使用官方 `POST /fapi/v3/assetExchange`。该接口没有业务参数，由平台决定转换的资产、数量、价格和成本；界面明确说明可能改变抵押物，不提供虚构报价／费用或自动兑换。用户先手动读模式和完整资产，再查看确认；外部 EOA 直接签名，邮箱使用已有 Privy 钱包，均不创建额外钱包。Aster 是否接受同一 EOA 作为 user/signer 仍待真实授权验收。
- 首次读取两次签名，确认后新读模式／账户两次、请求签名一次、结果模式／账户核对两次，正常完整流程共七次。按最早快照起 30 秒有效；完整金融条款（账户汇总／逐资产／仓位）变化、同时间戳事件重放、配置提交、停止、离屏或钱包作用域变化均拦截尚未发出的 POST。Decimal／整数保留精度，无 double 金融运算；编号／钱包／原 nonce 可复制。
- main 首屏前加载独立 v1 文件日志，POST 前先串行落盘并 flush＋同目录替换，再复核作用域和有效期。只保存公开恢复条款和不可覆盖的返回响应，不保存签名或可执行队列；有界严格 JSON 解析现由 `core/exact_json.dart` 共用，funding 原导出保持兼容。目录／读写失败保留内存中的返回响应，重试合并；损坏、原记录丢失或不一致阻塞，不提升临时文件。
- 返回空 body 才是平台报告未发生转换，JSON null／空对象不是无操作；明确返回的转换余额与另行签名读取的当前账户分开展示。已保存响应需完成新的账户读取才移除记录；停止／切账户／退出路由／provider 释放后的已返回响应仍归原钱包。发送后未知保留原 nonce，拦截新 Rebalance、下单和合约配置，不自动重发或清除；撤单不属于此共享锁的覆盖范围。官方没有按原 nonce 查询结果的协议，因此后来余额非负也不能解除未知记录，缺口需平台提供可验证恢复合同。
- 新增 84 项（协议 25、日志 18、控制器 29、Widget 7、模式拦截 5），全量 2108 项测试通过；551 个 Dart 文件格式及静态分析通过，中英文各 1085 条消息。Android arm64 Release 成功、未安装，构建哈希及自动验证见 [本轮验证记录](reference/rebalance-verification.json)，公开协议及边界见 [合同记录](reference/rebalance-public-contract.json)。没有设备工具、APK 安装、真实钱包／RPC／私有／资金请求。真实转换、七次签名体验、手机文件／强杀恢复、原生布局与 iOS 全部只记录在 [原生待验收清单](native-verification-pending.md)。Rebalance 返回不代表提现获准或单资产切换已完成；本轮不自动执行后续资金／配置操作，整体 PRD 仍未完成。

## 2026-11-04 ERC‑20 授权与未决恢复

- 充值 Gas 页增加独立的精确授权／清零入口。当前 EOA 或已有 Privy 钱包直接发送；不创建新钱包。先明确展示本次数量、代币目标、链上 vault spender、Gas、nonce 和作用域，再单独确认。只允许 ERC‑20 approve；原生币或已有充足 allowance 的充值步骤无法经此入口发送。每个后续步骤都需重新读取、预估和确认，成功后不自动充值。实际充值仍因 PRD 要求的平台／用户剩余额度不可验证而阻塞。
- 确认后重新读余额／allowance 并模拟 Gas／nonce，将精确 unsigned 参数与已确认条款对比；变化或过期要求重新预览。先将恢复条款落盘，再核对钱包和最早有效期才请求发送。明确未发送／结构化拒绝可移除记录；未知保留，绝不重发。停止／退出／切账户／provider 释放后返回的哈希仍写入原钱包记录。钱包弹窗的最终执行状态不以 UI 操作推断。
- main 首屏前加载独立 v1 文件日志；严格有界 JSON／整数／ABI 校验，串行更新、临时文件 flush 后同目录替换、损坏保留。同一钱包任何支持链存在未决授权就阻止新授权。保存哈希时即使目录、文件读取或写入失败也先保留内存哈希并阻塞新发送；重试核对原条款后合并回原记录。文件只含公开 unsigned 条款和可选哈希，不含签名／密钥／自动执行队列。
- 充值和资金信息页提供当前钱包恢复入口。恢复后的 EOA 无需签名即可显式公开查询；手填原哈希或钱包加速／取消哈希，先核对链／from／nonce，再比较 to／input／value。回执还核对交易块号／哈希、状态、Gas、最近区块和原块的规范哈希，至少观察两次确认才解除未决状态。它是客户端观察策略，不保证最终性；成功也不证明 allowance 已变化，要求重新读取。不同意图的同 nonce 替换只报告“已替换”，不报告授权成功；pending 替换不覆盖原哈希。
- 回执费用用 BigInt 精确计算 gasUsed × effectiveGasPrice（缺失时取交易 legacy gasPrice，否则未知），明确额外网络费可能另计。失败／停止／滚动保留手填哈希，地址／合约／nonce／哈希可复制；钱包变化隐藏旧记录。无重发、删除、自动扫描 nonce 或自动发现哈希；无原始错误／堆栈展示。应用数据清除、卸载及哈希写入失败后立即进程丢失的边界保留在合同中。
- 新增 108 项自动测试：日志／codec 19、替身 RPC 40、控制器及 host 文件 40、Widget 9；全量 2024 项通过，536 个 Dart 文件格式检查及静态分析通过，中英文各 1056 条消息。Android arm64 Release 成功，哈希与验收见 [验证记录](reference/deposit-approval-verification.json)。
- 公开协议及边界见 [授权合同](reference/deposit-approval-public-contract.json)。本阶段不使用设备工具、不安装 APK、不请求真实钱包／链上／私有／资金接口；真实钱包、手机文件写入／强杀恢复、网络替换／重组、原生中英文布局及 iOS 均记录于 [待验收清单](native-verification-pending.md)。实际充值／提现／划转及整体 PRD 仍未完成。

## 2026-11-04 EOA／Privy 钱包交易发送底层

- 新增不可变 `EvmWalletTransaction`，按三条充值链校验精确地址、偶数 hex calldata、uint256 金额／单价、uint64 Gas 与 nonce；RPC 参数固定包含 from／to／chainId／data／value／gas／gasPrice／nonce，以 BigInt 生成规范 hex，不能被 Widget 修改。没有新增依赖、用户界面或文案，应用仍提供既有中英文。协议及参考源码哈希见 [合同](reference/wallet-transaction-public-contract.json)。
- Reown 新会话请求 eth_sendTransaction，发送前核对原地址／所选链／会话批准的方法和链，旧会话缺权限时在发请求前失败；不会隐式切链或提升授权。直接委托当前 EOA，external 路径不调用 Privy 交易通道或创建钱包。邮箱登录路径只使用已存在且唯一匹配的 Privy 钱包。repository 与 Reown connection 各自阻止并发发送，钱包提示期间及会话变化后仍保持锁直到请求结束；不会自动重试。
- 参考 `/data/dodo/rwa-interface/lib/data/auth/privy_transaction_requester.dart`，为固定 Privy Flutter 0.10.2 复用同一 `privy_flutter` 原生通道的 ethSendRpcRequest：一个 transaction JSON 字符串及已有 walletAddress。SDK 公共 Dart provider 会丢弃 PlatformException code，这个仅允许发送方法的适配器保留原生结构化 code 并校验 response.method。原生插件仍可能把 4001 归并为 RPC_REQUEST_FAILED，不能从错误文本恢复成拒签结论。
- 本地校验／身份／地址／签名能力／调用方作用域／链／权限失败使用明确的发送前异常。调用钱包 RPC 后仅结构化 4001 为拒绝；超时、断线、模糊错误（包括文本含 rejected／4001）、无效／零哈希、错误 response.method 或独立 modal 异步错误均为结果未知。只认非零 32 字节返回值为“钱包已返回哈希”，不认作链上成功。退出、切钱包、换用户或释放 repository 后返回的哈希仍交给原调用者，后续资金日志必须按原钱包记录，不能套用普通只读请求的迟到丢弃规则。原始错误与调用栈不进入 UI。
- 新增 83 项（领域／dispatch 37、Reown 11、EOA repository 9、Privy 原生 channel 26），全量 1916 项测试通过，522 个 Dart 文件格式检查和静态分析通过，中英文各 1024 条消息。Android arm64 Release 构建成功，哈希见 [记录](reference/wallet-transaction-verification.json)。仅使用替身 WalletConnect modal、Privy 用户和 MethodChannel；没有请求真实钱包、执行链上／私有／金融请求、设备工具或 APK 安装，iOS 未构建。真实钱包权限／回跳／费用参数及 native 4001 边界列入 [待验收清单](native-verification-pending.md)。
- 这是实际资金操作所需底层，尚未接通业务确认／提交入口；实际充值／授权尚未完成。后续必须补齐发送前持久化日志、回执和原交易核对、未知哈希／替换／重组恢复、原钱包结果保存及平台到账；用户／平台额度仍依赖尚无第三方鉴权的私有 BAPI。充值页继续仅提供预检查和单步 Gas 模拟。

## 2026-11-04 充值交易编码与下一步 Gas 预估

- 充值金额表单新增显式预估入口，沿 Widget → Riverpod controller → repository → 只读 JSON-RPC service。先重新读取当前钱包的链 ID、固定区块余额／精度／allowance，再按官方三条 EVM 主网 vault 的 `depositFor(address,address,uint256,uint256)` 编码；接收账户始终为当前钱包，Spot broker=1000，Futures broker=0，原生币使用固定占位符且 value 等于精确最小单位金额，ERC20 value=0。仅支持公开目录的 normal 路径，不推断其他路由；ABI、来源及边界见 [协议记录](reference/deposit-gas-public-contract.json)。
- ERC20 授权不足且为零时仅准备 approve(vault,amount)，已有非零额度不足则先准备 approve(vault,0)。每次只模拟当前一步，清零／授权后必须重新读链状态；不准备无限授权，也不以授权预估替代充值预估。恢复后不能签名的 EOA 可公开估算，不创建新钱包；此阶段没有钱包交易发送能力。
- 使用 gasPrice 快照、latest／pending nonce（有待确认交易即拒绝）、精确 from／to／data／value／nonce 的 pending 模拟；Gas 上限为 ceil(模拟单位×1.20)，20% 是客户端预留规则而非实际费率。再次复核固定区块哈希、区块 gasLimit 和 pending nonce。全程 BigInt；原生币余额必须覆盖 value＋Gas 上限×单价。价格、链状态及实际执行仍可变化，发送前仍需新预估；后续步骤另需预留，原生 Max 继续禁用。
- 有效期取钱包读取后 30 秒、预估后 30 秒、区块时间后两分钟的最早期限，避免慢模拟延长旧余额有效期；拒绝过期或异常时间。失败保留旧预估并标历史，修改金额提示旧预估对应的金额，停止／路由释放／身份与签名能力变化丢弃迟到结果，路由持有 provider 防止滚动丢失。展示当前步骤、精确充值量、可复制目标合约、附带原生币量、单位／上限／单价／预留／总量及时间；没有充值提交按钮。RPC 错误只映射安全文案，不显示原始 revert 信息。
- 自动验收新增 100 项（领域 26、替身 RPC 37、控制器 31、Widget 6）；充提专项 342 项及全量 1833 项通过，515 个 Dart 文件格式无改动、静态分析无问题，中英文各 1024 条消息。Android arm64 Release 构建成功，哈希及验收记录见 [验证记录](reference/deposit-gas-verification.json)。没有使用设备工具、安装 APK、查询真实钱包、发送真实签名／金融请求；三条链的实际模拟、钱包回跳／原生布局及 iOS 仅记录到 [待验收清单](native-verification-pending.md)。用户／平台剩余额度仍依赖尚无第三方鉴权的私有 BAPI；实际授权／充值发送、链切换、回执／平台到账与未知结果持久化恢复均未完成，整体 PRD 继续推进。

## 2026-11-04 Scaled 初版分段委托

- 重新读取 Futures PRD：明确区间拆单／总量／子单预览，未确认实际表单、数量／价格分布或专用接口。采用此前说明的 Vanta 初版规则：用户选择 2–5 笔 GTC LIMIT，同一方向，价格端点精确且包含上下限；区间 tick 按索引比例向下取整，生成不同、近似等距价格。先给每笔 LOT_SIZE minimum，再等分剩余整数 step，尾差按价格从低到高分配；不适配的总量直接报错，不截断用户数量。产品规则尚待确认，不写成 Aster App 事实。官方 batchOrders 仅是候选，本实现逐笔普通 order，不承诺批量原子性；来源／公式／边界见 [公开协议及产品规则](reference/scaled-order-public-contract.json)。
- 普通实盘路由提供独立分段入口，专用平仓／仓位条件单不显示。用户显式读取账户／模式／资金后填写空默认的上下限、总量、方向及笔数；预览全部价格、数量、总量占比（约）、名义价值及汇总，确认冻结每笔独立 clientOrderId 和原条款。例：79000–81000、0.008 BTC、3 笔拆为 0.003@79000、0.003@80000、0.002@81000，合计 639 USDT。保证金仅显示未扣净额的总限价名义价值 ÷ 杠杆参考，明确不含仓位净额、已有挂单、手续费或释放保证金，不能作为最终可执行额度。
- Widget → Riverpod controller → 现有 signed repository → service。每笔单独新读取四类已签名上下文／配置／资金，再校验限制、签名 POST 和 GET 原编号核对；初次读取四次签名，每笔通常另需六次。共享配置／交易锁阻止并发；钱包身份、类型及签名能力变化使旧方案失效并隐藏旧输入／结果。每笔读取和 POST 前核对 30 秒有效期、账户事件对象（包含同时间戳重复事件）和配置／规则，配置变化停止余下子单；读取失败保留具体安全原因。继续使用当前 EOA，不创建额外钱包；enable-trading 与同 EOA 权限仍未证明。
- 所有子单独立执行，失败、未知、拒绝／取消／过期后停止余下提交；可停止等待或离开路由，阻止未发送 POST，已发单仍可完成查询且不会被撤销。取消确认、拒签和未知保留输入；未知期间锁定编辑与新操作，只能 GET 原编号，绝不自动补单、重复提交或续跑未发送队列。每笔复用原生预写日志：POST 前存原条款／编号，已核对后删对应记录；重启只恢复已发未决子单，不持久化可执行队列。查询状态不等于全部成交或最终余额。
- 新增 68 项自动测试：领域 27、控制器 26、真实签名仓库＋替身 HTTP／host 文件 8、Widget 7。覆盖四种笔数／两种方向、非整除 tick、非 step 整倍数的 minimum、极小量／精确总量／限制、篡改确认；逐笔新资金、配置及重复事件变化、超时／拒签／未知、共享锁与旧记录、切钱包、原编号 GET-only；单／双向买卖与精确签名字节、POST 前实际文件／第二笔未知重建、不恢复未发；中英文 320 宽／1.5 倍文字／横屏、全部预览、取消／保留输入、钱包隔离、离页及五笔卖单停止按钮。
- 全量 1733 项、506 个 Dart 文件格式、静态分析通过，中英文各 1002 条消息；Android arm64 Release 构建与哈希见 [验证记录](reference/scaled-order-verification.json)。未使用设备工具、未安装 APK、未发送真实私有／金融请求；签名钱包回跳、真实平台权限／撮合、手机存储强杀恢复／原生布局和 iOS 只列入 [待验收清单](native-verification-pending.md)。整体 PRD 仍未完成，其余缺口见 [需求进度](prd-progress.md)。

## 2026-11-04 剩余范围复核（Scaled 接入前）

- 当前未完成范围和开发草稿见 [PRD 进度](prd-progress.md)。Scaled 只有领域／控制器草稿，未接入应用页面，没有专项自动测试或真实验收，不构成可交付功能；拆单规则仍为初版产品假设。
- 真机待验收仅记录，不启动设备工具、安装 APK、发送真实私有或金融请求；iOS 继续受 Linux 环境限制。最近一次完整功能验证为下述 BBO 增量，不能据其测试数量声称 Scaled 已验证。

- 本次复核修正草稿的格式／lint；496 个 Dart 文件格式检查、静态分析及现有 1665 项回归测试通过，Android arm64 Release 构建成功且未安装。草稿没有专项测试，不能据这些检查认定 Scaled 行为已验证；构建哈希与日志见 [复核记录](reference/remaining-scope-review-verification.json)。

## 2026-11-03 开仓附加 TP/SL 的 BBO 主单

- 复核官方 V3 的复合策略创建／查询协议，接入 LIMIT／STOP／TAKE_PROFIT 主单的 BBO 定价：对手方或同侧 1、3、5、10、20 档，共十种。仅启用附加止盈止损且使用限价／条件限价主单时显示，未默认选中；市价／追踪／仅减仓／专用平仓不携带该设置。普通 order 端点的 peg 价格约束仍不明确，不从复合策略或官网私有请求推导普通下单参数。官方文档和公开官网源码版本见 [合同](reference/attached-entry-bbo-public-contract.json)。
- 使用不可变枚举保留精确 pegPriceType；用户草稿不携带假限价或 0 价格，只有策略子单参数在数据边界生成字符串 price=0。当前交易对有效策略仍限制 GTC／GTX／HIDDEN，IOC 不用于复合订单。TP／SL 仍为固定本次新增敞口数量的条件市价保护，主单全部 FILLED 后激活，双保护全部 FILLED 后撤同组另一条，不改变原有仓位复核、三次签名与数量／关联规则。
- 界面说明只在限价提交时／条件触发时按所选档位定价一次，不持续追价。确认与受理结果／恢复卡显示 BBO 档位名称，避免把 0 当成实际价格；下拉选项按内容高度换行，窄屏／放大字体不以省略号截断档位，菜单可滚动访问最后一项；固定价格在切换 BBO、市场类型、附加保护及滚动后保留，恢复固定价需显式选择。拒签和未知结果保留输入；未知期间不能切换档位或创建新策略。
- 金额与保证金按 Decimal 预估：普通 BBO 主单使用标记价，条件 BBO 主单使用触发价；明确这些不是所选盘口档位或成交价。不用本地猜测的盘口价硬性判断附加 TP／SL 相对主单价格方向；平台在实际定价后复核，HTTP 200 的 failureCode=-4142 仍通过原有失败检查与原编号查询处理。触发价步长、主单触发方向、数量、最低参考名义价值及资金读取约束仍校验。
- 独立查询同时核对精确 pegPriceType 和协议返回的 price=0；缺失、不同侧／档位、未知类型、正价格或其他条款不匹配均保留未知，只可 GET 核对，不重复 POST。固定价主单／保护子单也拒绝意外出现的非空 peg，防止数值巧合相同被误判为原策略。策略状态仍不代表成交数量、成交价、余额或剩余仓位。
- 未决订单日志升级 schema 2，冻结 peg 并继续使用原 canonical 文件路径，能找到并严格读取旧 schema 1 的普通／附加策略记录；实际文件读取及完成后的 v2 重写已用 host 文件测试。旧 schema 不接受新 BBO 字段，畸形和不兼容记录不清空。降级到旧应用不能读取 v2；原进程重建 GET-only 恢复继续适用，不保存签名、密钥或账户快照。
- 新增 56 项，全量 1665 项测试、494 个 Dart 文件格式检查及静态分析通过，中英文各 978 条消息；Android arm64 Release 构建成功，结果与哈希见 [验证记录](reference/attached-entry-bbo-verification.json)。本轮不启动设备工具、不安装 APK、不发真实私有请求或金融交易；所有真实撮合／触发／拒绝、手机布局／钱包回跳／文件升级及 iOS 验收均只列入 [待验收清单](native-verification-pending.md)。完整需求仍未完成，普通／专用平仓 BBO、Chase、Scaled 及资金／授权／子账户等继续跟踪。

## 2026-11-03 充值钱包余额、授权与金额预检查

- 充值资产卡提供「充值钱包预检查」入口，沿 Widget → Riverpod → repository → JSON-RPC service 公开读取当前认证钱包的链上余额。默认 PublicNode Ethereum／BNB Chain／Arbitrum 三个固定 HTTPS 主网端点；匿名 eth_chainId 探测均返回所选链 ID，响应及来源哈希见 [合同](reference/deposit-wallet-public-contract.json)。本轮未读取真实用户余额，不将端点链 ID 探测当作钱包或充值验收。
- 手动读取，无自动网络余额请求或签名。恢复后尚不能签名的外部 EOA 也可读取公开余额，地址来自当前身份，不创建额外钱包；没有地址时引导现有登录。先核对 RPC 链 ID，固定最新区块号／哈希／时间，再在同一高度读取原生币余额，以及 ERC20 decimals／balanceOf／allowance，最后重读区块哈希，变化则拒绝该快照。ERC20 精度必须与配置一致，原生 EVM 精度固定 18；ABI 32 字节无符号整数及 RPC 十六进制数量严格校验，全程 BigInt／Decimal，不经过 double。
- allowance 的 spender 仅使用官方文档三条主网 vault，地址可复制且明确标为授权查询对象，不能手动打款；原生币没有 ERC20 allowance，不伪造零授权。不开放发送交易方法，RPC service 对 eth_sendTransaction 或其他非读取白名单方法在发网络前拒绝；固定 origin、禁止重定向、请求 ID／envelope、限流／超时／大小和安全错误均验证。
- provider 按市场／链／资产合约／精度／类型／最低额隔离；30 秒标历史，已超过两分钟的区块立即视为历史。失败保留旧快照，重复读取互斥，停止等待、退出和身份／地址／钱包类型／签名能力变化丢弃迟到响应；路由持有仓库及快照直到退出，防止惰性列表控件离屏时丢失。金额输入离屏及刷新失败后保留，切身份／地址／钱包类型清空，不自动提交任何操作。
- 从公开配置及官网校验提取可选 minDeposit，数值型金额改用共享的严格词法 JSON parser，按原始数值文本直接解析 Decimal，元数据数值与数字字符串保持区分；字段缺失为未知，不合成零最低额。parser 拒绝重复 key、超过 32 层、非法语法和数字对象键，256 Ki UTF-16 code units／数字 160 字符／金额指数绝对值 160 的资源上限。费用端点继续复用此 parser，普通账户服务仍用原解码；四类已保存生产目录及三份生产费用响应重新通过正式 decoder／mapper。
- 金额预检查支持正数、资产精度、最低额、精确最小单位与 uint256 上限、当前匹配且未过期余额；代币 allowance 单独判断。代币 Max 仅填钱包余额，明确不代表平台可充上限；原生 Max 因 Gas 未估算禁用，避免把全部原生余额当作可充值。未知最低额、陈旧／缺失余额和余额不足给出明确原因；展示最小单位不生成交易 calldata，也不证明充值成功。
- 官网当前实现还用 get-asset-residual-deposit 及 user-balance 的 residualDeposit／residualPlatformDeposit 计算用户和平台剩余额度，都是私有 BAPI。现无已验证第三方登录协议／后端，不能把缺失值按无限额处理，也不能用 V3 可提额度替代充值额度。因此保留为预检查，实际 Gas 估算／链切换／授权发送／充值提交／持久化恢复／回执及平台到账仍未完成；不把预检查通过当作资金闭环完成。
- 新增 78 项：33 个金额／最低额／JSON、27 个 RPC 仓库与传输、10 个生命周期、8 个 Widget 测试；全量 1609 项、490 个 Dart 文件格式及静态分析通过，中英文各 971 条消息。覆盖三链精确读取、满 uint256 allowance、大整数／小数、错链／错精度／重组、停止／身份变化／资源释放、代币及原生差异，以及中英文 320 宽／1.5 倍文字／横屏与输入保留。Android 构建及哈希见 [验证记录](reference/deposit-wallet-verification.json)，无设备工具、APK 安装、真实用户余额／私有请求或资金交易；iOS 无 macOS／Xcode，原生验收只记录。

## 2026-11-03 最新公开提现费用

- 提现资产卡增加「查询最新提现费用」入口，只为用户选中的市场／网络／币种打开独立费用页并做一次匿名读取，不请求全部可见资产的费用，不要求登录、创建钱包或签名。费用页保留固定范围并分别显示币种手续费、USD 手续费、可选的 USD 参考单价及本地化读取时间。充值卡不提供此入口。
- 按 Widget → Riverpod family → repository → service 调用官方 `GET https://www.asterdex.com/bapi/futures/v1/public/future/aster/estimate-withdraw-fee`，参数为选定的 `chainId/network=EVM/currency/accountType`。只接受文档三条 EVM 主网和有效币种名，输入不合法则不发送。固定 HTTPS 域名、无签名／密钥、禁止重定向；超时／限流／畸形响应均提供安全错误，不展示原始响应。
- 该接口示例及实测返回 JSON 数值。新增仅供此端点使用的解码器：在 JSON 解码之前，保留字符串／转义，将数值值域的原始词法文本保留为字符串，然后将金额直接解析为 Decimal；避免先转 double 再转字符串。拒绝数字对象键、残缺数字、非法转义等畸形 JSON，限制响应 256 Ki UTF-16 code units、数字／金额 160 字符及指数绝对值 160；共享账户传输新增可选解码回调，其他账户／目录继续使用原解码方式。
- 验证严格 `code=000000/success=true/data=object`；gasCost 和 gasUsdValue 必须为非负有效数值，缺失失败而非补零，显式零费用保留。tokenPrice 可缺失，提供时必须为正；不使用 gasLimit/gasPrice/nativePrice 推算用户钱包 Gas，不将平台费用混为链上钱包交易费。负业务错误码仍由共享传输安全分类。
- family 作用域包含市场、链和币种，相等查询共享一次请求，错误作用域的返回不替换旧值。30 秒陈旧计时在刷新等待期间仍生效；刷新失败保留旧估算并标陈旧，可手动重试，没有自动轮询／签名。仓库被 watch 到最后一条费用路由退出，释放客户端并丢弃迟到结果。界面明确估算不授予提现权限，也不是最终提交费用。
- 匿名实测并通过正式 decoder／mapper：BSC USDT Perp 为 0.11 USDT／0.1 USD，BSC BNB Spot 为 0.00015 BNB／0.1 USD，Ethereum ETH Perp 为 0.00022 ETH／0.5 USD；这些仅为记录时的估算，不能作为之后执行的费率。原始 lexeme、响应及文档 SHA256 见 [公开合同](reference/funding-fee-public-contract.json)。
- 新增 70 项（41 个数字／JSON／数据边界、15 个仓库传输、7 个状态生命周期、7 个 Widget 测试），全量 1531 项、475 个 Dart 文件格式及静态分析通过，中英文各 941 条消息。覆盖 39 位小数和大整数／科学计数法、精确单位、三链双市场、无签名与单资产请求、过期／失败／重试／释放，以及中英文 320 宽／1.5 倍文字及横屏。Android 构建与哈希见 [验证记录](reference/funding-fee-verification.json)；没有设备工具、APK 安装或真实私有／资金请求，iOS 无 macOS／Xcode，原生验收均仅记录。
- 最新费用查询是提现必需的前置步骤。实际提现仍需主账户资格、最终额度和费用复核、用户业务签名＋API 签名、持久化提交及未知结果恢复；实际充值／授权／划转也仍未实现。原来的提现信息快照费用继续标明其来源，不用最新公开估算覆盖已签名快照的含义。

## 2026-11-03 充提网络／资产目录与提现额度只读

- Spot／Futures 资产面板新增「充提信息」入口，按 Widget → Riverpod → repository → service 匿名读取官方充值／提现资产目录，分别选择市场、操作和网络。当前仅覆盖文档的 Ethereum（1）、BNB Chain（56）、Arbitrum（42161）三条 EVM 主网，不代表 Aster 全网络。币种搜索、首次加载、空态、失败保留／重试与五分钟陈旧提示齐备；切查询释放旧客户端，迟到结果不接纳，自动释放仓库被控制器 watch 到最后一个消费者离开。
- 数据边界验证业务 envelope、字段类型、链／币种重复、EVM 地址、原生标记与精度；保留未知 route 而不推断可执行性。原生币占位地址不展示为目的地，ERC20 地址明确标为「代币合约 · 不是充值收款地址」且可复制。未提供付款目的地、代币授权或链上提交。
- 提现页以当前 EOA 显式签名调用只读 `POST /fapi/v3/aster/user-withdraw-info`，server time 后使用独立单调纳秒 nonce（毫秒 × 1,000,000）、30 秒签名期限、EIP-712 chainId=1666，`nonce/user/signer` 查询后最后附加 signature；禁止重定向，不记录签名 URL／敏感响应。不自动签名或创建 agent／替代钱包，Aster 是否接受当前 EOA 同时作为 user／signer 仍待真实授权联调。
- USD 用户／平台日限额及逐资产日限额，与所选市场的币种总量、所选链数量／限额和币种手续费分别显示。金额按官方字符串直接转 Decimal，数字 JSON 拒绝；缺失为未知，不以余额补齐，不合成最终 Max。负报告数量保留，负费用拒绝。当前费用仅为已读取快照，未接动态费用端点；不能作为最终提现费用或资格。
- 私有数据须手动读取／刷新，支持停止等待、30 秒历史提示、失败保留和钱包身份隔离。Spot／Futures 账户事件标记旧信息，不触发自动签名；同时间戳重复事件仍有效。提现路由保留 provider，修复惰性列表控件与资产卡之间离屏可能导致快照释放的问题；离开路由使迟到签名／响应失效，不声称关闭外部钱包弹窗。搜索离屏及刷新后保持。
- 匿名读取四种生产配置均通过实际 mapper：Spot 充值 94／提现 95，Perp 充值 33／提现 39，均返回链 1／56／42161。仅说明公开配置可读，不证明账户资格或可执行充值；来源文档／响应 SHA256、参数与限制见 [合同记录](reference/funding-info-public-contract.json)。
- 新增 59 项测试覆盖数据精度与单位、原生占位符／代币合约、四种匿名查询、精确私有签名参数、拒签与迟到保护、服务生命周期、过期／重复时间戳事件、两种市场入口、登录／停止／退出、中英文 320 宽与 1.5 倍文字及横屏。全量 1461 项、464 个 Dart 文件格式及静态分析通过，中英文各 930 条消息；Android 构建及哈希见 [验证记录](reference/funding-info-verification.json)。遵照用户要求无设备工具、APK 安装或真实私有／资金请求；原生钱包／布局／复制和 iOS 验收均仅记录。
- **实际充提仍未实现**：充值需要钱包原生／代币余额、链切换、最低金额／allowance／授权、最小单位、gas、depositFor、链上回执及平台入账核对；提现需要主账户资格、最终费率／额度、业务签名与 API 签名、确认／提交和未知结果恢复。Spot／Futures 及主子账户划转、enable-trading 与完整 Portfolio 继续保留，不把只读前置标为资金闭环完成。

## 2026-11-03 子账户签名列表

- 账户菜单新增「子账户管理」入口，按 Widget → Riverpod → repository → service 接入 `GET /fapi/v3/getSubAccountList`。打开页面不读取私有信息；用户显式签名后展示账户名称、精确可复制 ID、主／子账户标记和子账户数量，支持按名称／编号搜索、首次空态、仅主账户、进度、停止等待、失败保留与重试。搜索状态在滚动离屏及刷新后保留；读取列表不改变认证身份、演示账户或当前交易钱包。
- 签名严格按 `nonce → user → signer` 顺序，signature 最后附加，EIP-712 chainId=1666；使用共享微秒单调 nonce、固定 fapi 域名及禁止重定向的 GET。仍仅尝试当前连接 EOA 同时作为 user／signer，不生成 agent 或替代钱包，服务端是否认可其关联 signer 资格未完成真实授权联调。官方原文已重新匿名读取，SHA256、合同及边界见 `reference/subaccount-list-public-contract.json`。
- 列表数据边界严格保留不可变名称、正 64 位整数 ID 及 parentAccount 布尔值，拒绝重复 ID、多主账户和畸形响应。最多 1000 行／单名称 4096 个 UTF-16 code units 是客户端资源保护，不是创建上限；PRD 的最多十个子账户约束应在创建时实施，现存超过十个的记录仍完整显示，不截断。没有规定分页参数，不自行补发。
- 官方列表仅明确返回 accountId／subAccountName／parentAccount，未返回子账户地址、冻结状态或切换授权。ID 不转成钱包地址，不根据名称推断映射，也不添加臆测的 accountId 交易参数或“当前激活”标记。创建还需要独立 childSignature，再由主钱包签署包含该签名的消息，接口仅返回 code／msg，不返回私钥；子钱包托管方式待用户偏好确认。updateSubAccount 需要 subSourceAddr，当前列表也不能用作冻结前后状态核对。因此本轮只完成真实列表，创建／切换／冻结及主子划转仍待实现。
- 共用账户读取控制器增加停止等待：保留已有陈旧列表，递增 generation，使迟到签名不发送、迟到响应不接纳；不声称取消了钱包自身弹窗。列表 provider／repository 自动释放，离开页面关闭客户端并使未完成操作失效；30 秒将已有列表标历史，不自动重签。身份、地址、钱包类型及签名能力变化均清除列表。列表控制器显式 watch 自动释放仓库，保证签名／网络等待时客户端存活，页面结束才释放；同样修正资产指数控制器仅 read 仓库可能提前释放的问题，并增加两项延迟请求与释放时机回归。修复 AuthController 观察器遗漏 walletKind 的问题，同一地址由内嵌／外部签名方式切换也传播新身份并使相关快照失效。
- 新增 39 项测试，全量 1402 项通过；447 个 Dart 文件格式检查无改动，静态分析无问题，中英文各 893 条消息。覆盖精确签名字节、拒签／畸形签名不发送、重定向／安全错误、微秒 nonce 共享、迟到结果／停止／退出／身份变化、64 位 ID、超过十个现存账户不丢失、空态／搜索／复制／失败保留，以及中英文 320 宽／1.5 倍文字／横屏。Android arm64 Release 构建成功，未安装；最终校验见 `reference/subaccount-list-verification.json`。
- 按用户要求没有设备工具、APK 安装、真机或真实私有／金融请求；本次待验收见 [清单](native-verification-pending.md)。Linux 无 macOS／Xcode，iOS 仍未构建。交易授权、完整子账户管理和实际资金操作等尚未完成，见 [需求进度](prd-progress.md)。

## 2026-11-03 资产参考估值与小额过滤

- Spot／Futures 资产列表新增独立公开美元指数估值，沿用 Widget → Riverpod → repository → service。匿名 GET `/fapi/v1/assetIndex` 在边界严格验证为不可变 Decimal 指数快照，按资产名精确关联 `资产USD`，使用 `index`，不用买卖缓冲、永续标记价或固定稳定币汇率。匿名样本 43 个指数中 USDTUSD 为 0.99836000；该接口来自 PRD 对官网的来源分析，本轮不宣称它具有稳定开发者协议保证。来源、样本和 SHA256 见 `reference/asset-valuation-public-contract.json`。
- Spot 总量为 free＋locked，可用量为 free，分别给出 USD／BTC 参考估值。Futures 钱包量使用 walletBalance，逐资产保证金量使用 walletBalance＋接口明确提供的 unrealizedProfit；缺少浮盈亏时保留未知，不补零。钱包参考汇总只加钱包资产，不含浮盈亏、其他账户、Staking／Grid／Vault／预测市场、抵押折扣或执行成本，不能标成完整 Portfolio Total Value。缺价显示未知并列出排除数量；全部资产缺价时不显示虚假的零小计。已知零数量可直接显示零，无需推断价格。
- USD 乘法及汇总全部精确 Decimal；BTC 仅显示除法舍入，汇总先精确加 USD 再除一次 BTCUSD，极小数保留非零值。Spot 新增小额过滤，严格条件为 USD×10000 > BTCUSD，等于 0.0001 BTC 也隐藏，不用舍入后的 BTC 或固定美元线判断；缺价、价格陈旧、BTC 指数缺失／陈旧或账户快照陈旧时保留该资产。搜索及过滤不改变钱包汇总。隐藏零余额时仍保留 USDF／ASBNB。
- 页面有消费者且处于前台时每 30 秒公开刷新，共享一次请求，显式刷新不并行。当前应用新鲜度策略为接收后不足 60 秒、指数源时间不足 90 秒、最多允许 30 秒未来时钟偏差；这不是交易所服务保证。独立失效计时器可在网络请求未完成时标陈旧。失败保留值及安全提示，重试成功恢复；后台／失去消费者取消定时任务，恢复重新读取，generation 丢弃暂停前或已释放的迟到响应。只刷新公开价格，不自动签名账户。
- 本轮核对 Spot／Futures 划转协议：官方文档有 amount／asset／clientTranId／kindType 的 POST 及 tranId／status 响应，方向为 SPOT_FUTURE／FUTURE_SPOT；未定义按 clientTranId 查询的接口，也未定义该编号与 Spot 流水 tranId 的关联。超时后的原操作恢复、可划资产稳定协议及合约可划上限仍待确认，尚未实现划转；不凭余额差、重复编号错误或点击动作认定执行。具体文档版本及缺口见上述协议记录。
- 自动验收新增 42 项，全量 1363 项测试通过；437 个 Dart 文件格式检查无改动，静态分析无问题，中英文各 877 条消息。覆盖实际稳定币价格、超高精度临界值／极小数、缺价／陈旧、汇总除法、失败重试、30 秒轮询、请求中的到期、暂停／恢复与迟到响应，以及中英文 320 宽／1.5 倍文字／横屏。Android arm64 Release 构建成功，未安装；最终校验见 `reference/asset-valuation-verification.json`。
- 按用户要求没有启动设备工具、安装 APK、真机实测或发送真实私有／金融请求；本次原生待验收项已加入 [清单](native-verification-pending.md)。Linux 无 macOS／Xcode，iOS 仍未构建。完整产品总值、真实授权、实际资金操作等仍按 [需求进度](prd-progress.md) 跟踪。

## 2026-11-03 充提历史与状态通知

- 新增 `funding` feature，按 Widget → Riverpod → repository → service 分层读取 `POST /fapi/v3/aster/deposit-withdraw-history`，从通知中心及 Spot／Futures 资产面板进入。页面打开不读取私有信息，用户点击后才使用当前钱包签名；读取双方市场后按市场在本地筛选，记录展开显示可复制编号／哈希、Decimal 数量和资产、状态、网络 ID／已知网络名及 UTC 记录时间。未知网络保留 ID，缺失哈希明确未知，不猜失败原因或完成时间。此入口不提交充值、提现或划转。
- 仅该 funding 历史协议使用充提文档明确示例的毫秒 × 1,000,000 nonce、30 秒签名期限，以及签名 query／signature-last 的只读 POST。共享 nonce 对象按单位分别维护单调计数，既有交易／现货的微秒 nonce 和签名字节不变。当前 EOA 仍同时作为 user／signer，没有导入专用私钥或创建替代钱包；官方充提文档描述专用 signer，主 EOA 是否获授权仍未联调。文档未定义分页、筛选参数、记录保留期或完整历史保证，不自行发送这些参数。合同及文档 SHA256 见 `reference/transfer-history-public-contract.json`。
- 每个钱包第一次成功观察（包括空响应）只建立覆盖两个市场的本地基线，不把已有历史当新通知。之后按钱包＋市场＋充提类型＋记录 ID＋状态去重，未见过的记录／状态生成 `FUND_TRANSFER` 通知。每条观察保存已见状态集合；官方未定义状态更新水位或变更顺序，不擅自禁止 FAILED → SUCCESS 或仅凭 time 判定迟到状态；同状态重放、缺失记录后重新出现及同状态哈希更新不重复通知。历史／通知详情保持各次响应的字段，不把旧哈希补成当前响应已提供的哈希。通知的观察时间和接口记录时间分别显示。
- 通知仓库在原 SharedPreferences 键中读取旧 v1 收件箱；首次充提观察后使用 v2 外层，将严格校验的收件箱、钱包基线、各记录及已见状态放在同一个 value 串行保存，保留旧合约／现货通知和已读状态。加载损坏／失败不覆盖存储，并在请求签名前阻止建立未知基线；写入失败保留内存观察与通知，重试保存两者。基线不随通知驱逐而删除，跨 repository 重建后相同状态不重发；这是一项本地尽力保存机制，不承诺断电持久性或跨设备同步。
- 现有通知仍保留最近 500 条，整个 value 最多 4 MiB；基线合计最多 100 个钱包、5000 条观察及 1 MiB，不自动驱逐历史状态来获得空间。超过基线上限拒绝本次观察并保留已有数据。首次基线保存失败后退出进程，下一次仍从最后成功保存的基线继续；卸载／清应用数据会失去通知和基线，后续首次读取重新建立基线。没有系统推送、后台送达保证或完整断线补录。
- `ACCOUNT_UPDATE` 现在保留 `a.m` 和可选 Decimal `bc`。DEPOSIT／WITHDRAW／WITHDRAW_REJECT 只标记充提记录待刷新并展示入口，用户显式签名刷新后再生成状态通知；不会在 WebSocket 回调自动弹签名，也不会把 bc 当申请金额、链上完成证据或额外余额通知。读取期间发生新提示会在读取完成后保留待刷新状态。身份／地址／钱包类型／签名能力变化、停止等待及迟到响应受 generation 保护，切钱包或退出后不显示旧记录，也不为失效请求落基线。
- 自动验收新增 48 项，全量 1321 项测试通过；428 个 Dart 文件格式检查无改动，静态分析无问题，中英文各 859 条消息，Android arm64 Release 构建成功、未安装。完整结果及 APK 校验见 `reference/transfer-history-verification.json`。中英文覆盖窄屏／放大文字／横屏、首次读取／筛选／失败保留、通知详情及钱包隔离；协议和持久化测试覆盖精确签名字节／单位隔离、拒签／身份变化、v1 迁移、基线／通知同次保存及失败重试、已见状态去重和通知驱逐后重建。没有使用设备工具、安装 APK 或发送真实私有请求，新增原生待验收项见 [清单](native-verification-pending.md)。iOS 仍因 Linux 无 macOS／Xcode 未构建；enable-trading、子账户、实际充提划转及完整估值等缺口继续见 [需求进度](prd-progress.md)。

## 2026-11-03 通知中心：现货订单与独立监听

- 通知页新增独立现货监听控制，当前 EOA 显式签名 `POST https://sapi.asterdex.com/api/v3/listenKey` 后连接 `wss://sstream.asterdex.com/ws/{key}`，无需订阅报文。POST 也可续期现有密钥；从授权开始计 60 分钟，50 分钟提醒、60 分钟本地到期，不自动 PUT／POST 或签名。停止仅断开本应用，避免 DELETE 作废其他客户端可能共享的密钥；监听密钥不持久化或显示。
- 抽出真实被合约／现货共同使用的 `WalletStreamController`，保留身份／签名能力变化停止、捕获授权地址与 socket generation、防迟到事件、过期／断线状态以及后台暂停／恢复边界。合约现有余额／挂单合并仍由原控制器负责；现货事件只使 Spot 资产及历史快照待刷新，不进入合约挂单簿。两个市场分别授权、续期和停止，复用同一个 nonce 生成器及当前钱包签名。
- `executionReport` 在边界校验后映射为独立不可变 `SpotOrderNotification`。保留 symbol、订单／客户端／成交编号、买卖方向、当前／原始类型、执行／状态、原始／本次／累计数量、委托／本次／均价、Y／Z 本次与累计计价币金额、E／T 时间及可选佣金／币种、创建 O、触发 P 与计价币预算 Q。金额使用 Decimal，不从价格与数量重新计算并覆盖交易所报告的 Y／Z；以正 Q 申请的 MARKET 可保留零原始基础数量。创建 O=0 明确未知，不显示 1970 年日期；缺失原始类型等可选值不猜测。
- 现货成交通知按钱包＋SPOT＋symbol＋orderId＋tradeId 去重；非成交加执行／状态／E／T。相同钱包、交易对、订单号及成交号在 Spot／Perp 仍是两条通知。现货标题与详情仅使用买／卖，不附加 Long／Short、单向／双向、减仓或合约盈亏字段。
- 现货单位独立读取 `sapi /api/v3/exchangeInfo`，不复用同名合约的 base／quote 或按字符串后缀推导。元数据失败仍显示精确数值及未知单位，可显式重试公开读取；共用详情字段与错误组件。双语说明现在覆盖两个市场；本地收件箱继续保存已读标记，兼容既有 v1 合约记录，并沿用当前钱包隔离、打开详情切钱包隐藏、串行读写、失败重试和最近 500 条／4 MiB 的边界。
- 本轮仍未接入充提历史的首次基线、状态变化通知或余额原因触发历史刷新。`outboundAccountPosition` 只让快照待刷新，不把余额变化标成链上充提完成。没有系统推送、后台送达保证或断线漏报补录。协议与来源见 `reference/spot-notifications-public-contract.json`，自动验证及构建结果另记 `reference/spot-notifications-verification.json`。
- 自动验收：新增 49 项，全量 1273 项测试通过；413 个 Dart 文件格式检查无改动、静态分析无问题，中英文各 829 条消息。覆盖精确签名字节、Spot 专用域名、拒签／过期／切身份、真实本地 WebSocket 协议替身、两个市场相同编号去重、v1 历史兼容、快照失效、50／60 分钟计时及中英文 320 宽／1.5 倍文字／横屏与单位失败重试。Android arm64 Release 构建成功，未安装，APK 校验另记上述验证文件。
- 用户要求不做真机实测，本轮没有设备工具、APK 安装或真实私有请求。现货真实监听、钱包回跳、原生存储与双语布局待验收项已加入 [清单](native-verification-pending.md)；Linux 无 macOS／Xcode，iOS 构建仍未验证。

## 2026-11-03 通知中心：合约订单与风险事件

- 顶部通知入口显示当前钱包未读数量；通知页提供本地列表、详情、逐项／全部已读、读取中、空态、存储失败与重试，沿用显式授权的账户监听控制。抽出 `TradingHeader` 并按可用宽度调整品牌区域，为窄屏账户按钮保留触控空间；不更改原语言与订单恢复入口。
- `NotificationScreen → notificationInboxProvider → NotificationRepository → NotificationStorage` 保存本地记录。`AsterUserStream` 在数据边界把 `ORDER_TRADE_UPDATE` 和 `MARGIN_CALL` 映射为不可变类型，再由账户控制器校验捕获的授权钱包及 socket generation 后入箱；不在 Widget 构建私有连接，不自动签名或补读账户。离开通知页仍收集已显式开启的监听；停止、过期、切身份和后台暂停沿用现有边界。
- 成交通知按钱包＋PERP＋symbol＋orderId＋tradeId 去重，保留同一订单后续成交；非成交加入执行类型、状态及事件／订单成交时间。风险事件根据官方特殊客户端编号／状态／执行标识分类，ADL 明确身份优先于通用 CALCULATED 标识，冲突的明确身份拒绝。风险订单不插入普通挂单列表，仅生成一条风险通知并使完整账户快照过期；NEW_INSURANCE／NEW_ADL 不再被普通挂单状态校验错误地断开监听。
- 订单详情保留原始／本次／累计数量、委托／本次／均价、订单／客户端／成交编号、三个时间、类型／原始类型、执行／状态、可选佣金与资产、报告盈亏及触发／价格依据／减仓／全平标记。金额均用 Decimal；公开合约目录提供 base／quote／margin 单位，失败标为未知并可重试。风险通知不宣称整仓已平，也不虚构倒计时、强平价、风险百分比或送达保证。单条 MARGIN_CALL 保存全部仓位与可选全仓余额；未提供资产的全仓余额不猜币种。
- 本地 SharedPreferences 仅存严格版本化的规范字段及已读标记，不存原始敏感报文、监听密钥、签名、令牌或凭据。记录按钱包过滤，打开中的详情也会在切钱包／退出时隐藏。所有钱包合计最多 500 条、4 MiB，按事件时间移除较早记录；页面明确这不是完整历史。清应用数据／卸载会丢失本地通知，不能作为成交或账户完整性的证据。
- 读写串行，首次加载与实时事件／已读更新不互相覆盖；首次读取失败或格式损坏时不写盘清空，先保留内存变化，重试后合并。重放不会把磁盘中已读事件改回未读；写入失败保留内存状态与明确错误，重试保存最新状态。存储插件延迟初始化，插件不可用时进入可恢复错误，不影响行情首页。销毁监听不丢弃已接受的排队写入；通知持久化是尽力保存，不替代未决订单日志。
- 当前只完成合约订单及风险通知。Spot executionReport、充提历史基线／状态通知，以及 ACCOUNT_UPDATE 充提原因触发历史刷新仍未接入；首次旧历史不应当作新通知，余额变化不能作为链上充提完成证据。当前没有系统推送、后台送达或断线漏报补录。来源和协议边界见 `reference/notifications-public-contract.json`。
- 自动验收：新增 60 项，全量 1224 项测试通过；401 个 Dart 文件格式检查无改动、静态分析无问题，中英文各 820 条消息。Android arm64 Release 构建成功，未安装；APK 校验及用例对应关系见 `reference/notifications-verification.json`。构建仅保留现有第三方插件 KGP 未来兼容提示。
- 本轮不启动设备工具、不安装 APK、不发送真实私有请求。真实合约事件、手机本地存储、钱包回跳与原生布局待验收项记录在 [清单](native-verification-pending.md)；iOS 因 Linux 无 macOS／Xcode 仍未构建验证。自动验证结果另记 `reference/notifications-verification.json`。

## 2026-11-03 未决订单跨进程恢复

- 实盘普通／快捷、条件、Entire close、Trailing、专用单仓及批量平仓的每笔已发送订单，以及附加 OTO／OTOCO 策略，共用按钱包隔离的未决日志。`main` 在渲染前通过 `getApplicationSupportDirectory` 注入并读取 `FileOrderRecoveryJournal`；路径不可用或文件损坏保留安全错误并暂停新的下单／配置操作，公开行情及本地演示继续可用。`path_provider` 从已有间接依赖升为明确直接依赖，仅用于定位原生应用支持目录。预览／测试的嵌入入口使用独立内存实现，正式 Android／iOS 的 main 始终注入文件实现，不因读取失败退回空内存记录。
- 在钱包签名结束、所有发送前校验通过后，POST 边界先保存公开查询意图，再允许 HTTP 发送。文件替换使用同目录临时文件、`flush:true` 与 rename；写入失败不发送 POST。磁盘等待后再核对原确认的身份／期限／配置，期间失效则撤回本次尚未发送的记录并拒绝下单。进程在保存与实际发送之间退出仍按未知处理；不能凭重查不存在就证明原单未发送。已进入 POST 的超时、拒绝查询或条款不匹配保留记录，任何恢复路径均不能重发 POST。
- `OrderQuery` 仅包含地址、symbol、客户端编号、持仓模式、冻结订单条款及附加单原始固定保护数量；没有可提交的预读上下文、仓位／余额、邮箱、私钥、签名、nonce 或会话令牌。记录序列化严格验证版本／交易市场、地址／编号／symbol、枚举／布尔、十进制／数量／策略形状与完整字段，拒绝浮点金额、未知字段、重复编号及不支持版本；记录只用于核对，不还原陈旧资金快照以获得下单资格。
- 文件日志串行处理读写；准备新订单前重新读取规范文件，同一钱包存在任意未决编号时禁止覆盖或再插入新编号。不同钱包记录共同保留，完成核对只删除对应地址＋编号，不覆盖其他钱包。临时文件中断不替代规范文件；规范文件损坏不自动清空、不用临时文件猜测恢复、不覆盖原始字节。删除记录也使用同一替换机制，删除失败保留已核对结果，同时保留磁盘记录及阻塞错误，允许重试本地读取及原编号查询。日志不设自动过期／驱逐，最多 1000 条且 1 MiB，超限拒绝新写而不丢旧记录。
- 现有普通与附加查询抽到 `SignedOrderQueryRepository`，保留全部原参数、策略子单／关联动作和成交数量校验；原调用仍使用同一映射器。恢复入口 `OrderRecoveryScreen → OrderRecoveryController → OrderRecoveryRepository → AsterAccountService` 仅调用固定 GET 端点，重新使用当前同一钱包和新 nonce 签名。普通单使用原 symbol＋origClientOrderId，附加策略使用原 clientStrategyId＋OTO／OTOCO；策略 Open 的 -2013 可签名回退原编号 History，不将策略 ID 当普通 orderId。
- 顶部工具栏新增带当前钱包记录数量的恢复入口，订单／快捷／配置／批量平仓页显示明确阻塞原因及入口。列表显示可复制交易对／编号、方向／持仓侧、类型和本地记录时间；只有显式点击才请求钱包签名，没有自动读取私有数据。必须先登录并重连原钱包；其他地址看不到或操作该记录，切回后恢复阻塞。退出、切身份、签名状态变化清除迟到查询的界面结果，原记录继续保留。同一会话尚有操作锁时提示使用原操作页重查，避免两个恢复流程争抢钱包。
- 持久记录加载未完成、存储失败或当前钱包存在未决记录时，新实盘下单及四类配置操作通过共享互斥入口暂停；仅原编号查询可以恢复。成功匹配的 GET 才删除对应未决记录并解除阻塞，NEW／部分成交也只是原单受理／状态得到核对，不代表已全部成交。查询不到账、拒签、超时、错误条款或历史保留期已过均继续保留；不自动认定失败。策略查询仍不推导未提供的成交数量。查询后的账户／仓位／挂单标记需重新读取。
- 批量平仓仍逐笔发送，实际越过 POST 的每笔才登记。重建后只查询这些编号，绝不重建或续跑原未提交队列；已核对订单不会因本地记录清除而重新提交。当前增量不包含配置修改、撤单、子账户或资金操作自身的持久化恢复，也不是所有已受理策略的跨会话完整列表；这些边界与后续需求分开跟踪。
- 中英文各新增 11 条消息，现各 785 条。自动测试覆盖文件实例重建、普通／条件／跟踪／全部平仓／附加净额意图回放、文件损坏／中断／失败写入／删除失败、跨钱包串行写入及去重、保存后过期、精确签名字节与 GET-only 请求、身份竞态、全局阻塞、没有额外钱包创建，以及中英文 320 宽／1.5 倍文字／横屏的原编号重查、未知保留与明确错误。新增 42 项测试，全量 1164 项通过；386 个 Dart 文件格式检查无改动，静态分析无问题，Android arm64 Release 构建通过。最终证据及 APK 校验值见 `reference/order-recovery-verification.json`。
- 按用户要求没有设备工具、APK 安装、真实私有查询／交易或进程强杀真机测试；Linux 无 macOS／Xcode，iOS 构建仍未验证。host 文件重建与替身协议测试不代表手机文件系统、系统强杀、断电或真实钱包回跳已验收。日志只覆盖本版本启用后记录的操作，清除应用数据、卸载或设备损坏会丢失本地记录，不能据此保证无限期恢复；交易所查询保留期继续适用。具体原生待验收项见 [清单](native-verification-pending.md)，整体 PRD 缺口见 [进度](prd-progress.md)。以下保留各次增量当时的边界。

## 2026-11-03 开仓附加 TP/SL：创建与查询

- 核对 Futures PRD 的普通开仓表单及确认要求，独立实盘入口新增可选附加 TP、SL 或两者，支持 LIMIT／MARKET／STOP／TAKE_PROFIT 及相应条件市价主单；每条附加保护独立输入触发价格、Last／Mark 和价格保护，以固定数量的 TAKE_PROFIT_MARKET／STOP_MARKET 执行。不能与专用平仓、仅减仓、Entire close、Trailing 或 K 线快捷单混用；切换隐藏的附加设置不进入其他类型的签名参数。策略端不支持 IOC，原普通 IOC 能力继续保留。
- `LiveOrderForm → LiveOrderController → SignedLiveOrderRepository → SignedAttachedOrderRepository → AsterAccountService`。不可变 `LiveOrderAttachment` 收集意图，`attached_order.dart` 校验并生成固定顺序子单：1 为主单，2／3 为保护；单保护使用 OTO，双保护使用 OTOCO。请求 `securityType=USDT_FUTURES`，每个 clientOrderId 从冻结的客户端策略编号派生；主策略编号与普通 orderId 分开保存、查询和展示，普通订单参数／查询映射器拒绝附加草稿。
- 附加单 `firstDrivenId=1, firstDrivenOn=FILLED, firstTrigger=PLACE_ORDER`；双保护额外以另一保护子单 `FILLED` 驱动 `CANCEL_ORDER`。因此主单部分成交期间尚无该保护；保护部分成交也不等于已撤销另一条。确认页与表单明确显示这些边界，不以本地监听模拟自动 OCO。当前支持创建、核对和显式重新查询；App 内策略编辑、整体撤销及跨会话列表尚未实现，创建功能不代表完整管理闭环。
- 保护只覆盖本次新增敞口，使用 Decimal／有理数既有净额规则：单向相反订单先抵消原仓位，剩余为保护数量；无新增敞口拒绝确认，同向或双向开仓使用本单数量，不把既有同向仓位纳入保护。保护数量独立校验 LOT_SIZE，主单继续按其类型校验数量、价格、能力、名义金额与资金。固定保护不是 closePosition=true，不会自动改为整个账户或整个仓位。Last／Mark 不相互代替；即时主单按该依据当前价校验 TP／SL 方向，限价／条件主单按未来主单参考价校验，不把尚未激活的保护当作当前独立条件单。
- 确认后额外签名读取 positionRisk，核对原仓位数量／开仓价、杠杆和保证金模式；变化阻止 POST 并要求重新读取。再由当前同一 EOA 独立签名 POST `/fapi/v3/placeStrategyOrder`，随后签名 GET `/fapi/v3/strategyOpenOrder`，不创建额外钱包。四次基础配置／资金读取及第一份快照起 30 秒期限继续适用，签名返回后、POST 边界仍检查身份、配置版本与有效期。附加流程与普通下单／全部平仓／四类配置共用互斥锁。
- POST 即使 HTTP 200 仍检查 `failureCode`；非零代码保留安全错误，不显示 failureReason。POST 成功或失败都不能证明成交／未提交，越过发送边界后只查询冻结的原客户端策略编号与 OTO／OTOCO 类型，绝不重发。Open 查询收到已文档化 -2013（订单不存在）时，再用独立签名查询同一编号／类型的 strategyHistoryOrder；其他拒签／网络／权限错误保持未决，不自动扩大签名。历史接口最大回溯 90 天，不能承诺无限期恢复。
- 查询严格核对父策略编号／类型、唯一完整子单序号、同一策略 ID、钱包查询作用域、symbol／方向／positionSide、派生子编号、数量／价格／触发依据／保护／有效方式／reduceOnly／closePosition，以及两组驱动编号、事件和动作。文档查询示例返回的 FUTURE 作为 USDT_FUTURES 的只读别名兼容。未激活子单 orderId 可为零／缺失，不能将 strategyId 用于普通撤单。条件子单转为 MARKET／LIMIT 时须保留正确 origType 才能匹配；错误条款保持未知且原编号只查询。查询文档不提供可靠 executedQty，结果仅展示安全的策略／子单状态，不推导成交数量、余额或剩余仓位；实际成交和仓位仍须另行读取。
- 默认附加设置关闭，至少选一条保护并通过校验才可确认。确认页显示可复制钱包／交易对／客户端策略编号、主单与独立附加触发条款、比较符号、固定保护数量和生命周期。即使普通市价确认偏好关闭，附加策略仍要求独立确认；取消、拒签、刷新、开关隐藏／恢复均保留输入，身份变化清除。未决结果锁定输入与新提交；已核对策略可显式签名刷新，刷新失败也保留同一编号恢复。
- 本轮新增 24 条双语消息，中英文各 774 条。自动验收覆盖方向／持仓模式／单或双保护、主单策略／类型、反向净额与精确数量、价格／步长／能力、部分成交激活约定、精确签名字节及 nonce、仓位变化、晚到／拒签、HTTP 200 拒绝码、Open→History、原编号仅查询、身份竞态，以及中英文 320 宽／1.5 倍文字／横屏确认、取消与保留输入。新增 70 项测试，全量 1122 项通过；372 个 Dart 文件格式检查无改动，静态分析无问题，Android arm64 Release 构建通过。最终证据及 APK 校验值见 `reference/attached-order-verification.json`。
- 按用户要求不做真机实测：没有设备工具、APK 安装、真实私有读取／交易或资金请求。Linux 缺少 macOS／Xcode，iOS 未构建；实际激活、触发、成交与互撤、EOA signer 授权及原生钱包回跳均待验收，见 [清单](native-verification-pending.md)。整体 PRD 仍未完成，剩余实现以 [进度](prd-progress.md) 为准；下方记录保留此前各增量当时的范围。

## 2026-11-03 K 线快捷市价开仓

- 对照 Futures PRD 的 Chart／Trade 分页和快捷开仓规则，K 线页面新增独立基础资产数量输入，初始为空且不预选比例；默认仍打开原 Trade 工作区。两页用保留状态的可见性切换，原表单数量／价格与快捷输入分别保留。快捷入口固定 MARKET，不继承普通表单的限价、触发、跟踪、仅减仓、平仓、TP/SL、TIF 或其他隐藏设置；单向 BOTH 明确发送 reduceOnly=false，双向按买卖方向使用 LONG／SHORT 且省略 reduceOnly。严格领域校验与查询核对均拦截混入参数。
- `QuickOrderPanel → QuickOrderController → SignedQuickOrderRepository → AsterAccountService`。复用已有四次模式／配置／资金签名读取，再按当前交易对独立签名读取 commissionRate、leverageBrackets 和 openOrders，共七次读取签名；继续由当前选中的 EOA 签名，不创建额外钱包。费率要求有效非负十进制且小于 1，档位、挂单按既有严格映射器校验，其他交易对或持仓模式不一致的行拒绝使用。三项附加读取与现有下单／配置操作互斥，全部沿用第一份快照起 30 秒期限，不因最后一项较晚返回而延长。
- 25／50／75／100% 分别以快照买一／卖一参考价换算买卖基础资产数量。精确有理数预算为 `availableUSDT × leverage / (referencePrice × (1 + takerFee × leverage))`；选取支持当前杠杆的最大风险上限，扣除已有仓位和同向挂单敞口，用参考价与 Mark 中较高者限制新增数量。单向反向订单可计入净额平仓容量，但已挂同向 reduceOnly／closePosition 先占用该容量，避免重复花费；双向保守预留全部已有绝对仓位敞口。再限制 MARKET_LOT_SIZE 最大值，应用比例并按 `(qty−minQty)/stepSize` 向下取整，小于最小量返回零，绝不放大到最小订单。
- 百分比仅为 USDT 参考预算，不计释放保证金、其他资产抵押、返佣或后续成交，不能代表交易所可执行最大额度；实际账户、挂单及价格变化由交易所最终校验。按钮局部订阅公开盘口，买用 ask、卖用 bid，断线显示不可用；实时展示不偷偷改变已确认的数量。附加额度读取失败保留输入，账户基础快照仍有效时允许独立手输数量；身份／交易对切换清理旧数据，丢弃迟到回调。
- 默认显示快捷确认，核对可复制钱包／交易对、方向和基础数量；不添加市价委托价、名义金额或 TP/SL 行。与普通新开仓 MARKET 共用持久化确认偏好，只有用户明确关闭才能跳过应用确认，钱包签名仍执行；LIMIT、条件、跟踪及专用减仓确认保留。仅在点击确认时保存“不再提示”，取消不改变偏好；读失败默认确认、写入串行、晚到读取不能覆盖显式设置，写失败保留最后已保存选项并提示。
- 提交前复核同一快照／交易对／数量，复用既有身份、期限、配置版本及签名后 POST 边界检查。POST 后独立签名按原客户端编号 GET，核对 MARKET、数量和 reduceOnly=false／closePosition=false；POST 响应不等于成交。确认正常受理后清空快捷数量／比例，取消、拒签、失败和未知结果保留；未知结果锁定输入并只能原编号查询，不能重新 POST。跨进程未决编号持久化仍未完成。
- 验收覆盖精确额度／风险／减仓容量、签名字节及独立 nonce、单向／双向参数、过期／身份／配置变化、偏好异步竞态及保存失败、失败保留／未知查询／成功清空、双语 320 宽与 1.5 倍文字／横屏，以及 Chart／Trade 独立输入保留；修复新增分页与图表内部“图表／深度”控件重名导致的旧交互查找冲突。两种语言各新增 18 条消息，现各 750 条。新增 50 项测试，全量 1052 项通过；360 个 Dart 文件格式检查无改动，静态分析无问题，Android arm64 Release 构建通过。最终证据及 APK 校验值见 `reference/quick-order-verification.json`。
- 按用户要求只记录真机待验收项：本轮没有设备工具、启动设备、APK 安装或真实私有请求。Linux 无 macOS／Xcode，iOS 未构建；真实钱包／七次读取签名、授权账户额度和原生回跳仍见 [原生验收清单](native-verification-pending.md)。整体 PRD 未完成，功能缺口以 [需求进度](prd-progress.md) 为准；以下章节保留各次增量当时的验证记录。

## 2026-11-03 跟踪委托 Trailing Stop

- 对照 Futures PRD 的跟踪委托及确认规则，普通实盘和原仓位平仓入口新增 TRAILING_STOP_MARKET。使用固定基础资产数量、callbackRate（0.1～5，输入 1 表示 1%）、Last／Mark，以及可选 activationPrice；不发送 price、stopPrice、priceProtect、timeInForce 或 closePosition。跟踪委托是交易所跟踪极值后市价执行，和持续改价的 Chase 分开。固定 TP/SL 专用入口继续保留原条件类型，不被此开关改变。
- `LiveOrderTrailing` 是不可变意图；Widget → LiveOrderController → SignedLiveOrderRepository → AsterAccountService。交易对必须声明支持该 orderType。回调、数量、激活价均用严格十进制字符串与 Decimal，数量使用通用 LOT_SIZE，保留最小名义金额和开仓资金校验。指定激活价须符合 PRICE_FILTER，并按所选 Last／Mark 校验 BUY 低于最新价、SELL 高于最新价；等于或反向拒绝确认，交易所仍在实际下单时校验。Last 不可用不以 Mark 替代，用户可显式选择 Mark。
- 激活价留空时不把读取时的参考价填入请求，使用交易所实际下单时对应价格依据的默认最新价；确认明确说明默认规则。显式激活价在确认与签名中固定，查询核对对应 activatePrice。默认模式仅校验交易所返回值为有效正十进制，不错误要求它等于读取时快照。回调请求 callbackRate 与查询 priceRate 的百分数含义一致，不能除以 100 后提交。
- 单向仅减仓与原仓位平仓继续保留 reduceOnly；双向原 LONG／SHORT 反向平仓且不发送 reduceOnly，不能套用 closePosition=true。原仓位数量、开仓价、杠杆和保证金配置须独立签名复核后才可 POST；变化阻止提交。普通入口两次、原仓位平仓三次独立签名，继续直接使用选中的同一 EOA，不创建额外钱包。
- GET 核对原类型 origType、允许的 TRAILING_STOP_MARKET／触发后 MARKET、数量／执行状态、priceRate、workingType、activatePrice、reduceOnly、closePosition 和默认 GTC；POST ACK 不能证明成交。错参数、超时或查询拒签继续冻结原编号，只能 GET 重查，不能重复 POST。保留签名返回后的期限／身份／配置检查，不因新增类型绕过提交边界。
- 表单显示买单跟踪低点、上涨回调触发，卖单跟踪高点、下跌回调触发；回调与激活均不会自动更改为本地计算值。启用跟踪模式锁定市价并排除原固定条件字段，关闭后不发送保留的跟踪字段；取消、刷新和能力暂时丢失保留输入，未决结果锁定编辑。无固定成交价时，名义金额及新增保证金只按 Mark 参考估算，平仓 PnL 显示不可用；提示不含费用／资金费／滑点，实际资格由交易所决定。中英文各新增 15 条消息，当前各 732 条，入口范围说明同步更新。
- 自动验收新增 **54 项**，全量 **1002 项通过**；347 个 Dart 文件格式检查无改动，静态分析无问题，Android arm64 Release 构建成功。覆盖默认／指定激活价×Last／Mark×方向，单向／双向原仓位平仓、最小／最大／极精度回调、缺失字段／浮点／错误类型、激活方向／价格过滤、LOT_SIZE、能力与资金不足、精确签名字节、独立 nonce、拒签／过期／仓位变化及超时原编号仅查询；双语 320 宽／1.5 倍文字、横屏、确认取消／刷新保留、未知锁定和模式切换排除旧字段。
- 官方 V3 文档重新只读获取；匿名 exchangeInfo 确认 BTCUSDT 声明支持 TRAILING_STOP_MARKET。完整证据及 APK 校验值见 `docs/reference/trailing-order-verification.json`。没有真实私有请求、下单、设备操作或 APK 安装；iOS 因 Linux 缺少 macOS／Xcode 未构建，真实激活／跟踪／成交及原生流程见 [待验收清单](native-verification-pending.md)。整体 PRD 未完成；Chase、BBO、开仓附加 TP/SL／联动编辑、Scaled、子账户、资金及通知等见 [需求进度](prd-progress.md)。

## 2026-11-03 触发时全部平仓与 PnL／ROI 换算

- 仓位 TP/SL 入口新增“触发时全部平仓”，仅支持 STOP_MARKET／TAKE_PROFIT_MARKET。确认固定钱包、symbol、positionSide、方向、触发依据／价格／保护；请求发送 `closePosition=true`，不发送 quantity、reduceOnly、price 或 timeInForce。单向多空与双向 LONG／SHORT 均反向平仓，拒绝错方向、无仓位和混入固定数量／限价的草稿。普通部分平仓及批量即时平仓保持既有数量规则。
- 全部平仓由 Aster 在触发时确定实际数量；当前读取的仓位只供复核和估算，不能当已提交数量。全部模式跳过固定 LOT_SIZE／MIN_NOTIONAL 校验，保留触发价、支持类型、参考价及保护规则；最终资格由交易所校验。沿用原仓位独立复核、同一 EOA 的 POST 及单独 GET 三次签名；确认后、提交前的仓位／配置变化仍阻止提交，不自动修改确认。独立 TP 与 SL 不自动互撤，不宣称 OCO。
- 全部单查询严格匹配 closePosition=true、reduceOnly=false、原类型与触发参数。允许 origQty=0 和不同于读取时仓位的执行量；非零 origQty 时核对执行上界及 FILLED 数量一致性，NEW 必须零成交，FILLED 必须有正成交。查询结果只证明本单报告的执行，剩余仓位须另行签名读取。POST 超时、拒签和参数不匹配继续原编号 GET-only 恢复，绝不重复 POST；未决编号跨进程持久化仍待完成。
- 新增纯领域换算：`PnL=d×Q×(P−E)`，反推 `P=E+PnL/(d×Q)`；`ROI%=d×(P/E−1)×L×100`，反推 `P=E+E×ROI%/(d×L×100)`。d 为多仓 +1／空仓 −1，E 为已读开仓价，Q 为所选部分数量或全部模式的已读仓位数量，L 为已读杠杆。全程 Decimal／精确有理数计算，按 `(P-minPrice)/tickSize` 就近取整，半步远离零；校验取整后正数／价格范围，不自动钳制价格。拒绝无仓位、超量、零杠杆、缺失价格步长、格式错误和越界目标。
- 换算面板展示候选触发价及取整后的参考 PnL／ROI，用户明确“采用”才写入触发价；预览、模式切换、刷新与全部模式切换均不自动覆盖触发价，更不提交订单。ROI 是基于开仓价与杠杆的估算，并非账户收益率；不含手续费／资金费／滑点，不保证触发或成交。条件限价的成交 PnL 仍使用独立委托价。部分输入在全部模式下保留但不发送；身份变化清理输入，未决状态锁定数量模式和换算采用。
- Presentation 复用 Riverpod／repository／service 签名流程；从原领域文件抽出不可变 draft／交易规则，避免继续扩大单文件。新表单组件各自负责渲染与意图，领域函数负责换算。中英文各新增 21 条消息，当前各 717 条。
- 自动验收新增 **45 项**，全量 **948 项通过**；342 个 Dart 文件格式检查无改动，静态分析无问题，Android arm64 Release 构建成功。覆盖多空／双向、两种条件市价类型、精确签名字节与字段省略、提交前变化、超时／错作用域仅查询、零 origQty 与触发后不同数量；PnL／ROI 正负与单位、部分／全部参考量、循环除法、极小数、非零最小价与半步取整、输入及价格边界；中英文 320 宽／1.5 倍文字和横屏、取消／刷新保留输入、候选显式采用与未决禁用。构建结果与校验见 `docs/reference/entire-close-verification.json`。
- 遵照用户要求，没有使用设备工具、真机测试或安装 APK，没有发送真实私有读取／订单／资金请求。Android arm64 Release 仅编译验证；Linux 无 macOS／Xcode，iOS 构建与所有真实钱包流程仍未验收，详见 [原生验收清单](native-verification-pending.md)。开仓附加 TP/SL、联动／编辑、BBO／跟踪／Chase、子账户、资金及通知等仍按 [PRD 进度](prd-progress.md) 推进；Aster enable-trading 尚未实现，自身 EOA signer 接受性未证明。以下同日较早记录保留各增量当时的范围。

## 2026-11-03 独立指定数量止盈止损条件单

- 对照 Futures PRD 的 TP/SL Limit、TP/SL Market 及仓位 TP/SL 规则，独立实盘入口支持 STOP、TAKE_PROFIT、STOP_MARKET、TAKE_PROFIT_MARKET 四种指定数量订单。买卖方向、触发类型、Last／Mark、独立触发价与委托价、适用限价策略和价格保护均固定在确认意图中。原普通下单和批量 MARKET 平仓继续复用既有流程。
- 仓位卡新增按 symbol＋positionSide 打开的止盈止损入口；打开不自动读取或签名，进入后默认条件市价单，固定为条件单，不能误切成即时平仓。部分数量保留手输／比例操作；单向 BOTH＋reduceOnly，双向按原 LONG／SHORT 反向执行且不发送 reduceOnly。提交前沿用独立仓位数量、开仓价、杠杆及保证金配置复核，变化时不提交。
- 条件单模型不可变，orderTypes 在数据边界校验为无重复字符串枚举，并按交易对能力判断派生订单类型。触发价用 Decimal 校验 PRICE_FILTER 的范围及 `(stopPrice-minPrice) % tickSize`。普通 MARKET 使用 MARKET_LOT_SIZE；其他指定数量类型按文档通用 LOT_SIZE 处理，实际触发时的数量／敞口及交易资格由 Aster 校验。保留最小名义金额校验；普通限价继续校验当前标记价 PERCENT_PRICE，条件限价不拿当前标记价误拦未来的执行价格，Aster 仍可在下单及触发时拒绝。
- STOP 买入向上、卖出向下；TAKE_PROFIT 买入向下、卖出向上。界面明确展示比较方向，按已读对应参考价阻止已达到／等于触发条件的草稿；提交时实际价格仍由交易所最终校验，不自动猜测或改变订单类型。新增显式公开 GET ticker/price 读取 Last，与严格校验的标记价分开；失败只使 Last 条件单不可确认，不以 Mark／盘口／演示价格替代。ticker.time 是最后成交时间，允许安静市场的较旧成交记录，拒绝未来时间及错币种／浮点价格。整个预读仍从 mark 响应起 30 秒有效，不增加独立签名次数。
- 价格保护从可选 exchangeInfo.triggerProtect 读取 Decimal 阈值并展示百分数，不在创建时凭当前价差判断未来触发资格。开启后把 priceProtect=TRUE 明确签入意图；缺失阈值不能确认开启保护的草稿，刷新失败保留用户选择并允许明确关闭。保护只影响触发条件，不保证成交价。Last／Mark、触发价、阈值及提示均提供中英文。
- LIMIT 条件单传 quantity、price、timeInForce、stopPrice、workingType、priceProtect；条件市价不传 price／timeInForce，使用协议默认 GTC；不发送 closePosition。关闭普通入口的条件开关后，不会泄漏保留输入中的触发参数。参考名义价值／新增保证金及平仓 PnL：条件市价用触发价、条件限价用独立委托价；说明未来仓位、杠杆、资金、费用、深度及触发时规则变化，不当作成交收益或保证金承诺。
- POST ACK 不证明触发或成交。后续签名 GET 必须匹配原始条件类型 origType、触发价、价格依据、保护标志、reduceOnly、closePosition、数量以及适用限价条款。允许触发后 type 变为对应 LIMIT／MARKET，但 origType 必须保持本次原条件类型。字段缺失、错类型、超时或查询拒签仍保留原编号和条件，持有未决锁，只允许 GET 重查，不重发 POST。只有核对后的 FILLED 及完整数量证明该订单全量成交，NEW 不代表已平仓。
- 这是每次提交一笔独立条件单；两笔 TP／SL 不天然 OCO，界面及确认均说明不会互撤。仍待完成：Entire close 的 closePosition=true、PnL／ROI 输入反推、开仓附加 TP/SL 及联动／编辑、BBO、跟踪／Chase 和快捷开仓。完整账户、资金、通知及跨进程恢复继续按 [PRD 进度](prd-progress.md) 推进；不将独立指定数量订单当作整个 TP/SL 需求完成。
- 自动验收新增 55 项，全量 **903 项通过**；335 个 Dart 文件格式检查无改动，静态分析无问题，Android arm64 Release 构建成功。覆盖四种类型×多空×Last／Mark、边界与精度、保护与能力缺失、单向／双向仓位、触发后原类型核对、拒签／过期与未知结果、原编号仅查询、取消／刷新保留参数、关闭条件时排除字段、仓位卡入口，以及中英文 320 宽／1.5 倍文字和横屏。记录见 `docs/reference/conditional-order-verification.json`。
- 只匿名读取官方公开行情与协议；私有签名和交易响应均为测试替身。本轮没有设备操作、安装 APK、真实私有请求或金融提交；真机验收按用户要求暂停，仅更新 [待验收清单](native-verification-pending.md)。Linux 无 macOS／Xcode，iOS 构建及所有真实登录／交易流程仍未验证；enable-trading 和主 EOA 自身 signer 资格仍未完成官方授权联调。

## 2026-11-03 限价成交策略、Post Only 与 Hidden

- 按 Futures PRD 的限价／Post Only 订单表和仓位限价平仓规则，实盘开仓、单向仅减仓和专用单仓限价平仓现可选择 GTC、IOC、只做 Maker（GTX）及隐藏单（HIDDEN）。默认仍为 GTC；全部平仓继续使用 MARKET。成交策略选择和说明均为中英文，确认页与操作结果保留提交时的策略。
- 交易对 exchangeInfo.timeInForce 在数据边界校验为非空、无重复的枚举列表；只向用户开放官方协议与当前交易对均支持的策略。缺失／畸形列表拒绝作为规则；未来合法但未知的枚举不会自动开放，也不替代为 GTC。规则刷新移除已选策略时保留输入，要求用户显式重选；市价不依赖限价策略。
- 策略是不可变订单草稿／意图的一部分，LIMIT 参数使用所选 wire 值；MARKET 不发送 price 或 timeInForce。价格、数量、名义价值、方向、仅减仓／双向规则、过期、操作互斥、真实 EOA 签名及仓位复核均沿用原边界，不增加签名次数，不创建钱包。单仓 Hidden 平仓仍先签名核对原仓位；双向保留原 LONG／SHORT 且不发送 reduceOnly。
- POST 后的独立签名 GET 必须返回与提交意图一致的策略。策略不匹配仍为未确认结果，保留原编号和策略，仅允许 GET 重查，不能改为另一策略重发。IOC 的 EXPIRED 可以携带实际部分成交量，不能解释为零成交或全部成交；Post Only 拒绝不当作开仓成功。Hidden 只表示不在公开盘口展示，不承诺 Maker、成交或优先级。确认弹窗的显式策略行是本应用新增的复核字段，非声称 Aster 原组件已有此行。
- 修复英文长说明／窄屏下滚回顶部导致表单被 ListView 回收、已选策略重置的问题：当前路由中的表单保持存活，滚动、刷新及市价／限价往返保留输入和选择；钱包作用域变化仍重建／清空表单。新 Widget 回归覆盖滚动离屏后继续确认，提交中与未决状态禁止改选。
- 官方公开 exchangeInfo 匿名读取确认 BTCUSDT、ETHUSDT、ASTERUSDT 当前均声明 GTC／IOC／GTX／HIDDEN；只作为公开能力证据，不证明钱包权限或订单成功。协议与公开响应摘录见 `docs/reference/limit-policy-public-contract.json`。FOK 不在该合约协议枚举中，不展示。
- BBO 继续列为未完成：普通 New Order 文档说明 pegPriceType 由引擎定价，但 LIMIT 必填 price 的表格没有明确 peg 时应传的值；复合订单 legs 另有明确 price=0 约束，不能直接套给普通入口。未用盘口快照填单假冒服务端 BBO，也未暴露未经确认的普通 BBO 提交参数。独立指定数量 TP/SL 见上方增量；附加 TP/SL、Entire close、跟踪／Chase、快捷开仓、跨进程未决恢复及其他账户／资金功能仍按 [需求进度](prd-progress.md) 推进。
- 本轮没有安装 APK、操作设备或发送真实私有金融请求；用户要求暂停真机实测，待测策略与交互已加入 [原生验收清单](native-verification-pending.md)。iOS 缺少 macOS／Xcode，构建及原生流程仍未验证。自动验证与 Android 构建记录见 `docs/reference/limit-policy-verification.json`。
- 自动验收新增 38 项，全量 **848 项通过**；331 个 Dart 文件格式检查无改动，静态分析无问题，Android arm64 Release 构建成功。覆盖能力缺失／畸形／未来枚举、四种策略的参数与过滤器、查询策略不符、IOC 部分成交后过期、Post Only 拒绝、Hidden 单／双向平仓签名链、未知结果仅查询、中英文 320 宽／1.5 倍文字及横屏、滚动／取消／刷新保留输入、能力移除时显式重选和市价参数排除。

## 2026-11-03 实盘下单资金与初始保证金预估

- 对照 Futures PRD 的开仓 step2／step3：下单前显示可用保证金，输入完整后显示本单开仓数量及预计消耗保证金。普通实盘入口与确认弹窗现展示签名读取的单一／多资产模式、USDT 可用保证金、资金快照时间、参考新增开仓数量和预计新增开仓初始保证金。
- 保持 Widget → LiveOrderController → LiveOrderRepository → AsterAccountService；在已有模式／交易对仓位读取后，分别签名 GET multiAssetsMargin 和 accountWithJoinMargin，总共四次独立读取签名。沿用当前 EOA 作为 user／signer、共享 nonce、精确签名字节和原有下单确认／提交／查询边界，不生成新钱包。
- 新资金模型复用严格 AsterAccount 映射，金额只用 Decimal。account.availableBalance 官方定义仅适用于 USDT，不能当全部多资产抵押总值；多资产按币种列出 availableBalance 与 marginAvailable，不加总不同单位，不猜测汇率、抵押折扣或可提现额度。负值与极小值保留；字段缺失显示未知，不回退钱包余额或演示资金。
- 将资金响应中当前交易对的非零仓位，与先读的 positionRisk 数量／开仓价／杠杆／保证金配置核对；冲突或多资产＋逐仓的矛盾快照拒绝作为开仓依据。资金签名拒绝／读取失败保留规则、输入及安全原因，禁止新开仓确认；不静默复用旧资金。响应明确 canTrade=false 时禁止新的开仓确认，但 canTrade=true 不当作真实交易授权验收。
- 新增开仓数量：单向同方向为全部委托量，反方向先抵消已读原仓位，仅超出部分视作参考新增敞口；双向普通订单按所选方向全量计入；有效仅减仓为零。参考初始保证金＝新增数量×输入限价（市价用标记价）÷已读杠杆。全程 Decimal／有理数，循环除法保留足够小数避免极小数被抹为零。明确不含手续费、资金费、已有挂单影响、释放保证金、实际成交价和风险档位，不能当交易所最终保证金或成交承诺。
- 单资产估算超过已读 USDT 可用余额时提示核对，不把此近似比较变成额外的本地硬额度拦截；多资产不拿 USDT 字段与完整抵押价值比较。资金快照过期、账户事件或提交后标为历史，不后台自动签名。期限仍从公开标记价响应起 30 秒，签名后过期的资金 GET 不发送，也不继续追加签名提示；刷新保留数量／价格。
- 专用单仓平仓和全部平仓显式跳过额外资金读取，继续原有仓位复核与签名数量；这种上下文不能用来绕过普通开仓的资金读取要求。仍未发送真实私有／金融请求，本轮不安装 APK、不做真机实测。完整验收与构建校验见 `docs/reference/live-order-funds-verification.json`；iOS 缺少 macOS／Xcode，仍未构建验证。
- 自动验收新增 29 项，全量 **810 项通过**；327 个 Dart 文件格式检查无改动，静态分析无问题，Android arm64 Release 构建成功。覆盖独立 GET 与四次签名字节／nonce、资产模式与资金拒签、晚到／过期签名、快照不一致、身份与资金读取作用域、非USDT资产不加总、缺失／零／负值／极小值、单向抵消／双向新增／仅减仓及循环除法、中英文 320 宽／1.5 倍文字与横屏确认布局、刷新保留输入及历史快照。
- 范围校正：此前进度清单把独立“反手”和逐仓保证金增减列为待开发，但当前获取的 Futures／Portfolio PRD 未定义这两个入口。官方 API 可用不作为需求证据；现归为待产品确认项，继续推进已明确的 TP/SL、其他订单类型、账户与资金功能。

## 2026-11-03 全部平仓与当前交易对平仓

- 按 Futures PRD 的 Close All 要求，仓位风险页新增“平掉全部已列实盘仓位”入口，当前交易对筛选启用时作用域仅为当前 symbol。只接受同钱包、完整、未失败且 30 秒内的新鲜签名仓位快照，排除零数量负逐仓余额记录。未登录、未读取、陈旧／失败快照、有未确认的订单或配置操作时禁用。
- 确认页固定钱包、全部 symbol＋positionSide、精确绝对数量、执行方向与逐仓客户端编号；不含 Spot、已有挂单或确认清单外的新仓位。确认期间仓位快照、身份、配置 epoch 或期限变化时整份确认失效。取消不读取配置、不签名交易。
- `Widget → BatchCloseController → LiveOrderRepository → AsterAccountService` 顺序处理每个仓位。每项先独立预读交易规则、模式与仓位配置，对比已确认数量、开仓价、杠杆、保证金及单位，再复用单仓平仓的独立 positionRisk 复核、POST 和按固定编号 GET。单向 BOTH＋reduceOnly=true；双向保留 LONG／SHORT 且不发送 reduceOnly；普通 MARKET 平仓不发送 closePosition、price 或 timeInForce。一次正常操作每仓最多五次独立签名，最后另签名完整读取仓位。
- 数量严格使用确认时仓位的 Decimal 绝对值，不自动向下取整、缩量、拆单或追加新仓位；不符合交易所单笔过滤器时保留该项失败并停止后续提交。拒签、仓位变化、读取失败或订单结果未确认也停止后续操作。逐项保留已提交／已核对、失败／原因、未提交和可复制编号，不显示“全部成功”来代替实际结果。
- “停止后续提交”会拦截尚未发送的当前下单请求；已越过 POST 边界的订单继续按原编号核对。未知结果持有全局交易／配置锁，仅允许签名查询该原编号；查询恢复不重发 POST，也不恢复未提交队列。单仓下单、全部平仓和四类配置互斥；身份变化丢弃迟到回调。
- 正常执行结束后，原确认包含一次完整仓位签名读取；拒签或未知结果停止后不再自动追加签名提示，保留显式“读取剩余仓位”入口。只把截止于本轮核对之后、同钱包、完整且新鲜的快照作为余量证据，保留当前数量正负；失败、读取中、账户事件后或陈旧快照不显示余量。订单 FILLED 与整仓关闭分开表述；已有挂单及后续活动仍可能再次改变仓位。
- 自动验收新增 32 项，全量 **781 项通过**；322 个 Dart 文件格式检查无改动，静态分析无问题，Android arm64 Release 构建成功。测试涵盖签名字节／独立 nonce、单向及同 symbol 双向顺序、POST 超时／订单暂未找到、最终完整仓位读取、精确作用域、变化／拒签／超量过滤、停止、互斥、身份变化、失败保留、查询不恢复队列，以及中英文 320 宽／1.5 倍文字与横屏确认／结果布局和余量正负／陈旧／错误。
- 验收结果及构建校验值见 `docs/reference/batch-close-verification.json`。本轮没有真机实测、APK 安装或真实私有金融请求；中英文、放大文字和横屏以 Widget 自动验证。iOS 构建仍受 Linux／无 Xcode 限制；待验收项见 [原生验收清单](native-verification-pending.md)。整体 PRD 尚未完成。

## 2026-11-03 单向仅减仓与单仓平仓

- 仓位卡新增按 symbol＋positionSide 进入的独立平仓页；打开不自动签名。显式预读后提供 MARKET／GTC LIMIT、手输数量、25／50／75／100% 及 1% 步长滑块。普通实盘入口增加单向仅减仓开关；双向模式要求使用原仓位方向的专用平仓入口。
- 单向按原仓位反向 BUY／SELL、BOTH＋reduceOnly=true；双向按原 LONG／SHORT 反向执行且不发送 reduceOnly。均不发送 closePosition，不自动撤销已有挂单。使用 Decimal 校验数量不超过所选仓位；比例按相应数量过滤器的 `(value-minimum)` 步长向下取整，不静默截到交易所最大值。100% 可能保留不能满足步长的尾量；超过单笔上限需用户另行调整。
- 仓位数量、开仓价和盘口价格在数据边界严格映射为 Decimal，拒绝矛盾方向、残缺双向分组或无效开仓价。市价估算取预读买一平多／卖一平空，限价取输入价，明确不含手续费、资金费及深度滑点。盘口不可用只隐藏估算。仅单向 reduceOnly 按官方错误码说明豁免最小名义价值，双向平仓不猜测豁免规则；其他过滤器继续校验。
- 确认展示钱包、交易对、仓位方向、原仓位数量、执行方向、数量／限价与客户端编号。确认后先独立签名 GET positionRisk，核对数量、开仓价、持仓分组、杠杆及保证金模式均未变化，然后签名 POST，最后独立签名 GET 订单。拒签、过期、身份变化或复核不一致时不提交；不静默调整已确认数量。并发变化及已有挂单的可减仓数量由 Aster 最终校验。
- 延续原编号与未知结果查询规则，超时不重发 POST。订单状态／FILLED 不表示整仓已平；结果页提供显式签名读取剩余仓位，只展示本次订单核对之后的同钱包完整且新鲜快照，旧快照、失败、读取中与账户事件后的数据不作为平仓余量。完整新快照内缺失对应仓位才显示零。
- 自动验收：新增 40 项，全量 **749 项通过**；314 个 Dart 文件格式检查通过，静态分析无问题，Android arm64 Release 构建成功。覆盖单向多空／双向 LONG与SHORT 参数、精确步长和尾量、过滤器豁免边界、估算盘口、签名字节与 nonce、仓位／配置变化拦截、拒签／迟到授权、超时仅查询、刷新保留输入、仓位卡入口、剩余仓位非零／零／陈旧／错误，以及中英文 320 宽／1.5 倍文字和横屏。所有私有接口及交易响应均为受控测试数据。
- 按用户要求未做本轮真机实测，也未安装 APK 或发送真实私有金融请求；待验收清单见 [未完成的原生验收](native-verification-pending.md)，构建校验值见 `docs/reference/live-close-verification.json`。Linux 无 macOS／Xcode，iOS 构建仍未验证。
- 后续全部平仓、下单资金／资产模式及限价策略（含 Hidden）增量见上方；独立指定数量 TP/SL 见上方增量；仍待实现附加 TP/SL／Entire close、BBO、高级订单、快捷开仓和跨进程未决订单恢复；子账户、充提／划转与通知见 [需求进度](prd-progress.md)。BAPI 统计与 TWAP 本阶段按用户要求跳过；独立反手／保证金增减入口尚待产品确认。

## 2026-11-03 实盘市价／GTC 限价订单

- 交易页新增独立实盘入口，原表单继续明确为本地演示。遵循 Widget → Riverpod controller → repository → service，现有 EOA 直接作为 user／signer，不创建额外钱包。
- 显式读取 exchangeInfo 和 premiumIndex，以公开 serverTime 校验标记价在 10 秒内，再分别签名 GET 持仓模式与 symbol 配置。保留零数量配置行，核对 BOTH／完整 LONG+SHORT、杠杆及保证金模式一致性。仅开放 TRADING／PERPETUAL／USDT 报价与保证金且支持 MARKET／LIMIT 的合约。
- Decimal 校验 PRICE_FILTER、LOT_SIZE、MARKET_LOT_SIZE、MIN_NOTIONAL、PERCENT_PRICE；按官方 `(value-minimum) % increment` 校验精确价格和数量。市价名义价值与方向价格保护使用参考标记价，手续费、余额、敞口及最终资格由 Aster 校验。
- 确认钱包、symbol、多空、持仓与保证金模式、杠杆、数量、价格、参考名义价值及可复制客户端编号。MARKET 不发送 price／timeInForce／stopPrice；LIMIT 显式 GTC。普通下单单向发送 BOTH，双向发送 BUY LONG／SELL SHORT；单向未开启仅减仓时可能减仓或反转已有持仓，页面已说明。后续仅减仓／平仓扩展见上节。
- 共用 EIP-712 chainId 1666 与 nonce，POST form bytes 与签名字节一致。客户端编号在提交前固定；POST ACK 不作为成交证据。另一次签名按 symbol＋origClientOrderId GET 核对客户端编号、symbol、方向、类型、原始／成交数量和限价条款，只有 FILLED 且数量一致才确认全量成交。
- 从标记价响应起 30 秒有效，账户事件、配置 epoch、重新读取、身份变化或闲置页面前后台使旧确认失效；签名后与 POST 边界再次检查。外部钱包活动签名的正常前后台回跳保留原期限与身份检查。四类配置和下单共享操作互斥。
- POST 可能到达后超时、拒绝查询或查询畸形时，仅允许用同一编号查询，不重发 POST；会话内禁止绕过未决锁重新预读或提交。失败与刷新保留输入，汇总及挂单标记待核对，不自动签名刷新余额。
- 此轮之后补齐的仅减仓、专用平仓、全部平仓、下单资金／资产模式及限价策略见上方增量。独立指定数量 TP/SL 见上方增量；尚未实现附加 TP/SL／Entire close、BBO、快捷开仓；未决编号／锁当前仅内存保存，进程重启或退出身份后的持久化恢复待补齐。独立反手入口尚待产品确认。
- 自动验收：新增 31 项测试，全量 709 项通过；310 个 Dart 文件格式检查无改动，静态分析无问题，Android arm64 Release 构建成功。覆盖拒签、晚到签名、未知结果只查询、重复提交、配置互斥和中英文窄屏／放大文字／横屏布局。旧监听测试的固定授权已过期，现显式注入测试时钟；旧登录文案断言同步更新。
- 用户要求暂停真机实测，后续仅记录未验收项。已完成的有限检查仅为中文未登录页面与登录弹窗，不代表真实签名成功；英文／横屏新流程真机验收未完成。真实 Privy 邮箱、EOA SIWE 回跳、Aster enable-trading／主钱包 signer 授权、私有读取、实盘订单及成交、四类配置变更、撤单、用户流断线恢复均未完成真实授权钱包验收。Linux 无 macOS／Xcode，iOS 构建及真机流程尚未验证。没有发送真实私有金融请求。
- 官方协议与匿名规则见 `docs/reference/live-order-public-contract.json`；检查记录见 `docs/reference/live-order-verification.json`。整体剩余功能见 [需求进度](prd-progress.md)。

## 行情价格与数量精度

- 标记价、盘口、最新成交、行情头部、OHLC 图例、长按 K 线详情和订单确认价格统一使用 Decimal 格式化：有小数时保留现有数字，至少显示两位小数，不截掉第二个非零小数位，中间的零也保留。示例：`0.0000010203 → 0.0000010203`、`0.01002 → 0.01002`、`0.1 → 0.10`；整数不附加 `.0`。原值只有一个非零数字时不补造第二个非零数字。
- 读取 Aster exchangeInfo 的 PRICE_FILTER.tickSize 和 LOT_SIZE.stepSize，保留到 Market 与选币状态。交易所精度作为小数显示的最小位数，不把标记价强行对齐到限价 tick；接口返回的更细小数仍保留。图表／深度坐标根据原始数值与交易所步长确定精度，长价格在盘口和详情中按宽度缩放，避免截断或挤出布局。
- 点击盘口使用普通十进制完整价格填单，移除固定一位截断。限价校验改为 Decimal 整数倍 tick，数量按 step 校验；市价演示接受实际行情报价的更细精度。缺少元数据时数量回退 0.00001 步长，价格保留已有有效正数精度。比例分配全程使用有理数计算，最后按真实数量步长向下取整；减仓后保留对应交易对精度规则。此处为早期演示下单范围；2026-11-03 新增的独立实盘流程见本文最新章节。
- 修复图表包深度浮层把整数价格重复到小数部分的问题（例如 80000 不再成为 80,000.80000）。金额／手续费等其他字段的货币显示规则保持原有约定。OHLC、盘口与标记价现有模型仍使用 double，绘图坐标精度限 20 位；此改动解决显示和填单截断，不宣称任意长度传输精度。
- 验证：格式化、flutter analyze 无问题、完整 80 项测试通过。新增回归覆盖零／整数／极小值／科学计数法／零间隔非零数字、非 10 次幂步长、微小限价与市价、精确比例分配、元数据传递，以及 360 宽度和 390 宽度／1.5 倍字体下的标记价、盘口、成交、长按 OHLC、填单和订单确认。

# Vanta 移动合约交易界面

参考页面：https://app.vanta.exchange/perp/PERP_BTC_USDC 。原站截图保存在 `docs/reference/mobile.png` 与 `desktop.png`。Flutter 规则摘录自 rwa-interface 宪章 v1.1.1，见根目录 `AGENTS.md`。

- Android arm64 Release 构建通过（30.9 MB），已安装至 Android12 真机。实测 1000PEPE 的头部标记价、盘口／成交、OHLC 图例／长按详情和盘口填单保留 7 位小数，布局正常；截图 `docs/reference/price-precision{-detail,-book,-trades}-android.png`。当前 Linux 无法编译 iOS，仍需 macOS／Xcode 验收。

## 当前实现范围

- 仅支持 Android / iOS，共用 Flutter 页面，保留 Vanta 深色、青绿品牌样式；小屏上下排列图表与交易区，平板宽屏三列。跟随系统／简体中文／English切换并保存偏好、底部导航、安全区、键盘避让。
- 根据补充要求，行情统一来自 **Aster USDT 永续合约 V3 公共接口**。界面明确显示 Aster 与 USDT，K 线、盘口、成交及资金费率使用同一交易所来源。
- 获取 exchangeInfo、24h ticker 和 premiumIndex，包含全部具有 ticker 的 TRADING／PERPETUAL／USDT 合约并按 symbol 去重，不设 100 个上限。优先 BTC、ETH、SOL，其余按初始报价成交额用 Decimal 降序排列，缺失或负值放末尾，同额按 symbol 排序。该列表用于合约选择；只有当前图表的币种／周期加载200根历史并订阅一条K线流，其他币种和未访问周期不加载历史、不订阅。
- 周期支持Aster全部15种：1m、3m、5m、15m、30m、1h、2h、4h、6h、8h、12h、1d、3d、1w、1M。常用六周期保留快捷入口，其他从“更多”进入。仅在首次打开某个币种／周期时创建会话和请求历史，不预加载。实际访问过的图表缓存保留到应用会话结束，切回立即显示并校准。只有当前图表有K线订阅、重试、边界及元数据定时刷新；切换币种或周期后旧图表暂停，迟到响应只能进入自己的缓存。首次未缓存的数据展示真实加载状态。
- `k_chart_plus` 绘制价格蜡烛图 / 折线图、成交量，以及可选择的 MACD、KDJ、RSI、WR、CCI 副图。默认只显示价格主图与成交量，副图每次只显示一个，可切换或关闭。支持 MA/BOLL 主图指标、长按、横向拖动、双指缩放及单指纵向页面滚动；使用包原有指标算法。DepthChart 使用当前交易对的真实 20 档盘口累计数量，与价格图在同一工作区通过“图表 / 深度图”切换。
- 公共行情可以直接使用；Privy 邮箱／EOA 身份和钱包签名已接入，Aster 账户及挂单支持手动签名读取，挂单可逐笔或按确认的交易对范围签名撤销并核对状态，真实授权仍待钱包实测；实盘 MARKET／LIMIT（GTC、IOC、GTX、HIDDEN 按交易对支持）已有独立确认及签名查询流程，真实授权验收尚未完成；充值和结算未接入。账户入口将登录与本地演示分开，演示模拟 10,000 USDT。模拟市价单建仓、限价单待成交、撤单/平仓、历史、保证金预占和手续费均使用 Decimal。演示挂单不会假装在后台自动撮合。完整 PRD 进度及剩余范围见 [需求进度](prd-progress.md)。

## Privy 原生身份接入

- 根据用户要求参考 `/data/dodo/rwa-interface`，固定 `privy_flutter 0.10.2`。邮箱验证码登录、验证码校验、60 秒重发间隔、启动与返回前台恢复已有身份、Ethereum 内嵌钱包创建／重试、地址复制和退出均经 `IdentityPanel → AuthController → IdentityRepository → Privy SDK`。SDK 用户、令牌及签名对象不进入 Widget 或 domain。
- `PRIVY_APP_ID` / `PRIVY_CLIENT_ID` 由 Dart 编译参数读取。`config/privy.example.json` 提供空模板；`config/privy.local.json` 忽略提交，仅复用参考项目两个公开标识。生产环境需要正确登记 `exchange.vanta.vanta` 和相应 iOS Bundle ID；不使用服务端 App Secret。
- 邮箱登录仅在身份没有内嵌 Ethereum 钱包时创建，已有钱包直接恢复；外部 EOA 登录不会走创建分支。钱包创建失败保留登录身份并允许单独重试；退出失败保留身份和安全原因。SDK 明确发出会话失效时立即清除身份并拒绝迟到的钱包结果。请求中阻止重复点击，校验失败保留邮箱和验证码；错误只展示安全的简短原因，屏蔽验证码、令牌和原始载荷。地址在数据边界校验为 20 字节 Ethereum 地址。
- 登录不代表 Aster 交易授权，不读取或展示私钥。界面说明需使用独立实盘入口且须具备 Aster 权限；本地 10,000 USDT 演示账户独立管理，身份变化会退出演示。Aster 账户读取和独立确认的逐笔撤单请求已实现，真实授权成功尚未实测；enable-trading 授权、子账户切换、充提、开仓附加 TP/SL 与联动／编辑、Chase／BBO／Scaled 和远程通知仍未实现；TWAP 及 BAPI 历史统计按用户要求暂跳过。这些能力需要对应的账户／交易协议和服务接入，不以演示数据代替。
- Android Privy 插件的 compileSdk 经 `android/privy-compat.gradle` 对齐 36，避免其 AndroidX 依赖与插件默认 34 冲突；不修改 Pub 缓存。Android minSdk 28、iOS deployment target 17。未使用 OAuth／passkey，不添加不适用的回调和 Activity 补丁。
- 自动验收覆盖 SDK 配置和调用边界、会话恢复、重复请求、邮箱／验证码校验、失败重试、钱包仅创建一次、退出失败、会话失效竞态、安全错误、地址校验，以及登录页窄屏／横屏／放大文字／键盘避让。自动测试使用可控 fake，不作为真实验证码登录成功的证据。
- 验证结果：格式化检查无改动、`flutter analyze` 无问题、完整 104 项测试通过；`flutter build apk --release --target-platform android-arm64 --dart-define-from-file=config/privy.local.json` 成功（35.3 MB）。Gradle 对 Privy 插件旧 KGP 用法给出未来兼容提示，当前工具链构建成功。
- 最终 Release 已安装 Android 12 真机，目视确认邮箱登录页、独立演示入口、真实 Aster 行情快照、自选筛选与 ETH 搜索。截图：`docs/reference/privy-login-android.png`、`market-selector-android.png`、`market-favorites-android.png`、`market-search-android.png`。
- 尚未执行真实邮箱验证码收发及真实用户登录，也未验证生产 Privy 客户端许可配置。iOS 仍需 macOS／Xcode 构建与真机验证。

## 外部 EOA 登录与签名

- 接入与参考项目同版本的 `reown_appkit 1.9.0`。链为 Ethereum／BNB Chain／Arbitrum／Base，连接后向 Privy 请求 SIWE 挑战，由连接的 EOA 执行 `personal_sign`，服务端验签登录后核对外部钱包关联。关闭 SDK 邮箱／社交创建入口；EOA 分支不调用 `createEthereumWallet`。公开行情读取本身不需要签名。
- `signExternalRequest` 提供 EIP-712 签名边界，固定交给当前外部钱包，签名前后核对地址、网络及会话有效性，不退回内嵌钱包。`signWalletRequest` 按当前钱包类型分派：EOA 交给该接口，邮箱身份只使用已有内嵌钱包执行 `eth_signTypedData_v4`，不为读取创建钱包。Aster 账户只读 repository 已调用该边界，但未经真实授权成功验证，不能据此声称已读取真实资产或启用交易。SIWE 身份登录与 Aster enable-trading 是不同步骤。
- 本地仅保存用户 ID、钱包类型和公开地址，已有内嵌钱包不会覆盖用户选中的 EOA。重启后恢复身份和地址，但签名前必须重新连接同一个 EOA；关联地址缺失、账户或链改变时拒绝签名并要求重新登录。重连其他地址必须先退出当前身份。取消或拒签显示中英文安全原因，保留邮箱输入；请求中禁用重复操作。
- 钱包连接与签名客户端位于数据适配层，SDK 对象不进入 Widget／domain。连接弹窗使用长期存活的 Navigator 上下文，会话监听在替换连接及 repository 销毁时释放；退出同时断开外部会话。身份或地址变化会清除本地演示账户。
- 新增公开参数 `REOWN_PROJECT_ID`、`WALLET_LOGIN_ORIGIN`（HTTPS，无用户信息，按 origin 归一化）。Android 和 iOS 配置 `vanta://wallet` 回跳及钱包查询；Privy 控制台需允许应用标识和 SIWE origin，Reown 项目也需正确配置。没有将参考项目密钥复制到应用。
- Android 对 Coinbase 适配插件的 compileSdk 从 31 对齐 36，并去掉发布包中缺失的 consumer-rules.pro 引用，与参考项目相同，均通过项目内 Gradle 补丁完成；`connectivity_plus` 固定 7.0.0，与参考项目一致避开后续版本的 iOS 26 原生 API。Reown 新增依赖用于原生外部钱包连接，SharedPreferences 仅保存公开偏好。

## 多语言

- 参考项目使用 Flutter 官方 ARB／gen-l10n，本应用已将全部现有双语消息迁入 `lib/l10n/app_en.arb`／`app_zh.arb`，`l10n.yaml` 生成到 `lib/l10n/generated`。`core/strings.dart` 仅桥接现有动态图表／状态 key，不再保存另一套文案。新增消息需补齐两个目录后运行 `flutter gen-l10n`。
- 默认跟随系统，可选简体中文或 English，不支持的系统语言回退英文。SharedPreferences 保存选择，启动读完再渲染首屏，避免语言闪动；连续快速操作按顺序写入，失败保留当前语言并可重试。退出登录不清除语言，切换不重建导航／图表选择或表单输入。
- Material／Cupertino 原生控件、行情／订单／认证界面、图表详情及深度长按信息使用当前语言，验证码倒计时使用 ICU 参数。币种、钱包品牌及技术指标保留标准名字。Reown 1.9 未提供本地化接口，其第三方钱包选择弹窗仍使用英文；钱包应用内的签名确认由钱包自行控制，不宣称已翻译第三方界面。
- 自动验收覆盖双语目录 key／非空值一致、跟随系统与回退、保存／恢复／保存失败重试、切换时保留交易对，以及英文放大字体的顶部布局。EOA 测试覆盖 SIWE 请求、选中地址恢复、无额外钱包创建、typed-data 签名、失效时拒绝迟到签名、取消后重试与重连 UI，所有 SDK 登录测试使用 fake，不等价于真实钱包验签成功。
- 2026-11-02 最终复核：中英文目录各 332 条消息，key 完全一致，页面静态翻译 key 均有映射。147 个 Dart 文件格式检查无改动，`flutter analyze` 无问题，完整 222 项单元／Widget 测试通过；Android arm64 Release 构建成功（42.0 MB）并安装 Android 12 真机。再次目视确认英文页面、强制停止后重启恢复 English，以及改回跟随系统恢复中文；截图 `docs/reference/language-verification-{en,system}-android.png`。验证后设备已恢复原先的跟随系统设置。iOS 构建仍需 macOS／Xcode。

## 本轮 EOA 与多语言验收

- 格式化检查通过，完整 130 项单元／Widget 测试通过。`flutter analyze` 无问题。Android arm64 Release 构建成功（41.8 MB）并安装到 Android 12 真机。
- 真机确认系统中文首屏、三种语言选项、English 切换即时生效、强制停止后重启保留 English、改回跟随系统恢复中文、英文邮箱／EOA 登录说明、钱包列表打开、取消后显示可重试原因以及再次打开列表。截图：`language-picker-android.png`、`language-en-android.png`、`language-restored-android.png`、`language-system-android.png`、`eoa-login-en-android.png`、`eoa-chooser-android.png`、`eoa-cancel-android.png`、`eoa-retry-android.png`，均位于 `docs/reference`。
- 未使用真实 EOA 完成 SIWE 验签，也未执行真实邮箱验证码收发；真实登录、生产客户端许可和钱包回跳仍需使用实际测试账户验证。该轮尚未接入 Aster 账户读取；新增只读通路的边界和验收见下节，交易授权仍未接入。当前 Linux 环境无法验证 iOS 构建，需 macOS／Xcode。
- 本机 Nix Android SDK 附带 Ninja 执行 `--version` 即崩溃。仅在忽略提交的 `android/local.properties` 将 CMake 指向本机缓存镜像，使用同一 CMake 3.22.1 与可运行的 Ninja 1.13.2；没有改动 SDK／Pub 缓存或在工程中写死本机路径。正常 Android SDK 环境不需要该覆盖。

## Aster 账户只读通路

- Portfolio 默认显示独立的「Aster 账户」页，演示账户由单独标签进入。登录、导航和返回前台不会自动弹出签名；用户手动读取或刷新时，经 `AsterAccountPanel → AccountReadController → SignedAccountRepository → AsterAccountService / IdentityRepository` 执行。未登录显示登录入口；恢复但未重连的 EOA 提示连接同一钱包。Aster 页不展示演示余额、订单或持仓。
- 请求仅包含 GET `/fapi/v3/time`、`/fapi/v3/accountWithJoinMargin`，有非零持仓时再 GET `/fapi/v3/exchangeInfo` 确认单位。账户查询以选中的钱包同时作为 `user` 和 `signer`，不生成 agent、私钥或备用钱包，不调用注册 agent、交易授权、订单、转账或提款接口。
- 按 Aster V3 文档构造 EIP-712：`AsterSignTransaction`、version `1`、chainId `1666`、零 verifyingContract、`Message(string msg)`。nonce 取 Aster 服务器时间的微秒值，同一时间连续请求仍递增；固定 URL 编码后的 query，签名和发送使用相同字节。签名等待超过 50 秒拒绝继续发送，不自动重签／重放；HTTP 超时 12 秒，不跟随重定向、不记录签名 URL，错误仅保留本地化 key 和可选数字 code。
- **接入限制：V3 文档将 signer 描述为已授权 API wallet，尚未证实主钱包可直接作为自身 signer。** 当前路径会让 Aster 验证该钱包的权限，授权拒绝有明确提示；不能因 Privy SIWE 登录或本地签名成功就宣称账户读取成功。外部钱包还可能因当前网络与 EIP-712 的 chainId 1666 不同而拒签，应用不会改写官方 domain 来绕过。若协议必须使用独立 agent，这条直签路径需要官方支持或业务后端适配后才能完成真实验收，不能以创建新钱包代替用户选中的 EOA。
- USDT 概览仅展示 API 的 totalWalletBalance、totalMarginBalance、availableBalance、totalInitialMargin、totalUnrealizedProfit；明确不是 Spot／质押／金库／其他资产／子账户合计。资产逐币种显示，支持搜索和隐藏零余额，Multi-Assets 抵押资格只表示该模式下是否可作抵押，不表示当前账户已启用多资产模式。`canTrade` 仅保存在模型中，不作为已启用实盘的证据。
- 非零仓位保留 symbol、方向、数量、入场价、浮盈亏、初始保证金、杠杆和逐仓／全仓。单位使用 exchangeInfo 的 baseAsset、quoteAsset、marginAsset，不从 symbol 后缀猜测；包含已停止交易的合约。元数据不可用时保留账户快照并注明「单位待确认」。资产标识、钱包地址和合约标识可选择复制，地址另有复制按钮。
- 财务字段在数据边界解析为 Decimal，字符串／整数保留精度；拒绝 double、科学计数法、无效数值、重复资产／仓位、矛盾的方向数量和不完整的必需字段。缺失的可选值显示 `—`，不会变成零；不把无效余额静默丢掉。账户不持久化到磁盘。
- 刷新中禁止重复点击，显示准备／签名／读取阶段。失败保留旧快照与筛选输入，并标明历史数据；读取后 30 秒、退到后台或返回前台标记历史快照，不后台自动签名。身份、钱包类型、地址或签名连接变化会清空数据，迟到响应与销毁后结果被丢弃；返回的账户地址不一致也拒绝覆盖。
- 签名后检查会话代数与地址；SDK 在前台恢复为同一用户／钱包的新对象不会误判账户切换，退出或重登仍拒绝旧签名。自动测试覆盖 exact query、nonce 去重、只读方法、重定向禁用、取消／拒签、晚到服务器时间、网络与 API 错误、安全错误、本地化、Decimal、未知单位、陈旧快照、筛选输入、身份切换和销毁。
- Aster 返回 `-5050` 时，使用「关联主钱包需先完成充值」的独立中英文错误提示，保留数字错误码；该传输错误映射已通过回归测试，真实授权和充值条件仍由 Aster 校验。
- 自动验收：完整 172 项单元／Widget 测试、格式化检查、静态分析无问题。账户页覆盖 360 宽中文、390 宽英文／2 倍文字、844×390 横屏／1.5 倍文字；同时修复英文放大文字下盘口表头和底部数据源说明的横向溢出。所有账户成功响应均为测试 fixture，不能作为真实资产读取证据。
- Android arm64 Release 构建成功（41.9 MB），已安装 Android 12 真机。确认中英文只读页、读取按钮打开登录、语言切换保留 Portfolio、演示标签与 10,000 USDT 本地资金标注，以及演示启用后 Aster 页仍无余额。截图和校验记录为 `docs/reference/aster-account-{zh,en,login,demo,demo-active,demo-isolated}-android.png` 与 `aster-account-android.json`。没有在真机注入假登录或假资产；真实邮箱／EOA 登录、Aster 授权成功与私有读取仍未实测。Linux 环境无法编译 iOS，需要 macOS／Xcode。

## Spot 账户只读通路

- 对照 Portfolio 子页「5、spot资金分布」新增 Aster 账户下的「合约／现货」标签。现货经 `SpotAccountPanel → SpotAccountReadController → SignedSpotRepository → AsterSpotService` 访问官方 `https://sapi.asterdex.com` 的 GET `/api/v3/time` 和 `/api/v3/account`；不会把请求发到合约 fapi host。文档依据：[Aster Spot V3 Account information](https://github.com/asterdex/api-docs/blob/master/V3%28Recommended%29/EN/aster-finance-spot-api-v3.md#account-information-user_data)。
- 仅用户手动读取／刷新时签名，切标签、导航、切语言、恢复会话不自动签名。user 与 signer 都是当前选中钱包，不生成钱包／agent，不提交订单、授权、转账或提款。Spot 文档的 EIP-712 domain 同样为 AsterSignTransaction／version 1／chainId 1666／零 verifyingContract，签名与实际 query 字节一致。现货和合约共用 nonce 分配器，在同一服务器毫秒内也不重用 nonce；保留 50 秒签名等待过期保护、12 秒 HTTP 超时、禁止重定向和安全错误映射。
- 现货从 balances[] 读取 asset／free／locked，按 Decimal 计算 total = free + locked。必须是非负十进制字符串或整数，拒绝 double、科学计数法、缺失金额、重复资产、控制字符及异常载荷；不静默丢弃无效余额，也不以零覆盖。支持合法 Unicode 资产标识。模型列表不可变、资产标识可选择复制、钱包地址另有复制按钮。
- 现货快照与合约快照独立，不合并不同币数量、不用合约可用余额填现货，不展示未经估值的美元总额。搜索忽略英文大小写及首尾空格，「隐藏零余额」使用 free + locked，保留 free=0 但 locked>0 的资产；无资产与无匹配结果分别显示空态。刷新失败保留此前快照及当前输入，并标明历史数据；身份、钱包地址／类型／签名连接变化会清空两个账户，拒绝迟到结果。退出登录或切换身份不会保留原资产筛选组件。
- 抽取两处真实消费者共用的 GET 传输、签名请求、快照控制器、读取按钮及时间／陈旧提示，仍由各自 repository 解析各自模型。30 秒后、退到后台及返回前台标记历史快照；额外修复请求跨越后台切换后迟到成功被当作新鲜数据的竞态。签名被取消或会话失效不自动重试。
- 与完整 PRD 的差距：官方 account 没有 usdValuation／btcValuation；当前只有明确的零余额过滤，尚无 `btcValuation > 0.0001` 小额资产过滤。支持网络、充提、划转及 Spot 实盘下单未实现；Spot 历史入口的后续实现见下一节。Privy 登录态不能作为 Aster 官网 private BAPI 凭据，Aster 是否允许主钱包自身作为 signer 仍待验证；canTrade 等标志不展示为已开通实盘。
- 自动验收：完整 202 项单元／Widget 测试通过，格式化检查 136 个文件无改动，静态分析无问题。现货新增 18 项覆盖 Decimal／冻结余额、无效载荷、UTF-8、正确 host/path、跨 Spot／Perp nonce 去重、签名取消／地址切换、迟到响应、手动读取与快照隔离、失败输入保留、空态、中英文切换和 360 宽／1.5 倍字、390 宽／2 倍字、844×390 横屏／1.5 倍字布局；原合约回归继续通过。
- 公共接口实测 `docs/reference/spot-time-live.json` 由实际 AsterSpotService 匿名请求，仅证明 sapi 时间端点可达。自动测试成功账户响应均为 fixture，不作为真实 Spot 余额读取证据。真实邮箱／EOA 登录、主钱包授权及成功私有读取仍未实测。Android arm64 Release 构建成功（41.9 MB）并安装至 Android 12 真机，目视检查中英文现货页、语言切换保留 Spot、读取按钮打开登录、横屏可滚动且操作可见，以及不显示演示资金。截图 `docs/reference/spot-account-{zh,en,login,landscape}-android.png`，记录 `spot-account-android.json`。Linux 环境无法编译 iOS，需 macOS／Xcode。

## Spot 历史记录

- 对照 Portfolio 子页「5、spot资金分布」补齐 Order History、Trade History、Transaction History 三个入口，从资产页打开独立原生页面。分别调用 `https://sapi.asterdex.com/api/v3/allOrders`、`/api/v3/userTrades`、`/api/v3/transactionHistory`。所有私有请求均为 GET，通过 `SpotHistoryScreen → SpotHistoryController → SignedSpotHistoryRepository → AsterSpotService / IdentityRepository`，签名继续交给当前 EOA 或已有内嵌钱包，不创建钱包。与现货／合约读取和撤单共享 nonce，签名 query 字节与实际发送一致，不将签名 URL、原始响应或 SDK 对象暴露到 UI。
- PRD 的流水说明此前只确认了官网 BAPI；本轮重新读取官方 Spot V3 文档，确认已有文档化的 `transactionHistory`，因此使用该独立流水接口。不能用逐笔成交冒充所有资产变动，也不把流水号当链上交易哈希或把它用于推断充提待处理阶段。协议来源：[官方 Spot V3 文档](https://github.com/asterdex/api-docs/blob/master/V3%28Recommended%29/EN/aster-finance-spot-api-v3.md)，本次文档校验和、匿名 time／exchangeInfo 结果见 `docs/reference/spot-history-public-contract.json`；匿名元数据实测返回79个交易对，均有基础币与报价币。
- 订单保留 NEW、PARTIALLY_FILLED、CANCELED、FILLED、EXPIRED、REJECTED 及未来状态，显示原始创建／更新时间、已成交／委托数量、委托价、成交均价、已成交报价币金额、触发价和可复制订单号。没有成交时不伪造均价，市价不显示成零委托价。逐笔成交按 `symbol + tradeId` 去重，保留所属 orderId、费用币种、原始费用正负号、Maker／Taker；同一订单的多笔成交仍是多条。流水按 `type + asset + tranId` 组织，展示带符号的 Decimal 余额变动、类型、可选 tradeId 和可复制流水号；未知枚举以有界代码标记为其他类型，不猜测状态。
- 合约目录不能用于推断 Spot 单位。现货 exchangeInfo 独立关联 baseAsset／quoteAsset，包括非交易中记录；元数据失败仍显示有效历史并明确单位待确认，不从 symbol 截取资产。订单、金额、费用、数量均在边界以 Decimal 校验；异常金额、重复标识冲突、错误范围／记录类型、错账户结果均安全失败，不静默变零或删除记录。重叠读取按订单 updateTime 保留较新版本，成交与流水的冲突金额直接拒绝。
- 默认最近7天，支持最近24小时及自定义 UTC 日历日期；订单接口不返回创建超过7天的订单，因此限制订单查询跨度并始终显示保留期说明。成交和流水允许更长日期，按固定 endTime 切成最多7天、端点均包含且不重叠的区间，由用户逐次签名读取。每次最多1,000行，达到上限时保守标记不完整并继续拆分该区间；不能假定服务端返回顺序，也不混用 fromId／orderId 游标和时间参数。同一毫秒仍达到上限时停止细分，明确结果不完整并建议缩小资产／交易对范围。去重后的条数不用于判断接口是否达到上限。
- 每次继续读取只执行一个 GET，不后台自动翻页或请求签名。失败保留此前记录、输入及待处理的确切区间，可以重试；修改类型、范围或精确 symbol／asset 会清除旧结果，不发送请求。已加载记录每页10条，翻展示页不签名。保留首次读取时间，明确分段结果不构成原子快照；30秒、后台切换及返回前台标为历史数据。身份／钱包／签名连接变化清空输入与记录，丢弃迟到结果；停止等待或返回退出也使当前读取失效，不将迟到签名用于发出私有请求。停止本地等待不会关闭外部钱包自身的确认界面。
- 最终验证：格式检查176个 Dart 文件无改动，静态分析无问题，完整310项测试通过（本轮新增39项）；中英文各422条消息。覆盖订单各状态、Decimal／长编号、单位缺失、逐笔与流水隔离、超限／分段／冲突、失败保留、停止／返回／身份竞态，以及360宽英文2倍文字、844×390中文横屏1.5倍文字、UTC日期和切语言保留结果。
- Android arm64 Release 构建成功（42.4 MB）并安装 Android 12 真机，目视确认中文三个入口、订单保留期提示、流水资产筛选、英文成交页、登录入口和横屏滚动；验证后恢复原中文及竖屏偏好。截图与APK校验见 `docs/reference/spot-history-verification.json` 及 `spot-history-*-android.png`。未注入假账户／资产，也未发送真实金融请求；真实 Aster 授权和私有历史读取仍待测试钱包验收。签入后的记录卡片和错误／分页布局仅经受控 Widget 测试。当前 Linux 无法编译 iOS，需 macOS／Xcode 验证。

## 仓位风险快照

- 对照 Futures PRD「Positions」新增 Portfolio → Aster 账户 → 合约 → 仓位风险。链路为 `PositionRiskScreen → PositionRiskController → SignedPositionRiskRepository → AsterAccountService`，只调用官方签名 GET `/fapi/v3/positionRisk`。当前 EOA／已有内嵌钱包作为 user 和 signer，复用全局 nonce 分配器，不新建钱包或 agent。签名与发送复用相同 query 字节，禁止重定向；真实 Aster 主钱包签名授权仍待验收。
- 独立快照显示服务端 entryPrice、markPrice、liquidationPrice、带符号 positionAmt／notional、unRealizedProfit、杠杆、保证金模式，以及逐仓 isolatedWallet／isolatedMargin；不将独立账户读取的保证金字段拼入此快照。更新时间为服务端 updateTime（UTC），零值不制造时间；接收时间单独保留。全部金融值使用 Decimal，不从最新成交价估算风险，不用简化杠杆公式计算强平。
- 按 symbol＋positionSide 校验并去重，兼容单向 BOTH 和双向 LONG／SHORT，拒绝同交易对混合持仓模式及方向矛盾。通常保留非零仓位；额外保留数量为零且逐仓钱包余额为负的记录，明确显示负余额及数量为零，不将其标成多／空或隐藏。服务端强平价缺失或零时显示 —，附说明其不等于没有强平风险。可选字段缺失保留未知，畸形字段使整次刷新失败，不替换为零。
- 金额单位来自公开 exchangeInfo 的 baseAsset、quoteAsset、marginAsset，包括下架合约；元数据失败保留有效签名快照，并提示单位待确认。数量保留正负号；名义价值取服务端原值，不假定异步字段恰好满足数量×标记价。当前交易对过滤为本地筛选，随全局交易对变化，不发请求；负余额记录计入记录数。
- 手动签名读取、重复点击禁用、登录入口、错误安全文案沿用账户通路。失败保留旧快照及过滤输入并标记历史数据；身份、地址、钱包种类或签名连接变化清空记录并丢弃迟到结果。30秒、应用后台／恢复、逐笔／批量撤单后标记需刷新；不自动要求额外签名。
- 格式检查187个 Dart文件无改动，静态分析无问题，完整331项测试通过（新增21项），中英文各437条消息。覆盖精度、双向及逐仓负余额、零强平价、异常 payload、元数据失败、准确 GET／签名字节、拒签和身份竞态、30秒过期、筛选、失败保留、未登录和360宽中文／390宽英文2倍字体／844×390中文1.5倍字体布局。
- Android arm64 Release 构建成功（42.4 MB）并安装 Android 12 真机，目视检查中文、英文、登录入口和英文横屏，随后恢复原中文和竖屏偏好。未注入假登录或假资产，未发送真实金融操作；已登录数据卡片只经受控 Widget 验证。Linux 无 Xcode，iOS 构建尚未验证。证据见 `docs/reference/position-risk-public-contract.json`、`position-risk-verification.json` 和 `position-risk-*-android.png`。
- 此节记录最初 REST 快照增量。后续 ADL、标记价格估值、ACCOUNT_UPDATE 用户流、仓位初始保证金／ROE、平仓及独立指定数量 TP/SL 已补齐，见各增量章节；附加 TP/SL／Entire close 等剩余项以需求进度表为准。独立反手及逐仓保证金增减入口尚待产品确认。已有账户摘要内的简版仓位仍属于该账户读取时间，风险页独立展示完整风险来源，不将两者当作同次刷新。BAPI 历史统计及 TWAP 按用户要求继续跳过。

## ADL 自动减仓队列

- 对应原始 Futures PRD「Positions → ADL 指示条」。仓位风险页新增可展开的 ADL 区，单独手动签名 GET `/fapi/v3/adlQuantile`，遵循 `PositionAdlPanel → PositionAdlController → SignedPositionAdlRepository → AsterAccountService`。当前连接 EOA／已有内嵌钱包作为 user 和 signer，与其他签名读取共享 nonce；不创建钱包或 agent，不调用 BAPI，不自动弹签名或轮询。ADL 与仓位读取按钮在对方读取期间互相禁用，避免页面同时发起两个签名请求。
- 官方接口定义档位为整数0～4，约30秒更新；严格保留0为有效档位。以 symbol＋positionSide 关联：单向 BOTH 取 BOTH；逐仓双向取 LONG／SHORT；全仓双向要求 HEDGE 标记并取相应 LONG／SHORT。HEDGE 仅为模式标记，其整数值不作档位使用；BOTH 与 HEDGE 共存、全仓双向两侧档位冲突、非法档位或重复 symbol 会使此次刷新失败。缺少 symbol／side、模式不匹配或空成功响应保持未知；数量为零的逐仓负余额记录显示不适用，不推断方向或制造0档。
- 对照官网 `ADLBlock-4FTpf-yD.js` 的组件：共四格，档位N点亮N格（卖出色），其余为弱化文字色。因此0档有四个未亮格，4档全部点亮；未知状态不画有效档位指示条。使用统一主题色，附本地化档位文字和完整屏幕阅读器语义；Wrap布局支持窄屏及大字体。说明明确它是自动减仓队列指标，不是保证金率或强平倒计时。
- ADL 独立保留读取时间，与 positionRisk 快照不视为原子读取。ADL 或仓位任一状态过期时，匹配的档位明确标为历史档位；30秒、生命周期变化以及逐笔／批量撤单后标记需刷新。签名拒绝、网络或协议失败保留旧ADL及原时间，不影响仓位快照；身份／钱包／签名能力变化清空ADL并丢弃迟到响应。页面打开及本地交易对筛选不自动读取ADL。
- 自动验证：格式检查198个 Dart文件无改动，静态分析无问题，完整353项测试通过（新增22项）；新增／修改Widget断言后相关9项复核通过。中英文各446条消息。覆盖准确GET及签名字节、相同EOA／共享nonce、五档及四格颜色／无障碍语义、模式与侧别关联、HEDGE标记忽略、非法／缺失／冲突响应、过期／拒签／注销竞态、仓位快照隔离及并发签名按钮互斥。未知指示器经360宽英文2倍字体及844×390中文1.5倍字体验证。
- Android arm64 Release 构建成功（42.4 MB）并安装 Android 12 真机；目视确认中文、英文展开区、ADL读取按钮打开EOA／邮箱登录和英文横屏滚动，验证后恢复中文、竖屏及原字体设置。未注入假登录／假档位，也未发送真实金融操作；真实授权ADL成功读取仍待测试钱包验收，已登录卡片仅经fixture Widget验证。Linux无Xcode，iOS构建尚未验证。API／官网组件来源与sha256见 `docs/reference/position-adl-public-contract.json`；APK校验与截图见 `position-adl-verification.json` 和 `position-adl-*-android.png`。
- 实时标记价格估值的后续实现见下一节；总体PRD仍待鉴权用户流、仓位ROI、平仓／反手、保证金修改与TP/SL等；私有BAPI功能按用户要求跳过。

## 合约单一／多资产模式

- 对应Futures PRD「3.1保证金模式 → 全仓 → 单一／多资产；切换多资产需要把所有逐仓仓位切换成全仓」。仓位风险页增加独立账户级资产模式入口，明确作用于下方钱包的全部合约交易对；Widget → Riverpod controller → 签名repository → Aster服务，不复用本地演示的资金或模式。
- 用户显式点击后分别签名 `GET /fapi/v3/multiAssetsMargin`、不带symbol的 `GET /fapi/v3/positionRisk`。mode仅接受布尔multiAssetsMargin；全部仓位按symbol分组，要求BOTH或完整LONG／SHORT，核对方向、唯一性、账户持仓模式及同symbol保证金模式一致。positionAmt与isolatedWallet使用Decimal严格解析，缺失、浮点、科学计数或矛盾数据不会当作无逐仓敞口。
- 目标为多资产时，任意symbol存在非零逐仓仓位或留存逐仓抵押余额（含负余额）即阻塞检查修改，展示可复制交易对。空的逐仓零数量／零余额配置及全仓仓位不制造阻塞；单一资产目标不反向套用此限制。不会自动转换逐仓／全仓、平仓、撤单、兑换或划转。预读不是原子锁，余额要求、支持抵押币种及估值、最终资格由Aster校验；界面说明不能保证资金或风险数值。
- 配置30秒有效期从第一份模式响应开始，包含等待第二次签名和读取时间。到期、账户事件或任一合约设置提交使旧确认失效；签名返回后与实际发送前再次核对。身份／钱包／签名能力变化清空状态、阻止后续旧签名及迟到结果；页面级选择在滚动重建、失败、刷新和核对后保留。
- 确认弹窗固定完整钱包、全部合约作用域、原模式及目标模式。当前已连接EOA或Privy钱包签名 `POST /fapi/v3/multiAssetsMargin`，目标多资产明确提交字符串`true`、单一资产为`false`，不携带symbol／marginType／dualSidePosition，不创建额外钱包、agent或API key。然后另一次签名GET读取实际模式及UTC时间，POST确认或钱包审批不作为最终成功证据。官方未列出的专有错误不猜测含义，使用已有安全原因及数值错误码，不展示原始报文。
- 提交超时、错误或后续核对拒签均不重发POST，跨页面保留未决操作，只提供GET查询。资产模式与杠杆、保证金模式、持仓模式四类操作共用互斥及提交epoch；未决写入阻止其他设置，任一提交让全部旧确认过期，旧身份完成不能释放新租约。提交将余额、仓位、ADL及挂单标为历史，不用模式结果拼造新的风险或额外自动签名。
- 所有选择、确认、进度、阻塞、失败和未知结果纳入中英文ARB；钱包、受影响symbol可复制。参考rwa-interface明确支持模式、有效上下文和操作边界，Hip3协议不作为Aster参数依据。窄屏及横屏大字体的选择、可滚动确认、查询结果与失败保留由Widget测试覆盖。
- 678项全量测试通过（新增7项mapper／领域、17项签名仓库、13项controller、8项Widget、4项跨设置互斥），297个Dart文件格式检查无改动，静态分析无问题，中英文各593条消息。既有账户事件Widget回归补上筛选开关的滚动定位和布局等待，相关5项及完整套件重新通过。测试包含跨symbol逐仓仓位／抵押余额、极小数量、全仓与空配置不误拦截、两种方向参数、拒签、超时不重发、未知核对、身份及过期竞态、四类设置失效、确认取消和中英文大字体布局。
- Android arm64 Release（42.8 MB，68.6秒）构建并安装Android 12真机；目视检查中英文入口、全部合约范围、资产及风险说明、实际邮箱／EOA登录弹窗和英文横屏，无裁切／溢出。验证后恢复中文、竖屏及原字体设置，登录后字段仍只经受控Widget数据验证。
- 官方协议和SHA256见 `docs/reference/futures-asset-mode-public-contract.json`，验证证据见 `docs/reference/futures-asset-mode-verification.json`。真实授权EOA／Privy读取及修改、已登录真机值和iOS仍待验收；Linux无macOS／Xcode。本轮不发送真实私有请求或金融操作。
- 独立资产模式流程尚未接入实盘下单／快捷开仓表单。实盘下单、平仓／反手、逐仓保证金增减、TP/SL、子账户、资金和通知继续推进；私有BAPI历史统计／TWAP按用户要求跳过。

## 合约单向／双向持仓模式

- 对应Futures PRD「3.1交易参数设置 → 持仓模式：单向／双向，切换需要平掉已有仓位」。仓位风险页提供独立账户级入口，明确影响下方钱包的**全部合约交易对**，不沿用当前交易对筛选。Widget → Riverpod controller → 签名repository → Aster服务，使用不可变模式、上下文、确认意图和结果；与本地演示持仓设置分开。
- 用户显式读取时依次签名 `GET /fapi/v3/positionSide/dual`、不带symbol的 `GET /fapi/v3/positionRisk`、不带symbol的 `GET /fapi/v3/openOrders`。只接受布尔类型dualSidePosition，false为单向、true为双向；不猜测缺失值或接收字符串布尔。仓位按全部symbol＋side验证重复、模式、方向和Decimal数量，零数量行也校验，极小非零数量仍阻塞；挂单复用严格mapper并核对side与模式。模式、仓位或挂单失败均不能显示成无持仓／无挂单。
- 任意交易对存在仓位或有效挂单时显示账户级阻塞原因并禁用检查修改。不会自动平仓、撤单或切换保证金／资产模式。预读不是原子锁，其他终端或外部账户变化仍由Aster最终校验。30秒有效期从第一份模式响应开始，包含后续两次签名及读取时间；到期、账户事件、其他设置提交或身份变化后不能使用旧确认，发送前和签名返回后再次检查。
- 确认弹窗展示完整可复制钱包、全部合约范围、读取模式及目标模式。当前连接EOA或Privy钱包签名 `POST /fapi/v3/positionSide/dual`，仅提交dualSidePosition=`true`／`false`字符串及认证参数，不携带symbol、marginType或API key，不创建钱包或agent。POST后另一次签名GET核对实际模式和UTC时间；钱包审批及HTTP确认均不证明切换成功。官方-4059已是该模式、-4067存在挂单、-4068存在持仓映射为中英文具体原因与错误码，不展示原始报文。
- 超时、提交错误或核对拒签不重发POST。未知结果跨页面保留，只有GET查询恢复；杠杆、保证金模式和持仓模式共享设置互斥和提交epoch。任一未决修改阻止其他两类读取／修改，任一提交使全部旧确认过期；迟到操作不能释放新身份租约。提交将余额、仓位、ADL、挂单标为历史，结果仅为模式查询快照，不拼造新的余额／风险或额外自动签名。
- 模式选择由页面保存，滚动重建、失败、刷新和结果查询均保留，身份变化或退出页面清理。中英文选择、确认、加载、错误和未知结果均纳入ARB。风险页的配置入口提取为特性内组件，避免新增入口继续扩大页面build。参考rwa-interface的配置有效期和明确可修改边界，其Hip3传输协议不能替代Aster官方持仓模式定义。
- 629项全量测试通过（本轮新增4项mapper、18项签名仓库、12项controller、8项Widget、3项跨设置互斥），285个Dart文件格式检查无改动，静态分析无问题，中英文各569条消息。测试包含其他交易对仓位／挂单、极小数量、true／false精确签名字节、三次预读拒签、模式不一致、超时不重发、身份竞态、过期及英文360宽2倍字体／中文844×390横屏1.5倍字体的选择、确认和结果。
- Android arm64 Release（42.7 MB，67.4秒）构建成功并安装Android 12真机。目视检查中英文入口、全部合约影响范围、单向／双向说明、实际邮箱／EOA登录弹窗及英文横屏，均无裁切或溢出；已恢复中文、竖屏和原字体设置。登录后配置和修改字段仅经受控Widget数据验证。
- 官方协议及来源SHA256见 `docs/reference/futures-position-mode-public-contract.json`，构建、测试与真机证据见 `docs/reference/futures-position-mode-verification.json`。真实授权EOA／Privy读取与修改、已登录真机数据以及iOS仍待验收；本轮未发送真实私有请求或金融操作，Linux无macOS／Xcode。
- 本轮完成独立账户持仓模式流程，实盘下单／快捷开仓表单尚未接入。单一／多资产模式、平仓／反手、逐仓保证金增减、TP/SL、子账户、资金和通知继续推进；私有BAPI历史统计／TWAP按用户要求跳过。

## 合约逐仓／全仓配置与切换

- 对应Futures PRD「3.1交易参数设置 → 保证金模式：逐仓／全仓」。仓位风险页提供当前交易对入口，每张仓位卡片可进入该symbol设置；没有持仓也可读取配置。Widget → Riverpod controller → 签名repository → Aster服务；配置、意图、结果及状态均为不可变对象，Widget不构造客户端。与本地演示保证金设置分开。
- 显式点击后先签名 `GET /fapi/v3/positionRisk?symbol=…`，再签名 `GET /fapi/v3/openOrders?symbol=…`。保留零数量配置行，严格要求BOTH或完整LONG／SHORT，双向两侧保证金模式一致。共用配置行验证已用于杠杆；读取`cross`／`isolated`明确映射到领域enum，提交分别为`CROSSED`／`ISOLATED`，不把字符串大小写混用。数量以Decimal验证，拒绝浮点、科学计数、非法方向和错配symbol。
- 已知存在任意非零持仓或有效挂单时显示具体阻塞原因并禁用检查修改，极小数量也不能误判为空仓。挂单复用既有严格mapper且额外检查symbol范围；配置或挂单失败不会制造“无持仓／无挂单”。不自动撤单、平仓、划转或切换资产／持仓模式。两次查询仍不是交易所原子锁，外部变化、资产模式及最终资格以Aster校验为准。
- 用户选不同于已读值的目标模式，弹窗固定钱包、交易对、原模式及目标模式，明确双向两侧共用及风险。确认后由当前已连接EOA或Privy钱包签名 `POST /fapi/v3/marginType`；body与签名字节完全一致，user／signer同地址，不创建钱包、agent或API key。随后另一次签名GET查询实际模式并标注UTC时间，HTTP确认和钱包审批不作为成功证据。返回不同模式按观测值展示；-4046已是此模式、-4047存在挂单、-4048存在持仓映射为安全具体原因与错误码，不展示原始报文。
- 提交后超时、失败或拒绝查询签名均不重发POST；结果未明时全局保留该未决操作，仅提供GET查询，其他symbol读取和新修改被拦截。已发出的请求不能靠关闭页面撤回，迟到结果仍由controller核对。身份／钱包／签名能力变化清除作用域并阻止后续签名和旧结果回写；旧操作结束不能释放新身份的操作锁。
- 新增杠杆与保证金模式共用的设置操作状态。两个页面跨symbol互斥，未决修改必须先查询核对；任一设置提交都会让两类旧确认过期。配置30秒有效期从第一份响应开始计时，包含等待第二次签名／读取的时间；本轮也修正杠杆相同计时边界，不能在第二次响应后重置有效期。新账户事件、设置修改、到期或身份变化使旧意图失效，发送边界再次检查有效性。
- 提交时将余额、仓位风险、ADL和挂单快照标为历史，保留原值，不根据模式查询结果改写仓位风险或伪造保证金／ROE；用户需显式重读。模式选择由页面保存，滚动重建、读取失败／刷新、提交失败及结果查询均保留，退出页面或切换身份清理。设置互斥提示说明回到对应设置页继续处理。
- 所有说明、选择、确认、进度和错误纳入中英文ARB；钱包及symbol可选择复制。选择表单按职责提取为特性内组件；窄屏、大字体、横屏、可滚动确认和失败／未知结果由Widget测试覆盖。官方文档SHA256、参数及边界见 `docs/reference/position-margin-mode-public-contract.json`，构建／测试／真机证据见 `docs/reference/position-margin-mode-verification.json`。
- 584项全量测试通过（新增5项mapper／领域、14项签名仓库、12项controller、6项跨设置互斥、8项Widget），272个Dart文件格式检查无改动，静态分析无问题，中英文各543条消息。Android arm64 Release（42.6 MB）构建并安装Android 12真机；目视检查中英文风险页入口、保证金模式说明、实际邮箱／EOA登录弹窗及英文横屏，无裁切或溢出。验证后恢复中文、竖屏及原字体设置。既有ADL回归补上标题滚动和布局等待，全部重新通过。
- 参考项目的`PositionLeverageContext`／`Hip3PositionIntents`采用明确模式、有效期和可修改限制；该项目自己的Hip3协议不能替代Aster文档。真实授权EOA／Privy模式切换、已登录真机配置和iOS尚待验收，本轮没有真实私有请求或金融操作；Linux无macOS／Xcode。
- 本轮完成独立逐仓／全仓设置流程，尚未接入实盘下单／快捷开仓表单。单一／多资产模式、单向／双向持仓、平仓／反手、保证金增减、TP/SL、子账户、资金和通知继续推进；私有BAPI历史统计／TWAP按用户要求跳过。

## 合约杠杆配置与修改

- 对应Futures PRD「3.1交易前配置 → 杠杆倍数」及Positions杠杆展示。仓位风险页提供当前交易对入口，仓位卡片提供对应symbol入口；无持仓也可进入。独立页面通过Riverpod controller → repository → Aster服务读取／修改，Widget不构造客户端。与本地演示杠杆分开，不把实盘配置套入演示仓位。
- 显式点击读取后分别签名查询官方推荐复数路径 `GET /fapi/v3/leverageBrackets?symbol=…` 和 `GET /fapi/v3/positionRisk?symbol=…`。不在打开页面时自动签名；有零数量的配置行仍读取，不能复用过滤掉零仓位的列表mapper。单向BOTH或完整LONG／SHORT配置需要一致，缺失、重复、混合模式和交易对错配拒绝。档位验证起点、连续区间、序号和非递增杠杆上限；名义金额以精确整数或Decimal字符串接收，不接受浮点。
- 输入仅接受不同于已读值的正整数，上限为官方修改范围125与已读档位最大initialLeverage的较小值。该上限是交易对范围，不承诺任意账户敞口都可使用；当前仓位、挂单敞口、余额和附加限制最终由Aster核验。不能用市场徽标、最大杠杆或本地演示默认值冒充当前杠杆。配置超过30秒、收到新账户事件或身份变化后，旧确认不能提交；钱包审批返回时再次检查配置有效期。
- 确认弹窗固定钱包、symbol、已读杠杆和目标倍数，明确按交易对生效，双向两侧共用配置。用户确认后由当前EOA或Privy钱包签名 `POST /fapi/v3/leverage`；body严格使用签名字节＋signature，用户／signer为同一个已连接地址，不创建钱包、agent或API key。提交后另一次签名GET核对当前配置，展示观测倍数和UTC查询时间；POST响应或钱包审批均不作为最终成功证据。
- 超时、断线、提交错误或核对签名被拒绝后不会重复POST。结果未知时跨页面保留未决状态，禁止新的修改和其他symbol配置读取，只提供签名GET查询；查询发现不同值也如实展示，不误报修改成功。提交前拒绝签名可刷新配置后重新审阅；提交后的异常仍保留未知结果。钱包／身份／签名能力改变会清除作用域，迟到结果丢弃且不再发核对签名。
- 提交时将账户余额、风险、ADL和挂单快照标为历史，保留原值；核对配置不拼造新的风险字段，也不把已核对的配置直接写入仓位；原仓位估算继续带历史提示，不自动额外签名刷新仓位。用户需显式读取仓位／余额核对实际保证金和风险。表单输入由页面持有，滚动重建、失败、配置刷新和结果查询保留输入，退出页面或切换身份清理。
- 所有文案、范围、进度和错误纳入中英文ARB。-2027仓位超限、-2028保证金不足、-4028杠杆不被接受分别显示具体安全原因与错误码；不展示原始响应或敏感载荷。地址、symbol可复制。英文360宽2倍字体、中文844×390横屏1.5倍字体覆盖输入、可滚动确认和查询结果。
- 539项全量测试通过（新增6项mapper／领域、11项签名仓库、10项controller、6项Widget测试），256个Dart文件格式检查无改动、静态分析无问题，中英文各519条消息。Android arm64 Release（42.6 MB）构建成功并安装Android 12真机，目视检查中英文杠杆入口、实际邮箱／EOA登录和英文横屏；已登录配置与修改仅用受控Widget数据验证。完整验收证据见下方记录。旧风险页测试补上读取按钮的滚动定位，适配新入口后重新通过。
- 参考项目 `positions_repository_impl.dart` 的上下文、确认意图和结果核对边界；该项目使用自己的Hip3交易后端，其签名协议不作为Aster依据。官方合同、文档SHA256及实现范围见 `docs/reference/position-leverage-public-contract.json`；最终验证见 `docs/reference/position-leverage-verification.json`。真实授权EOA／Privy修改和已登录真机字段仍待验收，没有发送真实私有请求或金融操作；Linux无macOS／Xcode，iOS尚未验证。
- 此页完成独立杠杆配置流程，尚未接入实盘下单表单／快捷开仓。保证金模式、持仓模式、平仓／反手、保证金增减、TP/SL、子账户、资金和通知等剩余PRD继续推进；私有BAPI历史统计／TWAP按用户要求跳过。

## 仓位保证金与收益率估算

- 对应原始Futures／Portfolio PRD的「Positions → Margin／Cross」及仓位估值。当前仓位风险卡片新增逐仓钱包分配余额／估算全仓仓位保证金、估算初始保证金基数和仓位ROE；与既有标记价、PnL及快照／事件时间共同展示。Widget观察公开Mark → 不可变PositionReturns领域计算 → 展示组件；不增加私有读取、钱包签名或任何金融写入。
- 重新检查官方V3仓位字段及PRD引用的官网 `useUMColumn-B49LSHPK.js`、`useJMColumn-CIFF_lYV.js` 和 `futuresCalculatePre-bCeRTqn1.js`。官网Margin在逐仓时取isolatedWallet，全仓取绝对Mark名义价值×初始保证金率；ROE在逐仓和全仓均以该初始保证金为分母，不使用额外加到逐仓钱包的资金作为分母。参考项目的生产mapper直接承载服务端收益率，review ledger为本地演示；没有将其演示公式当作Aster协议。
- 已知单位且marginAsset等于quoteAsset的线性仓位：`initialMargin = abs(quantity × markPrice) / leverage`，全仓展示此估算保证金，逐仓分配单独使用isolatedWallet；`ROE% = PnL × leverage / abs(quantity × markPrice) × 100`。PRD的29.48 ASTER×0.71901÷4为5.2991037 USDT。ROE与TP／SL输入中按入场价换算的ROI不是同一个基数，也不是Portfolio账户历史收益率、可用资金或强平价。
- 全程Decimal／精确有理数除法；ROE不除以已舍入保证金，最终百分比保留两位、半值远离零，不显示负零。有限除法保留全部数字；无限小数保证金按输入scale＋24位截取精度并舍入，确保极小名义价值不因固定8位精度变成0。官网先将1／leverage保留5位的中间舍入未照搬，使用精确倒数并在证据中记录差异。
- 快照时以同一仓位的Mark及PnL计算并标为快照估算；有合格公开Mark时，以该行情及当前显示的数量、entryPrice重算PnL和ROE，标为公开行情估算。沿用逐symbol行情过期、仓位过期及独立快照时间，行情不能清除账户完整性提示；早于新仓位事务时间的行情不能作为基准。平仓、仓位数量变更及失效逻辑沿用账户事件同步。
- 数量为0的逐仓负余额记录保留其钱包分配，但不计算ROE。杠杆未知／非正、Mark未知／非正、单位未知或非线性时不制造初始保证金和ROE；PnL或entryPrice缺失／无效时ROE显示—。账户事件不提供杠杆，沿用清除旧杠杆的规则，不能将前一仓位杠杆套给更新后的数量；完整签名刷新后可恢复估算。
- 计算说明纳入中英文目录并放在仓位风险页和卡片旁，明确保证金基数、逐仓分配、费用边界、历史状态及未知值。组件使用语义主题色和可换行ValueRow；英文360宽2倍字体及中文844×390横屏1.5倍字体通过Widget验证。
- 本轮506项全量测试通过（新增15项领域测试、6项Widget测试），245个Dart文件格式检查无改动、静态分析无问题，中英文各494条消息。Android arm64 Release（42.6 MB）已构建并安装Android 12真机，目视检查中英文公式、实际邮箱／EOA登录入口和英文横屏滚动。旧风险页测试改用有标签的债务行定位；既有Mark时效测试改为等待期望发布事件，消除固定1秒等待与周期定时器的竞争。构建与真机证据见 `docs/reference/position-returns-verification.json`；官方／官网源码SHA256、公式及精度差异见 `docs/reference/position-returns-public-contract.json`。本地受控测试不构成真实授权仓位验收；没有真实私有请求或金融操作。真实EOA／Privy联调与iOS构建仍待验收，Linux无macOS／Xcode。
- 后续仍需平仓／反手、杠杆及保证金模式修改、保证金增减、TP／SL、实盘下单、子账户、资金操作和通知列表等；私有BAPI历史统计／TWAP按用户要求跳过，本轮估算不替代这些功能。

## 合约余额与仓位事件同步

- 对应Futures PRD「Positions → 实时更新／异常状态」。在现有账户监听上接入 `ACCOUNT_UPDATE`：AsterUserStream → 严格数据映射 → AccountChangeController → AccountReadController／PositionRiskController → 不可变账户／风险模型与卡片。复用既有当前EOA或Privy钱包和私有连接，不创建钱包、agent或API密钥，不引入BAPI或自动签名请求。
- 事件是部分更新，以asset更新余额，以symbol＋positionSide更新仓位。`wb`／`cw`是绝对钱包／全仓钱包余额，不把`bc`增量、`cr`累计已实现盈亏当作余额或到账证明。资金费事件可只含B、不含P；省略记录保持原值，不据此判断其他仓位关闭。只有明确数量为0的对应仓位移出；数量为0但逐仓钱包余额为负的异常记录保留。单向与双向分侧处理，冲突的活动模式停止监听并要求核对。
- 数据边界要求字符串Decimal、合法资产／合约标识、持仓方向、保证金模式和有效E／T，拒绝数值浮点、科学计数、符号冲突、负开仓价、重复资产／仓位及畸形字段。未知事件原因可携带合法记录，不推断其资金流业务含义；同一条事件的数据全量验证后才发布。
- 每个钱包作用域分别维护余额与仓位事件版本：E逐记录排序，T与REST每记录updateTime比较，不使用本地接收时间排序。旧事件或回退T不覆盖新值；同E／T同值忽略，同E／T不同值停止监听并标为需核对。同一T但更晚E可更新已应用的事件记录；与REST同T时以REST为准。零仓位的版本仍保留，防止迟到事件恢复旧仓位，同时允许更新的真实开仓事件。
- 显式完整签名读取仍是显示账户的前提。没有基准时事件只缓存，不制造“空账户”；完整读取期间的事件在REST返回后合并。读取开始前的旧事件不能补回新完整快照中缺失的记录；已有记录若REST时间未知，则保留已知事件并继续提示核对。已返回REST时间更新或相同的记录优先；所有零／隐藏REST记录的服务端时间也保留，避免丢失关闭依据。进度回调／读取失败继续显示已合并事件的值，不退回开始读取时的旧值。
- 已更新资产不沿用未提供的可用余额、资产PnL及抵押资格；已更新仓位不沿用未提供的杠杆、初始保证金、标记价、强平价、名义价值或逐仓保证金。账户汇总在应用事件后显示—，需重新签名核对，不按部分记录猜算。风险模型允许这些字段未知；事件PnL与快照PnL采用不同标签，每记录与列表显示独立的UTC事件时间，快照接收时间保持原值。未变化记录及ADL继续有历史提示。
- 公开Mark估值使用当前显示的数量与开仓均价；事件更新后不会套用早于仓位T的旧Mark。满足时间条件的新行情可给出估算，仍不清除账户过期／完整性提示。相同交易对的数量事件复用已有公开行情连接，只有交易对集合或钱包范围变化才重建，避免频繁更新导致重复订阅。
- 即使空仓，签名读取也加载完整公开合约单位供首个新仓位事件使用；公共配置失败仍保留私有读取结果并明确单位未知，不切割symbol猜测单位。单作用域每个事件簿最多10000个资产／仓位键，超限不驱逐零仓位保护记录，停止监听并提示退出重连后重新读取。断线、后台、到期和手动停止保留历史记录；恢复不自动补签或重放金融写入，缺口仍需用户显式完整读取。
- 格式检查241个Dart文件无改动、静态分析无问题，485项全量测试通过（新增51项），中英文各488条消息；Android arm64 Release（42.6 MB）构建成功并安装Android 12真机。中英文仓位说明、展开监听、真实登录入口和英文横屏已目视检查；最后REST负余额保留修正未改动UI，重建后的最终包已再次安装并验证中文启动。验证结果、两次APK校验及实机截图见 `docs/reference/account-events-verification.json`；官方文档SHA256、字段及PRD依据见 `docs/reference/account-events-public-contract.json`。真实EOA／Privy授权监听及已登录真机字段尚未验收；自动化仅用本地WebSocket与受控仓库，没有真实私有请求或金融操作。Linux无macOS／Xcode，iOS构建仍未验证。
- 后续仍需缺口完整恢复、跨仓初始保证金及ROI、平仓／反手、保证金和TP/SL、实盘下单、子账户、资金操作和通知列表等PRD功能。私有BAPI统计／TWAP按用户要求跳过；本轮事件合并不代表这些功能已完成。

## 合约挂单事件同步

- 在现有签名快照与账户监听上接入官方 `ORDER_TRADE_UPDATE`。链路为私有WebSocket → 数据边界严格映射 → 监听controller → OpenOrdersReadController／OpenOrdersEventBook → 挂单卡片。挂单区新增监听入口，可打开与Portfolio／仓位风险页共用的监听控制；不会额外建立第二份私有连接，也不自动签名。
- 逐 `symbol + orderId` 更新全部合约订单源；当前交易对筛选和计数仍作用于同一数据。NEW新增，PARTIALLY_FILLED保留并按Decimal计算剩余量；FILLED／CANCELED／EXPIRED／REJECTED从挂单移出。累计成交量不允许倒退；E按订单排序，o.T用于与REST updateTime比较，乱序、重复和更旧事件不能覆盖新状态。已观察终态或被签名查询确认关闭的订单保留结束标记，阻止迟到NEW及陈旧REST把它恢复。
- 订单事件映射严格要求文档里的字符串Decimal、非负数量／价格、合法精确ID、方向／持仓方向、状态及事件／交易时间。零原数量的Close-All终态允许实际成交数量；不把成交量与原数量缺失混淆。条件类型、原类型ot、止盈止损、激活价／回调率、价格依据、reduceOnly和closePosition分别处理；追踪单忽略sp。缺失可选字段时保留已有REST元数据，尤其BBO标记；新交易对单位从已加载完整合约配置关联，缺少配置则显示单位待确认，不切割symbol猜测。
- PRD明确不能用updateTime替换下单time。REST下单时间继续保留；用户流没有可靠下单时间，新事件新增订单显示「未知 · 请读取订单核对」，单独显示UTC订单更新时间。排序可使用更新时间作未知创建记录的稳定排序依据，不将它展示为下单时间。快照收到时间和最近已应用订单事件时间分开显示。
- 用户流不构成完整列表证明。未做过完整签名读取时只缓存事件，不能制造一个“空账户”；首次读取期间收到的事件在结果返回后合并。读取前已经收到、但完整快照不含的旧活动事件不会再次添加；快照内同一订单若REST updateTime更新，则以REST为准。新签名读取若仍被较新事件／结束标记修正，继续标记需核对；接通监听不清除历史／缺口提示。
- 读取期间显示最新已应用事件，进度回调和读取失败不会退回开始时的旧列表。较晚返回的完整REST会重放本次读取期间事件；每条事件仍使余额、仓位、ADL及挂单完整性失效。断线、后台、到期和手动停止保留历史值，需要显式钱包刷新核对；不自动发起额外签名读取、重放撤单或下单。
- 单笔／批量撤单核对同样记录开始时的事件版本，结果合并后再叠加期间事件。终态不会被较早的查询恢复；批量操作期间新出现的订单会保留，不在本机重放DELETE。查询期间收到同一订单／交易对的新事件时，结果区改为「查询可能反映较早状态，请检查更新列表」，避免声称较早查询就是当前状态。查询未确认仍保持GET-only重查门禁；较旧的确认在对应订单已被更新后不能再提交。
- 单一钱包作用域内最多保存10000个订单键的事件／结束记录；达到上限关闭监听并提示退出重连后重新读取，不驱逐结束标记来腾空间。未知状态、清算专用NEW_INSURANCE／NEW_ADL或畸形事件会安全断开并标记需核对，不擅自归为活动或终态。它们的专用通知／清算展示仍待后续实现。
- 本轮格式检查、静态分析和434项全量测试通过（新增31项），中英文各481条消息；Android arm64 Release（42.5 MB）已安装Android 12真机，检查中英文入口、默认展开的监听面板、真实登录入口及横屏；最后面板展开调整后另通过9项相关Widget测试。协议证据见 `docs/reference/open-orders-events-public-contract.json`，本轮验收及真机截图见 `docs/reference/open-orders-events-verification.json`。自动化使用本地WebSocket与受控仓库，没有真实私有请求、撤单或资金操作。真实EOA／Privy授权监听、已登录真机订单更新及iOS仍待验收。
- 仓位数量／余额事件合并已由前节增量接入；后续仍需账户缺口完整恢复，以及ROI、保证金、TP/SL、实盘下单和剩余PRD功能。私有BAPI统计／TWAP按用户要求跳过；订单事件同步不代表这些功能已完成。

## 合约账户变更监听

- 入口：Portfolio → Aster → Futures 的「合约变更监听」，仓位风险页也提供同一监听状态。监听由用户明确开启，并持续到手动停止、授权到期或账户作用域变化；普通页面导航不会重复创建连接。
- 官方 V3 文档确认 USER_STREAM 需要 signer 和 signature；POST `/fapi/v3/listenKey` 创建或返回已有账户密钥并续期60分钟。使用当前已连接 EOA／已有内嵌钱包作为 user 和 signer，沿用共享 nonce 和链1666 EIP-712精确字节签名；不创建新钱包、agent或API密钥。POST参数放入 form body，GET签名和现有撤单传输不受影响。真实EOA签名是否被Aster接受仍需真实授权账户验收。
- 密钥仅在repository内存保存，绝不显示、记录或持久化。私有WebSocket使用 `wss://fstream.asterdex.com/ws/<listenKey>`，不发送公开SUBSCRIBE消息。不采用公开行情35秒无消息超时，静默账户可以保持连接。停止、账户切换／断签、到期及容器释放关闭本机连接并清空本机密钥；不会DELETE账户复用密钥，从而避免影响该账户的其他客户端。
- 此节为最初的变更提示／快照失效实现；后续订单、余额与仓位数量事件合并见前两节。原实现中ACCOUNT_UPDATE、ORDER_TRADE_UPDATE、ACCOUNT_CONFIG_UPDATE、MARGIN_CALL及未知合法事件均保守标记合约账户、挂单、仓位风险及ADL快照为历史数据，保留数值和原快照时间。资金费事件可能只有一个余额、没有任何仓位，不能覆盖完整列表或将旧强平价当作当前值。不更新Spot、不自动签名刷新REST、不推算强平价，也不根据订单事件声称撤单／成交已确认。
- 新建连接、断线、后台暂停／恢复和手动停止同样失效相关快照；接通监听不会让旧快照恢复为当前值。每条事件都失效正在读取的快照，即使E相同或比前一条更早；最近事件时间仅取最大值用于显示，不能作为账户完整性的证明。畸形帧会安全断开并要求重连，不将原始响应／私有URL暴露为错误。
- 每次开启或续期由用户签名一次。约50分钟后提醒手动续期，保守本机截止时间从签名前开始计算，最长60分钟；服务端listenKeyExpired事件也立即停止。断线提供「无需签名重新连接」，只复用有效内存密钥；前台恢复可用同一有效密钥重新连接并保留历史提示。后台期间释放WebSocket，外部钱包签名回跳不会自行作废仍在等待的授权；授权在后台返回时暂不连接。不会自动签名续期、重放订单或提交资金操作。
- 格式检查221个Dart文件无改动，静态分析无问题，完整403项测试通过（新增26项），中英文各475条消息。Android arm64 Release（42.4 MB）已安装Android12真机，检查中英文展开区、登录入口和横屏；恢复中文、竖屏及1.0字体。
- 本轮验证结果及环境边界见 `docs/reference/account-change-verification.json`；官方合同核对见 `account-change-public-contract.json`。真实授权监听和已登录真机数值尚未验收；自动化使用本地WebSocket服务器和受控repository，无真实私有请求。iOS仍需macOS／Xcode。
- 挂单已增加经过校验的订单事件合并（见上节）；后续仍需完整账户事件、仓位数量更新和缺口恢复；监听在线不等于已经实现这些能力。私有BAPI统计／TWAP继续按用户要求跳过。

## 仓位公开标记价与估值

- 对应 Futures PRD「Positions → Mark price／Size／未实现盈亏」。仓位风险页在读取非零真实仓位快照后，通过 `positionMarkPricesProvider → MarkPricesRepository → AsterService` 接收公开 `!markPrice@arr@1s`，启动／重连同时 GET `/fapi/v3/premiumIndex` 补齐公开标记价。此链路不签名、不创建钱包、没有交易写入；筛选或切换图表交易对不改变仓位行情范围。无需依赖可交易市场目录，已下架但仍持仓的合约仍可关联行情。零数量逐仓负余额不启动该合约估值。
- 标记价严格读取流字段p、REST字段markPrice，使用Decimal和服务端事件时间；不使用最新成交价c、图表double或资金费率代替。带方向名义价值为 `signed positionAmt × mark`，未实现盈亏估算为 `signed positionAmt × (mark − entryPrice)`，仅对已确认quoteAsset＝marginAsset的线性合约及非零仓位计算；开仓价非正、单位缺失或非线性时保持未知。不包含手续费／资金费用，不表示最终成交收益。
- 卡片优先显示新收到的公开标记价及事件时间（UTC），并单独标注估算名义价值和估算浮盈亏；签名快照原有notional／unRealizedProfit仍以“快照”字段保留，不能被公开行情改写。新签名快照优先于其接收时间之前的旧公开行情。强平价、逐仓余额、杠杆和数量继续来自签名快照，绝不随Mark流推算强平价或伪装成账户事件已更新。
- 新鲜度逐交易对独立计算：连接当前会话、数据有效，接收时间及基于行情服务校准时钟的事件年龄均小于10秒，且不是超过容差的未来事件。乱序、重复、重放及异常未来时间不会覆盖可用价格，也不会延长其接收时间。单交易对畸形事件保留旧值并取消其新鲜状态，不影响其他交易对。250ms合并更新，1秒检查静默过期；旧HTTP响应不能覆盖请求期间的新流价格。REST失败可由有效流恢复；流全部恢复时不继续展示误导的REST失败提示。
- 页面显示新鲜行情覆盖数、部分不可用提示和公开行情重试按钮。无有效行情时展示签名快照标记价；断线保留上次公开价格并标为历史行情。行情或仓位任一过期，估值显示“历史估值”，新行情不能解除仓位过期状态。仓位30秒有效期仍保留，用户需手动签名刷新仓位。公开重连不发起私有读取或签名。
- 仅风险页消费者持有此公开流。退出页面、注销／换钱包或仓位范围变化释放旧订阅／定时器，迟到REST不可进入新作用域；后台暂停、恢复前台重开，旧会话数据不能仅因socket重连就恢复为新鲜。行组件按当前symbol观察行情，避免无关交易对更新重建地址、筛选或签名控件。
- 格式检查211个Dart文件无改动，静态分析无问题，完整377项测试通过（新增24项），中英文各460条消息。覆盖精度／单位、单向／双向有符号估值、过期／重放、畸形／部分失败、REST与流竞态、后台／注销／自动释放、快照优先级、过期仓位不能变实时、公开流恢复提示，以及360宽英文2倍字体及844×390中文1.5倍字体的长小数布局。此前测试中的虚拟时钟关闭等待已修正，最终套件全部结束，无悬挂测试进程。
- 匿名实测官方公开通路：BTCUSDT、ETHUSDT、SOLUSDT在首次订阅及后台暂停后恢复阶段，分别至少收到3个不同事件时间的有效标记价；暂停阶段新鲜集合为空。实测使用真实公开service／repository，无钱包、无假持仓、无私有请求。当前API依据与原始公开观察记录见 `docs/reference/position-mark-public-contract.json`、`position-mark-public-live.json`。这只证明公开行情通路，不证明已完成真实授权仓位读取。
- Android arm64 Release构建成功（42.4 MB）并安装Android 12真机；确认中文、英文估值说明、登录入口及横屏滚动，随后恢复原中文、竖屏及字体设置。没有在真机注入假登录／假仓位；登录后的估值卡片目前仅经受控Widget测试。APK校验及截图见 `docs/reference/position-mark-verification.json` 与 `position-mark-*-android.png`。Linux无Xcode，iOS构建仍未验证。
- 本节初次实现之后，鉴权账户用户流／仓位数量同步已由前节增量接入；总体PRD仍待跨仓初始保证金及ROI、平仓／反手、保证金修改和TP/SL；私有BAPI统计／TWAP按用户要求跳过。公开Mark估值不能替代鉴权仓位事件。

## Aster 合约挂单与逐笔撤单

- 对应 PRD「Futures trading → 4、订单列表 → Open Orders」。交易页底部的 Aster 挂单与上方演示订单分开，手动签名 GET `/fapi/v3/openOrders`，以 `symbol + orderId` 去重，支持当前交易对过滤；计数随过滤结果变化。数量、剩余量与普通限价单名义金额使用 Decimal；条件单分别展示触发价类型、追踪激活价／回调比例，BBO／市价不伪造零价格。合约单位来自 exchangeInfo；缺失时显示待确认，订单标识可选择复制。
- 逐笔撤单遵循 `Widget → OrderCancellationController → SignedOrderCancellationRepository → AsterAccountService / IdentityRepository`。确认弹窗显示当前钱包、合约和订单编号，说明仅撤销未成交部分及两次签名：DELETE `/fapi/v3/order` 提交 `symbol + orderId`，再 GET 同一订单核对状态。继续使用已选中的 EOA／已有内嵌钱包，不创建钱包或 agent；与账户读取共用 nonce 分配器，严格复用实际发送的编码字节。
- DELETE 成功回执不直接移除订单。查询确认 CANCELED／FILLED／EXPIRED／REJECTED 后移除；FILLED 显示已成交，不能显示撤单成功。NEW／PARTIALLY_FILLED 保留并更新已成交数量。核对失败保留旧订单、标记历史数据、阻止重复撤单，仅提供签名 GET 核对状态；不自动重放 DELETE。确认后账户退出／重连、地址或签名可用性变化会作废确认并丢弃迟到结果。较早的挂单刷新也不能覆盖已核对结果。
- 操作期间禁用重复点击和挂单刷新。撤单后挂单整体与账户余额／仓位标记需刷新，保留原快照时间；不会自动弹出额外钱包签名刷新余额。网络、拒签、协议权限和 `-5050` 充值前置条件采用安全本地化提示。签名 URL／原始响应不进入 UI、日志或持久化。
- 本轮完整 243 项测试通过，其中新增 21 项验证准确 DELETE／GET 方法与参数、相同 EOA、nonce 去重、字节一致、超时不重发、成交竞争、拒签、错误订单标识、不完整结果、旧确认失效、迟到刷新，以及 360 宽英文／1.5 倍字体和 844×390 中文横屏确认／未知结果布局。自动测试全部使用可控 fixture；尚未发送真实撤单请求，真实 Aster 授权、查询及撤单仍需测试钱包验收。
- 尚待实现：订单实时用户流、订单 Explorer 的可靠 hash 来源、其他实盘管理操作。Cancel all 的后续实现见下一节。接口依据：[Aster V3 Query Order / Cancel Order](https://github.com/asterdex/api-docs/blob/master/V3%28Recommended%29/EN/aster-finance-futures-api-v3.md#cancel-order-trade)。
- 最终格式检查 155 个 Dart 文件无改动，静态分析无问题，243 项测试通过；Android arm64 Release 构建成功（42.0 MB），已安装 Android 12 真机并目视确认本地演示标题与实盘挂单入口分离、未登录入口及登录说明。证据 `docs/reference/order-cancellation-signed-out-android.png`、`order-cancellation-login-android.png` 和 `order-cancellation-verification.json`。签入后的撤单弹窗／结果布局仅经 Widget 验证；没有在真机注入假资产或提交真实撤单。Linux 环境未验证 iOS 构建，仍需 macOS／Xcode。

## 全部撤单

- 对应同一 PRD 的 Cancel all。挂单区域始终显示入口，未读取真实挂单或没有适用订单时禁用；可作用于快照中的全部合约交易对，或当前交易对筛选范围。确认弹窗显示可复制的钱包地址、精确交易对清单和快照订单数，明确不包含 Spot、清单外交易对或已成交持仓。
- 官方 DELETE `/fapi/v3/allOpenOrders` 必须指定 symbol，因此冻结确认时去重排序的交易对清单，逐个提交并 GET `/fapi/v3/openOrders?symbol=…` 核对。每个交易对都需要撤单和查询签名，user／signer 使用当前 EOA 或已有内嵌钱包，不新建钱包。取消范围为 Aster 处理时该交易对的全部挂单，包括其他设备新添的同交易对挂单；后续出现的其他交易对不扩入范围。依据：[Aster V3 Cancel All Open Orders](https://github.com/asterdex/api-docs/blob/master/V3%28Recommended%29/EN/aster-finance-futures-api-v3.md#cancel-all-open-orders-trade)。
- 回执不代表最终结果。逐项显示“最后核对时无挂单”、剩余挂单数量、结果未确认或未提交；空查询可能包含先成交的订单，不能称为全数撤单成功。核对的快照只替换对应 symbol，保留其他交易对，数量和单位沿用 Decimal 模型。整体列表仍标记需刷新、保留原整体快照时间，不把不同核对时刻拼接为完整新快照。
- 拒签或结果不明立即停止后续 DELETE。超时及查询失败保留挂单，提供 GET-only 重查，绝不重发 DELETE，也不在重查后自动恢复未提交的交易对。新撤单必须重新确认。“停止后续提交”让当前交易对完成核对，剩余项保留为未提交。逐笔／批量撤单共用操作锁和确认版本；切换账户／退出后确认失效、迟到结果丢弃，较旧的读取也不能恢复已核对移除的挂单。
- 自动验收：完整 271 项单元／Widget 测试通过，较逐笔撤单轮新增 28 项。覆盖准确签名字节和唯一 nonce、每 symbol 顺序与范围、剩余／新挂单、超时、两次拒签、异常载荷、身份变更、单笔／批量互斥、旧刷新竞态、本地停止、仅查询重查及不恢复队列。界面覆盖未登录／未读取禁用、范围确认、当前交易对、未知结果保留，以及 360 宽英文／2 倍文字和 844×390 中文横屏／1.5 倍文字；切语言保留结果。
- 最终格式检查 163 个 Dart 文件无改动，`flutter analyze --no-pub` 无问题；Android arm64 Release 构建成功（42.0 MB），已安装 Android 12 真机，目视确认未登录全部撤单禁用、先读取说明、演示／实盘分离及读取入口打开登录页。截图 `docs/reference/batch-cancellation-signed-out-android.png`、`batch-cancellation-login-android.png`；APK 校验及验证边界见 `batch-cancellation-verification.json`。未注入假身份或资产，也未发送真实金融请求；真实授权、读取和撤单尚待测试钱包验收。签入后的结果与操作布局仅经受控 Widget 测试，iOS 因 Linux 环境未编译。

## 用户确认的暂跳范围

- 2026-11-02 用户回复「暂无，跳过」：目前没有可供移动端使用的 Aster BAPI 鉴权后端，暂跳过依赖该登录态的 Portfolio 历史统计、TWAP 等功能。原始需求继续保存在 [PRD 进度](prd-progress.md)，不将 Privy token 当作 Aster 官网凭据；公开行情及官方 V3 钱包签名接口继续推进。

## 交易对选择器

- 选择器在全部 USDT 永续与自选之间切换；搜索先去首尾空格并忽略英文大小写，按 symbol、基础资产、交易所名称和别名匹配，完全匹配 symbol／基础资产的结果优先，其余保持初始列表顺序。分类、自选与搜索取交集。选中交易对沿用当前图表、盘口和订单表单联动，并清空旧限价价格。无匹配项、空自选和空分类分别显示空态，并显示筛选数量／总数。
- 每行使用 Aster V3 ticker 初始化最新成交价、24 小时涨跌百分比、报价币成交额，以及 `premiumIndex.lastFundingRate × 100` 的当前资金费率。金额按 USDT 展示；不把基础币成交量当作报价成交额。字段缺失或无效时显示 `—`；真实零值显示为零，不用零掩盖缺失数据。
- 自选保存在 Riverpod 当前应用会话状态中；尚未接入账户自选持久层，不声明跨重启、跨设备或账户间同步。切换登录身份不会将自选写入远端。收藏过滤按完整候选目录执行；已下架或不满足 USDT 永续条件的交易对不会出现在本列表。
- 本轮实际 V3 `exchangeInfo` 已包含 `name`、`tags`、`underlyingSubType`，直接使用该既有接口，不增加官网扩展接口。名称来自 name、搜索别名来自 tags；分类只使用 underlyingSubType 的精确值，支持 Top、USD1-RWA、Meme、AI、pre-launch、STOCK、ETF、Commodities、Semiconductor。可选标签异常时忽略标签，保留合法合约；过滤控制字符、超长值、重复值和非字符串，并限制标签数量。不从名称、别名或 onboardDate 推断分类。
- New 分类未实现：PRD 尚未定义上线时间窗口或明确标签，不能自行选择 7／30 天；运营 sequenceNo 默认排序也未接入。OI 单位／美元换算与最大杠杆徽标来源仍待确认，不展示未确认值。USD1-RWA 在本轮目录无匹配项，按真实空分类显示。
- 首轮验收（当时上限 100 个，现已移除）：Widget 测试验证合约搜索与选择、四项公开行情字段、自选添加／移除、空自选状态和原行情数据身份联动。新增 360／1.5 倍字体、390／2 倍字体及 844×390 横屏／1.5 倍字体的搜索、清除和无结果回归测试；同时修复盘口买卖比例在大字体下的行溢出。

## 全量合约与分类验收

- 选择逻辑遵循 `MarketSheet → selectedMarketsProvider / MarketSelectionController → liveMarketQuotesProvider → MarketQuotesRepository → AsterService`；搜索输入控制器仅保留在展示组件中。列表按需构建行，报价流仍只有 ticker／markPrice 两路；没有增加 K 线预加载或逐币 HTTP 请求。
- HTTP JSON 按 UTF-8 解码字节，不依赖响应 Content-Type 提供 charset，保留中文名称、别名和 symbol；账户只读模型也允许合法 Unicode 字母／数字标识，仍拒绝控制字符。
- 匿名真实接口记录 `docs/reference/market-catalog-live.json`：567 个合约，Top 16、Meme 55、AI 39、STOCK 105、ETF 14、Commodities 9、Semiconductor 23、pre-launch 4、USD1-RWA 0。分类可能重叠，数量仅为验收时快照，不硬编码在应用。中文别名「股票」能检索到原 100 个上限以外的 TQQQUSDT；repository 进入 connecting → partial → live，567 个合约及分类元数据完整保留。
- 自动验收：完整 184 项单元／Widget 测试通过，格式化检查 118 个文件无变更，`flutter analyze --no-pub` 无问题。覆盖超过 100 个合约、Decimal 初始排序、分类／自选／搜索组合、精确匹配优先、中文别名、Unicode 标识、畸形标签容错和报价更新后元数据保留；原窄屏／横屏／放大文字回归继续通过。
- Android arm64 Release 构建成功（41.9 MB），已安装 Android 12 真机。目视确认 567／567 全部目录、16／567 热门分类、0／567 RWA 空态、TQQQ 搜索 1／567、选中后 TQQQ 图表和盘口／订单数量单位联动。截图 `docs/reference/market-categories-{all,top,empty,search,selected,book}-android.png`，汇总 `market-categories-android.json`。该验证仅使用公共行情，不执行实盘订单或资金操作。Linux 无法编译 iOS，仍需 macOS／Xcode 验收。

## 选择器实时报价

- 选择器和行情列表作为独立报价消费者，`MarketSheet → liveMarketQuotesProvider → MarketQuotesRepository → AsterService`。首次保留元数据快照，随后用一个 WebSocket 订阅 `!ticker@arr` 和 `!markPrice@arr@1s` 两个频道；每次连接／重连通过全市场 ticker 与 premiumIndex 各一次 HTTP 快照补齐。不开启其他币种或周期的 K 线加载，不逐币轮询报价。
- 支持 raw array 和 combined envelope array，逐条按 symbol 合并发生变化的合约；成交价／24h 涨跌／quoteVolume 来自 ticker，资金费率来自 markPriceUpdate.r，不用标记价覆盖最新成交价。仅更新已加载候选目录中的合约，保持列表顺序、名称／分类元数据、搜索和自选。Domain 数值使用 Decimal，资金费率原值在展示时乘 100。
- ticker 与 funding 按各自 symbol／事件时间防止乱序回退；快照请求开始后若收到对应分组的流事件，迟到 HTTP 不得覆盖该组。无效或负的无符号数值保留最近有效值并提示部分数据异常；缺失不变成零。列表通知每 250ms 合并一次，快照及连接状态变化立即通知。
- 状态区区分连接中、实时、部分恢复与离线，显示本机收到有效报价／快照的日期和时间，不将其称作交易所成交时间。两类流分别在 35 秒没有有效消息后失去实时状态；10 秒检查一次。断线保留可用数值，手动重连保留当前 repository 和最近报价。HTTP 失败显示安全原因并可重试。
- 最后一个列表消费者关闭后 autoDispose 释放 socket、重试和定时任务；后台暂停，回前台重新订阅和拉快照。生命周期 epoch 丢弃旧订阅、后台前请求和销毁后的迟到工作。连接本身继续沿用 AsterMarketStream 的退避与 35 秒空闲检查。
- 公开接口只读实测记录 `docs/reference/market-quotes-live.json`：15 次状态通知、100 个候选合约，观察到 connecting → partial → live，BTC 最新价从 78294.7 更新为 78311.1，24h 涨跌和报价成交额同步变化。该历史记录来自当时 repository 的匿名真实网络请求，无账户订单或资金操作。

- 本轮验收：完整 113 项测试、格式化和静态分析通过，Android arm64 Release 构建成功（35.4 MB），已安装 Android 12 真机。两次原生截图显示“实时报价”及更新的日期时间，BTC 最新价从 78,359.60 变化为 78,372.20，成交额与 ETH／SOL 报价也持续变化；截图 `docs/reference/market-quotes-live-android.png`、`market-quotes-updated-android.png`。断线状态、保留数值与重连由受控测试验证，未宣称真机断网验收。iOS 因 Linux 环境未构建。

## 同步与补齐

1. 当前图表发起一条K线订阅后立即请求自身200根历史，不等待WebSocket握手或2秒兜底。不为其他币种或周期发起预热请求；加载详情显示当前图表0/1或1/1。
2. 缓存主键为 `aster-usdt + symbol + interval + openTime`，与旧数据源隔离。WS 直接进入缓冲缓存，REST 合并不能覆盖请求期间收到的更新。相同开始时间覆盖，不追加重复蜡烛。
3. 用 E 判断 WS 事件新旧，用 x 判断是否收盘。已收盘数据不被未收盘覆盖；REST 校正保留 WS 事件水位，防止迟到旧消息重新覆盖。
4. 发现间隔缺口时，从前一根已有蜡烛开始请求，包含该根以校正边界。每页最多 1,000 根，持续分页，按时间排序去重合并。补齐期间 WS 不停订阅；无法补到时显示断档/失败原因，每 15 秒重试，不合成价格。
5. 重连时只重新查询当前图表最后几根并补到当前；每分钟再次校正其收盘边界，并以symbol参数刷新当前币种24h ticker和资金费率。App返回前台主动重连并重新同步，不唤醒其他缓存图表。
6. 快速切换期间共用至多5个并发历史请求，单个图表的历史与回补串行执行；旧图表已排队但未发出的请求取消。已发出的请求允许完成并进入对应缓存，切走后不继续分页或重试。当前图表恢复后按需重取最后边界及缺口。保留本地1,000 weight/min预算及429/418退避；自动同步的近期序列至多600根，主动浏览的更早历史另存于当前会话缓存，会话结束释放，长断线回补仍分页执行。

## 图表功能扩展验收

- 用户要求扩展周期、图表类型、指标参数、价格坐标和历史浏览。参考站桌面图表类型菜单实际开放Bars、Candles、Hollow candles、Line、Area、Baseline六种，截图 `docs/reference/reference-chart-types.png`；本应用覆盖这六种，并增加标记折线、阶梯线、柱形、高低线、平均K线，共11种时间图表。使用原生k_chart_plus，不引入WebView或TradingView网页。
- Aster文档列出15个原生周期，逐一请求BTCUSDT、limit=2均返回200及有效蜡烛，记录 `docs/reference/aster-chart-intervals.json`。周线按UTC周一，月线按真实日历月；缺口、分页和闭合计算不把月份当30天，也不自行聚合价格。日线／周线／月线自动使用日期轴。
- 价格坐标支持普通、对数、百分比、基准100。对数变换只作用于主图坐标，副图指标保留自己的单位；百分比／基准100以首根可见蜡烛开盘为基准，并在界面说明。报价、订单输入及详情始终使用原始Aster OHLC。平均K线只派生显示实体，有明确说明，当前价线仍是原始行情；不会把派生价写入domain或交易状态。当前仍自动缩放到可见数据，未新增手动纵轴拖动。
- 指标面板展开“指标参数”可编辑MA四周期、BOLL周期及小数标准差倍数、MACD快慢信号周期、KDJ周期及K/D平滑周期、RSI/WR/CCI周期。周期范围1–200整数、标准差倍数0.1–10；MACD快线必须小于慢线。错误保留输入，恢复默认先更新表单，应用后更新共享图表设置。参数仅在应用会话内保留；全屏共用设置。修复包内硬编码周期及标签，BOLL从首个完整周期计算总体标准差。
- 向左拖动或惯性到最早边界才加载前200根，endTime为当前最早openTime减1，不预取下一页。加载时保留可见图表并去重并发意图；前插后以时间锚点保持位置，历史加载失败不影响当前报价，空响应才标记无更早历史。按用户反馈去掉常驻“更早历史”按钮；正常只保留坐标选择，加载中／到底显示状态，失败可重试。用户浏览的历史在会话内保留，未加固定600根浏览上限。
- 新增13项测试覆盖15周期UTC边界、闰年月线缺口／分页、历史连续4页超过600根及到底、重复意图与失败重试、迟到响应隔离、对数等距与百分比单位、平均K线原始价格隔离、参数不可变与校验、BOLL/RSI/WR算例、全部图形及坐标渲染、参数表单及真实拖动加载后的视角保持。完整73项测试、格式化检查、flutter analyze无问题及Android arm64 Release构建（30.8MB）通过；移除历史按钮后相关16项Widget测试及分析／构建也通过。
- Android12真机已安装正式Release，目视确认取消历史按钮后的默认图表、11种图形菜单、带标记折线及对数坐标与BOLL叠加；截图 `docs/reference/chart-features-android.png`、`chart-types-android.png`、`chart-log-android.png`。月线／周线分页由真实接口探测与自动测试验证，未宣称逐项真机交互完成。坐标说明、平均K线说明及历史重试放在图表下方，避免遮挡指标；此最后布局调整通过相同16项Widget测试、静态分析和Android Release构建。当前Linux不支持iOS编译，需macOS／Xcode验收。
7. 实时更新每250ms合并一次，当前图表的首次历史响应立即通知UI，不等额外边界请求；初始快照没有真实缺口时不重复查询边界。当前图表失败保留可用缓存和安全原因，切换新图表可独立加载。图表底部保留数据源、连接指示点与详情入口，正常连接时不显示“形成中／已收盘”或重复的实时标签，断线时仍显示重连提示；详情可查看加载进度、修复数和K线状态。
8. 缓存图表通过同步读取避免StreamProvider重建时转圈；Market包含interval，当前报价同时校验币种和周期。未缓存周期加载时只保留淡化、有明确旧→新周期标签的视觉快照，不参与报价或交易。恢复的缓存在重新连接和REST校准完成前保留历史／离线标记，校准失败保留蜡烛及安全错误原因。行情流直接订阅并在取消时释放订阅。

### 周期切换加载过渡

- 参考站Android Chrome实测切换期间保留淡化图表，并在图表顶部显示三个小点。本次暂时延后其历史回调以观察加载状态，恢复后未保留修改；该观察不用于测量接口速度。
- 本应用切换到未缓存周期时保留同币种上一张图表及其缩放／滚动视角，透明度降至35%，图表中央显示三个6px加载点，下方显示例如 `1m → 5m` 的周期提示。新周期响应到达即替换；已访问缓存直接绘图。首次加载或换币种时显示网格和加载点，没有图表中央转圈。
- 旧图只存于CandleChart的视觉状态，等待期间不可交互且不参与无障碍读数；OHLC及当前行情provider不使用旧周期数据。切换币种立即清除旧图，避免其他币种价格出现在新币种下。底栏等待时不显示实时绿点。请求失败显示安全原因和重新连接入口；不以旧图掩盖失败。
- Riverpod默认自动重试会把流错误重新变成AsyncLoading，叠加行情层重试后造成等待状态持续。行情流关闭该默认重试，由MarketSync统一负责重试；流订阅直接返回，取消时立即解除。回归测试验证连续冷切换后provider退出加载、错误可见且重试成功。
- Widget验收覆盖连续5m→15m→1h、保留同一个图表State及按钮位置、旧图不成为当前报价、HTTP503及重试、跨币种清除旧图、初始网格、横屏全屏和1.5倍字体、减少动画时停止加载点动画。按需请求及无预加载策略不变；视觉过渡不承诺缩短Aster网络响应时间。
- 验证通过：格式化检查、flutter analyze无问题、完整60项测试、Android arm64 Release构建（30.6MB）。正式入口Release已安装到Android12真机，实际Aster请求切1m→5m捕获到淡化旧图、周期标签与三个点，随后出现5m数据；没有人为延时。截图为 `docs/reference/chart-loading-android-pending.png`、`chart-loading-android-loaded.png`。参考站观察截图为 `reference-chart-loading-pending.png`（历史回调人为延时，仅作加载样式证据）。iOS仍需macOS／Xcode，当前Linux未编译验证。
- 根据后续可见性反馈，将三点从右上移到图表中央，并由4px放大至6px，周期提示放在下方。格式化、静态分析、3项相关Widget测试与Android Release构建通过；已安装到Android12真机并验证实际1m→5m加载状态，截图为 `docs/reference/chart-loading-centered-android-pending.png`。

## 周期切换性能验收

- 旧实现将图表周期与100币种预热绑定，切换时重建加载任务、等待WS握手、重复查询边界并延迟通知。第一轮优化保留周期缓存及其他周期预取；按用户最终要求，现已取消全部K线预加载。
- MarketSessions以币种＋周期为键，仅为实际打开的图表创建MarketSync。每个MarketSync只持有一个CandleSeries，只订阅当前图表；切换时暂停旧订阅及所有定时任务。缓存命中立即显示，恢复同步期间显示历史标记；首次无缓存时显示加载，不展示旧币种／周期冒充的新数据。
- 回归测试覆盖首次只发当前图表一个历史请求及一条订阅、不等握手、没有其他币种或周期预热、首次打开冷周期才加载、实际访问图表复用缓存、快速切换全局5并发和过期排队取消、迟到响应隔离、刷新失败保留历史、长断线分页及WS保护、Riverpod同步读缓存。Widget测试先运行61秒定时任务，确认仍只请求当前图表，再验证冷加载和已访问周期连续切换的首帧／按钮位置；随后切换币种再推进61秒，确认旧图表全部停止校准与重试，元数据只刷新新币种。
- 头部不重复显示离线横幅，同步／历史状态统一放在图表底栏，避免周期按钮跳位。详情加载进度只对应当前图表（0/1或1/1）。单币元数据请求测试验证ticker与premiumIndex均携带当前symbol并解析单对象响应。
- 格式化、静态分析（无问题）、完整57项测试及Android arm64 Release构建（30.6 MB）通过；补充的停止旧币种定时任务Widget测试也已通过。已安装至Android 12真机，初始BTC 1m、首次5m／15m与切回1m／5m均显示正确周期蜡烛，详情为当前图表1/1；另已验证切换ASTER与ETH 5m，ETH首次加载显示进度指示，随后为ETH自身蜡烛并恢复实时状态。原生截图与记录为 `docs/reference/chart-demand-android*.png/json`；截图不作为精确绘制延迟测量，请求范围及无预加载由单元／Widget测试确认。iOS需macOS／Xcode，当前未编译验证。
- 之前的 `timeframe-cache-android*.png/json` 为保留100币种预热版本的历史验证证据，不代表当前按图表加载版本。

### 停留后切换的HTTP连接与实测

- 用户反馈的是历史数据到达前的图表转圈。新增Android12真机Profile分段探测：周期notifier选择、历史请求发出／完成、provider数据和Flutter首个数据帧。此前连续切换的冷周期首帧为317–765ms、343–401ms，缓存切回为27–94ms；并未在这两轮复现冷周期转圈数秒。绘制前provider／构建开销为几十毫秒；不是等待WS完成后才显示历史。
- 确认原来使用Dart默认HTTP空闲15秒超时。正常看图停留超过此时间会释放连接；下次冷周期可能重做连接／TLS。已改为原生IOClient保留空闲连接120秒，不发送保活预加载请求，不修改行情数据源、TLS校验或限流预算。
- 对照验证：本地HTTP服务器测试等待16秒，默认客户端远端端口改变（重连），行情客户端端口不变（复用）。同一Android设备两客户端并行请求相同Aster端点，预热后停20秒：默认客户端记录新连接且耗时855ms；120秒客户端无新连接且耗时352ms。后续暖请求仍有269／819ms波动，单次样本不构成整体性能保证。
- 改后实际图表停20秒再切5m首数据帧389ms，其他未访问周期400／402／1111／692ms，缓存切回83／34／64ms。首数据帧为Flutter构建结束回调，不是GPU光栅化完成。参考站此前200–300ms为桌面浏览器请求耗时；同手机只读Orderly请求为552–3433ms，不能拿不同设备／网络的测量认定Aster固有更慢。
- 探测也看到启动阶段约5秒的Socket／TLS失败及12秒请求超时；这些发生于元数据初始化，不作为已复现的周期切换根因。连接保留修复了一个确定的额外开销，不能据此声称消除所有网络停顿或已复现用户的每次数秒等待。
- 证据：`docs/reference/chart-http-idle-android.json`、`chart-load-android-before-{first,second}.json`、`chart-load-android-after.json`。临时探测入口已移出工程，正式包不包含探测日志或自动切换。
- 格式化、静态分析（无问题）、完整58项测试及Android arm64 Release构建通过。已重新安装正式入口Release包至Android12真机，确认初始1m与首次切5m的Aster图表正常、连接绿点恢复；截图 `docs/reference/chart-http-release-android-5m.png`。Linux环境仍不支持iOS编译。

### 参考站周期切换实测

2026-10-30以全新Chrome上下文打开参考站BTC页面，监听公开历史请求和K线订阅，再连续点击1m→5m→15m→1m→5m→15m→1h→5m。该观察用于区分参考站行为与本项目的实现选择，不表示两者内部结构相同。

- 参考站使用TradingView和Orderly；初始仅请求15m历史，没有观察到其他周期预取。首次进入1m、5m、1h时分别请求 `/tv/history`，本次请求完成耗时约293／222／205ms，这些是请求耗时，不是绘制耗时。
- 切回已访问的15m、1m、5m时，观察窗口内没有新的历史请求或K线订阅消息，说明存在数据／订阅复用。全程只打开一个行情WebSocket连接，新周期在既有连接上订阅；不在每次切换时重新握手。
- 本项目现已按用户要求取消其他周期预取和100币种订阅，改为当前图表按需加载、保留访问缓存。与参考站相比，本项目切走会暂停旧图表订阅，切回仍需连接并校准；不声称两者连接管理、缓存淘汰及长期刷新规则完全相同。
- 记录：`docs/reference/reference-site-timeframes.json`；最终5m页面截图：`reference-site-timeframes.png`。该记录仅描述参考站的公开网络观察。

### 同手机参考站与Aster进一步比较

用户仍感觉参考站更快，本次直接使用连接的Android12手机Chrome打开参考站，再在同一手机运行当前原生图表探测；未更换应用行情来源。

- 已确认接口不同：参考站BTC为Orderly `/tv/history`、USDC市场，应用为Aster `/fapi/v3/klines`、USDT市场。单纯接口名称不同不能说明耗时；需要分离缓存命中、连接冷热和网络波动。
- 实际参考站按周期顺序等待onDataLoaded：冷1m约821ms、15m约785ms、1D约1255ms；切回缓存1m约252ms、1h约159ms，无历史请求。4h在此样本请求多页1h数据后构建，约2226ms。记录包含CDP点击分发开销与两次rAF，不能与原生notifier首帧数字直接作精确优劣排序。
- 紧接着同手机原生Profile入口停留20秒再首次切换：5m／15m／1h／4h／1d首帧374／397／392／409／405ms，缓存切回74／26／35ms。本轮没有复现原生图表每次等待数秒；探测使用实际providers及数据服务，正式Release未嵌入探测逻辑。
- 同一AndroidChrome页面、相同200根历史数量、交替请求Aster和Orderly并在下一轮逆序：第一轮1m为Aster2958ms、Orderly330ms，5m为648／325ms，15m为818／428ms；因此确实观察到Aster单次近3秒的历史响应，这类情况直接导致无缓存图表转圈。第二轮Aster约231–435ms，Orderly约696–971ms，又出现反向差距。样本仅有两轮，不能推断长期均值或确定问题位于服务端而非连接／访问链路；可以确认秒级等待并非必然由绘图或预加载策略引起。
- 第一组真实应用请求量对比为Aster200根、Orderly1000根，单独保存，不用它下等量服务器快慢结论。等量测试确认两边响应均含200根，不替换行情来源、不混合两交易所价格。
- 证据：`docs/reference/reference-vs-aster-same-android.json`、`reference-vs-aster-android-native.json`、`reference-vs-aster-android-equal-bars.json`、`reference-vs-aster-android-reference.png`。本轮仅调查与记录，没有应用代码变更；完成后恢复正常Release入口安装。

## 实际端点

- HTTP 基址：`https://fapi.asterdex.com`，使用 `/fapi/v3/exchangeInfo`、`/fapi/v3/time`、`/fapi/v3/ticker/24hr`、`/fapi/v3/premiumIndex`、`/fapi/v3/klines`，均不需要账户鉴权。
- WebSocket：`wss://fstream.asterdex.com/stream`，K 线、aggTrade、depth20@500ms 均使用此地址；不沿用旧数据源的 market/public 分流地址。
- 使用SUBSCRIBE JSON订阅当前图表的单个K线频道。遵守 Aster 每个连接最多 200 路限制；忽略订阅确认，解析 combined envelope，兼容 raw event。断线或订阅失败时退避重连，切换币种／周期时立即取消旧连接，包括没有新消息的连接。
- K 线 REST limit 支持 1–1500，应用回补仍使用至多 1000 根／页；权重分别为 <100:1、<500:2、≤1000:5、>1000:10。全市场 ticker 权重40，单币 ticker 和 premiumIndex 权重1；维持更保守的本地1000 weight/min预算。
- 盘口沿用 20 档 partial book 快照流，深度图只计算这 20 档的累计数量，不宣称完整订单簿；不把 partial book 当成 diff 流累加。下单、钱包、账户及签名接口均不在本次公共行情迁移范围，继续明确显示本地演示。
- 来源：[产品接口说明](https://app.notion.com/p/409080d974e780188a4fedfdcf29e655?pvs=24#409080d974e78026ab12fc0a5e8388ba)、[Aster V3 官方文档](https://github.com/asterdex/api-docs/blob/master/V3%28Recommended%29/EN/aster-finance-futures-api-v3.md)。
- 外部请求边界：公开行情接口为 Aster 的 `fapi.asterdex.com` 和 `fstream.asterdex.com`；身份认证和内嵌钱包操作另由 Privy 原生 SDK 请求 Privy 服务；外部钱包选择和签名通过 Reown／WalletConnect 及选中的原生钱包，钱包列表／图标和 relay 属于该 SDK 的网络边界。主字体和品牌图片随原生应用打包，不使用 Web 渲染器及其 Google CDN／回退字体请求。

## 架构及依赖

`Widget → Riverpod → MarketSessions / MarketSync → CandleHistoryRepository → AsterService → HTTP / WS`；演示账户由独立notifier管理。不可变行情模型与CandleSeries规则位于market/domain；图表包的可变实体只存在于chart_canvas适配层。WebSocket生命周期由数据层AsterMarketStream管理，不在Widget中构造客户端。

`k_chart_plus 1.0.4` 的 intl 约束为 ^0.19，而 Flutter 3.47 的本地化固定 intl 0.20.3。显式 override intl 0.20.3；包使用的 NumberFormat API 已经静态分析、图表 widget 测试和 Web 编译验证。图表包通过 path override 使用 `third_party/k_chart_plus` 中的 1.0.4 源码及移动手势修复，保留原始 LICENSE，修改说明见该目录 PATCHES.md。上游源码不应用项目的严格 lint；应用和测试仍执行静态分析。应用依赖分别用于 Riverpod 状态、HTTP／WebSocket 行情、Decimal 财务运算、指定图表包及 Privy 原生认证。

主题色集中于 core/theme，文案集中于双语 strings。图表、盘口、表单、确认、持仓、账户选择按职责拆分；超过 80 行的组合 build 已按职责复核，保留同一组件的状态与局部布局，未增加跨 feature 的万能组件。

## 平台与验证

Android 最低 API 28，iOS 最低 17（Privy Flutter 0.10.2 原生要求）；iOS 编译、签名和真机运行需 macOS / Xcode。不锁定方向。手机、平板、横屏和放大文字仍在支持范围内。

## 移动端平台验收

- 按用户要求取消 Web 支持，移除 `web/` 工程及 `build/web` 产物、项目迁移元数据中的 Web 平台和分析配置中的 Web 排除项。运行／构建说明和 AGENTS.md 验收要求改为 Android／iOS，不修改全局 Flutter 平台开关。
- 本次未更改行情协议、演示账户逻辑、图表手势和响应式布局。HTTP／WebSocket 依赖保留，继续服务原生 Aster 行情；历史浏览器截图和记录仅作为开发档案。
- 当前检查通过：`dart format --output=none --set-exit-if-changed lib test`（无需修改）、`flutter analyze`（无问题）、`flutter test`（48项全部通过）、`flutter build apk --release --target-platform android-arm64`（30.6 MB）。已安装到连接的 Android 12 真机并启动，目视确认 Aster 行情、K线和原生页面正常，截图为 `docs/reference/aster-android.png`。确认项目与构建目录均无 Web 工程或产物；当前 Linux 环境无法运行 Xcode，iOS 未编译验证。

自动验证覆盖：当前图表按需加载且无其他币种／周期预热、快速切换5并发限制、跨 1,000 根断线分页、缓冲与 REST 竞态、乱序消息、收盘保护、REST 事件水位、市场/币种/周期隔离、迟到请求、Decimal 计算、模拟交易，以及 360/390/768/1440 宽度与 1.5 倍文字缩放的图表和下单交互。

构建和实测结果在完成后同步至 README。行情依赖所在网络能访问 Aster 公共接口。应用展示真实加载/断线状态，不承诺 REST/WS 固定时差。

迁移前历史验证：`flutter analyze` 无问题，37 项自动测试通过，Web 与 Android arm64 Release 构建通过。旧数据源的 Chrome 观察覆盖 100 个历史交易对、100 个实时交易对和 1,818 条 K 线消息；Android 12 真机已安装运行。以下原有交互截图及 Android 安装包来自迁移前，不作为 Aster 接口证据。iOS 尚未在 macOS / Xcode 编译验证。

## Aster 接口迁移验收（取消 Web 支持前的历史记录）

下述 Web 构建、浏览器请求及截图均为历史证据，不表示当前仍支持 Web。

- 自动检查：V3 host/path、无鉴权初始化、可交易 USDT 永续过滤、100 个交易对选择、按 symbol 合并 ticker/premiumIndex、服务器时间、K 线分页参数及 OHLC 校验、HTTP 错误和无效 JSON 的安全失败、combined/raw WS 事件、20 档／成交频道、订阅错误重连及 200 路上限。保留原有缓存同步、Decimal 演示交易与响应式 Widget 回归测试。
- 2026-10-30 匿名实测 exchangeInfo、time、ticker/24hr、premiumIndex、klines、depth 均返回 HTTP 200，响应包含允许 Web 跨域的 `Access-Control-Allow-Origin: *`；Aster WebSocket 已实际收到 kline、depthUpdate、aggTrade 和订阅确认。当前界面使用 partial depth 流，depth REST 只在验证文档合同的只读探测中调用。
- 最终检查通过：`dart format lib test`、`flutter analyze`（无问题）、`flutter test`（48 项全部通过）、`flutter build web`。新增 11 项 Aster 接口／连接回归测试；原有模拟下单 Widget 测试补充滚动及输入后的布局等待，保证实际点击按钮。
- Chrome 实测加载 100 个交易对历史，收到全部 100 个交易对的实时 K 线（观察期 162 条），并收到 depthUpdate／aggTrade；无 HTTP 错误、页面运行错误和控制台错误，行情请求仅访问 Aster HTTP／WS 域名。390×844 与 1440×1000 页面已目视检查。证据：`docs/reference/aster-live-verification.json`、`aster-mobile.png`、`aster-desktop.png`。本次未重新构建或安装 Android／iOS。
- Chrome 联动验收通过：从1m切到5m后加载全部100个交易对历史，搜索并选择 ETHUSDT，盘口与成交订阅改为ETH，旧周期与旧币种的3个连接已关闭，再切换当前ETH深度图；无页面运行错误。记录：`docs/reference/aster-interactions.json`，截图：`aster-eth-5m.png`、`aster-eth-depth.png`。

## 移动图表交互

根据参考站的 TradingView 表现形式组织单一工作区，渲染继续使用 k_chart_plus。默认蜡烛主图 + 成交量，不默认添加 MA 或副图；主图 MA/BOLL、VOL 开关、MACD/KDJ/RSI/WR/CCI 可在底部横向快捷栏切换，也可通过技术指标弹出面板选择。副图互斥，重复点击当前副图可关闭。蜡烛 / 折线入口为图形菜单；深度图复用当前图表区域。

周期位于主图上方；最新 OHLC 在紧凑图例中显示，长内容可横向滚动。长按显示十字光标和有宽度约束的价格浮层，横向拖动查看历史，双指缩放，单指纵向移动滚动整个交易页。全屏使用独立 SafeArea 页面，沿用图形、主副图指标、成交量和深度选择，不锁屏幕方向，窄高 / 横屏均可访问全部操作。所有图表操作的触控区域至少 44 logical pixels。

图表底栏取消常驻“形成中／已收盘”文字，K线图和深度图统一保留数据源、连接指示点与可点击详情入口，断线时仍显示重连提示。K线状态只在行情详情中显示，避免当前蜡烛持续更新被理解为加载未完成；不更改收盘判断和行情同步。格式化、静态分析、11项页面Widget测试及Android arm64 Release构建通过；现有详情交互测试确认标签仅在打开详情后出现。已更新到Android 12真机并目视确认底栏标签已移除、行情正常更新，截图为 `docs/reference/chart-status-android.png`。

本次图表交互验证新增：默认无副图、主图指标同轴叠加、副图互斥切换 / 关闭、VOL 开关、指标弹出面板、全屏共享设置与横屏布局、长按十字光标浮层、真实画布横向滚动及双指缩放。

右侧默认留白为可用图表宽度的 18%（48–100 logical pixels），允许继续向左拖动蜡烛，露出最多 60% 图表宽度的未来空白，最新蜡烛保留在图内；继续向历史方向拖动则回到已有 K 线。拖动与惯性共用边界，松手不会回跳。留白按屏幕尺寸计算，双指缩放保持当前未来留白，实时新增 K 线不重置位置；旋转屏幕后重新限制边界。未来区只有空白与网格，不添加价格或伪造 K 线。

`test/chart_future_space_test.dart` 覆盖窄屏蜡烛/折线、横屏全屏再旋回竖屏、边界停止及反向拖回、双指缩放保持留白和新增实时蜡烛保留位置。原逻辑在最新蜡烛处锁定 scrollX ≥ 0，新增“拖出未来空白”回归用例已先验证失败，再通过本地包的 viewport 边界补丁修复。

Android 12 真机已验证默认留白、连续拖动在约 60% 留白处停止和反向拖回；截图为 `docs/reference/future-space-android-{before,limit,stopped,returned}.png`。Chrome 移动触控同样验证边界和拖回，截图为 `future-space-web-*.png`，无页面运行错误。

## 盘口数量背景条

盘口原有背景在 Align 的松约束下高度为 0，因此数量虽实时更新，颜色条没有绘制。修复用 AnimatedFractionallySizedBox 明确 heightFactor 为 1，背景从价格侧向右延伸；红色卖盘、绿色买盘采用独立于成交量图的语义色。每档宽度为该档数量 / 当前可见买卖各 8 档中的最大数量，两侧共用标尺，零数量不绘制宽度。

背景宽度以 180ms easeOut 平滑更新，小于盘口 500ms 推送周期；行按市场币种、买卖方向、真实价格设置 key，档位插入或排序变化时保持对应价格的动画状态。系统要求减少动画时直接更新。数量与价格仍展示最新真实快照；背景条为单档挂单量，不是累计深度，不生成假变化。点击价格填入限价输入的行为保留。

`test/order_book_test.dart` 先复现旧版背景高度为 0，再验证完整行高、左右锚点、买卖共用标尺、数量增长/缩减、档位插入、180ms 中间帧、零数量、减少动画和点价填单。

Android 12 真机与 Chrome 已观察真实盘口数量及红绿背景条变化，截图为 `docs/reference/order-book-bars-{android,mobile}.png` 及对应 `-updated.png`。Chrome 无页面运行错误；37 项测试、静态分析、Web 与 Android arm64 Release 构建通过，修复版已安装到真机。

### 双指缩放修复

上游 1.0.4 的横向拖动与缩放 recognizer 竞争；第一根手指先拖动或长按后，第二根手指无法接管已识别的手势。原有“两指同时落下、小步移动”测试通过，不能代表上述实际操作。新增回归测试先拖动再放第二指，在原始包上实际失败（scaleX 保持 1.0），修复后通过。

本地包的 KChartPinch 用原始触点距离比更新原有 scaleX（仍限制为 0.5–2.2），双指接管时取消惯性和十字光标，阻止残留单指在抬起时误触发拖动、惯性或点击。ChartTouchScroll 在事件派发完成后再次结束父级滚动 activity，避免先纵向移动时父级屏蔽第二根手指；保持单指上下滚动页面的行为。

`test/chart_gestures_test.dart` 覆盖同时落指、先横移、先纵移、先长按和全屏，逐项验证张开放大、合拢缩小、页面不跟随滚动、抬指后比例保留、无误触惯性，以及取消后下一次双指手势可继续使用。价格图、数据合并、指标算法与深度图渲染未更改。

Android 12 真机通过系统注入双触点 MotionEvent，对比修复前后“先横移再双指张开”：旧包蜡烛宽度不变，修复包明显变宽，合拢后缩回。Chrome 移动触控通过 CDP 双触点同样确认张开/合拢，页面无运行错误。截图为 `docs/reference/pinch-android-{before,expanded,contracted}.png` 与 `pinch-web-{before,expanded,contracted}.png`。同时保留触控缩放后切回鼠标拖动的兼容性测试。
