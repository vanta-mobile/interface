## 2026-11-17 全部改动提交前验证

- 范围：当前交易与合约设置界面、资金操作自动核实、Privy 提现收款地址、公开行情与持仓量、QA 修复、资源、接口契约和版本号等全部待提交改动。
- `dart format --output=none --set-exit-if-changed lib test integration_test test_driver` 分两次检查共 1349 个文件，无格式改动；`flutter analyze --no-pub` 无问题；`git diff HEAD --check` 通过。
- `flutter test --no-pub --reporter expanded`：5982 项通过、3 项跳过、零失败。环境提示缺少 Linux Rive 动态库，未影响测试结果。
- 未启动应用、执行原生构建或进行真机／模拟器验证。

## 2026-11-17 前端版本号更新为 0.0.5+5

- `pubspec.yaml` 的版本号由 `0.0.4+4` 更新为 `0.0.5+5`；Android 与 iOS 沿用 Flutter 版本配置，版本名为 `0.0.5`，构建号为 `5`。
- 验证：设置模块格式检查 16 个文件无改动；`flutter analyze --no-pub` 无问题；`flutter test --no-pub test/features/settings` 38 项全部通过。测试期间有 Linux Rive 原生库缺失提示，未影响测试结果；未启动应用、执行原生构建或设备验证。

## 2026-11-17 安静行情的公共推送不再每 35 秒断线重连（TAS-5047）

问题：AAPLUSDT 等成交清淡的品种（美股盘前），输入数量后 Est. Liq. Price／Margin／Max 显示“—”，Long／Short 下方没有“≈数量”；SOLUSDT 正常。原因：`AsterMarketStream` 35 秒收不到任何消息就判定连接失效，主动断开重连。实测 AAPL 的 `bookTicker` 45 秒只推 5 条、`aggTrade` 0 条，订阅约每 37–40 秒断一次。每次断开都把盘口、成交价置为未确认，下单预估要等重连、REST 再确认，约 1.3–2.8 秒不可用。

- 心跳（`aster_stream.dart`）：连接空闲 20 秒时发送 `{"method":"LIST_SUBSCRIPTIONS","id":2}`，服务器回复（`{"id":2,"result":[...]}`）会重置空闲计时。35 秒内连心跳回复都没有时，仍按原逻辑断开重连。
- 重连退避：原来只有收到行情事件才把延迟重置为 1 秒，安静品种连续重连时延迟会翻倍到 20 秒。现在收到订阅确认或心跳回复也会重置。
- 边界：只改公共行情 WebSocket 生命周期，未改价格新鲜度规则、REST 轮询、私有账户流和下单校验。
- 测试：`test/features/market/aster_stream_test.dart` 新增 3 项（有心跳回复时 2 分钟不断开、心跳无回复 35 秒后重连、只收到订阅确认也重置退避），这 3 项在改动前的代码上均失败；`flutter test test/features/market` 182 项、`test/features/portfolio` 3138 项全部通过，`flutter analyze` 无问题。全量 `flutter test` 5981 项通过、1 项失败（`portfolio_actions_test` “portfolio opens market close without submitting”），该项单独运行时修复前后都通过，属于全量并发下的偶发失败。线上实测：改动前 4 分钟内 AAPL 断开 3 次，改动后 3 分钟 0 次。未在设备上运行。

## 2026-11-17 Trailing Stop 下单表单与确认弹窗按设计稿对齐

依据：Figma 07.01 Trailing（331:61868）、双向持仓开/平（331:62046、331:62225）、二次确认（331:72693 做多、331:70675 做空）。

- 表单（`LiveOrderTrailingControls`）：去掉 Material 输入框、说明文字、参考价行和单独的价格类型下拉框，改用下单区的 `EmbeddedInputBox`/`EmbeddedTextInput`。“回调幅度”卡片右侧是 `%` 单位和 `1%｜2%` 快捷选项，与输入值相等的选项高亮，点击后填入；“激活价格”卡片右侧复用 `TriggerBasisSelector`（标记/最新）。数量、滑杆、可用余额、仅减仓、保证金卡片等其余部分沿用公共组件，双向持仓的开/平按钮同样沿用公共组件，未改动。
- 确认弹窗（`OrderConfirmationTerms`）：Trailing 订单不再显示“订单类型”和“追踪价格类型”两行。行顺序改为交易对/方向 → 回调幅度 → 委托价格（市价）→ 委托数量。用户填写了激活价时，在回调幅度后增加“激活价格”行，显示为“价格类型 价格 计价币”（按用户要求保留，设计稿中没有这一行）。
- 删除不再使用的文案：`liveTrailingHint/Rate/RateBounds/Basis/Activation/Default/ActivationDirection/Buy/Sell/EstimateHint`、`liveOrderTriggerReference`（中英文）。回调幅度/激活价越界仍由已有的 review 校验提示（`liveTrailingRateInvalid` 等）。
- 验证：`dart format`、`flutter analyze` 无问题；新增 `live_order_trailing_controls_test` 4 项（设计字段、快捷选项填值与高亮、禁用时不响应、确认弹窗行顺序和激活价行的有无），`flutter test test/features/portfolio` 全部通过。按用户要求，未做真机验证。

## 2026-11-17 Privy 登录提现可填写收款地址

依据：Aster 官网邮箱/Privy 登录的提现表单要求输入收款地址（线上 `DepositAndWithdrawDialogBase-lU_7YplV.js`，`autoWithdraw` 资产签名 `Action.destination` 并调用 `/bapi/futures/v1/private/future/aster/user-withdraw` 的 `receiver`）。我们使用的 `/fapi/v3/aster/user-withdraw` 是同一提现的 API 入口，官方文档（https://github.com/asterdex/api-docs/blob/master/demo/aster-deposit-withdrawal.md “withdraw by fapi[v3] [evm] [futures]”）对 `receiver` 只要求与签名一致。

- 内嵌钱包（Privy，`WalletKind.embedded`）：提现页在网络下方显示“接收地址”输入框（`FundingAddressField`），必填。地址须为非零 EVM 地址；大小写混合时须符合 EIP-55 校验和（`withdrawal_receiver.dart`），否则显示“请输入有效的 EVM 收款地址。”并禁用提现。确认页显示可复制的完整收款地址。
- 外部钱包（Reown）：不显示输入框，仍只提到自身地址；仓库层忽略传入的地址。
- 签名 `destination`、请求 `receiver`、本地记录 `terms.receiver` 都用收款地址；`user`、`signer`、签名钱包和记录 `address` 仍是当前登录钱包。本地记录不再要求 `receiver` 等于签名地址。
- 未验证：服务端是否对 fapi v3 的任意 `receiver` 另有限制（文档未写，未用真实账户提交）。
- 测试：`withdrawal_repository_test` 新增内嵌钱包收款地址签名/请求/记录、5 种无效地址在任何请求前被拒、外部钱包忽略传入地址；`funding_withdraw_screen_test` 新增输入框必填、校验和错误提示、确认页展示与传递地址，以及外部钱包无输入框。

## 2026-11-17 下单不再要求最新成交价在 10 秒内

问题：成交清淡的币种 10 秒内没有新成交时，下单表单显示“No recent trade price is available. Refreshing automatically.”，USDT 数量换算、比例滑杆、Est. Liq. Price／Margin／Max 和 Long／Short 都不可用。PRD 中没有这条要求；Aster 官网前端（2026-11-11 缓存的 bundle）直接用价格 store 中的 lastPrice／markPrice 计算可开数量，不检查成交时间。

- 最新成交价不再受“交易所成交时间距今 10 秒”限制（`order_reference_prices_repository.dart` 中 `_fresh(..., eventAge: false)`）。只要 10 秒内经推送或 REST 轮询确认过（安静行情每 5 秒轮询一次 `/fapi/v3/trades`，同一笔成交会刷新接收时间），就作为当前最新价使用。
- 保留的限制：连接断开／连接中、时钟未校准、成交时间超前服务器 10 秒以上、REST 结果比已有成交更旧、价格无效或缺失；盘口与标记价格仍按原 10 秒规则。
- 测试：`order_reference_prices_repository_test`、`order_reference_polling_test` 中 4 项按新规则更新（旧成交仍可用，接收超过 10 秒才失效）。market、portfolio、trade、core 测试 3622 项全部通过；静态分析仅剩未改动的 `reown_session_liveness_test.dart` 既有警告。未在设备上运行。

## 2026-11-17 QA 回归问题修复（0.0.4 / 2004 人工复核报告）

依据 QA 人工复核报告与 Notion「前端核对1」。会改变布局的裁剪问题（QA-005 周期选择器、QA-006 持仓卡、QA-008 委托价输入框）先与设计确认，确认后的实现见下方对应条目。

- QA-001 行情详情：进入或切换交易对时立即读取 `ticker/24hr`，并订阅该交易对 `@ticker` 推送持续更新 24h 高低价、成交额与涨跌幅（直接用接口 `P`），不再沿用目录加载时的快照（`market_sync.dart`）。
- QA-007 充提网络（2026-11-17 设计确认）：未手动选择时，外部钱包默认选中钱包当前网络，该网络充提不支持（如 Base）或未连接时显示「选择网络」；邮箱内嵌钱包默认 BNB Chain。手动选择优先。充值或授权发送交易时，钱包网络与所选网络不一致会像开启交易那样先请钱包切换，切换成功才发送；用户拒绝或钱包不支持时提示「请在钱包中切换到 {网络} 后重试。」（新增 `fundingSwitchNetwork`），不发送任何交易（`funding_selection.dart`、`privy_identity_repository.dart`）。注：WalletConnect 会话的网络在钱包内被切走时连接会失效、需要重新连接，这是现有行为。
- QA-009 / 分段委托按 Figma 10.01–10.17（node 331:47119）重做：不再打开独立页面（原页面的手动读取按钮与签名次数说明随之去掉），作为交易页下单区的一种订单类型内嵌显示，复用下单区的下单配置与自动续期：最低/最高价格、订单数量、数量与单位选择、数量分布与等差/等比切换、可用余额、隐藏委托、仅减仓与 GTC（按 PRD 子单只有 GTC 或 HIDDEN）、多空保证金卡片；预览与下单确认为底部弹层，数量分布说明弹层使用设计稿曲线资源（`assets/trade/scaled-*.svg`）。参数未成立时不显示「预览」；数量超出最大可下数量时数量框红框并提示「最大数量为 …」：PRD 未给公式，按 Aster 官网前端（`isOverMaxAmount` 的 Scaled 分支）取交易对单笔上限与该方向限价可开数量（复用主下单表单容量，按计划均价计算）的较小值，整组总数量与之比较，USDT 单位按上限 × 均价提示，只减仓不检查；与官网一致，只在点击做多或做空时校验该方向，超出时数量框红框并提示该方向的最大数量、不进入确认，改动输入后提示清除；后台续期期间沿用上次算出的上限。子单草稿新增只减仓与有效期；确认后全部子单成交受理才关闭弹层，失败按子单原因提示。切换到分段委托时主下单表单隐藏并保留输入。原独立分段委托页面（`scaled_order_screen/form/options/review/status/details.dart`）、只测旧界面的两个 widget 测试及 34 条仅旧页面使用的文案已删除（`scaled_order_embedded.dart`、`scaled_order_sheets.dart`、`scaled_order_confirmation.dart`）。与 PRD 有出入、按设计稿保留的：默认单位为币（PRD 为报价币）；无随机偏差输入和重新随机按钮、预览不列名义金额与未分配金额、确认不列钱包与账户配置、提交后不逐笔列出结果（结果以 toast 提示，子单见挂单列表）。
- QA-011 / toast：用户操作的成功提示替换当前失败提示；后台通知传 `preserveFailure` 保持原规则。所有 toast 显示关闭按钮，自动关闭的 toast 外圈倒计时圆环随 3 秒缩短，减少动态效果时为静态圆环。
- QA-012 / QA-013 全部平仓、全部撤单：确认前后快照被替换或过期时不再静默返回。平仓静默重读持仓，集合不变即执行，变化则按新数量重新确认；撤单按已确认范围重读后执行。
- QA-014 持仓刷新：有交易授权、App 在前台且持仓或挂单可见时，每 15 秒静默重读持仓与挂单，使交易所侧触发的成交在当前会话出现。自动接入账户推送的方案会让下单数据反复过期，已放弃。
- QA-019 分段委托：子单校验失败时提示子单序号、价格、数量和原因（新增文案 `scaledChildInvalid`）。
- QA-016 钱包签名等待：60 秒响应上限只在 Vanta 位于前台时生效。到点时用户仍在钱包里则不判超时；回到 Vanta 后再等最多 10 秒，期间钱包的签名或取消优先，仍无响应才提示「钱包未返回签名结果」。文案不变，所有钱包签名场景共用（`reown_signature_request.dart`）。auth、assistant、authorization 测试通过。
- QA-005 积分周期选择器：按设计确认，选择器宽度随文案自适应（上限为行宽的 70%），由左侧标题省略（`points_period_section.dart`）。
- QA-006 持仓卡：按设计确认，盈亏和仓位价值（USDT）固定 2 位小数，开仓价、标记价、强平价最多 4 位小数（新增 `TokenAmountFormatter.formatRoundedFixed`），小数点后有 4 个及以上 0 的价格（0 < |价格| < 0.0001）改用科学计数法，尾数最多 4 位小数，如 `1.2346e-5`（新增 `formatScientific`）；三列价格与盈亏行在空间不足时等比缩小，滚动动画不再越出列宽。
- QA-008 委托价输入框：± 按设计稿 331:48603 改为两个 14px 图标、间距 8px，占宽由 56px 降为 36px；空间不足时仍隐藏 ±。设计稿中 ± 相对整个输入框垂直居中，但 360dp 中文下会把标题挤成「价格（USD...」，因此改为与价格同一行，标题占满宽度。限价与 Stop Limit 共用。
- QA-018 免打扰：后端 8f0bcadc75 已支持显式 null 清除，契约同步到该提交。关闭后回查 `/v1/push/status` 若仍返回时段，提示「免打扰关闭未生效，请稍后重试。」（新增文案 `pushQuietHoursNotCleared`），不再静默回弹。

真机验证（2026-11-17，M2007J17C）：分段委托在 ASTERUSDT 上验证了子单错误提示（第 1 笔子单的价格、数量与原因）、预览弹层（子单价格、数量与占比、平均价格、保证金）、等差/等比切换、数量分布说明弹层、高级设置与下单确认弹层（点取消，未实际提交）。显示密度临时设为 480 模拟 360dp，验证后已恢复：QA-005 积分页「Season 1 · Epoch 18」完整显示；QA-006 SOL 持仓卡盈亏 -0.66、仓位价值 10.86、开仓价 $76.816、标记价 $72.3906，三列无重叠、ROI 完整（科学计数法无实际小价格仓位，仅单元测试）；QA-008 BTC 限价 64340 与 ± 同行、标题完整，+ 按 tick 步进为 64340.1，限价止盈止损同样正常；QA-007 充值页默认选中 Arbitrum（钱包当前网络未在 App 外核对），未实际发送充值，切链未验证；QA-018 推送设置需钱包签名授权，未验证。

验证：相关文件格式化检查通过，`dart analyze lib` 无问题；全量 `flutter test` 5,987 通过、3 跳过。真机（M2007J17C，显示密度临时设为 480 以模拟 360dp，验证后已恢复）验证了 QA-001（BTC、SOL 详情与公开接口一致并持续更新）和 toast 倒计时圆环与手动关闭。其余项需连接钱包，且全部平仓、全部撤单涉及真实资金操作，尚未真机验证。

## 2026-11-17 下单、撤单与资金操作：不再出现“结果未知”

按 AGENTS.md 新规则处理剩余功能。用户确认：没有服务端查询接口的操作（内部划转、再平衡、提现、子账户冻结/划转、没有交易哈希的充值）统一显示「网络异常，请稍后在记录中确认」作为错误，且不阻止再次提交。风险是交易所其实已执行时，用户手动重试可能重复操作；应用本身仍不会自动重发。

- 下单（主表单、快捷下单、确认弹窗、平仓、止盈止损、附加止盈止损）：发出后结果未确认时，`LiveOrderController` 自动按原 clientOrderId 再查询一次（设备授权签名）。确认则按成功显示；仍未确认则作为错误（查询给出的原因）显示，不再有 `unknown` 状态、提示或“签名查询结果”按钮。去掉 `LiveOrderController.recheck`、`LiveOrderState.needsRecheck`、`OrderSubmissionKind.unknown`、`PositionOrderOutcome.unknown`；删除只为此显示的 `LiveOrderStatus`、`AttachedOrderStatus` 及其专用的摘要组件。恢复日志（order recovery journal）照旧在内部保留未确认记录。
- 分批下单、批量平仓：每个子单发出后若未确认，自动再查询一次；发出后抛出异常也先查询。仍未确认则该项显示错误并停止后续子单，不重发。去掉手动重查按钮与 `recheck()`。
- 撤单、批量撤单：撤单后若未确认，自动查询一次；仍未确认显示为错误，不锁住订单或其他操作（自动读取、改单、止盈止损列表均不再因此禁用）。改单：发出后的查询失败时，toast 显示该查询错误，内部结果改名为 `unverified`。
- 逐仓保证金调整：调整后若未确认，自动按原编号再查询一次历史；不再因存在未确认记录而阻止读取或新的调整；记录列表去掉“核对原调整编号”按钮，未确认记录显示统一提示。
- 内部划转、再平衡、钱包操作日志（提现、子账户）：不再因同一钱包已有未确认记录而拒绝新的提交（仅拒绝完全相同的记录）；存储解码也不再要求每个钱包最多一条未确认记录。删除首页／资金页的未确认提醒卡片（`InternalTransferRecoveryNotice`、`RebalanceRecoveryNotice`）。
- 充值：链上确认中的交易（已有哈希）仍需先完成，再发起下一笔；没有哈希的记录不再阻止新充值。
- 交易授权：授权结果未确认时自动查询一次授权状态。
- 文案：`rebalanceUnknown`、`internalTransferUnknown`、`walletOperationUnknown`、`depositSubmissionUnknown`、`depositApprovalUnknown`、`marginAdjustUnknown`、`authorizationUnknown` 统一为「网络异常，请稍后在记录中确认」／“Network error. Check the records later to confirm.”。`apiErrorText` 对这类 key 仍在该提示后附上具体原因（超时、连接失败或服务端信息）。

验证：相关 provider、仓库、widget 测试改为断言“自动查询一次、仍未确认显示错误、不重发、不阻塞”，新增“仍未确认即为错误”的用例；测试替身增加 `checkResult`。`flutter analyze` 无问题，格式检查无改动。全量 `flutter test`：5969 项通过、3 项跳过、4 项失败。4 项失败都在查找成功 toast 文案（“Cache cleared”“Order submitted”“Order modified.”“Exact adjustment found…”），源于另一会话正在修改的 `app_toast.dart`，已告知对方，本次未改动。按要求未启动 App。

## 2026-11-17 合约设置：不串行、无“结果未知”、加载骨架屏、开启交易授权入口

规则已写入 AGENTS.md：不在界面暴露“结果未知”状态和手动“签名查询结果”按钮；已发出的写请求由应用自动核实，期间按钮保持加载，最终只显示成功或失败（核实本身失败时显示具体错误）。互不相关的操作不再相互阻塞，只禁止同一操作重复提交。数据未读到时显示局部骨架屏，不显示多余文案或“刷新设置”按钮。需要交易授权而未开启时，按钮显示“开启交易”并跳转授权页。

- 串行：`SymbolSettingsActivity` 改为记录进行中的操作（`running`），`acquire` 不再拒绝。删除 `owner`／`unresolved`／`recoveryBlocked`／`blocks()`，以及 `SymbolSettingsNotice` 提示（“请先处理尚未完成的合约设置”）。保留 `epoch`：任一写请求发出后，之前读到的确认数据仍标记为过期。下单、额度、快捷下单、分批、批量平仓、逐仓保证金、再平衡、内部划转、策略执行及自动续期中由此产生的互相阻塞全部去掉。同一功能的待确认记录（如未拿到回执的内部划转）仍只阻止该功能再次提交。充值钱包流程（`FundingTransactionActivity`）不在本次范围：外部钱包一次只能处理一个签名请求，仍保持串行。
- 结果未知（四个合约设置及多资产开通）：写请求发出后结果不明，会在同一操作内自动再查询一次（设备授权签名，不弹钱包）。查到即按成功或“查询结果与目标不同”显示；仍失败则显示该错误。设置保持可用，不再锁定，也不提供手动重查；不会自动重发写请求。删除 provider 的 `needsRecheck`／`recheck()` 及相关界面。
- 开启交易授权：新增 `modeAccessProvider`／`ModeAccessAction`，替换原来的 `ModeReadAction`。按账户状态依次为：检查中（按钮转圈）、连接钱包／创建钱包（打开账户弹窗）、开启交易（跳转 `EnableTradingScreen`）、就绪（显示 Confirm）。只有就绪时才自动读取，没有设备授权时不再提供绕过授权的手动读取。保证金模式、杠杆、资产模式、持仓模式和多资产开通共用这套规则。
- 骨架屏：首次读取完成前，选项卡的勾选框、杠杆数值和剩余可开名义价值显示骨架；读取失败时显示错误，下拉刷新可重读。
- 保证金模式：有持仓或挂单时，另一个选项禁用（变暗、不可点击），下方只显示一条合并原因：“当前合约有持仓或挂单，平掉持仓并撤销挂单后才能切换保证金模式。” 持仓模式按同样方式处理。
- 删除不再使用的 `FuturesAssetModeScreen`／`FuturesPositionModeScreen` 及其 Form／Status，相关 label 和打开函数移入对应 sheet 文件。逐仓保证金的存储故障原先只靠全局锁拦截，现在由该功能自己的 `prepare` 检查。

下单与资金部分见下一节。

验证：重写 `symbol_settings_activity_test`（并发、自动核实、核实失败不阻塞、身份切换）、四个设置 provider 测试及其签名仓库测试、保证金模式／杠杆弹窗 widget 测试（骨架屏、开启交易跳转、合并阻止原因、自动核实成功或报错、改保证金时杠杆弹窗不受阻塞）、`mode_settings_sheet_test`，并把其余依赖旧阻塞语义的用例改为断言“不阻塞”。删除针对已移除页面的两个测试文件。`mode_settings_design_test` 的 5 张设计稿截图在提供交易授权后逐像素一致。全量 `flutter test`：5972 项通过、3 项跳过、零失败；`dart format` 无改动；`flutter analyze` 无问题。按要求未启动 App。

## 2026-11-17 保证金模式／杠杆改为设计稿底部弹窗，选择页金额加 $

- 选择页成交量与持仓量前加 `$`：公开目录只收录 USDT 计价的永续合约（`AsterInstrument.quote` 默认 USDT），两项都是 USDT 金额，按 PRD「USDT 市场按产品美元展示约定加 $」显示。
- 交易页标题的最高杠杆徽标：已签名读取的档位优先，没有时用公开 brackets 的最大值，未登录也显示。
- 保证金模式（Figma 331:54982）：原独立页面（读取按钮、下拉选择、确认对话框）换成 `PositionMarginModeSheet` 底部弹窗，复用资产模式弹窗的 `showModeSettingsSheet`／`ModeSheetBody`／`ModeOptionCard`。标题「{symbol} Margin mode」、仅对当前合约生效的说明、Cross／Isolated 两张带说明的选项卡、底部 48 高 Confirm（`ModeAction(large: true)`）。点选只改本地选择；Confirm 时如读取已过期或不是该合约，先重新读取，再签名修改。选择与当前一致时直接关闭；查询核实为目标模式后关闭。有持仓／挂单时在选项下方给出原因且不提交；结果未知时保留弹窗和选择，按钮换成「签名查询结果」，不会重新提交。
- 杠杆（Figma 331:54742）：原独立页面（数字输入框＋确认对话框）换成 `PositionLeverageSheet`：标题「{symbol} Adjust leverage」、−／+ 步进器（图标从设计稿下载为 `assets/trade/minus.svg`、`plus.svg`）、滑杆、名义价值卡片、提示文字、Confirm。滑杆直接复用下单数量的 `MainOrderAmountSlider`：拖动连续，五个点和下方的 1x／四分位／最大值刻度只作参考，任意整数杠杆都能选中，不会吸附到刻度。上限沿用 `PositionLeverageContext.maximum`（档位最大值与 125 取小）。剩余可开名义价值＝允许所选杠杆的档位中最大的 notionalCap，减去该合约现有持仓的名义价值，不低于 0。持仓名义价值取自读取杠杆时已在请求的签名 positionRisk 中各方向 `notional` 的绝对值之和（对冲模式两侧相加），没有新增请求。positionRisk 的 `maxNotionalValue` 只对应当前杠杆，不能用于其他杠杆，所以没有采用；`notional` 缺失时显示 —。设计稿中的「Learn more」没有链接目标，未实现。错误（如保证金不足）用设计稿的红底提示框显示接口给出的原因。
- 两个弹窗打开时：有有效设备交易授权就自动读取（新增 `symbolModeSettingsLoadProvider`，与资产／持仓模式相同的规则，不会弹钱包）；否则底部显示「读取／登录」按钮，读到之后才出现 Confirm。未登录时杠杆显示公开档位的默认值和范围，不能修改。多资产开通流程中「切换为全仓」也改为打开该弹窗并预选 Cross。删除旧的 `PositionMarginModeScreen`／`Form`／`Status` 与 `PositionLeverageScreen`／`Status`。

验证：重写 `position_margin_mode_widget_test`（10 项）和 `position_leverage_widget_test`（8 项）：设计文案与选项、未登录只打开登录、选择当前值直接关闭、提交一次且忙碌时禁用、核实后关闭、未知结果只查询不重提、持仓／挂单阻止、过期读取在签名前重读、签名拒绝的错误、步进器／刻度、滑杆拖到两个刻度之间可选中该处的杠杆（如 11x）、剩余名义价值（97,500＝100,000−2,500；100x 时 7,500）、窄屏大字号与横屏中文。`position_leverage_mapper_test` 新增持仓名义价值（对冲两侧相加、缺字段为未知）与剩余值不低于 0。同步更新多资产开通、订单恢复、资产／持仓模式和后台续期测试中对旧页面的引用；多资产测试改为按固定时长推进帧，因为弹窗下层的进行中指示器会持续动画。全量 `flutter test`：5985 项通过、3 项跳过、零失败；`dart format` 检查 1359 个文件、零改动；`flutter analyze` 无问题。按要求未启动 App、未在真机上与设计稿目视比对。

## 2026-11-16 样式问题合集（TAS-5043）修复

来源：Notion「样式问题合集」。第 1 条的未登录初始配置（Cross／20×／Multi-assets 与 PRD 的 Isolated／10x／单资产不一致）按用户要求本轮不改。

- 交易页方向卡片：「预估强平价／保证金／最大」框只有上圆角，下面的按钮四角圆角，接缝处露出框的直角并与按钮重叠。按钮改为只保留下圆角，与上方框拼成一个整体；未登录（`TradeOrderPending`）与已登录（`MainOrderDirectionCard`）两处一致。
- 邮箱验证码错误：Privy SDK 报错形如 `apiError(httpCode: 422, error: …, description: "…")`，原先整串脱敏后显示。`failureFromPrivy` 现在优先取 `description` 中的服务端文案（如 “Invalid email and code combination”），仍经过同样的脱敏规则；错误分类 key 不变。
- 交易对选择页：
  - 去掉「N / M 个永续合约」、行情连接状态、更新时间和 Reconnect 这一块（设计稿没有）。按 PRD 本期不做分类标签，也不请求分类配置。行情离线时下拉刷新会重连行情流，失败字段仍显示 —。`MarketQuoteStatus` 已删除。
  - 表头改为可排序的 Symbols／Funding rate、24h volume／Open interest、Price／24h change，各带排序箭头（`MarketListHeader`）。点击依次为降序、升序、恢复交易所目录顺序；Symbols 首次点击为升序。缺失值在两个方向都排最后，相同值保持目录顺序；精确搜索命中仍排在最前。默认（未选排序）时行情更新不会重排列表。
  - 行高从 64 降为 48，收藏星标列宽 44 降为 28（点击高度仍为 44）。
  - 第二行在资金费率前显示最高杠杆徽标，取公开 brackets（`publicLeverageProvider`，未登录可用）各档 `maxOpenPosLeverage` 的最大值；没有数据时不显示。徽标组件与交易页标题共用（`MaxLeverageBadge`）。
  - 成交量下方显示持仓量：公开 `GET /fapi/v3/openInterest?symbol=` 返回基础币数量，乘以标记价换算为 USDT。标记价来自已有的 `premiumIndex` 快照与 `!markPrice@arr@1s` 行情流（`MarketQuote.markPrice`），与资金费率同组做版本保护。Aster 没有全市场持仓量接口，所以只有屏幕上的行才请求；`OpenInterestRepository` 最多 4 个并发请求，排队中被取消的请求不会发出。行离开屏幕后结果保留 30 秒，在屏幕上的行每 30 秒重读一次。读取失败或缺少标记价时显示 —，不显示 0。下拉刷新会等待持仓量与杠杆档位重读结束。
  - 搜索框点击后键盘闪退：键盘弹出使页面高度低于 500，选择页在全屏布局和紧凑滚动布局之间切换，重建了搜索框，导致失焦。判断高度时现在加回键盘高度，键盘开合不再切换布局。
- 交易页：
  - 交易对名称的点击区域只覆盖图标、名称和下面的标签，右侧空白不再打开选择页。
  - 保证金模式／杠杆／资产模式三个按钮：已登录时后台续期几乎一直在进行，其账户读取也占用 `order` 租约，三个按钮因此一直处于禁用状态。现在后台续期期间按钮可用；点击时先停止后台续期（`stopBackground`，同时释放租约），再打开设置页。前台读取、下单或其他设置进行中时仍禁用。
  - 点击合约页空白处收起键盘；按钮、输入框等自身处理点击的控件不受影响。

边界：持仓量接口未收录在所查 V3 文档中，USDT 口径（数量 × 标记价）与官网显示值是否完全一致仍需联调核对。最高杠杆徽标是交易所公布的上限，不是账户当前杠杆。未改动下单、签名或任何财务写入流程。

验证：新增或更新的测试：排序（方向、缺失值、平局、持仓量估值、循环切换）；`OpenInterestRepository` 的并发上限、按顺序交接、全部结束后才算完成、负值／交易对不符视为格式错误、排队中取消不发请求；选择页显示徽标与持仓量、点击表头排序；键盘占用 500 高度时搜索框保持同一实例且不失焦（撤掉修复后该用例失败）；交易页空白处既不打开选择页，也会取消焦点；后台续期期间设置按钮可点，点击后停止续期、释放租约并打开保证金模式页；Privy `description` 提取。`widget_test` 与性能场景随删除的数量行和新增的持仓量读取更新了断言／替身。全量 `flutter test`：5980 项通过、3 项跳过、零失败；`dart format --set-exit-if-changed lib test` 检查 1362 个文件、零改动；`flutter analyze` 无问题。测试环境仍提示缺少 Linux Rive 动态库。按要求未启动 App、未在真机／模拟器上目视验收，未做平台构建。

## 2026-11-16 WalletConnect 前台恢复时的 relay 重连竞争

排查“开启交易”签名提示 `The client closed with pending request "irn_subscribe".`：`requestReownSignature` 和 Reown AppKit 1.9.0 均监听 `resumed` 并调用 `reconnectRelay()`，网络恢复、心跳和 socket-close 恢复也可触发重连。实际使用的 reown_core 1.5.1 在 `_connect` 入口只检查已连接状态，未合并正在建立的连接；第二次连接在 JWT／socket 准备后会关闭第一条 JSON-RPC 连接，使其未完成的订阅失败。用 SDK 原版的真实 RelayClient／JSON-RPC 配合可控的本地 socket，两个回归用例在修复前分别复现“建立两条连接”和完全相同的 `irn_subscribe` 错误。这证明该竞争能够产生此报错；没有该次设备日志，尚不能确认用户当次错误的唯一原因。

修复：去掉应用签名监听器重复的前台重连，保留前后台签名 watchdog；在 `third_party/reown_core` 保留已锁定的 1.5.1 源码和许可证，通过 `dependency_overrides` 应用补丁，避免改动本机 pub cache。仅 `lib/relay_client/relay_client.dart` 改变运行行为：在首个 await 前占用连接任务，所有并发入口共用该任务；断开时使旧的准备任务失效，已完成的晚到 socket 立即关闭；连接前等待进行中的断开清理；忽略旧 peer 的关闭回调；成功／失败后释放任务，保留 SDK 原有的连接超时恢复，显式断开后不再恢复。补丁边界和升级移除条件见 `third_party/reown_core/PATCHES.md`。供应商文件沿用原 SDK 的职责划分，未为压缩行数拆改协议实现；其余 104 个库文件逐字节保持原样。

边界：只修改 WalletConnect WebSocket 连接生命周期；未改 HTTP 请求、钱包签名载荷、财务写入／未知结果恢复策略，不自动重放签名、订单、转账或授权写请求。每个 core 独立维护任务，不在不同钱包客户端之间共享会话或凭据。真实网络中断、中继拒绝连接仍可产生订阅失败。

验证：`flutter test --no-pub test/features/auth test/features/authorization test/features/funding/funding_wallet_return_test.dart test/features/funding/deposit_wallet_repository_test.dart` 共 429 项通过、3 项既有跳过、零失败（测试环境提示缺少 Linux Rive 动态库）。其中 `reown_relay_connection_test.dart` 10 项通过，覆盖并发重连、待响应订阅保留、JWT／socket 准备期间断开、断开清理与新连接交错、连接超时恢复／断开后停止恢复、失败后显式重试、SDK socket-close 恢复与前台重连合并、两个 core 隔离；既有签名测试确认钱包返回后不重复重连，超时、取消、账号切换和晚到签名结果保护保持有效。`dart format --output=none --set-exit-if-changed lib test` 检查 1313 个文件、零改动，补丁文件格式检查通过；全仓 `dart analyze --fatal-infos` 与单独分析供应商补丁文件均无问题。未启动 App、未在真机／模拟器上验证、未执行 Android／iOS 构建；真实钱包切换及网络关闭码仍需设备联调确认。

## 2026-11-13 清理确认过时的失败测试

按用户要求核查并删除剩余过时失败用例：

- 删除 `main_order_refresh_widget_test.dart` 的 7 项用例：依赖已移除的独立页面、读取／取消按钮及自动错误提示；当前刷新／保留输入／错误恢复由内嵌表单和 provider 测试覆盖。
- 删除 `position_risk_screen_test.dart` 的 5 项用例：仓位风险独立页面和入口已移除；保留仓位风险 mapper、provider 及当前仓位卡片测试。
- 从 `main_order_capacity_panel_test.dart` 仅删除 1 项要求生产表单显示显式额度读取按钮的用例，并移除该用例专用的挂载分支；保留其余 15 项额度面板测试。
- 删除临时 `real_response_audit_test.dart`：其 `/tmp` 响应夹具已过时，缺少当前仓库读取必需的 `/fapi/v3/ticker/price`、`/fapi/v3/ticker/bookTicker` 和 `/fapi/v3/commissionRate` 响应，单独复跑仍失败。保留使用确定性夹具的 `signed_live_order_repository_test.dart` 和 `signed_main_order_capacity_repository_test.dart`，未读取或提交临时私有响应数据。

本次只清理测试及其专用辅助分支，未修改应用行为。验证：`flutter test --reporter expanded` 耗时 3 分 40 秒，5668 项通过、3 项跳过、零失败；`dart format --output=none --set-exit-if-changed lib test` 检查 1312 个文件、零改动；`dart analyze --fatal-infos` 剩 1 条既有 info（`position_margin_mapper.dart:26` 缺少 if 语句花括号），无 error／warning。测试环境仍提示缺失 Linux Rive 动态库；未启动应用或进行平台构建。

## 2026-11-13 全量测试复跑与过时用例核查

运行 `flutter test --reporter expanded`：耗时 3 分 47 秒，5668 项通过、3 项跳过、15 项失败。按用户要求删除仅包含过时 K 线周期切换用例的 `test/features/trade/timeframe_switch_test.dart`，该用例仍断言显示“历史行情 · 重连中”。该全量结果来自删除前启动的测试。

其余失败集中在 `main_order_refresh_widget_test.dart`（7 项）、`position_risk_screen_test.dart`（5 项）、`main_order_capacity_panel_test.dart`（1 项）和 `real_response_audit_test.dart`（1 项）；单独复跑这 4 个文件仍有 14 项失败、15 项通过。

核查下单刷新用例：旧测试直接把 `LiveOrderScreen` 挂载为独立页面，并寻找已移除的 `live-order-page`、`live-order-read`、`live-order-read-stop` 和 `live-order-refresh-error`。当前组件只渲染内嵌表单，需要父页面提供 Material 和滚动／刷新容器；旧测试还要求自动显示价格／过期错误，与当前后台刷新保持安静、方向按钮触发后显示错误的行为不符。本轮仅核查，保留该测试文件。

复核当前刷新行为：`main_order_refresh_provider_test.dart`、`silent_order_refresh_widget_test.dart`、`order_polling_review_widget_test.dart`、`order_entry_gate_test.dart` 和 `automatic_order_refresh_test.dart` 共 61 项通过，覆盖账户／额度刷新、取消、保留输入、后台错误及方向按钮显式重试。删除 K 线用例后，格式检查 1315 个文件、零改动；静态分析仍有此前记录的 6 项 info。测试环境提示缺失 Linux Rive 动态库；未启动应用或执行平台构建。

## 2026-11-13 应用版本 0.0.3+3

将 `pubspec.yaml` 的应用版本从 `0.0.2+2` 调整为 `0.0.3+3`。Android 和 iOS 继续读取 Flutter 版本配置，版本名为 `0.0.3`、构建号为 `3`；仅修改版本元数据。

验证：`dart format --output=none --set-exit-if-changed lib test` 检查 1316 个文件、零改动；`flutter test test/widget_test.dart --reporter compact` 共 14 项通过，运行时提示 Linux Rive 原生动态库缺失。`dart analyze --fatal-infos` 报告 6 项既有 info，位于未在本次修改的 `position_margin_mapper.dart` 和 `real_response_audit_test.dart`；未修改这些无关代码。未启动应用、进行设备检查或执行 Android／iOS 构建。

## 2026-11-13 K 线页签按 Figma `chart` 组件（12.08，1222:58604）重做

上一条（同日）只改了交易页的 K 线面板，K 线页签（`CandleChart`）仍是旧样式。本次：

- 行组件抽到 `chart_controls.dart`：`ChartTimeframeRow`、`ChartOhlcRow`、`ChartIndicatorRow`、`ChartActionBar`。K 线页签与交易页面板共用，各自按设计稿给行高（页签 36/28/36/48，面板 36/24/32/36）。Key 统一沿用原 K 线页的 `timeframe-*`、`chart-more-timeframes`、`chart-quick-*`、`chart-price-scale`、`chart-expand`，新增 `chart-type`、`chart-indicators`、`chart-ohlc`。
- K 线页签非全屏改为通栏组件：周期行 → OHLC → 画布（手机主图 285、宽屏 360，副图／成交量 104）→ 指标快捷行 → 底部操作栏（价格坐标、图表类型、指标、全屏）。默认 MA + VOL 时组件总高 551，与设计稿一致。全屏按钮从周期行右侧移到底部操作栏；全屏页本身不变。
- 删除 `ChartAxisControls`、`ChartIndicatorShortcuts`、`_CandleLegend`；其中「加载更早历史中／已到最早」提示和 Heikin Ashi、相对坐标说明一并去掉（价格坐标弹窗仍有说明）。保留：历史加载失败的重试行、缺口／行情失败提示行（仅出现时占位）。按用户要求去掉组件下方的数据来源行（Aster · USDT 及其行情详情弹窗），删除 `chart_market_status.dart`；K 线页不再显示行情来源和同步状态，行情失败仍由画布失败态和提示行展示。用户确认同时取消「界面明确显示 Aster 与 USDT」的要求（见当前实现范围）。随后删除不再使用的文案 `chartSource`、`chartSourceShort`、`marketSource`、`poweredBy`、`sync`、`syncing`、`closedCandle`、`formingCandle`、`chartHint`（中英 ARB、`strings.dart` 映射，已重新生成本地化代码）。
- 图表配色（`ChartCanvas`，两处共用）：坐标与时间文字白色、网格 #232526、MA5/10/20 为黄 #E9A83C／绿 #00E4AB／灰 #959B9E、成交量柱 30% 透明、成交量 MA10 灰，最高／最低标注白色；指标快捷选中色改为涨绿 #0FB276（交易页面板同步）。
- 当前价标签改为实心涨跌色圆角徽标、白色 11px 粗体：在本地 `third_party/k_chart_plus` 补丁新增可选 `KChartColors.nowPriceTextColor`，未设置时保持原绘制。

验证：新增 `trade_kline_panel_test`「K 线页签 551px」1 项；`chart_options_test`（周期／价格坐标改为弹窗选项）、`widget_test`（底部操作栏恢复图表类型与指标入口；画布上限 400→480）、`chart_future_space_test`、`chart_gestures_test`（全屏按钮移到底部，点击前先滚动到可见）按新结构更新；`trade_design_widget_test` 中 K 线页 TradeIcon 数量 4→8（新增操作栏 4 个图标）。K 线／交易相关 28 个测试文件逐个运行全部通过（含 `quick_order_widget_test`、`deep_link_navigation_test`）。改动文件 `dart format`、`flutter analyze lib/features/trade test/features/trade test/widget_test.dart` 无问题；k_chart 补丁文件无新增告警。
未启动应用、未在真机/模拟器上目视核对。

## 2026-11-13 交易页 K 线（快捷下单）按设计稿 12.01 重做，并补回图表设置弹窗

依据 Figma「12｜K线图」12.01 及 12.02–12.07。

- `TradeKlinePanel` 改为设计稿结构（通栏）：周期行 1m/5m/15m/1h/4h/1d/More▾（More 打开周期弹窗，选中长周期时占用 More 位）→ OHLC 行（10px，标签白色、数值按涨跌着色）→ K 线画布（主图 164px + MA 图例 12px，开启 VOL／副图时各加 62px）→ 指标快捷行 MA/BOLL/VOL/MACD/KDJ/RSI/WR/CCI（选中为主题绿）→ 底部操作栏（「价格坐标: 普通▾」、图表类型、指标、全屏）。去掉原「时间」分时入口，改由图表类型弹窗选 Line。
- 面板不再强制 MA、无副图、无成交量，与 K 线页签、全屏共用 `chartPreferencesProvider`；共享偏好默认主图指标由 none 改为 MA（12.01、12.08 设计稿均默认选中 MA），成交量默认仍为开。快捷行切换逻辑收进 `ChartPreferences.shows`／`ChartPreferencesController.toggle`，K 线页签的 `ChartIndicatorShortcuts` 同用。
- 新增弹窗（统一 `showModeSettingsSheet` + `ModeSheetBody`，带背景模糊）：
  - `chart_settings_sheets.dart`：图表类型（12.02，11 种 `KChartType`）、选择周期（12.03，列出全部 `candleIntervals`，比设计稿多 5m/1w/1M）、价格坐标（12.04，百分比／基准100 附说明）。点选即生效并关闭。
  - `chart_indicator_sheet.dart`（12.05）：主图 None/MA/BOLL、副图 None/MACD/KDJ/RSI/WR/CCI 芯片、成交量开关（复用 `SettingsSwitch`）、指标参数入口；选择为草稿，点「确认」才写入，关闭则丢弃。
  - `chart_parameter_sheet.dart`（12.06/12.07）：指标下拉（默认当前主图指标），各参数输入框显示范围，按 `IndicatorParameterSpec` 校验，MACD 快线须小于慢线；「确认」写入并关闭，失败保留输入。
- `TradeOptionRow` 新增 `unselectedMark`，图表设置列表不画未选中的空框（与设计稿一致），其他调用不变。新增 `TradeColors.chipSelected`／`chipSelectedText` 两个色值。
- 新图标取自设计稿 SVG：`assets/trade/chart-style.svg`、`chart-indicators.svg`、`chart-fullscreen.svg`、`chart-caret.svg`、`chart-select-caret.svg`、`chart-chevron.svg`。新增文案 `chartSelectTimeframe`、`chartSettingsConfirm`（中英）。
- 未改动：K 线页签（`CandleChart`）的布局与控件样式、全屏页、行情订阅。已知问题（未处理）：共享弹窗关闭按钮的 tooltip 使用 `close` 文案，中文为「平仓」。

验证：新增 `trade_kline_panel_test` 3 项（布局高度与快捷行、三个列表弹窗生效、指标草稿确认/关闭丢弃及参数校验）。`widget_test` 中「MA 快捷」用例因默认改为 MA 调整为切换 BOLL。`widget_test`、`chart_future_space_test`、`chart_gestures_test`、`order_book_test` 及 `test/features/trade` 下 22 个文件逐个运行全部通过；合并成一次运行时超时，出现 90 项失败（集中在 `trade_design_widget_test`、`market_loading_widget_test`，加载阶段失败），单独重跑均通过。改动文件的 `dart format`、`flutter analyze` 无新增问题（全仓剩余 94 项均在他人未提交的 portfolio 测试等文件）。未启动应用、未在真机/模拟器上核对视觉效果。

## 2026-11-13 iOS Siri／快捷指令（App Intents）

与 Android 的 Gemini AppFunctions 对应。所有 intent 只打开 `vantaapp://` 链接，由 Dart 深链统一校验；不读取账户数据，不下单、不撤单、不划转、不签名。

- `ios/Runner/VantaAppIntents.swift` 定义 4 个 intent，均为 `openAppWhenRun`：
  - `OpenVantaPageIntent`：参数为 AppEnum，8 个页面，ID 与 `vantaapp://open?feature=` 及 Android `shortcuts.xml` 一致；
  - `OpenVantaMarketIntent`：市场，可选 K 线／下单、委托／持仓／资产；
  - `PrepareVantaOrderIntent`：限价或市价、价格、数量、USDT 或币；描述写明只预填、需用户选方向、确认并签名，预填订单在 App 内强制弹确认框；
  - `AskVantaAIIntent`：问题最多 2000 字，只填不发。
- `VantaShortcuts`（AppShortcutsProvider）提供英文 Siri 短语，`zh-Hans.lproj/AppShortcuts.strings` 提供对应中文短语（如「用 Vanta 打开持仓」）。`zh-Hans.lproj/Localizable.strings` 翻译全部 58 个标题、选项、同义词和错误提示。
- 链接构造与 Android `VantaLinks` 规则一致：对 UTF-8 做 RFC 3986 百分号编码，`&`、`=`、`+` 不会破坏查询串。价格和数量只接受纯十进制，非法时抛出本地化错误让用户重说。打开方式为 `UIApplication.open(vantaapp://…)`，交给 App 自己的 URL 处理；`app_links` 7.2.2 实现了 UIScene 回调，并在 Flutter 开始监听前缓存链接（`pendingLinks`），冷启动不丢失。
- `project.pbxproj` 为手工登记（本机无 Xcode）：Runner 源码加入 Swift 文件，两个 `.strings` 作为 `zh-Hans` 变体组加入资源，`knownRegions` 增加 `zh-Hans`。已检查括号配平，8 个新 ID 各定义一次且均被引用。
- 验证：`agent_links_test` 新增跨平台一致性检查，读取 Swift 源码，核对页面、账户区、视图、订单类型、数量单位的取值与 Dart 解析器及 `shortcuts.xml` 一致，链接参数名一致，且每条中文短语都含 `${applicationName}` 并对应一条 Swift 英文短语；`test/features/deep_link` 全部通过。另用脚本核对 Swift 中 58 个面向用户的字符串都有中文翻译、`.strings` 语法正确且无重复键。**iOS 未编译、未运行**：本机为 Linux，没有 Xcode，Swift 语法、App Intents 元数据提取、pbxproj 能否被 Xcode 打开、Siri 中文短语识别均未验证，需要在 macOS 或 iOS CI 上构建后再确认。

## 2026-11-13 修改仓位止盈止损后交易页下单表单下方出现订单详情文字

- 原因：仓位止盈止损（以及平仓弹窗）通过共享的 `liveOrderProvider` 提交，提交后 intent／result 留在全局状态里。交易页嵌入的 `LiveOrderStatus(compact: true)` 只要有 intent 或 result 就渲染独立下单页的整块状态（交易对、地址、客户端订单号、触发条件、成交结果等）。
- 修复：compact 模式只在未知结果待核对（`needsRecheck`）时显示，保留原有核对按钮和恢复流程；已结算的成功或失败订单不再在交易页和 K 线页显示，反馈仍由确认弹窗和 toast 负责。独立下单页（非 compact）行为不变。
- 测试：新增 `live_order_status_compact_test`（3 项）：compact 隐藏已结算订单、非 compact 保留订单详情、compact 保留未知结果核对按钮。改动前第一项失败，改动后全部通过。相关的嵌入表单、快捷下单、附带止盈止损、下单门槛等 14 个测试文件共 131 项通过；`flutter analyze` 该文件无问题。未启动应用，未做真机或模拟器检查。

## 2026-11-13 Gemini（AppFunctions）与 Google 助理（App Actions）入口

两者都只负责跳转和预填，全部经由已有的 `vantaapp://` 深链进入 App，由 Dart 深链解析统一校验；不读取账户数据，不下单、不改单、不撤单、不划转、不签名。仅 Android；iOS 未做。

- Gemini（AppFunctions，Android 16+）：依赖 `androidx.appfunctions:appfunctions:1.0.0-rc01`，并通过 KSP `com.google.devtools.ksp:2.3.13` 运行 compiler；版本与写法对照了官方 release notes 和 android/appfunctions 官方示例（同为 AGP 9 内置 Kotlin + KSP 2.3.13）。`BaseVantaAppFunctionService`（`@AppFunctionServiceEntryPoint`，具体类 `VantaAppFunctionService` 由 KSP 生成）声明 6 个函数：`openFutures(symbol?, view=trade|chart, section=orders|positions|assets)`、`prepareFuturesOrder(symbol, orderType=limit|market, price?, quantity?, quantityUnit=quote|base)`、`openPortfolio`、`openPoints`、`openNotifications`、`askVantaAi(question?)`。KDoc 即函数描述，写明下单函数只预填、由用户选方向、确认并签名。每个函数返回显式指向 `MainActivity` 的 `ACTION_VIEW` `PendingIntent`（`FLAG_IMMUTABLE | FLAG_ONE_SHOT`），由用户点开，不会交给 `vanta://` 的 Privy 回调页。链接由纯 Kotlin 的 `VantaLinks` 生成，按 RFC 3986 对 UTF-8 做百分号编码；只预先拒绝 agent 能当场改正的输入（空币对、非纯十进制的价格／数量、超过 2000 字的问题），拒绝时抛 `AppFunctionInvalidArgumentException`；币对存在性、tick／step 精度、不覆盖用户输入、强制确认框等规则仍由 App 内既有逻辑负责。Manifest 声明服务（`BIND_APP_FUNCTION_SERVICE`、`tools:targetApi=36`）与 `app_functions_metadata.xml`，后者写给 agent 的操作说明（只开页面、不得声称已下单）。按 beta01 的改名使用 `appfn:instructions` 属性（官方示例仍写 `description`）。
- Google 助理（App Actions）：在 `MainActivity` 上挂 `@xml/shortcuts`。`OPEN_APP_FEATURE` 通过 inline inventory 把 8 个功能（futures、chart、orders、positions、portfolio、points、assistant、notifications）及其中英文同义词映射到 `vantaapp://open?feature=<id>`；必需的兜底 intent 为 `vantaapp://open`，Dart 端打开首页。`GET_THING` 映射到 `vantaapp://futures?symbol=…`，走合约列表校验，未知市场保持当前币对。entity 快捷方式不带 intent 和 label，按官方说明不会出现在桌面长按菜单。官方资料中 `OPEN_APP_FEATURE` 只列了英语／西班牙语／葡萄牙语，中文同义词仅为将来准备。需要上传 Play Console（内部测试即可）后才生效。
- 新增深链路由 `vantaapp://open?feature=…`；未知、缺失、重复或编码错误的 feature 一律打开首页。
- 验证：Dart 端 `flutter analyze`（deep_link）无问题，`test/features/deep_link` 18 项通过。其中 `agent_links_test` 与 Kotlin 的 `VantaLinksTest` 断言同一批字面链接（含中文与 `&`、`?` 的编码），并读取 `shortcuts.xml` 与中英文 `assistant_actions.xml`，校验每个 shortcut ID 都有对应功能、每组同义词在两种语言中都存在且不超过 20 条。新增 XML 均已检查格式正确。**Android 构建（经用户同意执行）**：直接运行 `./gradlew` 在本机连 `help` 都失败（The settings are not yet available for build），与本改动无关。Flutter 调用 Gradle 时会额外带 `--project-cache-dir` 和 Kotlin 持久目录（Nix 环境需要）。按 Flutter 的参数运行 `:app:testDebugUnitTest`，并跳过被他人进行中的 Dart 改动卡住的 `compileFlutterBuildDebug`（`spotSideBuy` 等本地化键缺失、`position_tpsl_screen` 参数不匹配）。结果在 `checkDebugAarMetadata` 失败：AppFunctions 要求 compileSdk 37，查 Google Maven 上 1.0.0-alpha10 到 rc01 的 AAR 元数据，`minCompileSdk` 均为 37。本机 Nix Android SDK 只有 android-31/34/35/36。临时把 AppFunctions 依赖和服务类移出构建后（结束后已原样恢复并逐字比对一致），资源合并（shortcuts.xml、同义词、元数据 XML）、manifest 合并、Kotlin 编译均通过，`VantaLinksTest` 4/4 通过。之后用户安装了含 `android-37.0`／build-tools 37.0.0 的 Nix SDK，App 的 `compileSdk` 改为 37（`targetSdk` 不变，运行时行为不变；本机 `local.properties` 的 `sdk.dir` 已指向新 SDK，该文件不入库）。完整依赖下重跑 `:app:testDebugUnitTest` 构建成功：AAR 元数据检查通过，KSP 生成了 `VantaAppFunctionService` 和 `vanta_app_function_service.xml`，后者包含全部 6 个函数、KDoc 描述和 9 个枚举取值约束；合并后的 manifest 含该服务、`BIND_APP_FUNCTION_SERVICE`、`app_metadata` 和 `android.app.shortcuts`；`VantaLinksTest` 4/4 通过。**CI 镜像也需要提供 android-37 平台**，否则 CI 的 Android 构建会失败。也未在设备上用 `adb shell cmd app_function list-app-functions --package exchange.vanta.app` 或 Android Studio 的 Google Assistant 插件验证。Gemini 实际调用还需要通过 AppFunctions EAP 审核。

## 2026-11-13 系统推送点击跳转并标记已读

通知中心列表保持原样（点击仍进详情页）。只改系统推送的点击。后端需要在推送 `data` 里加的字段已整理到 Notion「接口联调」第三节，目前尚未提供。

- 来源：`PushOpenSource` 封装 `FirebaseMessaging.getInitialMessage`（冷启动）与 `onMessageOpenedApp`（后台唤起），只取 `data`。只有 Firebase 初始化成功时 `main` 才提供它，测试和无推送环境下为 null，什么都不做。`pushOpenRouterProvider` 从 App 启动就开始监听，避免丢失冷启动那次点击。
- 解析（`PushNotificationOpen.fromData`）：`kind`、`id`、`type` 必填，且 `kind` 与 `type` 的对应关系和收件箱接口一致（只有 ANNOUNCE/MAINTENANCE 是 broadcast）。event 还必须带 `event_key` 和 `address`（`0x` 加 40 位十六进制，统一转成小写）。交易类事件必须带大写的 `BTCUSDT` 形式 `symbol`。`id` 只接受不带前导零的正整数。任一字段缺失或不合法，就只打开通知中心、不标已读，所以格式错误的推送不会标掉别的通知或别的账号的通知。资金数据从不从推送内容读取。
- 跳转走现有深链：`deepLinkInboxProvider.deliver`。FILL/LIQUIDATION/MARGIN_CALL 跳到该币对合约页的「持仓」，ORDER/TRIGGER 跳到「当前委托」，FUNDING/TRANSFER 跳到资产页，ANNOUNCE/MAINTENANCE 跳到通知中心（接口没有按 ID 取单条通知，打不开详情）。币对仍要经过合约列表校验。
- 新增深链参数 `vantaapp://futures?panel=orders|positions|assets`：通过一次性的 `futuresAccountRequestProvider` 让合约页底部的账户区切到对应 Tab，并滚动到可见位置。Tab 仍是页面自己的状态，所以正常切换底部导航时依旧回到默认 Tab。
- 标已读：`pushNotificationReadProvider` 暂存请求，等 Vanta API 会话就绪、且会话地址与当前钱包一致后（等待恢复、签名、切换钱包的过程），再调用收件箱的 `markReadTarget`：事件按 `event_keys`，公告按 `broadcast_up_to`。这复用了已有的幂等写入和角标刷新，不需要新接口。事件的 `address` 与当前钱包不一致时直接丢弃请求，换回原钱包也不会补标。公告属于所有人，标给当前登录用户。已知已读的不重复请求。为此 `ApiNotificationRepository.markRead` 增加了 `target` 参数（原 `entry` 参数保留）。
- 验证：`flutter analyze lib` 只剩既有的 `position_margin_mapper` info。新增测试覆盖：推送解析（9 种类型的跳转与已读目标、22 种缺失或非法载荷）；路由（冷启动点击先跳转、等对应钱包会话就绪才标、切换期间地址不一致时等待、只标一次、其它钱包丢弃且不再复活、公告标给当前用户、无字段推送只开通知中心）；收件箱 `markReadTarget`（未加载条目、已加载条目、公告游标、已读不重复）；外部请求切到持仓 Tab 并滚动到可见、用户之后仍可切换；`panel` 解析与导航。notifications 全部测试、深链、下单预填及合约页账户区相关测试共 234 项通过。未在真机上收发推送，后端字段也尚未提供，因此端到端效果未验证。

## 2026-11-13 应用内深度链接（vantaapp://）

为后续接入 Google 助理／Gemini、推送跳转与 iOS 快捷指令准备统一的外部导航入口。

- Scheme：`vantaapp://`。Privy SDK 0.15.0 把 `appUrlScheme: 'vanta'` 拼成不带 host 的 `vanta://` 作为 OAuth 回调（反编译 `RealLoginWithOAuth` 确认；回调参数为 `privy_oauth_code`／`privy_oauth_state`），所以 `PrivyRedirectActivity` 必须声明整个 `vanta` scheme。原先 `MainActivity` 的 `vanta` + `wallet` 钱包回跳与它重叠，Android 可能弹出选择框或把钱包回执交给 Privy。因此 `vanta` 只留给 Privy：外部钱包（Reown）回跳改为 `vantaapp://wallet`（`WalletConfiguration.redirect`，`WalletRedirectHandler` 由该常量取 scheme/host 校验），与导航共用 `vantaapp`，按 host 区分，深链解析不认 `wallet` host。Android `MainActivity` 只保留一条 `vantaapp` intent-filter，iOS `CFBundleURLSchemes` 为 `vanta`（Privy）与 `vantaapp`。应用未上线，没有已配对会话需要迁移；Privy 与 Reown 后台无需改配置。开发机上的钱包若曾连过 Vanta，需要先断开再重连，才会拿到新回跳地址。
- 路由：`futures`（`symbol`、`tab=chart|trade`）、`portfolio`、`points`、`assistant`（`prompt`）、`notifications`。host 即页面；path 只能为空或 `/`；带 userInfo/端口、超过 8192 字符、未知 host 一律忽略。可选参数格式不对（重复、编码错误、取值非法）时只丢弃该参数，页面照常打开。
- `symbol` 接受 `ETHUSDT`／`eth-usdt`／`ETH/USDT`／`ETH`，统一成 `ETHUSDT`，并且必须出现在 `instrumentsProvider` 合约列表里才会切换；列表读取失败、15 秒超时、期间来了新链接或用户自己换了币对，都保持当前市场。
- `prompt` 去掉首尾空白后最多 2000 字符，超长整条丢弃（不截断）。等 AI 会话已认证、历史已读完且处于空闲状态后才填进输入框，**只填草稿、不发送**；输入框已有内容时不覆盖；用户先离开 AI 页签则取消预填。
- 安全边界：链接只能选择页面、币对和 AI 草稿，不携带下单方向、数量、价格，不触发任何签名或写操作。
- 时序：`VantaApp` 启动即订阅 `app_links`，链接先放进 `deepLinkInboxProvider`；`DeepLinkHost` 包在 `TradingScreen` 外，启动页／钱包引导结束、主界面挂载后才取出执行，所以冷启动链接不会打断钱包恢复。`app_links` 会把启动链接同时通过 stream 和 `getInitialLink` 给出，只打开一次。执行前逐层关闭主界面上方的弹窗和页面；遇到不允许关闭的路由（`PopScope(canPop: false)`，如待签名流程）则放弃这条链接，不打断进行中的操作。
- 下单预填（`vantaapp://futures?symbol=…&type=limit|market&price=…&qty=…&unit=quote|base`）：只填主交易页下单表单，不选方向、不提交。必须带 `symbol`，否则所有下单参数丢弃，避免落到当前选中的币对；带下单参数时强制切到下单页签。`type` 仅 `limit`／`market`，只给 `price` 视为限价，市价单丢弃 `price`；`unit` 默认 `quote`（USDT），取值非法时丢弃 `qty`（单位不明会改变数量含义）；`price`/`qty` 只接受不带符号、指数、逗号的正十进制。币对经合约列表确认后，按该币对 tick／step（USDT 金额按 0.01）检查：不是整数倍的值直接丢弃，不四舍五入。预填存放在 `orderFormPrefillProvider`，切换币对、离开合约页或来了新链接即作废；表单（`LiveOrderForm` 的 `bookPricing` 主表单，排除平仓与条件单入口）在读取／复核／签名都结束后应用一次，用户已输入价格、数量、比例、触发价、追踪参数或附加止盈止损中任一项时整组放弃。应用后该表单的确认框始终弹出，即使用户对该订单类型关闭了确认（`reviewLiveOrder(alwaysConfirm:)`），直到表单因换币对或换身份重建。方向仍由用户点开多／开空决定，因为主交易页没有方向选择器。
- 未做：桌面长按快捷方式（`shortcuts.xml`）与 App Actions capability；下单预填的止盈止损、条件单、只减仓、杠杆，以及平仓链接。
- 下单预填验证：解析（参数组合、无币对丢弃、非法数值、单位）、精度适配（tick／step／USDT 两位）、预填作废（换币对、离开页面、新链接）、导航仅对存在的币对给出预填，以及真实下单表单 widget 测试（未输入时填入且关闭确认后仍弹确认框、不自动提交；市价切换模式并保留 USDT 金额；用户已输入时整组放弃且照常按其偏好跳过确认；其它币对或非主表单不应用），共 18 项通过。回归：下单表单／确认／快捷下单／交易页 8 个测试文件对比"同一工作区仅撤回本人改动"的副本，两边共有 14 项相同的既有失败（quick_order 320 横屏、real_trade 横屏 1.5 倍字号等）；唯一差异 `expired confirmation and expired wallet prompt cannot submit` 单独运行时两边各 2 次均通过，属并行负载下的时序抖动。未在真机上验证。
- 钱包回跳迁移验证：auth、deep_link 与 funding 钱包回跳相关文件 `flutter analyze` 无问题；`wallet_redirect_handler_test`（新增：`vanta://wallet` 与 `vantaapp://futures` 带回执参数时一律忽略）、`reown_wallet_connector_test`、`funding_wallet_return_test`、`privy_repository_test` 与 deep_link 测试共 56 项通过。未在真机上验证外部钱包跳回与 Google/Twitter 登录。
- 验证：`dart format`、`flutter analyze`（deep_link 源码／测试与 `main.dart`）无问题。新增 `test/features/deep_link` 10 项全部通过：host 与参数解析、币对规范化、prompt 边界、启动链接去重、`getInitialLink` 失败与 stream 报错容错、页面／页签／币对选择、晚到的合约列表不覆盖新链接或用户选择、AI 草稿只在就绪且为空时填入且离开页签即取消、冷启动链接在主界面挂载后打开、可关闭弹窗被关闭而受保护路由保留。`navigation_widget_test` 5 项在撤回 `main.dart` 改动后同样失败，属工作区既有问题。挂载 `VantaApp` 的 trade 等测试组合运行时，本机根分区写满（0 MB 可用），结果没能保存下来，因此没有完成全量回归对比。未启动应用、未在真机／模拟器上点链接验证，也未构建 Android/iOS。

## 2026-11-13 交易页设置入口改为设置页

依据 Figma 1191:35486（设置页）、1191:35270（语言）、1191:35883（推送通知）、1191:36127（通知时间选择）。

- 交易页头部去掉 Ask AI 按钮（AI 仍可从底部导航进入），只保留设置与通知；设置按钮从原「账户设置」弹窗改为打开整页 `SettingsScreen`（`lib/features/settings/`），原 `TradeModeSettings` 弹窗移除。
- 设置页两张卡片：资产模式、持仓模式（保留原两个入口，取值逻辑不变，点击仍打开原模式弹窗）；语言、推送通知、检查更新、App 版本、缓存大小、使用条款、隐私政策。整页支持下拉刷新，等待资产/持仓模式、推送状态与缓存大小全部完成。
- 语言：弹窗只列 English／中文（设计中的其它语言不提供，也不提供“跟随系统”），选择后立即切换并持久化；保存失败显示既有错误文案。当前值按已选语言，未选时按系统解析出的语言显示。
- 推送通知：读取 `GET /v1/push/status` 的 `prefs`，写入走既有 `PushDeviceController.updatePreferences` → `POST /v1/push/prefs`（只发送变更字段，带幂等键，身份切换时取消）。六个类别开关对应 fills／triggers／orders／funding／transfers／announcements；设计中重复的第二个「Conditional Order Triggers」未实现。最小成交金额按十进制字符串提交。请求中开关禁用，失败时保持服务端原值并显示接口错误信息。未登录 Vanta API 时显示既有登录提示。
- 免打扰：开关打开且服务端未设置时，先在本地选择开始/结束时间，两者都有且不同才提交；开始结束相同时提示且不提交。**关闭免打扰时发送 `quiet_start: null, quiet_end: null`**——合约未说明如何清除免打扰，此行为未经后端验证；之后以重新读取的服务端状态为准。
- 时间选择：24 小时滚轮（时 00–23、分 00–59，循环），确认/取消；设计稿时列中出现的「24」视为笔误。
- 检查更新：读取公开接口 `GET /v1/app/bootstrap` 的 `config.min_supported_version` 与本机版本比较；低于最低版本提示需更新到该版本，否则提示无需更新。合约没有最新版本号或商店链接，因此不跳转商店。离开设置页会关闭该请求连接。
- App 版本取原生安装包版本（与推送注册同一通道），读取失败显示“—”。缓存大小统计并清除平台 cache 目录（及内存图片缓存）；日志、会话、偏好与恢复日志不在该目录，不受影响。
- 使用条款/隐私政策复用登录页同一链接（抽出 `LegalLinks`），用外部浏览器打开，失败时提示。
- 资源：`assets/settings/` 下 language、chevron-right、switch-on/off、time-separator 均为设计稿 SVG。
- 修正：设置行右侧留白过大。原布局标签 Expanded、值 Flexible 各占一半宽度，短值和箭头停在中间；改为右侧区域靠右对齐，值与箭头贴齐卡片内边距。新增布局测试：393 宽下各行最右元素右边缘为 361（页面 16＋卡片 16），旧布局实测 226.75 失败，新布局通过。之后其它会话修改 `live_order_embedded_inputs.dart` 导致启动完整 App 的测试在交易页报 IntrinsicHeight／LayoutBuilder 断言，设置页测试需在其改完后复跑；推送设置弹窗与数据层 18 项不受影响、通过。
- 验证：`dart format` 已执行；`flutter analyze` 只剩既有 info（portfolio mapper、未跟踪的 real_response_audit_test）。`test/features/settings` 与 `test/features/notifications` 共 214 项全部通过（新增：版本比较、字节格式、bootstrap 最低版本读取与错误、缓存统计/清除、设置页入口与行、仅中英文语言切换、缓存清除成功/失败、推送偏好渲染与只写变更类别、失败保留原值并显示接口信息、关闭免打扰发送空值、两端选齐才提交且相同时间拒绝、最小金额只提交一次、未登录显示登录提示、窄屏 1.5 倍字号）。测试发现并修复：最小金额在「完成」与失焦时会重复提交。交易头部/模式弹窗/localization/widget_test 中仍失败的 7 项在 HEAD 干净 worktree 中同样失败（如 `selectWorkspace` 找不到 `trade-workspace-tabs`），属既有问题。`mode_settings_design_test` 金图在 HEAD 通过、当前工作区失败，原因是其它会话未提交的 `deep_link` 功能在测试中调用 `app_links` 插件（MissingPluginException），与本改动无关。`modes-settings.png` 金图随弹窗删除。未启动应用或真机检查。

## 2026-11-12 Vanta AI 页面按最新设计重做

依据 Notion「Ask AI」PRD、`vanta-ai-api.md` 与 Figma 943:31804（01–18 画板）。沿用既有 AI 数据层（auth-nonce／verify-wallet／starchild-chat／ai_daily_usage、SSE、隔离安全存储），重做页面与应用状态。

- 入口与导航：Vanta AI 是一级页面（设计稿 943:31804 各帧），底部 Ask AI 与交易页 AI 按钮切到该页签；页面保留底部主导航，头部无返回箭头，输入框与免责声明位于主导航上方，键盘弹出时输入框随之上移。离开页签即释放对话控制器。
- 加载：恢复已保存会话、或首次读取本地历史且尚无消息时，内容区显示与默认提问页同结构的骨架屏（头像、标题、说明、三张推荐问题卡），不再显示居中加载圈。控制器状态 `sessionChecked` 记录是否已查过本钱包的保存会话：查询完成前（含首帧与钱包身份变化后的重置）一律显示骨架，避免先闪出认证页；页面监听该标记被重置后重新查询。头部「今日剩余」在额度尚未读到时显示单行骨架，读到后或读取失败后显示数值／“–”。已有消息或额度时刷新不显示骨架。
- 认证：进入页面时若本钱包已有保存的 AI 会话则直接恢复进入提问页（无保存会话时不发网络请求、不签名）；否则显示 01 用途说明＋Authenticate，打开「Wallet authentication」页（02–06）：未连接钱包→Connect wallet（复用账户弹窗）；已连接→Sign with wallet 一次完成取挑战与钱包签名（钱包内展示原文），成功后自动返回对话页。签名取消／请求过期／验签失败分别显示 Try Again／Sign Again／Retry，失败时优先显示接口或已知原因。保存的会话被拒（恢复或聊天 401）显示 07 会话过期提示并要求重新认证。
- 提问页（08–11）：头部显示「Remaining today: 剩余/上限」与 Clear（保留清空确认弹窗）；三个推荐问题直接发起提问且不覆盖草稿；输入框 1–5 行自适应，超出后在框内滚动，文字放不下时发送按钮移到文字下方；窗口很矮（键盘＋大字）时自动减少可见行数。
- 回复（12–18）：等待显示旋转图标＋「Agent is thinking…」；生成中显示正文与停止按钮；完成为 Markdown 气泡（保留远程图片屏蔽、仅 HTTPS 外链）；停止后显示「This response was manually interrupted.」（已有正文时保留正文并附该说明）；失败（无内容／部分内容）显示失败卡片与 Retry，Retry 复用原 `request_id` 并替换原失败回复，不再插入新问题；上游内部诊断（starchild/supabase 等）不展示。用户消息与回复均显示 HH:mm。
- 额度：上限按官网逻辑默认 5，收到 429 `daily_quota_exceeded` 后采用服务端返回的 `limit`；已用次数在认证/恢复后与每次回复结束后读取 `ai_daily_usage`，下拉刷新可重读；跨 UTC 日清除旧额度。429 时撤回本次未进入模型的提问并把内容放回输入框，显示 Daily AI limit reached 卡片，发送按钮与推荐问题禁用。
- 本地历史无法读取／保存时，在对话顶部保留原有「重读／重试保存」恢复入口；历史损坏时 Clear 仍可用作恢复手段。
- 资源：Figma 图标 SVG 存于 `assets/assistant/`；失败图标复用 `assets/feedback/fail.svg`。颜色与字体集中在 `AssistantColors`／`AssistantTypography`。
- 与设计稿的差异：01/07 卡片文案去掉「in Portfolio Settings」，因为 App 没有 Portfolio Settings 页面，Authenticate 直接打开钱包认证页。
- 认证页把「外部钱包无可用会话（需重连）」视为未连接，显示 Connect wallet 而不是去签名；其它已知失败原因（如需重连）显示具体文案，只有未知原因使用设计稿通用文案。
- 验证：`dart format` 无改动；`dart analyze`（assistant/trade/test 相关目录）无问题，全仓仅剩 1 条既有 info（portfolio mapper）。AI 测试 283 项与本地化测试全部通过（新增：一次签名认证并返回、签名取消重试、已存会话免签进入、推荐问题不覆盖草稿、思考/流式/停止、失败重试复用同一 request_id、429 撤回提问并禁用发送、401 会话过期、需重连钱包走 Connect、1.5 倍字号＋键盘＋横屏/平板布局）。全量 `flutter test -j 4` 与 HEAD 基线 worktree 对比：两边都在既有的 `order_review_lifecycle_widget_test` 挂起处超时，失败集合一致（交易/资产页 Enable Trading 门禁相关的既有失败）；唯一差异是未跟踪的 `real_response_audit_test.dart`，它依赖本机 `/tmp` 审计文件，与本改动无关。
- 真机（M2007J17C，Android 12，debug）：确认 01 未认证页、钱包认证页 02/03、交易页 AI 按钮入口（一级页面改版前的检查；改版后未在真机复查，仅跑了 widget 测试）、中文文案。本机 MetaMask 会话需要重连而现有登录页提示「外部钱包登录暂不可用」，因此未能完成真实签名、聊天与额度接口联调；对话页 08/11/14/15/16/17/18 的布局和键盘挤压，是用临时注入的本地状态在真机上检查的，检查完已移除该注入代码。iOS 未构建。
- 钱包绑定校验对齐官网：verify-wallet 后读取 `vanta.wallet_bindings`，只要当前用户有一条地址与当前钱包一致且 `verified_at` 非空的记录即通过；重复或其它地址的记录不再导致失败。真机实测该钱包在服务端有 2 条相同地址的已验证绑定，旧的"恰好 1 条"规则因此误报"服务端未确认此钱包与 AI 账户的绑定"。改后真机签名认证成功进入提问页（今日剩余 5/5）。注意真机须用 `make run`（带 `.env`），此前直接 `flutter run` 缺少 Privy/Reown 配置会出现"外部钱包登录暂不可用"。
- 已知影响：语言选择弹窗原先只能从旧 AI 标签页头部进入，全屏 AI 设计没有该按钮，目前 App 内没有语言切换入口（跟随系统仍生效），需确认放置位置。

## 2026-11-12 资产页账户弹窗隐藏子账户入口

- 按 Figma 950:23058，资产页顶部账户弹窗只保留当前账户卡片与 Log out，移除“管理账户”（`portfolio-subaccounts`）入口；预览账户选择弹窗同步去掉子账户管理项。子账户页面、身份面板入口及相关仓库逻辑保留不变。
- `account_design_test` 改为断言账户弹窗不再出现子账户入口。
- 3 个改动文件格式检查及 `dart analyze --fatal-infos` 通过；`accounts-selector` 金图按新弹窗更新，`account_design_test` 48 项通过。`portfolio_design_test` 有 10 项在 `navigation-portfolio` 处失败，撤回本次改动后同样失败，属既有问题。未启动应用或真机检查。

## 2026-11-12 交易页进入时预读持仓与委托数量

- 修正数量读取依赖 Tab 内容构建的问题：`FuturesWorkspace` 在页面进入时订阅共享的 `positionRiskAutoReadProvider` 与 `openOrdersAutoReadProvider`，未点击持仓 Tab、甚至账户区尚未滚入视口时，也会通过已有有效设备授权读取数量所需的持仓/委托快照。
- `positionsAutoReadProvider` 组合上述共享读取，再在持仓 Tab 显示时读取卡片需要的账户保证金数据。进入页面不会为了数量而提前构建持仓卡片；点击 Tab 复用同一份快照、在途任务和读取所有者，保留批量平仓/撤单期间的阻挡、现有节流及失败后停止自动读取的行为。
- 未授权不自动弹钱包或读取私有账户；持仓数量继续排除仅有余额的记录。加载中或首次失败时保留无数字的标签，只有有效快照才能给出真实数量，不把未知状态显示为 0。未改变金融写入或传输实现。
- 新增 `trade_account_counts_test` 3 项：进入后未选持仓 Tab 即取得真实数量且不构建卡片；切换 Tab 不重复读取；等待/失败不伪造 0、不循环重试；无设备授权不读私有数量、不弹钱包。旧实现先复现持仓请求次数为 0 的失败，修改后通过。
- 相关 6 个测试文件共 42 项已完成验证：新增数量测试、持仓操作、委托列表、列表状态、交易页设计及交易资产列表。委托列表/状态测试先滚动至懒构建区域，Retry 点击前等待滚动布局完成；修正这些测试定位后复跑对应 2 个文件，9 项全部通过。新增 3 项和其余 30 项相关测试已在组合运行中通过。
- 本次 7 个 Dart 文件格式检查、定向静态分析及 `git diff --check` 通过。未启动、热重载、构建应用或运行真机/模拟器检查。

## 2026-11-12 K 线全屏改为请求系统横屏

- 用户确认后，`AGENTS.md` 为 K 线全屏页加了唯一例外：只在该页打开期间请求横屏，关闭时恢复系统默认。其他页面仍不锁定方向。
- `ChartFullscreenPage` 进入时调用 `SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])` 并隐藏系统栏。离开时（`dispose`，包括点退出、返回手势）调用 `setPreferredOrientations([])` 恢复系统旋转，并恢复系统栏。iOS `Info.plist` 和 Android Manifest 都允许横屏，不需要改原生配置。
- 不再把画面转 90° 显示。只有平板（最短边 ≥ 600）在请求横屏后仍是竖屏（如 iPad 分屏）时，才把横屏布局转 90° 作兜底。组件结构不随旋转变化，所以图表的滚动和缩放位置保留。
- 去掉“转回竖屏时自动关闭全屏”：页面已经锁定横屏，转动手机不会再回到竖屏，所以只能点「退出全屏」或用返回手势离开。
- 手机转横屏时仍会自动进入全屏。全屏期间底下的 K 线页也是横屏，会被标记为“已处理”，所以退出后即使手机还横着，也不会被重新推进全屏，转回竖屏后才恢复自动进入。和上一版的计划不同，退出时没有先强制竖屏再放开：如果放开时手机仍横着，Android 会立刻按传感器转回横屏，导致闪一下。现在直接恢复系统默认，手机竖着时回到竖屏，横着时停在横屏普通页。
- 测试：`widget_test` 拦截平台通道，断言进入时请求“仅横屏”、退出时请求空列表（恢复）；新增平板分屏兜底旋转用例。辅助函数 `recordOrientationRequests`、`fullscreenTurns` 放在 `test/support/workspace_navigation.dart`。全屏相关 5 个测试文件（widget、chart_gestures、chart_future_space、chart_options、chart_loading_transition）共 31 项通过，`flutter analyze` 无错误或警告。
- 同批回归中，`quick_order_widget_test`、`trade_design_widget_test`、`futures_defaults_widget_test`、`navigation_widget_test`、`market_loading_widget_test` 有 40 项失败。失败点都在测试启动后第一次找交易页签（`trade-workspace-tabs` 不存在）或交易页签下的 `LiveOrderScreen`，此时还没有进入 K 线页或全屏。工作区里同时有他人正在修改的登录／开通交易相关文件（`login_screen.dart`、`enable_trading_screen.dart`、`trading_authorization_provider.dart` 等），判断与本次无关，未排查。上一轮这些文件全部通过。未在真机上验证转屏效果。

## 2026-11-12 竖屏进入 K 线全屏时整页横向显示

- 用户反馈：竖屏点全屏按钮后，页面没有像 02.17 那样整体横过来。项目规范不允许锁定屏幕方向，所以不调用 `setPreferredOrientations`。改为：设备是竖屏时，`ChartFullscreenPage` 把整页横屏布局顺时针旋转 90°（`RotatedBox`），用户把手机向左转即可按设计稿阅读，周期行在顶部，「退出全屏」在右上角。子组件拿到的 `MediaQuery` 尺寸改为横向，边距改为零，外层 `SafeArea` 按竖屏的实际边距避让。设备真正转成横屏时不旋转，按原布局显示。
- 旋转与不旋转使用同一组件结构，只改变 `quarterTurns`，所以在全屏里转动手机，图表的滚动和缩放位置都保留。之前的做法是增加或去掉一层包装，切换时图表会被重建，测试发现后已修正。
- 全屏期间隐藏系统状态栏和导航栏（`SystemUiMode.immersiveSticky`），否则旋转后状态栏会竖着压在横向内容旁边；离开全屏时恢复显示全部系统栏（`SystemUiMode.manual` + `SystemUiOverlay.values`）。
- 已知限制：「More」周期弹出菜单等系统浮层不跟随旋转，仍按竖屏方向弹出。
- 测试：`widget_test` 断言竖屏按钮进入时旋转 1 次、画布宽大于高，横屏自动进入时不旋转；`chart_future_space_test` 的平移辅助按图表自身坐标换算屏幕位置（`localToGlobal`），覆盖竖屏旋转显示下的拖动，以及旋转前后滚动边界保持；`chart_gestures_test` 的全屏双指缩放用例改为进入全屏后转成横屏再操作。相关 11 个测试文件共 89 项通过，`flutter analyze` 无错误或警告。在测试环境渲染 393×852 竖屏进入全屏的截图核对，临时文件已删除。未在真机上验证状态栏隐藏和旋转显示效果。

## 2026-11-12 K 线页去掉图表／深度页签并支持横屏全屏

参照 Figma `331:53096`（02.16 竖屏）与 `1085:34925`（02.17 K线横屏）。

- 按用户要求去掉 K 线顶部的「图表／深度图」页签及右侧的图表类型、指标设置、全屏三个操作。周期行（`ChartTimeframes`）最右侧改为全屏按钮，位置对应设计稿的 Chart settings。删除不再有入口的 `ChartToolbar`、深度图 `DepthCanvas`（`depth_panel.dart`）、指标面板 `chart_indicator_sheet.dart` 和参数编辑器 `chart_parameter_editor.dart`。所以 K 线页不能再切换图表类型、修改指标参数，也看不到深度图。已保存的偏好不变，指标快捷行（MA／BOLL／VOL／MACD…）、价格坐标和行情状态都保留。
- 横屏全屏（`ChartFullscreenPage`）：去掉 AppBar 和交易对标题，只有周期行、右上角「退出全屏」（设计稿 SVG `assets/trade/chart-exit-fullscreen.svg`，16px）和满屏图表（含成交量等已开启的副图）。不显示 OHLC 图例、坐标设置、指标快捷行、行情状态。画布高度为可用高度减去周期行。
- 进入方式按用户选择：手机（最短边小于 600）在 K 线页签转成横屏时自动进入全屏，竖屏点周期行右侧按钮也可手动进入。点「退出全屏」后留在普通页面，直到转回竖屏才会恢复自动进入。由旋转自动打开的全屏，转回竖屏时自动关闭。在交易页签、平板，或上面盖着其他页面或弹层时，旋转不会自动进入。不锁定屏幕方向。
- 测试：`widget_test` 新增“横屏自动进入、退出后保持、转回竖屏复位、交易页签不触发”，并把指标面板用例改为指标快捷行 + 全屏保持指标；移除深度图切换和参数编辑器用例；`chart_options_test` 改为通过偏好设置图表类型。`trade_design_widget_test`、`futures_defaults_widget_test` 的手机横屏用例改为先确认进入全屏，再退出继续检查（共用辅助 `leaveLandscapeChart`）。
- 验证：格式化；`flutter analyze` 无错误或警告。相关 11 个测试文件共 89 项通过：widget、chart_options、chart_future_space、chart_gestures、chart_loading_transition、timeframe_switch、trade_design、futures_defaults、quick_order_widget、market_loading、navigation。另外，在 Inter 字体、393×852 竖屏和 852×393 横屏的测试环境里渲染截图核对；临时渲染文件已删除。`price_precision_widget_test` 的 2 项失败在文档中原本就记为既有失败。未启动或构建应用，未做真机或模拟器检查。

## 2026-11-12 K 线快捷下单改为吸底三段按钮

参照 Figma `331:53096`（02.16 K线-快速下单）中的 `Section / Trade Actions`，以及同帧旁的“输入中”变体 `387:22144`；行为按 PRD 3.3「K线界面快捷开仓」与默认参数表。

- `QuickOrderPanel` 改为 K 线页签底部吸附的一行：左侧 Market Buy（绿，第二行显示卖一价），中间数量输入（标题为“数量(基础币)”，空值时显示“可用 USDT 余额”），右侧 Market Sell（红，第二行显示买一价）。外层不滚动，位于底部导航之上，键盘弹出时随之上移；交易页签不显示。买卖价按交易对价格精度用 `marketNumber` 显示，盘口未连接时显示 —。
- 数量输入聚焦时显示主题色描边，下方出现 25%／50%／75%／100% 比例按钮（选中项为主题色描边）。选比例后输入框显示“N%”，买／卖各自按原 `QuickOrderSizing` 换算数量；重新输入数字即替换比例。输入初始为空，不默认选比例，下单正常受理后清空。
- 去掉独立的“读取钱包”按钮、说明文字、账户设置行和确认偏好开关（设计稿没有这些元素）。签名读取改为由用户显式点击触发：点比例或买／卖时，若签名上下文缺失、过期或比例换算数据不对应，先执行原有的读取流程。未连接钱包时打开账户弹窗。读取期间对应的方向按钮显示转圈，所有快捷按钮禁用；读取失败时用现有 `message` 提示接口错误，保留输入。
- 订单参数、确认弹窗、“不再显示”、未知结果只查询及恢复流程均不变。新增：未知结果待核对期间（`needsRecheck`）也禁用快捷输入和按钮。未知结果的核对入口 `LiveOrderStatus(compact: true)` 改放在 K 线页盘口下方。
- 尺寸修正：中间数量框原先被 Material 输入框 48px 最小高度撑高（整条约 86px，文字上压到标题）。现在把输入行固定为设计的 20px，三个按钮都是 56px；聚焦时 1px 主题色描边使中间按钮变为 58px，与设计稿“输入中”变体一致。比例按钮去掉了自加的选中描边，设计稿没有这个状态，选中后输入框会显示“N%”。使用 Inter 字体，在 393×852 的测试环境渲染截图核对默认态和聚焦态；临时渲染文件已删除。
- 市价确认偏好与主表单共用；关闭后，如需恢复，目前只有独立下单页有开关，嵌入表单和 K 线页都没有入口（与 2026-11-11 记录一致）。
- 文案：新增 `quickOrderMarketBuy`、`quickOrderMarketSell`、`quickOrderAmount`、`quickOrderAvailable`（中英文）；删除不再使用的 8 条旧快捷面板说明文案。删除 `quick_order_account_settings.dart`。

验证：`dart format`、`flutter analyze`（lib 和 test 只剩 6 条原有 info）。`quick_order_widget_test` 11 项、`order_confirmation_shared_widget_test` 4 项、`futures_defaults_widget_test` 21 项已按新交互更新并通过，覆盖：中英文、320 宽 1.5 倍字号、横屏、平板；单向／双向和买／卖的参数；读取失败保留输入；比例换算；确认偏好共用；未知结果核对。
-`market_loading_widget_test` 的报价断言改为无单位的 `marketNumber` 格式，5 项通过。
- 全量 `flutter test`：5561 项通过，95 项失败。引用 K 线页签或快捷下单的 14 个测试文件已逐个重跑，其中只有上述报价断言是本次改动造成的，已修复。`navigation_widget_test` 中 2 项 zh 用例仍失败（访问资产页并切换语言后出现 15px RenderFlex 溢出）。由于交易页签（chart=false）不渲染快捷条也同样失败，判断与本次改动无关。验证期间工作区并行加入了“交易页进入时预读持仓与委托数量”的改动。之后再跑 `futures_defaults_widget_test`，此前全部通过的 2 项“访问资产页后返回”用例出现同样的 15px 溢出，需由该改动排查。其余失败的文件（如 `funding_activity_test`、`attached_entry_peg_widget_test`）都不涉及快捷下单，本次未排查。
- 未启动或构建应用，未做真机或模拟器检查。

## 2026-11-12 修正交易资产总余额的右侧对齐与图标间距

- 总余额原来在 `Row` 中使用 `Expanded` 标题与松约束 `Flexible` 金额。金额小于分配宽度时，未占用空间留在整行尾部，使充值入口和金额一起偏左；金额区改为 `Expanded` 并通过 `Align.centerRight` 对齐。
- 进一步修正加号的视觉间距：原来的 44px 按钮将 16px SVG 居中，图标右边仍多出 14px 空白。现在只为图标与金额的 8px 间隔预留共 24px，SVG 右边缘贴齐内容区（距窗口右侧 16px）。44×44 按钮在同一行内覆盖非交互内容，保留完整触控范围，不通过裁小按钮或向父布局外溢出实现。
- 坐标断言直接验证 SVG 的 16×16 显示尺寸、距窗口右侧 16px、金额到图标 8px，以及按钮 44×44 尺寸。覆盖预览数值、未知估值占位、中英文 320px 窄屏与 844×390 横屏 1.5 倍字号；还点击按钮最左侧、图标之外的位置，确认仍能触发操作。
- 先验证旧布局坐标断言失败（393px 窗口中 SVG 右边缘为 363px，预期 377px），修复后交易资产 10 项测试全部通过。本次两处 Dart 文件格式检查、定向静态分析通过；未启动或构建应用，未进行真机/模拟器检查。

## 2026-11-12 交易页资产列表与详情按设计稿对齐

参照 Figma `331:82381`（交易页资产列表）和 `331:82784`（资产详情）。

- 交易页资产 Tab 改用 `TradeAssetsSection`，复用资产页的 `portfolioAccountLoadProvider`、`portfolioOverviewProvider`、`portfolioLoadingProvider`、`PortfolioAssetList` 和资产行。共用已验证的账户余额、公开 USD 指数估值、按美元价值降序排列、缺失估值保留及绝对美元价值小于 1 的小额过滤；不新增资产接口或另存列表快照。
- `FuturesWorkspace` 使用页面级 `CustomScrollView` 与 Sliver；资产列表直接接入同一滚动视口的 `SliverList.separated`，按币种保留行标识，不使用嵌套 shrinkWrap 列表。资产页通过可选 header 插槽复用同一列表结构；交易页在过滤项下显示总余额与充值入口，过滤不改变总余额。
- 首次账户加载使用局部骨架；刷新保留已有资产。交易页刷新纳入共享 USD 指数，并允许已打开资产 Tab 在首次读取失败后重读账户，等待所有任务（包括失败）结束。无钱包显示连接入口，未授权沿用账户反馈；本地预览保留明确标识，充值/提现动作沿用预览提示。
- 两个页面共用的资产详情弹层采用已有底部弹层容器：背景模糊、24 圆角、关闭按钮、分隔线、40px 币种图标、目录返回的本地化币种名称、美元余额与可复制的原币数量。保证金与可用于下单的余额使用原币单位，未实现盈亏使用 `pnlUsd` 和盈亏颜色；未知估值显示占位，隐藏余额不泄露数量。小屏、横屏与放大字体下允许换行和滚动。
- 新增设计稿原始 SVG `assets/portfolio/asset-deposit.svg`（16px）与 `asset-close.svg`（24px）；列表沿用现有动态币种图标。详情图标在保留 SVG 原始尺寸的情况下通过外层适配到 40px，Widget 测试验证有效显示尺寸。
- 验证：格式检查、`git diff --check` 通过；本次修改的 7 个 Dart 文件定向静态分析无问题。`flutter analyze --no-pub` 全仓仍报告 6 条既有 info（`position_margin_mapper.dart` 1 条、`real_response_audit_test.dart` 5 条），没有本次新增问题。
- 10 个相关测试文件合计 75 项通过：`trade_assets_section_test`、`portfolio_asset_list_test`、`portfolio_virtual_lists_test`、`portfolio_asset_order_test`、`portfolio_loading_test`、`portfolio_asset_logo_test`、`asset_valuation_widget_test`、`trade_positions_section_test`、`trade_design_widget_test`、`real_trade_widget_test`。包含首次骨架、数据来源一致、过滤保留未知估值、原币与美元单位、1,000 条资产仅构建视口行、刷新等待账户与估值失败、中英文 320px 竖屏与 844×390 横屏 1.5 倍文字、预览及未连接账户。图标尺寸断言补充后再次运行资产列表/图标/交易资产 3 个文件，21 项通过；持仓测试改用滚动查找以适配延迟构建。
- 未启动、热重载或打包应用，未运行 Android/iOS 构建、真机或模拟器视觉检查；未改动传输层或金融写入流程。

## 2026-11-11 下单确认弹窗按设计稿重做

参照设计稿 331:71125（市价做多）、331:69310（市价做空）、331:72940／331:73858（带止盈止损）。
- 弹窗（`OrderConfirmationDialog`、`OrderConfirmationTerms`）：居中卡片，圆角 20、细边框，背景模糊加半透明遮罩。依次为标题“下单确认”和关闭按钮、分隔线、交易对和多空标签（买入/做多为绿底，卖出/做空为红底；减仓显示平多/平空）、委托价格（市价单显示“市价”）、委托数量（按 USDT 下单时显示 USDT 金额，另起一行显示实际提交的币数量），最后是取消按钮和方向色确认按钮。
- 止盈止损：标签分别用绿、红色，值为“最新成交价/标记价 ≥/≤ 价格 USDT”，比较符号按方向计算。设计稿中做多止盈写作“≤”，是沿用了做空稿，不采用。限价出场追加执行方式和价格，开启触发保护时同样标注。
- 其他设置：只显示订单实际用到的项，与上面同样的行样式。包括 BBO 档位（显示在价格行）、条件单的订单类型、触发价和触发保护、跟踪单的回调比例、价格依据和激活价、非 GTC 的有效期（IOC、只做 Maker、隐藏委托），以及仅减仓。
- 提交：确认按钮在提交期间转圈并禁用，取消、关闭、返回手势也一并禁用；点遮罩不会关闭弹窗。成功时 toast 提示“下单成功”并关闭弹窗。失败时 toast 显示接口错误，弹窗保持打开。结果未知时 toast 提示用客户端编号核对，不会自动重发。账户已变化或订单信息失效、没有发出请求时，提示“订单信息已失效，请关闭弹窗后重新下单”。弹窗打开期间若下单页被卸载（如登出），提交改为通过 `ProviderContainer` 读取状态，不再访问已卸载的 `ref`。
- 移除：旧弹窗中的风险说明、资金面板、额度冻结信息、客户端编号，以及“不再显示”勾选框。确认偏好仍可在独立下单页的开关中设置，交易页嵌入表单目前没有关闭确认的入口。
- 新增文案 10 条（中英文），颜色和字体沿用 `TradeColors`/`TradeTypography`，新增 `buyLabel`、`sellLabel`、`onDirection`、`scrim`、`tag`、`action`。

验证：新增 `order_confirmation_dialog_test` 8 项，覆盖设计行、提交中转圈与防重复、成功后 toast 并关闭、失败/未知/未发出时 toast 且不关闭、止盈止损方向、高级设置附加行，以及 320 宽 1.5 倍字号、横屏、平板下无溢出，全部通过。旧确认流程相关的 20 个 widget 测试文件已按新弹窗更新断言，其中 attached_entry_peg、attached_exit_input、attached_order、live_close、live_order_peg、live_order_widget、order_confirmation、order_confirmation_shared 在当时都已通过。之后其他会话在同一组 provider 和弹窗上继续开发（打开期间实时复核、`main_order_review_submission_provider` 等），在那些改动下，`order_review_lifecycle` 的 2 项会超时，部分“提交后表单锁定”断言也会失败，需在相关开发完成后重新核对。`live_order_mode` 的“未登录菜单横屏”1 项与本改动无关。按用户要求，本次未做真机验证。

## 2026-11-11 多资产抵押汇率不再因订阅空档报“缺失或已过期”

交易页偶尔出现“抵押资产换算价格缺失或已过期，请刷新后重新计算额度”。核查公开 `/fapi/v1/assetIndex` 时，各资产 `time` 均在 1 秒内，接口本身已按 30 秒轮询，原因在客户端的两个空档：
- `assetIndexProvider` 是自动释放的。下单签名上下文每 30 秒过期一次，过期时定价 provider 提前返回、不再订阅汇率，控制器随即被释放、快照清空；重新读取后，在首次拉取完成前，额度计算就报“缺失”。现在无人订阅时保留 60 秒并继续轮询，60 秒内重新订阅会直接使用当前汇率。
- 某次拉取失败时，定价 provider 会丢弃仍在有效期内的上一份快照，并要等 30 秒才重试。现在失败后继续提供旧快照（每个汇率的 60 秒接收期和 90 秒数据时间限制仍在计算时校验），并在 5 秒后重试。拉取中或首次未返回时视为等待，刷新流程会继续等待而不是立即报错。
- 汇率超过有效期仍拿不到新数据时，照常提示，不隐藏真实的不可用状态。

验证：`asset_index_provider_test` 按 60 秒保留期更新了 2 项，新增“保留期内重新订阅沿用汇率”和“失败保留旧快照、5 秒重试”2 项；asset index、实时定价与主下单刷新相关测试共 54 项全部通过。按用户要求，本次未做真机验证。

## 2026-11-11 交易页代码按职责拆分（行为不变）

- 删除无引用代码：旧演示下单表单 `trade/presentation/widgets/order_form.dart`，及只被它使用的 `order_controls.dart`、`order_review.dart`。`OrderBookPanel` 只剩紧凑用法，交易页改为直接使用 `CompactOrderBook`。原 `order_book.dart` 里共享的 `BookFeedState` 和 `retryOrderBook` 移到 `book_feed_state.dart`，非紧凑盘口和成交列表的死代码一并删除。两个测试中对 `OrderForm` 的“不存在”断言随之移除。
- `live_order_form.dart`（505→350 行，build 约 220→67 行）：独立下单页、平仓页、持仓条件单的布局移到 `part 'live_order_form_full.dart'`，与已有的 `live_order_form_embedded.dart` 对称；身份变化时的重置逻辑抽成 `_resetForIdentity`。表单状态仍集中在一个 State 中，两种布局共用。
- `live_order_screen.dart`（328→239 行，build 约 210→70 行）：独立页专用的标题、读取按钮、提示、上下文摘要和 Scaffold 移到 `part 'live_order_screen_standalone.dart'`；共用的表单区块抽成 `_orderForm`，监听抽成 `_listenSelection`。
- `main_order_capacity_panel.dart`（326→173 行，build 45 行）：完整面板和 `_Side` 卡片移到 `part 'main_order_capacity_full.dart'`。主文件负责计算可用性和预览，再按 `compact` 分发；分发时传入的数据集中在 `_PanelFacts` 记录类型中。

验证：格式化零改动；lib 与 test 静态分析无新增问题。portfolio、trade 与盘口测试的结果与拆分前一致，仍失败的 10 项均为既有失败（`main_order_risk_mapper_test` 1、`real_response_audit_test` 1、`price_precision_widget_test` 2、`real_trade_widget_test` 6）。Android 12 真机冷启动后，交易页显示与拆分前相同。

## 2026-11-11 交易页盘口列、K线辅助、最大杠杆与下单弹窗按设计稿补齐

参照设计稿 331:47488（高级设置展开）、331:47291（K线辅助）、331:57082（选择价格类型）、331:60809（选择单位）、331:62597（止损市价＋止盈止损）。
- 最大杠杆徽标：交易对名称下、涨跌幅前显示 `200x`。公开 `exchangeInfo` 的 `requiredMarginPercent` 换算为 20x，与实际不符，不能使用。现在从签名 `leverageBrackets` 读取的最大 initialLeverage 写入 `MainOrderCapacitySnapshot.maximumLeverage`，再由 `symbolMaximumLeverageProvider` 按交易对缓存本会话的值。未连接或尚未读取过的交易对不显示徽标，不展示未确认的数值。该值仅用于展示，不是修改杠杆时的上限（仍为 125 与档位的较小值）。
- 盘口列（`CompactOrderBook`）：顶部为收藏星标与 K 线开关（设计稿 SVG：`assets/trade/favorite.svg`、`chart-on.svg`、`chart-off.svg`）。下面依次为资金费率、“价格/USDT”“数量/USDT▾”表头，以及每侧 8 档、开启 K 线时 6 档的档位。每档有两层深度条：累计深度 7%，本档 15%。数量默认按 USDT 名义值紧凑显示，可在单位弹窗中切换为基础币。最新价为 18px 粗体，按涨跌着色；标记价为 10px 灰色，按价格精度取整，不再显示旗帜图标。B/S 比例为上方两段细条（#013220／#4E210F）加下方两端标签。
- K 线辅助（`TradeKlinePanel`）：点击 K 线图标后，在下单区上方插入 200px 通栏 K 线，包含 时间/1m/3m/5m/15m/30m/1h 周期行和 MA 主图。与完整图表共享行情流、周期和指标参数，不另开订阅；MA 周期沿用共享设置（5/10/30/60）。开关状态只在会话内保存。
- 选项弹窗（`showTradeOptionSheet`）：圆角 24 底部弹窗，含标题、关闭按钮、分隔线，选项为标题加可选说明，选中项右侧为 20px 圆角主题色勾选框（`assets/trade/check.svg`）。触发价格类型（最新成交价/标记价）、下单数量单位、盘口数量单位、止盈止损输入方式均使用该弹窗。
- 高级设置：止盈止损、隐藏委托、仅减仓三个 11px 勾选框，仅减仓行右侧为 TIF 下拉（GTC/IOC/GTX）。隐藏委托即 `HIDDEN` 时间策略，只对限价且交易所支持时显示。勾选止盈止损后显示两个设计稿输入框：标签旁为“标记价▾”，右侧为“盈亏（USDT）▾”（可切换价格或收益率）；有值的那一腿才会提交，出场按市价执行。嵌入表单不再提供限价出场、触发保护和免确认开关，独立下单页仍保留。
- 条件单：止损/止盈市价只显示“触发价格＋价格类型”输入框，不显示限价框。条件单和跟踪单的方向卡片不显示预估强平价，只保留保证金和最大。
- 做多/做空按钮有数量时，第二行显示“≈数量 基础币”。

验证：`order_book_test` 按双层深度条和默认 USDT 名义值更新断言；`live_order_embedded_layout_test` 新增选项弹窗（选择/关闭）与勾选框行 2 项。portfolio、trade 与盘口测试中，除既有失败（`main_order_risk_mapper_test` 1 项、`real_response_audit_test` 1 项、`price_precision_widget_test` 2 项、`real_trade_widget_test` 6 项）外全部通过。lib 与 test 静态分析的剩余提示均来自他人未提交的文件。Android 12 真机目视核对：最大杠杆徽标、盘口列、K 线开关与通栏 K 线、单位弹窗、价格类型弹窗（切换后显示“最新成交价”）、止损市价布局、高级设置及止盈止损输入框。未提交真实订单。

## 2026-11-10 交易页已连接下单表单按设计稿重排

修复右侧"加载失败"后，已连接钱包时显示的 `LiveOrderForm` 仍是独立下单页的长表单：快照时间、资金范围说明、读取额度按钮、方向切换、仅减仓说明和 0–100 比例滑块等，与设计稿 331:52901 不符。现在 `LiveOrderScreen(embedded: true)` 给开仓表单传入 `embedded`，改用与未连接态相同的设计布局，并填入真实数据。平仓、持仓条件单和独立下单页保持原布局。
- 主流程：价格框（`价格（USDT）`，−／+ 按 `priceTick` 步进，偏离 tick 的价格先下取整再步进；市价时显示对应文字）＋ BBO 按钮（切换普通 BBO 档位；开启附加 TP/SL 时切换入场档位，Post Only 时使用排队一档；开启时按设计稿显示绿底绿描边）。BBO 开启后价格框按设计稿改为 `BBO 模式／当前档位 ▾`，点击弹出 BBO Mode 档位底部弹窗（复用 `showTradeOptionSheet`，底部附说明）。档位按官方 V3 合同真实支持范围显示（不按设计稿示例的 1、5 档筛选）：普通 BBO 仅对手价／排队价 1 档；附加 TP/SL 的入场 BBO 列全部 1、3、5、10、20 档；Post Only 仅列排队 1 档。弹窗返回时若普通／附加定价已切换则丢弃选择；数量框（右侧单位下拉 USDT／基础币）；五档滑块（0/25/50/75/100%，沿用 `mainOrderAllocationProvider` 与原可用性判断）；`可用余额`（合约 USDT 可用，紧凑格式）及充值入口；`高级设置` 折叠区；做多、做空两张卡片（预估强平价、保证金、最大）及其按钮。
- 高级设置折叠区收纳设计稿主界面没有的现有功能：仅减仓、TIF、BBO 档位选择、附加 TP/SL、按模式免确认开关。条件／跟踪模式的触发价、回调率等输入仍直接显示在价格框上方。
- 卡片数值来自原 `mainOrderCapacityPreviewProvider`。保证金按两位小数向上取整，最大可开向下取整，强平价按合约价格精度。未输入数量时不显示预览的临时失败；输入后在卡片内显示。做多／做空走原有复核路径：分配复核在签名前重新校验额度，入场 BBO 走原意图复核。资金读取失败、账户禁止交易和表单校验错误仍显示原因。
- 下单上下文和额度有效期为 30 秒，嵌入表单不再显示"读取额度"按钮。数据过期后，点击做多／做空会先执行与下拉刷新相同的完整刷新，成功并重建表单后，如原本有可复核数量则继续进入复核。不做定时自动刷新，因为外部钱包读取可能需要签名。
- 账户事实变化不阻断：点击做多／做空时，若签名前的额度读取或点击触发的完整刷新报 `liveCapacityChanged`／`liveCapacityStale`／`liveOrderContextExpired`／`liveAllocationChanged`（成交、挂单保证金或设置在两次读取间变化），且表单未改动，则自动再做一次完整刷新并按同一表单重新询价进入复核；只重试一次，第二次仍失败才显示原因。这只是只读重读与复核，不自动发送或重放订单。点击方向按钮时先收起数量框焦点，避免刷新期间输入框只读→恢复后重新弹出软键盘。验证：`order_polling_review_widget_test` 新增用例（首次额度读取报变化→1 次账户读取、3 次额度读取后出现确认弹窗，不显示变化提示，点击后数量框失焦；去掉失焦修复时该用例失败），`test/features/portfolio` 全部 3161 项通过，全仓 `flutter analyze` 无问题。未在真机复现。
- 挂单保证金不再作硬校验：额度读取原先要求按挂单计算的预占保证金与账户 `openOrderInitialMargin` 相差不超过末位一个单位，否则报 `liveCapacityChanged`。交易所按自己的标记价和公式计算该值（单向持仓还随标记价变化），实际几乎不可能完全一致，所以只要该合约有普通限价挂单，额度读取和后台续期就会一直失败：做多／做空卡片保证金显示"—"，点击报"挂单保证金已变化"。现在预占只按开放订单本身（剩余数量 × 价格）计算，不再与交易所汇总值比对；无法推断的挂单类型仍报 `liveCapacityPendingUnknown`。
- 点击反馈：做多／做空从点击起到读取、复核及免确认直接提交结束，按钮一直转圈，两个方向按钮都禁用（确认弹窗打开时由弹窗显示进度）。点击触发的读取失败、复核失败（含最大可开变化）以 toast 显示，失败 toast 需手动关闭，不再写在表单里、随下一次后台续期消失。免确认模式原先忽略提交结果，现在与确认弹窗一样用 toast 报告成功、失败或结果未知。复核没有返回原因时也重读一次，仍失败则提示"下单输入、账户数据或额度已变化"，不再静默无反应。
- 下单后刷新：下单与持仓止盈止损（两者都经 `liveOrderProvider` 提交）完成后，原本只把账户、持仓和挂单快照标为过期，由交易页的后台读取立即重读。交易所刚确认后 REST 列表可能还没更新，重读拿到旧数据后又算作新鲜，要等 30 秒到期才再读。现在用 `markStaleAfterWrite`：立即标过期，2 秒后再标一次，后台读取（最短间隔 5 秒）会再读一轮。仍只通过有效的设备交易授权读取，不弹钱包签名；撤单和改单原本就按核实结果直接更新挂单列表，未改。
- 下单成功后清空数量：`reviewLiveOrder` 仅在提交核实为已下单时返回 true（确认弹窗与免确认模式都一样），开仓表单随后清空数量、金额和比例输入，保留价格和其他设置。被拒、失败、结果未知或取消时保留原输入。
- 验证（续）：`position_risk_provider_test` 新增写入后 2 秒再次标过期；`order_polling_review_widget_test` 确认下单成功后数量清空、价格保留（去掉清空时失败）。全仓 `flutter analyze`、格式检查通过；`test/features/portfolio` 3162 项通过，`test/features/trade` 各文件逐个运行全部通过。


## 2026-11-16 Integrated changes and pre-commit verification

- Integrated owner-signed Aster Builder approval/update for the configured public Vanta address. The client never needs a Builder private key. Live binding reads confirm approval; durable journals retain uncertain writes, and only a renewed explicit action after verification permits a missing Builder grant to be signed again. Wallet initialization, relay correlation and launch recovery use the scoped, documented Reown patches with upstream licenses. Builder signing uses a 50-second local deadline within the general V3 60-second nonce window; Agent registration retains its separate stricter deadline.
- Crypto and RWA targets remain total Maker 0.015% / Taker 0.05%. New order/strategy placement reads current symbol commission and binding, computes one additional Builder fee with Decimal for every possible entry/protection fill, rejects applicable base fees above budget and signs the exact attribution bytes. Uncertain orders are queried by their original IDs without replay. The additive fee formula, actual fill accounting and backend Builder discovery/archive completeness remain operational acceptance boundaries; successful wallet signing alone does not establish them.
- Included backend history/notification contract updates, income archival, quantity-unit mapping, app-update handling, safe-read cancellation/backoff and order input/allocation feedback and refresh improvements. Financial writes do not use automatic read retries. Builder fixes retain the agreed authorization UI and copy; unrelated UI changes in this working tree belong to their existing feature work.
- Before committing all current changes, `dart format --output=none --set-exit-if-changed lib test` checked 1,357 files with no changes, `flutter analyze --no-pub` reported no issues, and the full `flutter test --no-pub` suite passed **5,973 tests with 3 skipped**. Application whitespace checks passed. Staged whitespace diagnostics in vendored licenses, README and generated SDK files were verified byte-for-byte against the published package cache; their upstream formatting was retained. Logs: `/tmp/vanta-commit-format.log`, `/tmp/vanta-commit-analysis.log`, `/tmp/vanta-commit-tests.log`. The existing Linux Rive native-library warnings/skips remain. No app launch, reload/restart, native build or real signed financial write was performed for this verification.
