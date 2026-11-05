# Vanta Flutter

参考 Vanta 的移动永续交易界面，仅支持 Android 和 iOS。深色主题，支持跟随系统／简体中文／English并保存语言偏好，K 线使用 `k_chart_plus`。保留手机、平板和横屏布局适配。

本轮统一实盘下单模式入口：限价／市价直接切换，更多默认收起、记忆限价止盈止损，列齐九种模式。六种普通模式与独立Scaled可用，Post Only固定GTX；Chase缺恢复协议、TWAP本阶段跳过，均明确禁用，不伪装执行。身份变化重置，刷新／语言保留，忙碌／未知结果及离页旧回调拦截。新增49项、专项156项／全量4088项通过，842个Dart文件格式与静态分析、`make env-check`／`make build-apk` Android arm64 Release通过，中英文各1669条。APK未安装、真机和真实钱包仍未验收；开仓比例滑杆／部分设置及完整策略管理／Portfolio／Swap继续推进。见 [来源与边界](docs/reference/order-mode-entry-public-contract.json)、[验证记录](docs/reference/order-mode-entry-verification.json) 与 [进度表](docs/prd-progress.md)。

此前按最新账户PRD补齐：仅外部EOA登录可创建子账户，Privy托管登录禁用创建入口，并在准备／确认／提交前拦截。列表、切换、冻结／解冻和划转保留；切换使用独立地址输入，身份或签名能力变化会清空输入／子签名并使旧确认失效。新增40项、专项121项／全量4039项测试通过，837个Dart文件格式检查和静态分析通过，`make env-check`／`make build-apk` Android arm64 Release通过，中英文各1661条。APK未安装，真实钱包／原生与iOS仍未验收，完整PRD继续推进。见 [来源与边界](docs/reference/subaccount-creation-access-public-contract.json)、[验证记录](docs/reference/subaccount-creation-access-verification.json) 与 [进度表](docs/prd-progress.md)。

此前补齐首访 Futures／K 线／BTCUSDT、底部导航返回保留页签与交易对、快捷面板公开基础币单位及真实账户设置展示。账户未读取时显示 —，不会自动签名或写入新户预设；盘口加载／失败隐藏残留旧报价。新增33项、专项69项／全量3999项测试、834个 Dart 文件格式检查、静态分析及 `make build-apk` Android arm64 Release通过，中英文各1660条消息，APK未安装。见 [来源与边界](docs/reference/futures-navigation-public-contract.json)、[验证记录](docs/reference/futures-navigation-verification.json) 与 [进度表](docs/prd-progress.md)。最新账户PRD的Privy创建限制已由后续增量补齐；完整策略管理、部分表单设置、Portfolio及Swap等继续推进。

此前补齐 Scaled 总金额／基础币输入、等量／递增／递减／随机、等差／等比、固定随机偏差、2–110笔、首次空输入及完整分页预览／确认／结果。精确尾差、原编号恢复与逐笔失败停止保留。新增97项、完整3966项测试、824个 Dart 文件格式、静态分析及Android arm64 Release构建通过，中英文各1659条消息，APK未安装。见 [来源与边界](docs/reference/scaled-order-alignment-public-contract.json)、[验证记录](docs/reference/scaled-order-alignment-verification.json) 和 [进度表](docs/prd-progress.md)。真实／原生待验收，完整PRD仍在推进。

此前补齐独立 Futures 订单／逐笔成交／资金流水历史，支持显式签名读取、交易对／UTC日期／流水类型筛选、满额时间范围细分和手动继续。撤单保留实际成交，手续费／盈亏分别展示原币种，缺失金额／单位保持未知；开页、筛选及本地翻页不签名。新增139项、完整3819项测试、812个 Dart 文件格式检查、静态分析及 Android arm64 Release 构建通过，中英文各1625条消息。APK未安装，真实／原生未验收，见 [来源与边界](docs/reference/futures-history-public-contract.json)、[验证记录](docs/reference/futures-history-verification.json) 和 [进度表](docs/prd-progress.md)。完整Portfolio、Swap、Chase恢复、完整策略管理和部分表单细节仍待完成。

此前补齐主表单基础币／USDT 委托金额切换、精确换算／步长向下取整、首次有效 Last 限价预填及条件／Trailing 默认 Mark。金额不乘杠杆，确认后固定基础币数量，签名与恢复不按后来报价重算；实际支出可能超过估算。新增63项、完整3680项测试、794个 Dart 文件格式检查、静态分析及 Android arm64 Release 构建通过，中英文各1608条消息。APK未安装，真实／原生未验收；见 [来源及边界](docs/reference/order-amount-public-contract.json)、[验证记录](docs/reference/order-amount-verification.json) 和 [进度表](docs/prd-progress.md)。确认偏好及合约历史现已接入；Scaled及首屏导航已由后续增量补齐；部分设置、完整Portfolio及Swap仍未完成。

此前新增已知附加策略的逐腿成交详情：显式签名核对原策略与各实际子单，展示真实回报的数量／成交金额、独立策略／订单状态和时间。缺编号／金额保持未知，拒签后停止后续提示，不推断数量自动增补或对侧撤销。新增88项、完整3617项测试、787个 Dart 文件格式、静态分析及 Android arm64 Release 构建通过；中英文各1593条消息。APK未安装，真实／原生未验收，见 [合同](docs/reference/strategy-execution-public-contract.json)、[验证](docs/reference/strategy-execution-verification.json) 和 [进度表](docs/prd-progress.md)。合约历史已由后续增量补齐；完整策略管理、跨产品Portfolio、Swap及部分表单细节仍未完成。

此前增量：附加 TP/SL 已补齐 PnL／价格／ROI、默认 Mark、独立市价／手动限价／自动限价退出、本次主单全量保护及部分／全部成交联动；旧策略仍按原数量与原事件恢复，未知不重发。新增82项、全量3528项测试、773个 Dart 文件格式、静态分析及 Android arm64 Release 构建通过，中英文各1570条消息。APK 未安装；逐腿实际成交详情现已由上述增量接入，完整策略列表仍待补齐，真实权限／撮合／原生未验收，见 [进度表](docs/prd-progress.md)、[合同](docs/reference/attached-exit-alignment-public-contract.json) 与 [验证记录](docs/reference/attached-exit-alignment-verification.json)。

此前增量：逐仓保证金追加／移除已接入：非零逐仓仓位入口、双语确认、精确额度／强平预估、同账户保证金率、原编号历史核对及持久化恢复；完整刷新成功后关闭调整页并更新主账户／仓位。当前连接 EOA 直接签名，未知结果不重发。新增98项、全量3446项测试、766个 Dart 文件格式检查、静态分析及 Android arm64 Release 构建通过；中英文各1547条消息。APK 未安装，真实钱包／资金和真机仍待验收，详见 [进度表](docs/prd-progress.md)、[协议](docs/reference/position-margin-adjustment-public-contract.json) 与 [验证记录](docs/reference/position-margin-adjustment-verification.json)。

此前增量：Futures 资产卡已接入抵押贡献参考值：完整全仓仓位使用公开标记价重算，字段或行情不完整时明确回退签名快照；可展开查看权益、价格率及 UTC 时间。新增 80 项／全量 3348 项测试、格式检查、静态分析和 Android Release 构建通过；未做本轮真机或真实资金验收，详见 [进度表](docs/prd-progress.md) 与 [验证记录](docs/reference/asset-collateral-verification.json)。Swap 和完整跨产品 Portfolio 仍未完成。

## CI 与发布

已适配参考项目的质量检查、原生性能报告、PR 自动审查与 Android／iOS 签名发布，不包含 Web 或私钥导出站点部署。触发方式、凭据配置和验证边界见 [CI 文档](docs/ci.md)。

iOS CI 和 IPA 打包自动检测签名配置：`APPLE_TEAM_ID` 与三个 `IOS_*` Secrets 全部未填时跳过，填齐后自动构建；只填部分会提示缺项。Android 可独立发布，App Store Connect 配置仅控制可选 TestFlight 上传。

配置 `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` Secret（服务账号完整原始 JSON）后，main 新版本会在 AAB 校验通过后自动上传 Google Play 内部测试；未配置时跳过。首次 Console 设置、服务账号权限及版本递增要求见 [Google Play 配置](docs/ci.md#google-play-内部测试)。

## 运行

与参考项目一致，通过 `make` 加载根目录 `.env`：

```sh
cp -n .env.example .env
# 编辑 .env，填写 PRIVY_APP_ID、PRIVY_CLIENT_ID、REOWN_PROJECT_ID
flutter pub get
make env-check
make run FLUTTER_ARGS='-d <android-device-id>'
# macOS / Xcode 上使用 iOS 设备 ID
make run FLUTTER_ARGS='-d <ios-device-id>'
# 切换配置文件
make run ENV_FILE=.env.staging FLUTTER_ARGS='-d <device-id>'
```

`.env` 只允许模板中的四个公开应用配置项，`WALLET_LOGIN_ORIGIN` 可省略，默认 `https://app.vanta.exchange`。必填 ID 为空、格式错误、重复或未知配置项会在 Flutter 启动前报错，错误不回显值。配置文件不作为 shell 执行，不做变量插值；使用普通 `KEY=value`，可加注释或单／双引号。签名证书、密码、`OPENAI_KEY` 等 Secrets 不放入此文件。`.env`／`.env.*` 已被 Git 忽略，仅提交 `.env.example`。

`ENV_FILE` 默认 `.env`，`FLUTTER_ARGS` 用于追加 Flutter 参数；`make` 或 `make help` 列出命令。已有 `config/privy.local.json` 仍可通过原 Flutter 命令使用。GitHub Actions 继续从仓库 Variables／Secrets 生成 CI JSON，不读取开发机 `.env`。

## 行情与图表

- Aster USDT 永续合约，使用 V3 公共行情接口。列表包含接口返回的全部可交易 USDT 永续合约（本轮实测 567 个）；只为当前图表的币种和周期加载 200 根历史 K 线，并订阅该图表的实时更新，不预加载其他币种或周期。
- 交易对选择器支持 symbol／基础资产／名称／别名搜索、全部合约与自选筛选，以及交易所标签分类，列表通过两路全市场公开报价流更新最新价、24 小时涨跌、报价币成交额及资金费率；关闭选择器或离开行情列表后释放报价订阅，K 线仍只加载当前图表。断线保留最近报价并显示更新时间。自选仅保留在当前应用会话；持仓量单位、最大杠杆徽标来源、New 时间规则和运营默认排序仍待确认。分类来自 V3 exchangeInfo 的 underlyingSubType，不按名称猜测。
- 单一图表区域：默认蜡烛 + 成交量，支持蜡烛、空心蜡烛、美国线、折线、带标记折线、阶梯线、面积、基准线、柱形、高低线和平均K线；MA/BOLL 叠加，MACD/KDJ/RSI/WR/CCI 副图按需切换，现有指标参数可编辑；深度图在同一区域切换。
- 先订阅再拉历史、缓冲合并、按开始时间去重、乱序及收盘保护、断线重连、最多 1,000 根一页回补；不编造缺口价格。
- 支持Aster全部15个K线周期（1m至1M），常用周期旁的“更多”提供完整列表。仅保留实际访问过的币种／周期缓存，切回立即绘图并校准，首次打开才发历史请求且不等待WebSocket握手。切走即停止旧图表的订阅和定时任务，快速切换最多5个已发出的历史请求，过期排队任务取消。
- 支持普通、对数、百分比及基准100价格坐标。向左浏览到历史边缘自动按200根分页，保持当前视角；正常状态没有“更早历史”按钮，只显示加载／到底状态，失败提供重试。
- 未缓存周期切换时保留淡化的旧图与原视角，图表中央显示三个加载点，下方显示周期过渡，新数据到达即替换；首次加载或换币种显示网格。旧图仅供过渡，不参与当前报价及下单。
- 5 个 REST 并发、请求权重预算、重试退避、缓存进度和事件时间/收盘状态。原生HTTP空闲连接保留2分钟，减少停留看图后再切换的重复建连，不发送预加载请求。
- 图表底栏仅保留数据源、连接指示和详情入口；断线时提示重连。“形成中／已收盘”只在行情详情中显示。
- 已修复双指缩放与拖动/长按的手势冲突：先放一根手指、再放第二根也能缩放。图表包使用附带原始许可的本地 1.0.4 补丁，见 `third_party/k_chart_plus/PATCHES.md`。
- 价格图右侧默认留白，可继续拖出最多约六成图表宽度的未来空白；拖动和惯性到边界停住，缩放和实时更新保留留白位置。
- 订单簿的红绿数量背景条从价格侧延伸，随真实挂单量平滑伸缩；买卖两侧共用数量标尺，点击价格可填入下单框。

账户入口已接入 **Reown 外部 EOA + Privy SIWE 登录、邮箱验证码登录、会话恢复和退出**，参考 `/data/dodo/rwa-interface` 的认证边界。连接 EOA 时直接使用该钱包签名，不创建额外钱包；邮箱登录使用 Privy 内嵌钱包。恢复 EOA 身份后需要重新连接同一个钱包才能签名。真实登录身份与本地演示交易分开；本地演示使用初始 10,000 USDT 模拟资金。另有独立实盘入口，支持当前钱包签名提交订单及平仓，再以原编号查询核对；这些实现尚未完成真实授权账户验收。Spot ↔ Futures 内部划转已有显式读取／确认／签名提交与独立日志恢复入口，真实权限及划转未验收；充值、提现及主子账户划转现有独立确认／提交和持久化核对，真实资金执行尚未验收。Aster 挂单支持逐笔撤单或按确认的交易对范围全部撤单，均签名提交后再签名核对结果；可停止后续交易对提交，结果不明时只查询、不重发撤单。实际使用需要 Aster 认可的钱包权限。行情来自 Aster，报价单位为 USDT。

Portfolio 已增加独立的 **Aster 账户只读页**：手动钱包签名查询合约 USDT 概览、逐币余额与非零持仓；另有 Spot 标签，单独签名查询现货可用、冻结及总余额。支持搜索、零余额过滤和历史快照提示。切换身份会清除数据，与本地演示分开。V3 文档要求授权 API signer，主钱包直签是否获准及 chainId 1666 的钱包兼容性尚待真实验证；当前实现不代表已完成实盘账户接入，遇到授权拒绝不会新建 agent 钱包。

Spot 资产页新增当前挂单独立入口，使用 sapi 全账户签名基准，支持本地筛选、同范围计数和现货事件合并。另有订单历史、成交历史和资产流水三个独立入口，通过官方 V3 接口手动签名读取。支持 UTC 日期、交易对／资产筛选、超过7天的成交与流水分段读取，以及1,000条上限提示；加载失败保留记录，停止等待会丢弃迟到结果。订单历史保留未成交及部分成交记录，流水与成交分开，金额保留 Decimal 精度。真实私有读取尚待授权钱包验收。

运行前将 `.env.example` 复制为 `.env` 并填写 Privy 的公开 App ID / Client ID、`REOWN_PROJECT_ID` 和 HTTPS `WALLET_LOGIN_ORIGIN`，通过 `make run` 使用；本地文件已忽略。旧的 `config/privy.local.json` 仍兼容 Flutter 的直接调用。开发环境已从参考项目复用公开的 Privy 和 Reown 标识，未复制密钥。生产客户端须在 Privy 控制台正确登记 Android 包名、iOS Bundle ID 和 SIWE 域名；钱包回跳为 `vanta://wallet`。未配置时仍可浏览行情和使用本地演示。最低 Android API 28、iOS 17。

HTTP：`https://fapi.asterdex.com/fapi/v3/`；WebSocket：`wss://fstream.asterdex.com/stream`。接口依据为产品 [Notion 文档](https://app.notion.com/p/409080d974e780188a4fedfdcf29e655?pvs=24#409080d974e78026ab12fc0a5e8388ba) 和 [Aster V3 官方文档](https://github.com/asterdex/api-docs/blob/master/V3%28Recommended%29/EN/aster-finance-futures-api-v3.md)。

## 多语言

与参考项目一致使用 Flutter 官方 ARB／gen-l10n：文案位于 `lib/l10n/app_en.arb` 和 `app_zh.arb`，修改后运行 `flutter gen-l10n`。顶部语言按钮支持跟随系统、简体中文和 English；选择即时生效并持久化，保留当前页面和交易输入。不支持的系统语言回退英文，保存失败可重试。图表说明、订单、行情状态及认证步骤均使用语言目录；钱包品牌、币种符号和技术指标保留原名。Reown 1.9 的第三方钱包选择弹窗自身仍使用英文，钱包应用内的确认语言由钱包控制。

## 检查与构建

```sh
dart format lib test
flutter analyze
flutter test
make build-apk-debug
make build-apk
make build-appbundle
# macOS / Xcode，无签名编译验证
make build-ios
# 构建时也可选择配置文件及追加参数
make build-apk ENV_FILE=.env.staging FLUTTER_ARGS='--obfuscate --split-debug-info=build/symbols/local'
```

Android arm64 体验包：`build/app/outputs/flutter-apk/app-release.apk`（使用本地调试签名，仅供安装体验）。调试包：`build/app/outputs/flutter-apk/app-debug.apk`。正式商店分发需配置生产签名；iOS 构建需要 macOS / Xcode。

完整行为、同步规则、依赖兼容说明与平台限制见 [实现说明](docs/implementation.md)，原始需求与剩余范围见 [PRD 进度](docs/prd-progress.md)。Flutter 规范见 [AGENTS.md](AGENTS.md)。品牌素材来自参考站，字体附带 OFL 授权文本。

## 已验证

- 2026-11-04 最新增量：AI 原生页面与导航、Riverpod／外部钱包前台回跳、挑战原文独立确认、双语流式聊天／停止／复制／解释展开、安全历史／草稿与显式 UTC 用量。沿用当前 EOA 或已有 Privy 钱包，不新建钱包；不自动附带账户数据、不执行金融动作。历史损坏保持只读，清空和本地遗忘需独立确认；遗忘不远程撤销。新增 57 项、全量 3268 项测试通过，742 个 Dart 文件格式及静态分析通过，中英文各 1490 条消息。Android arm64 Release 构建成功（45,515,604 字节），AOT 已含 AI 文案；未安装，无真实认证／聊天／个人用量／资金请求或设备工具。iOS 需 macOS／Xcode。见 [实现说明](docs/implementation.md#2026-11-04-ai-原生页面与应用状态层)、[验证记录](docs/reference/assistant-ui-verification.json)、[进度表](docs/prd-progress.md)。以下按增量保留历史状态。

- 2026-11-04 此前增量：AI 当前钱包认证／刷新、服务器身份与绑定、安全会话／历史和 UTC 用量数据层。原钱包签名、无额外钱包，支持有界钱包回跳前台 gate；令牌不凭本地解码授权。独立 native secure storage namespace、按身份／钱包／服务器用户隔离，历史最多 200 条／512 KiB，重启中的流标中断且不自动发送。新增 133 项、AI 专项 214 项／全量 3211 项测试通过，722 个 Dart 文件格式／静态分析通过。仍未接 Riverpod、生命周期／前台回跳、导航及双语聊天页面；APK 未证明包含新 AI 类。Android Release 构建通过、未安装，无真实认证／聊天／个人用量或设备请求。见 [实现说明](docs/implementation.md#2026-11-04-ai-钱包认证与安全会话底层)、[验证记录](docs/reference/assistant-session-verification.json) 和 [进度表](docs/prd-progress.md)。

- 2026-11-04 此前增量：AI 助手协议与聊天底层（尚无 App 页面）。公开配置仅解析 JSON、固定来源／禁止重定向；有界 SSE、中文分片、超时／停止、同编号补全和上下文已实现。新增 81 项、全量 3078 项测试通过，708 个 Dart 文件格式／静态分析通过。认证、安全会话／历史、Riverpod 和双语聊天界面待接入；没有真实认证／聊天／个人额度请求。Android Release 构建通过、未安装；无入口引用，新底层未证明进入 AOT，APK 与前版一致。见 [实现说明](docs/implementation.md#2026-11-04-ai-助手协议与聊天底层)、[验证记录](docs/reference/assistant-chat-verification.json) 和 [进度表](docs/prd-progress.md)。

- 2026-11-04 此前增量：CHANNEL 活动入口／独立前 10 名、注册／钱包连接／净充值任务、UTC 每日签到和里程碑／推荐指标。手动读任务、当前已有钱包独立确认签名、提交前公开意图日志、未知只核对原任务／日期，不重发；官网活动时间过期时阻塞，Vanta Orderly 活动不计 Aster 交易／充值。新增 93 项、全量 2997 项测试通过，701 个 Dart 文件格式／静态分析通过，中英文各 1419 条消息，Android arm64 Release 已构建（45,056,792 字节）。代码与边界见 [实现说明](docs/implementation.md#2026-11-04-channel-活动与任务)，自动测试／构建见 [验证记录](docs/reference/channel-events-verification.json)。只做匿名公开读取，没有真实个人端点／动作 POST／钱包签名或设备工具，APK 未安装，iOS 待 macOS／Xcode。完整 [进度表](docs/prd-progress.md) 已同步，AI 仍未实现。以下为此前增量。

- 2026-11-04 此前增量：Spot／Futures 资产名称／官方 PNG、双语名称搜索、独立失败重试与过期／前后台处理；不改变原资产代码、数量、估值或签名。名称源当前 18 项、有效图标 807 项；缺失名称保留代码。新增 79 项、全量 2904 项测试通过，688 个 Dart 文件格式／静态分析通过，中英文各 1379 条消息；Android arm64 Release 构建通过（44,991,256 字节），见 [验证记录](docs/reference/asset-metadata-verification.json)，未安装。仅匿名公开读取（含只读 public POST），未启动设备或做真实钱包／账户／资金联调。当前 [进度总表](docs/prd-progress.md#当前进度总览2026-11-04) 区分已接入、待实现、协议限制与按要求跳过项。以下为此前增量。

- 2026-11-04 当前增量：同一 EOA 的 Aster 交易授权与权限核对、可选 IP 白名单提现权限；子账户双签名创建／重登切换／冻结解冻／主子四市场方向划转；充值发送与链上回执／平台到账恢复、提现复核／双签名／提交／withdrawId 历史核对。均使用已有钱包，无自动重发。子钱包需已有独立 EOA 并外部签名，充值最低额缺失及私有剩余额度需在 Aster 核实；同一 EOA 自注册、提现 nonce 兼容性和真实资金未验收。新增 162 项、全量 2825 项测试通过，677 个 Dart 文件格式／静态分析通过，中英文各 1370 条消息；Android arm64 Release 已构建（44,860,056 字节）、未安装。测试／构建见 [本轮验证](docs/reference/account-funding-operations-verification.json)，具体边界见 [实现说明](docs/implementation.md#2026-11-04-交易授权子账户管理与实际充提)。按要求不启动设备或安装 APK，iOS 未构建。以下为此前增量记录，当时的“未实现”以最新 [需求进度](docs/prd-progress.md) 为准。


- 普通交易活动：积分页进入 RETAIL 活动列表／详情，支持任务／规则／图片／奖励／排行榜和手动查询参与情况；当前钱包 personal_sign 确认报名，不新建钱包，受理／核实／未知明确区分。Vanta Orderly 活动跳转原网站交易，不映射到 Aster。新增 103 项，全量 2663 项测试通过；635 个 Dart 文件格式和静态分析通过，中英文各 1261 条消息，Android arm64 Release 已构建、未安装。见 [验证记录](docs/reference/trading-events-verification.json)。真实个人接口／钱包／报名 POST／手机及 iOS 未验收，频道专属签到等扩展和 AI 助手仍未实现。

- 积分主页：当前周期／积分池、总榜与分期榜、首 100 条分页；个人积分／历史由用户显式查询，切钱包清空，不创建钱包或签名，未知不补零。Vanta Orderly 积分与 Aster 活动独立。新增 92 项，全量 2560 项测试通过；611 个 Dart 文件格式及静态分析通过，中英文各 1206 条消息，Android arm64 Release 已构建、未安装。见 [验证记录](docs/reference/points-verification.json)。无设备工具、真实个人接口／钱包／RPC／私有／资金请求；个人实际响应、手机及 iOS 待验收。活动列表／详情及报名见后续增量；频道专属扩展和 AI 助手仍未实现。

- USDF／asBNB 公开收益率：Spot／Futures 资产卡支持展开查看来源 APY／日期／分项与条件说明；保留原始数字精度，跨市场共享、失败保留、旧日期／过期提示与前后台暂停。新增 78 项，全量 2468 项测试通过；597 个 Dart 文件格式及静态分析通过，中英文各 1154 条消息，Android arm64 Release 已构建、未安装。见 [验证记录](docs/reference/asset-yield-verification.json)。无设备工具、真实钱包／RPC／私有／资金请求；真机及 iOS 仍待验收。积分主页后续增量见上；普通活动后续增量见上；频道专属扩展与 AI 助手仍未实现，见 [需求进度](docs/prd-progress.md)。

- 现货当前挂单：独立全账户签名读取、Spot 交易对元数据、本地筛选及同范围计数、精确数量／可复制编号；现货 executionReport 合并部分成交／终态，乱序、重放和读取竞态保护，断线仍需显式补读。新增 81 项（映射 39、事件合并 10、签名协议 10、控制器 13、Widget 9），全量 2390 项测试通过；587 个 Dart 文件格式及静态分析通过，中英文各 1139 条消息，Android arm64 Release 构建成功、未安装。见 [验证记录](docs/reference/spot-open-orders-verification.json)。无设备工具、真实钱包／RPC／私有／资金请求；真实授权／原生与 iOS 仍待验收。

- Spot ↔ Futures 内部划转：双向／币种、显式读取、精确额度／Max、独立确认、发送前日志、一次签名提交及双方余额刷新；原钱包成功响应保存，未知结果保留并阻塞新提交。新增 141 项（领域／映射 37、日志 24、签名协议 38、控制器 33、Widget 9），全量 2309 项测试通过；574 个 Dart 文件格式及静态分析通过，中英文各 1126 条消息；Android arm64 Release 构建成功、未安装。见 [验证记录](docs/reference/internal-transfer-verification.json)。无设备工具、真实钱包／RPC／私有／资金请求；原 clientTranId 查询协议、真实权限／划转、手机恢复／布局及 iOS 仍待完成。

- 普通下单／单仓平仓 BBO：LIMIT／STOP／TAKE_PROFIT 可选对手方或同侧一档，保留原方向／减仓／条件条款；发送前日志、原编号精确 peg 查询、schema3 兼容旧恢复记录，未知不重发。新增 60 项，全量 2168 项测试、556 个 Dart 文件格式及静态分析通过，中英文各 1088 条消息；Android arm64 Release 已构建、未安装，见 [验证记录](docs/reference/ordinary-bbo-verification.json)。真实权限／定价／触发／成交及原生均未验收，未请求真实钱包／RPC／私有／资金操作。

- 负 USDT 的 Rebalance：多资产模式下先手动读账户、查看转换风险并确认，重新核对后一次提交；发送前持久化、响应归原钱包、独立读当前账户，未知保留且不重发。多→单模式缺失／负 USDT 均阻塞。新增 84 项，全量 2108 项测试、551 个 Dart 文件格式及静态分析通过，中英文各 1085 条消息；Android arm64 Release 已构建、未安装，见 [验证记录](docs/reference/rebalance-verification.json)。未知请求缺少原 nonce 查询协议，实际提现仍未实现。无设备工具、真实钱包／RPC／私有／资金请求；原生和 iOS 仅记录待验收。

- ERC‑20 精确授权／清零：独立确认、发送前日志、当前 EOA／已有 Privy 钱包发送；原哈希或加速／取消哈希只读核对，规范回执达到至少两个区块确认，未知不重发，退出／切账户后保留原哈希。新增 108 项，全量 2024 项自动测试；Android arm64 Release 已构建、未安装，见 [验证记录](docs/reference/deposit-approval-verification.json)。授权不等于充值；实际充值仍受未知平台额度与到账恢复缺口阻塞。无设备工具、真实钱包／RPC／资金请求；手机布局／钱包回跳／强杀恢复及 iOS 只记录为待验收。中英文各 1056 条消息。

- EOA／Privy 钱包发送底层：当前 EOA 的 Reown 发送权限／链校验及已有 Privy 钱包的原生交易通道，精确金额／费用／nonce、并发拦截，结构化拒绝与未知分开，退出／切钱包后仍保留已返回哈希且不重发。新增 83 项，全量 1916 项测试、522 个文件格式及静态分析通过；Android arm64 Release 成功，见 [记录](docs/reference/wallet-transaction-verification.json)。本项仅记录当时的发送底层；授权业务已由上述增量接通，实际充值与到账仍未完成。未使用设备工具、安装 APK 或请求真实钱包／金融交易。

- 充值交易准备：普通 EVM 路径的当前钱包充值／精确授权／清零编码，手动模拟下一步 Gas、20% 单位预留与原生币金额＋费用余额检查；nonce／区块复核、最早到期、失败保留及中英文布局。新增 100 项，全量 1833 项、515 个文件格式和静态分析通过，中英文各 1024 条消息；Android arm64 Release 构建成功，见 [验证记录](docs/reference/deposit-gas-verification.json)。仅完成只读准备，实际授权／充值提交、回执／到账恢复及平台额度仍缺失；原生 Max 禁用。未使用设备工具、安装 APK 或发送真实 RPC／私有／金融请求。

- Scaled：普通实盘入口支持2–110笔、计价币总额／基础币总量独立输入，等量／递增／递减／随机和等差／等比，首次主字段空白。预览、专用确认和结果每页10笔可查完整计划；计价币精确尾差单独显示，随机方案固定且最终偏差≤10%。沿用当前EOA／已有Privy逐笔复核／签名／原编号查询；失败、未知或停止不续发，重启不恢复未发队列，不提供原子成交保证。新增97项、全量3966项及Android Release通过，未安装或请求真实私有／金融接口，见 [最新合同](docs/reference/scaled-order-alignment-public-contract.json) 和 [验证记录](docs/reference/scaled-order-alignment-verification.json)；[初版记录](docs/reference/scaled-order-verification.json) 保留作历史。

- 附加 TP/SL 的 BBO 主单：限价／条件限价主单支持同侧／对手方 1、3、5、10、20 档，确认显示档位，参考金额不当作成交价；签名查询严格核对 peg，未决日志 schema 2 兼容旧记录，未知结果只查询。新增 56 项，全量 1665 项测试、494 个文件格式及静态分析通过，中英文各 978 条消息，Android arm64 Release 构建成功；见 [验证记录](docs/reference/attached-entry-bbo-verification.json)。当时普通／专用平仓 BBO 尚未接通，现见最新的一档 BBO 增量；各次记录的 APK 均未安装。

- 充值钱包预检查：手动公开读取钱包原生币／代币余额、ERC20 精度及 vault 授权，固定区块并复核；最低额／精度／最小单位／余额校验，代币余额 Max，原生 Max 因 Gas 未估算禁用。新增 78 项，全量 1609 项测试、490 个文件格式及静态分析通过，中英文各 971 条消息；构建及未实测项见 [预检查验证记录](docs/reference/deposit-wallet-verification.json)。实际平台额度／Gas／授权／充值仍未实现，本轮不安装 APK 或真机实测。

- 最新公开提现费用：提现资产卡按市场／网络／币种查询，币种费用与 USD 分开显示，原始 JSON 数字直接保留为 Decimal；30 秒过期、失败保留／重试与路由释放，不需要钱包签名。新增 70 项，全量 1531 项测试、475 个文件格式及静态分析通过，中英文各 941 条消息；构建及待验收见 [费用验证记录](docs/reference/funding-fee-verification.json)。实际提现仍未实现，本轮不安装 APK 或真机实测。

- 充提目录与提现额度只读：Spot／Futures 的公开币种及三条 EVM 网络目录、显式签名读取提现信息，分开显示币种数量、美元日限额和费用快照。新增 59 项，全量 1461 项测试、464 个文件格式及静态分析通过，中英文各 930 条消息；构建见 [验证记录](docs/reference/funding-info-verification.json)。实际充提／授权／划转仍未实现，真实钱包资格、原生布局与 iOS 均待验收；本轮不安装 APK 或真机实测。

- 子账户签名列表：账户菜单新增手动签名读取、名称／精确可复制 ID／主子标记、搜索、停止等待与失败保留，读取不会切换交易账户。新增 39 项，全量 1402 项测试、447 个文件格式及静态分析通过，中英文各 893 条消息；构建见 [验证记录](docs/reference/subaccount-list-verification.json)，本轮不安装或真机实测。列表未返回地址／冻结状态，创建、切换、冻结及划转仍待实现，真实授权和 iOS 待验收。

- 资产参考估值与小额过滤：新增 42 项，全量 1363 项自动测试、格式及静态分析通过，中英文各 877 条消息；Spot／Futures 逐资产 USD／BTC 及钱包参考汇总，使用实际指数汇率，Spot 精确 >0.0001 BTC 筛选，缺价／陈旧保留。完整 Portfolio 总值仍待补齐；构建见 [验证记录](docs/reference/asset-valuation-verification.json)。按用户要求不安装 APK、不做真机实测，待验收已记录；Linux 无 Xcode，iOS 未构建。

- 合约单一／多资产模式：678项全量测试、格式和静态分析通过，中英文各593条消息。全账户签名预读模式与仓位，启用多资产前显示逐仓敞口及余额阻塞；确认后提交并签名查询，未知结果只查询，与其他合约设置互斥。Android Release（42.8 MB）已安装真机，中英文、登录和横屏检查通过；真实授权账户与iOS待验收。详见 [实现说明](docs/implementation.md#合约单一多资产模式)。
- 合约单向／双向持仓模式：629项全量测试、格式和静态分析通过，中英文各569条消息。读取模式及全部合约仓位／挂单，存在任意仓位或挂单时阻塞；账户级确认后签名提交并单独查询，未知结果只查询，与杠杆和保证金模式互斥。Android Release（42.7 MB）已安装真机，中英文、登录弹窗及横屏检查通过；真实授权账户和iOS待验收。详见 [实现说明](docs/implementation.md#合约单向双向持仓模式)。
- 合约逐仓／全仓切换：584项全量测试、格式和静态分析通过，中英文各543条消息。签名预读配置／挂单，存在持仓或挂单时提示阻塞；确认后提交并签名查询，未知结果仅查询。与杠杆设置互斥，配置有效期计入第二次签名时间。Android arm64 Release（42.6 MB）已安装真机，检查中英文入口、说明、登录弹窗和横屏；真实授权模式切换和iOS待验收。详见 [实现说明](docs/implementation.md#合约逐仓全仓配置与切换)。

- 合约杠杆配置与修改：539项全量测试、格式检查和静态分析通过，中英文各519条消息。当前钱包显式签名读取交易对档位与配置，确认后提交并另签名查询结果；结果未知仅查询，不重发修改。Android arm64 Release（42.6 MB）已构建安装，真机中英文、登录入口和横屏检查通过；真实授权钱包修改和iOS尚待验收。详见 [实现说明](docs/implementation.md#合约杠杆配置与修改)。

- 仓位保证金与收益率：506项全量测试、格式检查和静态分析通过，中英文各494条消息；Android arm64 Release（42.6 MB）已安装真机，检查中英文、登录入口和横屏滚动。区分逐仓钱包分配、估算初始保证金和ROE，公开标记价更新估算，未知杠杆及过期仓位明确提示。真实授权仓位和iOS仍待验收。详见 [实现说明](docs/implementation.md#仓位保证金与收益率估算)。

- 合约余额与仓位事件同步：485项全量测试、格式检查和静态分析通过，中英文各488条消息；Android arm64 Release（42.6 MB）已安装真机。逐资产更新绝对余额、逐交易对与持仓方向更新数量；处理零仓位、乱序和读取竞态，事件缺少的可用余额及风险字段明确待核对。真实授权监听和iOS仍待验收。详见 [实现说明](docs/implementation.md#合约余额与仓位事件同步)。

- 合约挂单事件同步：434项全量测试及相关最终Widget回归、格式检查和静态分析通过，中英文各481条消息。Android arm64 Release（42.5 MB）已安装Android 12真机，检查中英文、监听面板、登录入口和横屏。已校验事件更新部分成交、剩余量、新订单及终态移出；保留下单时间／单位，防止旧事件、REST及撤单核对覆盖较新状态。完整列表仍需钱包签名核对，真实授权监听和iOS尚未验收。详见 [实现说明](docs/implementation.md#合约挂单事件同步)。

- 合约账户变更监听：403项测试、格式检查和静态分析通过，中英文各475条消息；Android arm64 Release（42.4 MB）已安装真机并检查中英文、登录入口和横屏。支持当前钱包显式签名开启／续期、有效期内免签重连、到期及前后台释放；初始实现仅失效快照，订单、余额与仓位事件合并已由上方增量实现；真实授权监听仍待验收。详见 [实现说明](docs/implementation.md#合约账户变更监听)。

- 仓位标记行情与估值：377 项测试、格式检查和静态分析通过，中英文各460条消息；Android arm64 Release（42.4 MB）已安装真机。独立公开Mark流按已读仓位数量估算名义价值／浮盈亏，保留快照原值，断线及仓位过期明确标注。匿名实测BTC／ETH／SOL新标记价及暂停恢复；真实授权仓位与iOS仍待验收。详见 [实现说明](docs/implementation.md#仓位公开标记价与估值)。

- ADL 自动减仓队列：353 项测试、格式检查和静态分析通过，中英文各446条消息；Android arm64 Release（42.4 MB）已安装真机，检查中英文展开区、登录和横屏滚动。支持独立签名读取、四格档位、持仓模式关联、未知与历史提示。真实授权读取及 iOS 仍待验收。详见 [实现说明](docs/implementation.md#adl-自动减仓队列)。

- 仓位风险快照：331 项测试、格式检查和静态分析通过，中英文各437条消息；Android arm64 Release（42.4 MB）已安装真机，检查中英文、登录和横屏。支持服务端标记／强平价、逐仓余额、负余额记录及交易对筛选。真实授权读取、ADL、实时同步与仓位操作仍待完成。详见 [实现说明](docs/implementation.md#仓位风险快照)。

- Spot 历史：310 项测试、格式检查和静态分析通过；中英文各422条消息，Android arm64 Release（42.4 MB）已安装真机。订单、逐笔成交和资产流水分别读取，支持日期分段、上限提示、失败重试与停止等待。真机检查中英文入口、登录和横屏；真实私有读取及 iOS 仍待验收。详见 [实现说明](docs/implementation.md#spot-历史记录)。

- 全部撤单：271 项测试、格式检查和静态分析通过，Android arm64 Release（42.0 MB）已安装真机。逐交易对签名撤单后核对，支持停止后续提交；拒签／未知结果停止队列，重查不重复撤单。未登录入口和提示已目视检查，真实钱包授权及撤单仍未实测；详见 [实现说明](docs/implementation.md#全部撤单)。

- 合约挂单及逐笔撤单：243 项测试、格式检查和静态分析通过，Android arm64 Release（42.0 MB）已安装 Android 12 真机。撤单后单独签名查询最终状态；超时保留订单、阻止重复撤单并提供状态重查。真实钱包授权及撤单尚未实测，iOS 仍需 Xcode；详见 [实现说明](docs/implementation.md#aster-合约挂单与逐笔撤单)。

- 最新多语言复核：中英文各 332 条消息，222 项测试、格式检查和静态分析通过；Android arm64 Release 构建成功（42.0 MB）并安装真机，确认英文页面及重启恢复语言。入口为顶部语言图标；第三方 Reown 钱包选择弹窗仍为英文。详见 [多语言实现说明](docs/implementation.md#多语言)。

- Spot 账户只读：完整 202 项测试、格式化和静态分析通过，Android arm64 Release 构建成功（41.9 MB）。现货与合约快照、签名请求独立，使用同一钱包；官方 sapi 时间接口匿名实测通过。真机验证中英文、Spot 标签保留、登录入口及横屏；真实 Spot 私有读取仍待授权钱包验证，详见 `docs/reference/spot-account-android.json` 和实现说明。

- 全量合约与分类：184 项测试、格式化和静态分析通过，Android arm64 Release（41.9 MB）已安装。真实接口验证 567 个合约及两路报价流，真机验证全部／热门／空分类、TQQQ 搜索和图表／盘口联动。记录见 `docs/reference/market-catalog-live.json`、`market-categories-android.json`。

- Aster 账户只读通路：完整 172 项测试、格式化和静态分析通过，Android arm64 Release 构建（41.9 MB）并安装成功。真机验证中英文账户页、登录入口和演示数据隔离；真实 Aster 授权／读取仍未实测。详见 `docs/reference/aster-account-android.json`。

- 本轮多语言与 EOA：130 项测试、格式化和静态分析通过，Android arm64 Release 构建成功（41.8 MB）并安装至 Android 12。真机验证语言切换／重启恢复／跟随系统，以及 EOA 钱包列表打开／取消／重试；真实钱包 SIWE 验签和真实邮箱登录尚未实测，iOS 构建需 macOS。

- 行情选择器已接入两路全市场实时报价，包含按 symbol 增量合并、乱序／迟到快照保护、离线保留、更新时间和前后台释放。完整 113 项测试、静态分析及 Android arm64 Release 构建通过（35.4 MB），真机已确认报价持续变化，截图 `docs/reference/market-quotes-{live,updated}-android.png`；匿名网络验证为 `docs/reference/market-quotes-live.json`。仍有其他 PRD 功能未完成，见实现说明。

- 历史 Privy 首轮验收：原生邮箱登录／会话／内嵌钱包流程和行情选择器通过格式化、静态分析、完整 104 项测试及 Android arm64 Release 构建（35.3 MB）。最终包已安装 Android 12 真机，检查登录页、100 合约公开行情和自选筛选；截图见 `docs/reference/privy-login-android.png`、`market-selector-android.png`、`market-favorites-android.png`。该轮未进行真实邮箱验证码登录，尚无外部 EOA 或 Aster 账户入口；后续已增加 EOA 和只读通路，真实授权／读取与实盘充提仍未验收。Linux 环境未验证 iOS 构建。

- 行情价格改为自适应小数精度：标记价、盘口、成交和 OHLC 不截掉第二个非零小数位，极小价格不再按固定一位显示为零；盘口点价保留精度，演示订单按 Aster tick／step 校验。完整80项测试、静态分析及Android Release构建通过，已安装Android12真机并验证1000PEPE价格显示与盘口填单。

- 图表扩展为15周期、11种图形、可编辑指标参数、4种价格坐标和拖到左侧自动分页历史；移除常驻历史加载按钮。73项测试、静态分析及Android Release构建通过；更新后的相关16项Widget测试也通过。

- 周期切换采用淡化旧图和中央三点加载过渡，修复失败状态被自动重试持续覆盖的问题。格式化、静态分析、60项测试及Android arm64 Release构建通过，正式包已在Android12真机验证；截图见 `docs/reference/chart-loading-android-{pending,loaded}.png`。
- 平台已收敛为 Android／iOS，移除 Web 工程、构建产物和对应运行命令。原生应用的行情接口仅使用 Aster，身份认证通过 Privy 原生 SDK；主字体和品牌图片随应用打包，无需 Web 渲染 CDN。
- 当前平台调整通过格式化、静态分析、48项测试和 Android arm64 Release 构建（30.6 MB）。已在 Android 12 真机安装并检查 Aster 行情与原生页面，截图见 `docs/reference/aster-android.png`；详情见 [实现说明](docs/implementation.md) 的「移动端平台验收」。
- 当前环境为 Linux，iOS 编译和签名需在 macOS／Xcode 完成。
- 图表加载已改为按币种／周期请求，取消100币种后台预热及其他周期预取；测试覆盖首次仅一个请求／订阅、空闲期间不预加载、冷周期加载、缓存首帧显示、快速切换隔离、失败回退及全局并发限制。格式化、静态分析、58项测试及Android Release构建通过，已在Android 12真机验证周期／币种切换及当前图表1/1进度；截图与记录为 `docs/reference/chart-demand-android*`，详情见实现说明的「周期切换性能验收」及「停留后切换的HTTP连接与实测」。

## 历史验证

以下记录中的浏览器截图和 Web 构建均为取消 Web 支持前的历史证据，不属于当前支持平台或验收要求。

- Aster 迁移时格式化、静态分析、48 项单元／Widget 测试及 Web 构建通过。Chrome 实测100个交易对的历史／实时行情、周期切换、ETH选择和深度图联动，记录见 `docs/reference/aster-live-verification.json`、`aster-interactions.json`。

以下为切换 Aster 之前的记录。历史 Android 安装包和截图不作为 Aster 接口的验证证据。

- `flutter analyze`、37 项单元 / Widget 测试、Web 构建与 Android Debug / Release 构建。
- Chrome 实际加载 100 个交易对历史，并收到全部 100 个交易对的实时更新（观察期 1,818 条 K 线消息，无页面异常），证据见 `docs/reference/live-verification.json`。
- 已在 Android 12 真机安装并运行，显示行情缓存 100/100、真实图表与底部导航；单指纵向滑动已在真机确认，可切换指标和深度，并进入全屏查看。当前布局截图见 `docs/reference/compact-android.png` 与 `compact-android-indicator-sheet.png`。
- Android 真机与 Chrome 移动触控均已实际验证双指张开/合拢；截图见 `docs/reference/pinch-android-before.png`、`pinch-android-expanded.png`、`pinch-android-contracted.png`，Web 对照见 `pinch-web-*.png`。自动测试覆盖先拖动/长按/纵移再双指、缩放后抬指、取消后重试和全屏。
- iOS 工程已生成；当前环境为 Linux，未进行 iOS 编译或真机验证。
