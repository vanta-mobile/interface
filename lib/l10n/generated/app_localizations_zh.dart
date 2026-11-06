// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get demoOrdersTitle => '本地演示持仓与订单';

  @override
  String get connectExternalWallet => '连接 EOA 钱包';

  @override
  String get externalWallet => '外部 EOA 钱包';

  @override
  String get embeddedWallet => 'Privy 内嵌钱包';

  @override
  String get reconnectExternalWallet => '重新连接钱包';

  @override
  String get externalWalletLoginHint => '使用已有钱包连接并签名登录，不会额外创建钱包。登录签名不启用实盘交易。';

  @override
  String get walletConnectStep => '请在钱包中确认连接。';

  @override
  String get walletSignStep => '请在钱包中签名以验证登录身份。';

  @override
  String get authWalletConfiguration => '外部钱包登录暂不可用。';

  @override
  String get authWalletCancelled => '钱包连接已取消，可以重新尝试。';

  @override
  String get authWalletRejected => '你已拒绝钱包请求，可以重新尝试。';

  @override
  String get authWalletUnavailable => '钱包连接失败，请检查钱包应用和网络后重试。';

  @override
  String get authWalletUnsupported => '请选择支持的 Ethereum、BNB Chain、Arbitrum 或 Base 钱包网络。';

  @override
  String get authWalletChanged => '钱包账户或网络已变更，请重新连接并登录。';

  @override
  String get authWalletReconnect => '账户身份已恢复。签名操作前，请重新连接对应的 EOA 钱包。';

  @override
  String get authWalletSignature => '钱包未返回有效签名，请重试。';

  @override
  String get quotesConnecting => '正在连接实时报价';

  @override
  String get quotesLive => '实时报价';

  @override
  String get quotesPartial => '部分报价正在恢复';

  @override
  String get quotesOffline => '报价已离线，保留最近数据';

  @override
  String get quotesUpdatedAt => '更新于';

  @override
  String get quotesSnapshotFailure => '报价快照刷新失败，保留可用数据。请检查网络后重试。';

  @override
  String get quotesDataFailure => '部分报价无效或缺失，保留最近有效数据。';

  @override
  String get done => '完成';

  @override
  String get chartType => '图表类型';

  @override
  String get loadingChart => '正在加载图表';

  @override
  String get more => '更多';

  @override
  String get moreTimeframes => '全部周期';

  @override
  String get typeCandles => '蜡烛图';

  @override
  String get typeHollowCandles => '空心蜡烛图';

  @override
  String get typeBars => '美国线';

  @override
  String get typeLine => '折线图';

  @override
  String get typeLineWithMarkers => '带标记折线';

  @override
  String get typeStepLine => '阶梯线';

  @override
  String get typeArea => '面积图';

  @override
  String get typeBaseline => '基准线图';

  @override
  String get typeColumns => '柱形图';

  @override
  String get typeHighLow => '高低线';

  @override
  String get typeHeikinAshi => '平均K线';

  @override
  String get heikinAshiHint => '平均K线为计算值，报价与详情显示原始行情';

  @override
  String get priceScale => '价格坐标';

  @override
  String get scaleRegular => '普通';

  @override
  String get scaleLogarithmic => '对数';

  @override
  String get scalePercentage => '百分比';

  @override
  String get scaleIndexed => '基准100';

  @override
  String get relativeScaleHint => '基准为可见区域首根开盘价';

  @override
  String get loadingHistory => '历史加载中…';

  @override
  String get historyEnd => '已到最早历史';

  @override
  String get indicatorParameters => '指标参数';

  @override
  String get period => '周期';

  @override
  String get period1 => '周期1';

  @override
  String get period2 => '周期2';

  @override
  String get period3 => '周期3';

  @override
  String get period4 => '周期4';

  @override
  String get deviations => '标准差倍数';

  @override
  String get fastPeriod => '快线周期';

  @override
  String get slowPeriod => '慢线周期';

  @override
  String get signalPeriod => '信号周期';

  @override
  String get smoothK => 'K平滑周期';

  @override
  String get smoothD => 'D平滑周期';

  @override
  String get invalidChartParameter => '请输入范围内的有效数值';

  @override
  String get invalidMacdPeriods => '快线周期必须小于慢线周期';

  @override
  String get resetDefaults => '恢复默认';

  @override
  String get apply => '应用';

  @override
  String get mainIndicators => '主图指标';

  @override
  String get secondaryIndicators => '副图指标';

  @override
  String get volumeBars => '成交量';

  @override
  String get indicatorHint => '均线叠加在价格主图上，副图每次显示一个，可随时切换或关闭。';

  @override
  String get exitFullscreen => '退出全屏';

  @override
  String get marketDetails => '行情详情';

  @override
  String get depth => '深度图';

  @override
  String get candles => '蜡烛图';

  @override
  String get lineChart => '折线图';

  @override
  String get sync => '行情缓存';

  @override
  String get syncing => '历史加载 / 缺口修复';

  @override
  String get closedCandle => '已收盘';

  @override
  String get formingCandle => '形成中';

  @override
  String get eventTime => '消息时间';

  @override
  String get startTime => 'K 线开始';

  @override
  String get chartSource => 'Aster 永续合约 · USDT';

  @override
  String get chartSourceShort => 'Aster · USDT';

  @override
  String get marketSource => 'Aster 永续合约';

  @override
  String get poweredBy => 'VANTA  /  行情来自 ASTER';

  @override
  String get gap => '检测到行情断档，正在补齐';

  @override
  String get connect => '连接钱包';

  @override
  String get loginTitle => '登录 Vanta';

  @override
  String get loginDescription => '连接已有 EOA 钱包，或使用邮箱验证码登录 Privy 钱包。';

  @override
  String get emailAddress => '邮箱地址';

  @override
  String get sendCode => '发送验证码';

  @override
  String get verificationCode => '6 位验证码';

  @override
  String get verifyAndLogin => '验证并登录';

  @override
  String get resendCode => '重新发送';

  @override
  String get changeEmail => '更换邮箱';

  @override
  String get logout => '退出登录';

  @override
  String get copyAddress => '复制钱包地址';

  @override
  String get createWallet => '创建内嵌钱包';

  @override
  String get tradingNotEnabled => '钱包已登录。请使用独立的实盘下单入口核对真实订单，须具备 Aster 认可的权限。';

  @override
  String get loginInProgress => '正在处理登录…';

  @override
  String get walletInProgress => '正在处理钱包会话…';

  @override
  String get demoAccountHint => '使用独立的本地模拟资金体验交易，不影响你的 Privy 钱包。';

  @override
  String get authConfiguration => '当前安装包尚未配置可用的 Privy 登录，请联系应用提供方。';

  @override
  String get authInvalidEmail => '请输入有效的邮箱地址。';

  @override
  String get authInvalidCode => '验证码无效或已过期，请检查或重新获取。';

  @override
  String get authNetwork => '登录连接失败，请检查网络后重试。';

  @override
  String get authRateLimited => '请求过于频繁，请稍后重试。';

  @override
  String get authSessionUnavailable => '登录会话已失效，请重新登录。';

  @override
  String get authUnavailable => '登录服务暂不可用，请重试。';

  @override
  String get demo => '演示账户';

  @override
  String get perpetual => '永续';

  @override
  String get perps => '合约';

  @override
  String get markets => '市场';

  @override
  String get portfolio => '资产';

  @override
  String get points => '积分';

  @override
  String get trade => '交易';

  @override
  String get chart => '图表';

  @override
  String get data => '数据';

  @override
  String get change => '24h 涨跌幅';

  @override
  String get volume => '24h 成交量';

  @override
  String get high => '24h 最高';

  @override
  String get low => '24h 最低';

  @override
  String get mark => '标记价格';

  @override
  String get index => '指数价格';

  @override
  String get funding => '资金费率 / 倒计时';

  @override
  String get book => '订单簿';

  @override
  String get trades => '最新成交';

  @override
  String get price => '价格';

  @override
  String get quantity => '数量';

  @override
  String get total => '累计';

  @override
  String get time => '时间';

  @override
  String get buy => '买入 / 做多';

  @override
  String get sell => '卖出 / 做空';

  @override
  String get long => '做多';

  @override
  String get short => '做空';

  @override
  String get cross => '全仓';

  @override
  String get leverage => '杠杆倍数';

  @override
  String get leverageHint => '杠杆越高，价格波动带来的风险越大。';

  @override
  String get limit => '限价';

  @override
  String get market => '市价';

  @override
  String get available => '可用余额';

  @override
  String get marketPrice => '以当前市场价格成交';

  @override
  String get orderValue => '订单价值';

  @override
  String get margin => '所需保证金';

  @override
  String get fees => '预估手续费';

  @override
  String get reduceOnly => '仅减仓';

  @override
  String get positions => '持仓';

  @override
  String get orders => '挂单';

  @override
  String get history => '历史记录';

  @override
  String get pnl => '未实现盈亏';

  @override
  String get noPositions => '暂无持仓';

  @override
  String get noPositionsHint => '把握下一次机会，从第一笔交易开始。';

  @override
  String get noOrders => '暂无挂单';

  @override
  String get noHistory => '暂无交易记录';

  @override
  String get walletTitle => '连接你的交易世界';

  @override
  String get walletHint => '可使用本地演示账户体验交易，或通过独立实盘入口使用钱包下单。资金划转尚未启用。';

  @override
  String get enterDemo => '体验演示账户';

  @override
  String get demoBalance => '10,000 USDT 模拟资金 · 无真实交易';

  @override
  String get demoActive => '本地演示 · 非真实交易';

  @override
  String get review => '确认订单';

  @override
  String get confirm => '确认模拟下单';

  @override
  String get cancel => '取消';

  @override
  String get close => '平仓';

  @override
  String get entry => '开仓价格';

  @override
  String get size => '仓位数量';

  @override
  String get invalidQuantity => '请输入大于 0 且符合该币种数量步长的数量。';

  @override
  String get invalidPrice => '请输入大于 0 且符合该币种价格步长的价格。';

  @override
  String get insufficient => '可用保证金不足，请减少数量或调整杠杆。';

  @override
  String get reduceHint => '仅减仓需有同币种、反方向且数量足够的持仓。';

  @override
  String get submitted => '模拟订单已提交';

  @override
  String get closed => '模拟持仓已平仓';

  @override
  String get canceled => '模拟挂单已取消';

  @override
  String get filled => '已成交';

  @override
  String get pending => '待成交';

  @override
  String get canceledStatus => '已取消';

  @override
  String get offline => '历史行情 · 重连中';

  @override
  String get live => '实时行情';

  @override
  String get retry => '重新连接';

  @override
  String get snapshotHint => '实时连接中断，展示最近历史行情。';

  @override
  String get marketUnavailable => '当前行情不可用，请稍后重试。';

  @override
  String get search => '搜索交易对';

  @override
  String get selectMarket => '选择交易对';

  @override
  String get favorites => '自选';

  @override
  String get allMarkets => '全部合约';

  @override
  String get lastPrice => '最新价';

  @override
  String get fundingRate => '资金费率';

  @override
  String get volume24h => '24h 成交额';

  @override
  String get addFavorite => '加入自选';

  @override
  String get removeFavorite => '移出自选';

  @override
  String get emptyFavorites => '还没有自选合约';

  @override
  String get noMarketsFound => '没有匹配的合约';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get equity => '账户总权益';

  @override
  String get usedMargin => '占用保证金';

  @override
  String get overview => '资产概览';

  @override
  String get portfolioHint => '连接账户，开启你的交易旅程。';

  @override
  String get pointsTitle => '每一笔交易，都有回响。';

  @override
  String get pointsHint => 'Vanta Genesis 积分计划奖励真实交易与生态参与。演示交易不产生积分。';

  @override
  String get yourPoints => '你的 Genesis 积分';

  @override
  String get comingSoon => '即将上线';

  @override
  String get aiTitle => '你的下一步，多一点洞察。';

  @override
  String get aiHint => 'AI 行情助手将在后续版本提供市场分析。当前可在交易页查看实时价格、K 线与订单簿。';

  @override
  String get backToTrade => '查看交易行情';

  @override
  String get language => '语言';

  @override
  String get settings => '设置';

  @override
  String get indicators => '技术指标';

  @override
  String get none => '无';

  @override
  String get fullscreen => '展开图表';

  @override
  String get chartHint => '长按查看价格 · 双指缩放';

  @override
  String get network => '行情连接';

  @override
  String get demoReset => '退出演示账户';

  @override
  String get demoExitHint => '退出会清除本次本地演示的持仓和挂单。';

  @override
  String get minOrder => '最小数量';

  @override
  String get feeHint => '模拟手续费 0.05%，仅用于演示计算。';

  @override
  String get orderReviewHint => '这是本地模拟订单，不会发送到交易所。';

  @override
  String get refresh => '刷新行情';

  @override
  String get account => '账户';

  @override
  String get bookWaiting => '正在连接订单簿…';

  @override
  String get bookError => '订单簿连接中断，正在重连。';

  @override
  String get noTrades => '等待最新成交…';

  @override
  String get spot => '现货';

  @override
  String get open => '开';

  @override
  String get candleHigh => '高';

  @override
  String get candleLow => '低';

  @override
  String get candleClose => '收';

  @override
  String get orderId => '订单编号';

  @override
  String get tapPrice => '点击盘口价格填入订单';

  @override
  String get followSystem => '跟随系统';

  @override
  String get languageSaveFailed => '语言设置保存失败，请重试。';

  @override
  String get saveLanguage => '保存语言';

  @override
  String get midPrice => '中间价';

  @override
  String resendCountdown(int seconds) {
    return '重新发送 ($seconds秒)';
  }

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get asterAccountTitle => 'Aster 合约账户';

  @override
  String get asterAccountTab => 'Aster 账户';

  @override
  String get asterAccountScope => '查询下方钱包对应的账户数据。每次刷新都由该钱包签名读取。';

  @override
  String get asterUsdtSummary => 'USDT 账户概览';

  @override
  String get asterMarginBalance => '保证金余额';

  @override
  String get asterUsdtScope => '以上仅为 USDT 数据。其他资产在下方按原币种展示；此处不代表现货、质押、金库或子账户的总资产。';

  @override
  String accountSnapshotTime(String time) {
    return '快照接收时间：$time';
  }

  @override
  String get accountSnapshotStale => '当前为历史快照，请签名刷新后再使用这些数值。';

  @override
  String get accountSignInToRead => '登录以查看账户';

  @override
  String get accountReadWithWallet => '签名读取 Aster 账户';

  @override
  String get accountRefreshWithWallet => '签名刷新账户';

  @override
  String get accountReadPreparing => '正在准备账户查询…';

  @override
  String get accountReadSigning => '请在钱包中确认账户查询签名。';

  @override
  String get accountReadLoading => '正在从 Aster 读取账户数据…';

  @override
  String get accountReadNotice =>
      '此操作仅查询账户，不下单、不创建钱包、不划转，也不授予交易权限。Aster 必须认可该钱包的查询权限；完成签名不代表已获得访问权限。';

  @override
  String accountErrorCode(int code) {
    return 'Aster 错误代码：$code';
  }

  @override
  String get accountAssetBalances => '合约资产余额';

  @override
  String get accountSearchAsset => '搜索资产';

  @override
  String get accountHideZero => '隐藏零余额';

  @override
  String get accountNoAssets => '该账户没有返回资产余额。';

  @override
  String get accountNoMatchingAssets => '没有符合当前筛选条件的资产。';

  @override
  String get accountCollateralEligible => '可在多资产模式中作为保证金';

  @override
  String get accountCollateralIneligible => '不可在多资产模式中作为保证金';

  @override
  String get accountLivePositions => 'Aster 持仓';

  @override
  String get accountNoPositions => '暂无合约持仓。';

  @override
  String get accountPositionMargin => '仓位起始保证金';

  @override
  String get accountWalletBalance => '钱包余额';

  @override
  String get accountUnrealizedPnl => '未实现盈亏';

  @override
  String get accountPositionDirection => '方向';

  @override
  String get accountMarginMode => '保证金模式';

  @override
  String get accountDataInvalid => 'Aster 返回的账户数据不完整或无效，请重试刷新。';

  @override
  String get accountRateLimited => 'Aster 暂时限制账户查询频率，请稍后重试。';

  @override
  String get accountNetwork => '无法读取账户数据，请检查网络后重试。';

  @override
  String get accountReadFailed => 'Aster 未能完成账户查询，请重试或检查账户权限。';

  @override
  String get accountSignatureExpired => '账户查询签名已过期，请重试并及时确认新的钱包请求。';

  @override
  String get accountSignatureRejected => 'Aster 拒绝了账户查询签名，请检查钱包及账户授权。';

  @override
  String get accountPermissionRequired =>
      'Aster 未认可此钱包的账户访问权限。请检查该钱包在 Aster 的 API 授权；登录 Vanta 不会自动获得该权限。';

  @override
  String get accountUnitUnavailable => '（单位待确认）';

  @override
  String get accountIsolatedMode => '逐仓';

  @override
  String get marketCategoryTop => '热门';

  @override
  String get marketCategoryRwa => 'USD1-RWA';

  @override
  String get marketCategoryMeme => 'Meme';

  @override
  String get marketCategoryAi => 'AI';

  @override
  String get marketCategoryPreLaunch => '盘前';

  @override
  String get marketCategoryStocks => '股票';

  @override
  String get marketCategoryEtf => 'ETF';

  @override
  String get marketCategoryCommodities => '大宗商品';

  @override
  String get marketCategorySemiconductors => '半导体';

  @override
  String get marketNoCategoryResults => '该分类下没有符合筛选条件的合约。';

  @override
  String marketResultsCount(int shown, int total) {
    return '$shown / $total 个永续合约';
  }

  @override
  String get marketCategories => '市场分类';

  @override
  String get marketCategoryAll => '全部分类';

  @override
  String get accountPerpetualTab => '合约';

  @override
  String get accountSpotTab => '现货';

  @override
  String get spotAccountTitle => 'Aster 现货账户';

  @override
  String get spotBalanceScope => '余额以各资产数量显示，总额 = 可用 + 冻结。现货余额与合约余额分开统计。';

  @override
  String get spotAssetBalances => '现货资产余额';

  @override
  String get spotNoAssets => '现货账户暂无资产。';

  @override
  String get spotTotalBalance => '总余额';

  @override
  String get spotLockedBalance => '冻结余额';

  @override
  String get asterOpenOrdersTitle => 'Aster 合约挂单';

  @override
  String get asterOpenOrdersScope => '实盘合约订单，与上方演示订单分开。读取及撤单需要钱包签名与 Aster 认可的权限。';

  @override
  String get openOrdersReadWithWallet => '签名读取挂单';

  @override
  String get openOrdersRefreshWithWallet => '签名刷新挂单';

  @override
  String get openOrdersCurrentSymbol => '隐藏其他交易对';

  @override
  String openOrdersCount(int count) {
    return '挂单（$count）';
  }

  @override
  String get openOrdersEmpty => '该账户暂无合约挂单。';

  @override
  String get openOrdersNoCurrentSymbol => '当前交易对暂无挂单。';

  @override
  String get openOrdersBuy => '买入';

  @override
  String get openOrdersSell => '卖出';

  @override
  String get openOrdersLongSide => '多仓方向';

  @override
  String get openOrdersShortSide => '空仓方向';

  @override
  String get openOrdersOneWay => '单向持仓';

  @override
  String get openOrdersOrderType => '订单类型';

  @override
  String get openOrdersStatus => '状态';

  @override
  String get openOrdersNew => '未成交';

  @override
  String get openOrdersPartiallyFilled => '部分成交';

  @override
  String get openOrdersCreatedLocal => '下单时间（本地）';

  @override
  String get openOrdersFilledTotal => '已成交／总数量';

  @override
  String get openOrdersRemaining => '未成交数量';

  @override
  String get openOrdersClosePosition => '全部平仓';

  @override
  String get openOrdersOrderPrice => '委托价格';

  @override
  String get openOrdersOrderValue => '委托价值';

  @override
  String get openOrdersActivationPrice => '激活价格';

  @override
  String get openOrdersCallbackRate => '回调比例';

  @override
  String get openOrdersTriggerPrice => '触发价格';

  @override
  String get openOrdersMarkPrice => '标记价';

  @override
  String get openOrdersLastPrice => '最新成交价';

  @override
  String get openOrdersUnknownTrigger => '触发基准待确认';

  @override
  String get openOrdersReduceOnly => '只减仓';

  @override
  String get openOrdersHidden => '隐藏单';

  @override
  String get openOrdersLimit => '限价';

  @override
  String get openOrdersMarket => '市价';

  @override
  String get openOrdersStopLimit => '止损限价';

  @override
  String get openOrdersStopMarket => '止损市价';

  @override
  String get openOrdersTakeProfitLimit => '止盈限价';

  @override
  String get openOrdersTakeProfitMarket => '止盈市价';

  @override
  String get openOrdersTrailingStop => '追踪止损';

  @override
  String get openOrdersOtherType => '其他订单类型';

  @override
  String get openOrdersBbo => '最优挂单价';

  @override
  String get accountDepositRequired => 'Aster 要求该账户关联的主钱包先完成充值，才可使用 V3 私有账户或订单查询。';

  @override
  String get orderCancelTitle => '撤销订单';

  @override
  String get orderCancelKeep => '保留订单';

  @override
  String get orderCancelConfirm => '签名撤单';

  @override
  String get orderCancelConfirmHint =>
      '仅撤销该合约订单尚未成交的部分，已成交仓位保留。当前钱包将先签名撤单，再单独签名查询最终状态。此操作需要 Aster 认可的钱包权限。';

  @override
  String get orderCancelSigning => '请在钱包中确认撤单签名。';

  @override
  String get orderCancelSubmitting => '正在提交撤单，结果尚未确认。';

  @override
  String get orderCancelChecking => '正在核对订单最终状态。';

  @override
  String get orderCancelCheckSigning => '请在钱包中签名查询订单状态，以核对撤单结果。';

  @override
  String get orderCancelUnknown => '撤单结果尚未确认。核对状态前保留原订单，请先查询状态再决定是否重新撤单。';

  @override
  String get orderCancelRecheck => '签名核对状态';

  @override
  String get orderCancelVerified => 'Aster 已确认该订单已撤销。已成交仓位保留，账户余额需另行刷新。';

  @override
  String get orderCancelFilled => 'Aster 显示该订单已全部成交，并未撤销。请刷新仓位和余额。';

  @override
  String get orderCancelExpired => 'Aster 显示该订单已过期，请刷新仓位和余额。';

  @override
  String get orderCancelRejected => 'Aster 显示该订单已被拒绝，请刷新仓位和余额。';

  @override
  String get orderCancelStillOpen => 'Aster 显示该订单仍未完成，请查看当前已成交数量后再决定是否重试。';

  @override
  String get batchCancelAll => '撤销列表内全部挂单';

  @override
  String get batchCancelCurrent => '撤销当前合约全部挂单';

  @override
  String get batchCancelTitle => '撤销所列合约的全部挂单？';

  @override
  String get batchCancelHint =>
      '撤销 Aster 处理请求时所列合约的全部挂单，包括其他设备新建的同合约挂单。范围不含其他合约和现货订单。每个合约均需签名撤单，再签名查询状态。已成交仓位保留。';

  @override
  String batchCancelScopeCount(int orders, int symbols) {
    return '快照范围：$symbols 个合约，共 $orders 笔挂单';
  }

  @override
  String get batchCancelConfirm => '逐合约签名撤单';

  @override
  String get batchCancelNotSubmitted => '未提交';

  @override
  String get batchCancelUnknown => '结果未确认，请先核对状态再决定是否重试。';

  @override
  String get batchCancelNoOpen => '核对时已无挂单';

  @override
  String batchCancelRemaining(int count) {
    return '仍有 $count 笔挂单';
  }

  @override
  String get batchCancelRecheck => '签名核对未确认的合约';

  @override
  String get batchCancelStop => '停止后续提交';

  @override
  String get batchCancelStopped => '已停止后续提交，请查看各合约的处理结果。';

  @override
  String get batchCancelReadFirst => '请先读取实盘挂单，再选择全部撤单。';

  @override
  String get batchCancelInProgress => '正在处理，结果尚未核对';

  @override
  String get historyTitle => '现货历史';

  @override
  String get historyOrders => '订单历史';

  @override
  String get historyTrades => '成交历史';

  @override
  String get historyTransactions => '资产流水';

  @override
  String get historyScope => '当前现货钱包的历史记录。订单、逐笔成交与资产变动分别展示。';

  @override
  String get historySymbolFilter => '现货交易对（可选）';

  @override
  String get historyAssetFilter => '资产（可选）';

  @override
  String get historyFilterHint => '请输入完整标识，留空查询全部。更改筛选会清除旧结果，不会自动签名。';

  @override
  String get historyWindowLabel => '查询时间范围（UTC）';

  @override
  String get historyDay => '最近24小时';

  @override
  String get historyWeek => '最近7天';

  @override
  String get historyCustom => '选择日期';

  @override
  String get historyRead => '签名读取所选范围';

  @override
  String get historyRefresh => '签名重读所选范围';

  @override
  String get historyContinue => '签名读取下一个时间窗口';

  @override
  String get historyPartial => '所选范围尚未读取完整。每次请求最多覆盖7天、1,000条记录；请继续签名读取剩余时间窗口。';

  @override
  String get historyTruncated => '至少一个毫秒内的记录达到接口上限，结果不完整；请缩小交易对或资产范围。';

  @override
  String get historyComplete => '已读取所选时间范围，结果受接口保留期限制。';

  @override
  String get historyEmpty => '所选时间范围和筛选条件下未返回记录。';

  @override
  String get historyRetention => '现货订单接口不返回创建超过7天的订单。';

  @override
  String get historyNotAtomic => '不同读取时刻的结果可能变化。继续读取会保留首次响应时间，并按记录标识合并。';

  @override
  String get historyInvalidScope => '请输入完整交易对或资产标识，最多50个字母、数字、点、下划线或连字符。';

  @override
  String get historyInvalidWindow => '请选择有效日期范围。订单历史最多查询7天。';

  @override
  String historyLoaded(int count) {
    return '已加载记录：$count';
  }

  @override
  String historyPage(int page, int pages) {
    return '已加载记录第$page／$pages页';
  }

  @override
  String get historyPrev => '上一页';

  @override
  String get historyNext => '下一页';

  @override
  String get historyCreatedUTC => '下单时间（UTC）';

  @override
  String get historyUpdatedUTC => '更新时间（UTC）';

  @override
  String get historyExecutionUTC => '成交时间（UTC）';

  @override
  String get historyEventUTC => '时间（UTC）';

  @override
  String get historyAveragePrice => '成交均价';

  @override
  String get historyExecutedQuote => '已成交报价币金额';

  @override
  String get historyTradeId => '成交编号';

  @override
  String get historyTransactionId => '流水编号';

  @override
  String get historyCommission => '手续费／返佣';

  @override
  String get historyLiquidity => '流动性角色';

  @override
  String get historyMaker => '挂单方';

  @override
  String get historyTaker => '吃单方';

  @override
  String get historyBalanceChange => '余额变动';

  @override
  String get historyTransactionType => '流水类型';

  @override
  String historyUnknownCode(String code) {
    return '其他（$code）';
  }

  @override
  String get historyFilled => '已成交';

  @override
  String get historyCanceled => '已撤销';

  @override
  String get historyExpired => '已过期';

  @override
  String get historyRejected => '已拒绝';

  @override
  String get historyPendingCancel => '撤销处理中';

  @override
  String get historyDeposit => '充值';

  @override
  String get historyWithdraw => '提现';

  @override
  String get historyTransfer => '划转';

  @override
  String get historyTradeSource => '交易转出';

  @override
  String get historyTradeTarget => '交易转入';

  @override
  String get historyAirdrop => '空投';

  @override
  String get historyDividend => '分红';

  @override
  String get historySwap => '兑换';

  @override
  String get historyRebate => '手续费返佣';

  @override
  String get historyTradeQuantity => '成交数量';

  @override
  String get historyStop => '停止等待';

  @override
  String get historyReadStopped => '已停止本次读取，可重新尝试。';

  @override
  String get positionRiskTitle => '仓位风险';

  @override
  String get positionRiskScope =>
      '读取当前连接钱包的仓位。签名快照为基准；启用账户监听后可逐项更新仓位，公开标记价另行更新估值。余额需独立读取。平仓需单独确认和签名，TP/SL 尚未接入。';

  @override
  String get positionRiskRead => '签名读取仓位风险';

  @override
  String get positionRiskRefresh => '签名刷新仓位风险';

  @override
  String positionRiskCount(int count) {
    return '仓位记录（$count）';
  }

  @override
  String get positionRiskNoCurrent => '当前交易对没有仓位记录。';

  @override
  String get positionRiskBalanceOnly => '逐仓负余额';

  @override
  String get positionRiskSide => '持仓模式方向';

  @override
  String get positionRiskNotional => '带方向名义价值';

  @override
  String get positionRiskLiquidation => '强平价格';

  @override
  String get positionRiskIsolatedWallet => '逐仓钱包余额';

  @override
  String get positionRiskIsolatedMargin => '逐仓保证金';

  @override
  String get positionRiskUpdated => '仓位更新时间（UTC）';

  @override
  String get positionRiskLiquidationHint => '强平价缺失或为零时显示 —，不表示仓位没有强平风险。';

  @override
  String get positionRiskBalanceHint => '仓位数量为零，但逐仓钱包余额为负，保留此记录以便核查。';

  @override
  String get positionAdlTitle => 'ADL 自动减仓队列';

  @override
  String get positionAdlScope =>
      '使用钱包单独读取 ADL。档位为 0～4，由低到高，交易所约每30秒更新；四格全亮表示最高档位。此指标不是保证金率或强平倒计时。请分别刷新仓位和 ADL，核查对应快照。';

  @override
  String get positionAdlRead => '签名读取 ADL';

  @override
  String get positionAdlRefresh => '签名刷新 ADL';

  @override
  String get positionAdlUnknown => '未知，请读取或刷新匹配的 ADL 数据';

  @override
  String get positionAdlNotApplicable => '零数量余额记录不适用';

  @override
  String positionAdlLevel(int level) {
    return '档位 $level / 4';
  }

  @override
  String positionAdlHistorical(int level) {
    return '历史档位 $level / 4，请刷新';
  }

  @override
  String get positionAdlEmpty => '接口未返回 ADL 记录，未匹配的仓位保持未知。';

  @override
  String get positionMarkReadFirst => '读取仓位后自动接收公开标记价。';

  @override
  String get positionMarkScope =>
      '估值使用当前显示的仓位数量、开仓均价及公开标记价，不含手续费与资金费用。行情超过10秒视为过期；更新行情不会核对完整仓位列表、保证金或强平价。';

  @override
  String positionMarkCoverage(int fresh, int total) {
    return '新鲜标记行情：$fresh / $total 个交易对';
  }

  @override
  String get positionMarkSnapshot => '快照标记价';

  @override
  String get positionMarkCurrent => '当前标记价';

  @override
  String get positionMarkHistorical => '历史标记价';

  @override
  String get positionMarkTime => '标记行情时间（UTC）';

  @override
  String get positionEstimatedNotional => '估算带方向名义价值';

  @override
  String get positionEstimatedPnl => '估算未实现盈亏';

  @override
  String get positionEstimateStale => '历史估值：仓位或标记行情需要刷新。';

  @override
  String get positionSnapshotNotional => '快照带方向名义价值';

  @override
  String get positionSnapshotPnl => '快照未实现盈亏';

  @override
  String get positionMarkUnavailable => '部分标记行情不可用或已过期，保留值为历史行情。';

  @override
  String get positionMarkRetry => '重试公开标记行情';

  @override
  String get accountChangeTitle => '合约变更监听';

  @override
  String get accountChangeScope =>
      '使用当前钱包签名监听合约账户。完整签名读取后，已校验事件逐项更新挂单、钱包余额及仓位数量；不代表列表完整，也不补回断线期间的更新。汇总、可用余额、杠杆、强平价及 ADL 仍需签名核对，Spot 需单独读取。启动或续期各需一次签名，不会自动弹出钱包。授权最长 60 分钟。停止仅关闭本机连接。';

  @override
  String get accountChangeStopped => '未开启监听';

  @override
  String get accountChangeConnecting => '正在连接变更监听…';

  @override
  String get accountChangeConnected => '变更监听已连接 · 快照仍需核对';

  @override
  String get accountChangeDisconnected => '监听已断开 · 可能遗漏变更';

  @override
  String get accountChangePaused => '后台已暂停 · 返回后需核对快照';

  @override
  String get accountChangeExpired => '监听已到期 · 请重新签名开启';

  @override
  String get accountChangeStart => '签名开启监听';

  @override
  String get accountChangeRenew => '签名续期监听';

  @override
  String get accountChangeReconnect => '无需签名重新连接';

  @override
  String get accountChangeStop => '停止本机监听';

  @override
  String get accountChangeRenewalDue => '监听即将到期，请使用钱包手动签名续期。';

  @override
  String accountChangeExpiry(String time) {
    return '本机监听截止时间：$time';
  }

  @override
  String accountChangeLastEvent(String time) {
    return '最近事件时间：$time。请重新读取快照核对。';
  }

  @override
  String get openOrdersCreationUnknown => '未知 · 请读取订单核对';

  @override
  String get openOrdersUpdatedUTC => '订单更新时间（UTC）';

  @override
  String openOrdersEventTime(String time) {
    return '最近已应用订单事件（UTC）：$time';
  }

  @override
  String get openOrdersEventScope =>
      '已校验的订单事件会更新列表，保留部分成交并移出终态。快照时间仍代表最近一次完整读取；重连或遗漏事件可能导致列表不完整，请使用钱包刷新核对。';

  @override
  String get orderEventsCapacity => '订单事件记录已达上限。请退出并重新连接钱包，再读取订单核对。';

  @override
  String get orderCancelEventsDuringCheck => '核对期间收到了订单事件，查询可能反映较早状态。请先检查更新后的挂单列表，再进行后续操作。';

  @override
  String get accountEventsCapacity => '账户事件记录已达上限。请退出并重新连接钱包，再读取余额和仓位核对。';

  @override
  String accountEventTime(String time) {
    return '最近已应用账户事件：$time UTC';
  }

  @override
  String get accountEventScope =>
      '部分记录含事件更新。事件未提供的汇总和字段显示 —，需签名读取；未变更记录可能已过期。缺失记录不代表平仓，中断后请重新核对完整列表。';

  @override
  String get accountEventRowTime => '记录事件时间（UTC）';

  @override
  String get accountCrossWalletBalance => '全仓钱包余额';

  @override
  String get positionEventPnl => '事件未实现盈亏';

  @override
  String get positionEventFieldsHint =>
      '此事件未提供杠杆、强平价、标记价、名义价值及逐仓保证金，需重新读取仓位核对。公开标记价估算使用当前显示的数量和开仓均价，不证明账户完整。';

  @override
  String get positionAllocatedMargin => '逐仓钱包分配余额';

  @override
  String get positionEstimatedCrossMargin => '估算全仓仓位保证金';

  @override
  String get positionEstimatedInitialMargin => '估算初始保证金基数';

  @override
  String get positionEstimatedRoe => '估算仓位收益率（ROE）';

  @override
  String get positionSnapshotRoe => '快照仓位收益率估算（ROE）';

  @override
  String get positionReturnScope =>
      '线性合约：初始保证金基数＝绝对数量×标记价÷杠杆，ROE＝未实现盈亏÷该基数×100。逐仓分配使用钱包余额，与ROE基数分开。估算不含手续费和资金费，不代表账户收益率或可用余额；仓位或行情过期时仅为历史估算。杠杆或单位未知则显示 —。';

  @override
  String get leverageSettings => '合约杠杆';

  @override
  String get leverageSettingsScope => '设置此交易对的初始杠杆，双向持仓的两个方向共用此设置。修改杠杆会影响保证金要求和风险。';

  @override
  String get leverageReadSettings => '读取杠杆配置（2次签名）';

  @override
  String get leverageSettingsReadHint => '签名读取杠杆档位和交易对配置，读取不会提交修改。';

  @override
  String get leverageCurrentSetting => '读取时杠杆';

  @override
  String get leverageTarget => '目标杠杆';

  @override
  String leverageInputHint(int maximum) {
    return '请输入1至$maximum之间且不同于当前值的整数。实际可用上限还受仓位金额等限制，以Aster校验为准。';
  }

  @override
  String get leverageContextExpired => '配置需要重新读取后才能修改杠杆，已保留输入。';

  @override
  String get leverageInvalidTarget => '请输入显示范围内且不同于当前值的整数杠杆。';

  @override
  String get leverageReviewChange => '检查杠杆修改';

  @override
  String get leverageConfirmTitle => '确认修改合约杠杆？';

  @override
  String get leverageConfirmHint => '将修改下方钱包在此交易对的杠杆，包含双向持仓的两个方向。签名提交后，还需再次签名查询结果。更高杠杆会增加风险。';

  @override
  String leverageRequestedChange(int previous, int target) {
    return '$previous× → $target×';
  }

  @override
  String get leverageSignChange => '签名修改杠杆';

  @override
  String get leverageSubmitting => '正在提交杠杆修改…';

  @override
  String get leverageCheckSigning => '请签名核对杠杆';

  @override
  String get leverageChecking => '正在查询杠杆…';

  @override
  String leverageVerified(int value) {
    return '查询已核对目标杠杆：$value×。';
  }

  @override
  String leverageObservedDifferent(int observed, int target) {
    return '查询显示$observed×，目标为$target×。请刷新配置后再检查新的修改。';
  }

  @override
  String get leverageOutcomeUnknown => '请求可能已到达Aster，结果尚未核实。请重新查询配置；查询不会再次提交修改。';

  @override
  String get leverageRecheck => '签名查询结果';

  @override
  String get leverageResultScope => '此结果是查询快照，请重新读取仓位和余额以核对保证金及风险字段。';

  @override
  String get leverageExposureLimit => '仓位金额超过此杠杆允许的上限。请降低杠杆并刷新配置。';

  @override
  String get leverageMarginInsufficient => '当前保证金不足以使用此杠杆。请核对余额并刷新配置后重试。';

  @override
  String get leverageNotAllowed => 'Aster未接受此杠杆，请刷新交易对档位和当前配置。';

  @override
  String get marginModeSettings => '合约保证金模式';

  @override
  String get marginModeSettingsScope => '选择此交易对的全仓或逐仓模式，双向持仓的两个方向共用设置。此操作会修改真实账户配置及保证金风险。';

  @override
  String get marginModeCrossHint => '全仓模式下，合格账户抵押资金由全仓仓位共享。';

  @override
  String get marginModeIsolatedHint => '逐仓模式为每个仓位单独分配抵押资金。切换保证金模式不会切换单一／多资产模式或单向／双向持仓模式。';

  @override
  String get marginModeReadSettings => '读取模式和挂单（2次签名）';

  @override
  String get marginModeReadHint => '签名读取此交易对配置和挂单，读取不会提交修改。配置30秒后过期，包含等待第二次签名的时间。';

  @override
  String get marginModeCurrentSetting => '读取时保证金模式';

  @override
  String get marginModeTarget => '目标保证金模式';

  @override
  String get marginModeContextExpired => '请刷新模式和挂单后再检查修改，已保留选择。';

  @override
  String get marginModeChangeBlocked => '请选择不同的模式。切换前需先平仓并撤销挂单。';

  @override
  String get marginModeHasPosition => '此交易对存在持仓，请先平仓并刷新配置后再切换保证金模式。';

  @override
  String get marginModeOpenOrders => '此交易对存在挂单，请先撤单并刷新配置后再切换保证金模式。';

  @override
  String get marginModeAlreadySet => 'Aster提示已经是此模式，下方签名查询结果显示实际观测模式。';

  @override
  String get marginModeConfirmTitle => '确认切换合约保证金模式？';

  @override
  String get marginModeConfirmHint =>
      '将修改下方钱包在此交易对的配置，包含双向持仓的两个方向。签名提交后，还需再次签名查询结果。Aster将校验持仓、挂单和资产模式限制。';

  @override
  String get marginModeSignChange => '签名切换保证金模式';

  @override
  String get marginModeReviewChange => '检查模式切换';

  @override
  String get marginModeSubmitting => '正在提交保证金模式切换…';

  @override
  String get marginModeCheckSigning => '请签名核对保证金模式';

  @override
  String get marginModeChecking => '正在查询保证金模式…';

  @override
  String marginModeVerified(String mode) {
    return '查询已核对目标保证金模式：$mode。';
  }

  @override
  String marginModeObservedDifferent(String observed, String target) {
    return '查询显示$observed，目标为$target。请刷新配置后再检查新的修改。';
  }

  @override
  String get marginModeOutcomeUnknown => '请求可能已到达Aster，结果尚未核实。请签名重新查询，查询不会再次提交切换。';

  @override
  String get symbolSettingsOtherPending => '请先回到对应设置页处理尚未完成的合约设置请求，再发起其他设置操作。';

  @override
  String get positionModeSettings => '合约持仓模式';

  @override
  String get positionModeAllSymbols => '全部合约交易对';

  @override
  String get positionModeSettingsScope => '为此钱包账户的全部合约交易对选择单向或双向持仓模式，此操作会修改真实账户配置。';

  @override
  String get positionModeOneWay => '单向持仓';

  @override
  String get positionModeHedge => '双向持仓';

  @override
  String get positionModeOneWayHint => '单向模式下，每个交易对保留一个净持仓。';

  @override
  String get positionModeHedgeHint => '双向模式分别保留多头和空头仓位。切换前需清空全部交易对的持仓和挂单；此操作不会自动平仓、撤单或切换保证金及资产模式。';

  @override
  String get positionModeReadSettings => '读取模式、仓位及挂单（3次签名）';

  @override
  String get positionModeReadHint => '分别签名读取持仓模式、全部合约仓位和挂单，读取不会提交修改。配置从首个响应起30秒有效，包含等待后续签名的时间。';

  @override
  String get positionModeCurrentSetting => '读取时持仓模式';

  @override
  String get positionModeTarget => '目标持仓模式';

  @override
  String get positionModeContextExpired => '请刷新模式、仓位及挂单后再检查修改，已保留选择。';

  @override
  String get positionModeChangeBlocked => '请选择不同模式，切换前需平掉全部合约仓位并撤销挂单。';

  @override
  String get positionModeHasPosition => '此账户存在合约持仓，请先平仓并刷新配置后再切换持仓模式。';

  @override
  String get positionModeOpenOrders => '此账户存在合约挂单，请先撤单并刷新配置后再切换持仓模式。';

  @override
  String get positionModeAlreadySet => 'Aster提示已经是此持仓模式，下方签名查询显示实际观测模式。';

  @override
  String get positionModeConfirmTitle => '确认切换全部合约的持仓模式？';

  @override
  String get positionModeConfirmHint =>
      '将修改下方钱包全部合约交易对的持仓模式。签名提交后还需再次签名查询结果。Aster将校验全部仓位和挂单；预读不能锁定其他终端的变更。';

  @override
  String get positionModeSignChange => '签名切换持仓模式';

  @override
  String get positionModeReviewChange => '检查模式切换';

  @override
  String get positionModeSubmitting => '正在提交持仓模式切换…';

  @override
  String get positionModeCheckSigning => '请签名核对持仓模式';

  @override
  String get positionModeChecking => '正在查询持仓模式…';

  @override
  String positionModeVerified(String mode) {
    return '查询已核对目标持仓模式：$mode。';
  }

  @override
  String positionModeObservedDifferent(String observed, String target) {
    return '查询显示$observed，目标为$target。请刷新配置后再检查新的修改。';
  }

  @override
  String get positionModeOutcomeUnknown => '请求可能已到达Aster，结果尚未核实。请签名重新查询，查询不会再次提交切换。';

  @override
  String get assetModeSettings => '合约资产模式';

  @override
  String get assetModeAllSymbols => '全部合约交易对';

  @override
  String get assetModeSettingsScope => '为此钱包账户的全部合约交易对选择单一或多资产保证金模式，此操作会改变抵押资产及保证金风险。';

  @override
  String get assetModeSingle => '单一资产';

  @override
  String get assetModeMulti => '多资产';

  @override
  String get assetModeSingleHint => '单一资产模式使用合约对应的保证金资产。';

  @override
  String get assetModeMultiHint =>
      '多资产模式由全仓仓位共享合格抵押资产。需先处理逐仓仓位或留存的逐仓抵押余额；支持资产、估值、余额要求及最终切换资格由Aster确定。';

  @override
  String get assetModeReadSettings => '读取资产模式及仓位（2次签名）';

  @override
  String get assetModeReadHint => '分别签名读取资产模式和全部合约仓位配置，读取不会提交修改。配置从首个响应起30秒有效，包含等待第二次签名的时间。';

  @override
  String get assetModeCurrentSetting => '读取时资产模式';

  @override
  String get assetModeTarget => '目标资产模式';

  @override
  String get assetModeContextExpired => '请刷新资产模式及仓位后再检查修改，已保留选择。';

  @override
  String get assetModeChangeBlocked => '请选择不同的资产模式，启用多资产前需先处理逐仓仓位或抵押余额。';

  @override
  String get assetModeIsolatedBlocker => '下列交易对存在逐仓仓位或留存的逐仓抵押余额，请先处理后再启用多资产模式。应用不会自动切换保证金模式。';

  @override
  String get assetModeConfirmTitle => '确认切换全部合约的资产模式？';

  @override
  String get assetModeConfirmHint =>
      '将改变下方钱包全部合约交易对的抵押资产及保证金风险。签名提交后还需再次签名查询结果。Aster将校验余额及限制，预读不能锁定其他终端的变更；本请求不修改持仓模式、交易对保证金模式或演示配置。';

  @override
  String get assetModeSignChange => '签名切换资产模式';

  @override
  String get assetModeReviewChange => '检查资产模式切换';

  @override
  String get assetModeSubmitting => '正在提交资产模式切换…';

  @override
  String get assetModeCheckSigning => '请签名核对资产模式';

  @override
  String get assetModeChecking => '正在查询资产模式…';

  @override
  String assetModeVerified(String mode) {
    return '查询已核对目标资产模式：$mode。';
  }

  @override
  String assetModeObservedDifferent(String observed, String target) {
    return '查询显示$observed，目标为$target。请刷新配置后再检查新的修改。';
  }

  @override
  String get assetModeOutcomeUnknown => '请求可能已到达Aster，结果尚未核实。请签名重新查询，查询不会再次提交切换。';

  @override
  String get liveOrderEntry => '实盘合约下单';

  @override
  String get liveOrderEntryHint => '上方表单使用本地演示资金。实盘订单使用独立的钱包确认流程。';

  @override
  String get liveOrderTitle => '实盘合约下单';

  @override
  String get liveOrderScope =>
      '使用当前钱包提交真实普通单、条件单或跟踪委托；限价使用交易对支持的成交策略。单向模式的买卖可能减仓或反转现有持仓；双向模式操作所选多仓或空仓。费用、可用保证金及最终资格由 Aster 校验。';

  @override
  String get liveOrderReadContext => '读取下单配置（2 次签名）';

  @override
  String get liveOrderReadHint => '读取公开交易规则及标记价，再分别签名读取持仓模式和交易对配置。有效期从标记价响应起算 30 秒。读取不会下单。';

  @override
  String get liveOrderSettingsBusy => '请先完成待处理的合约配置操作，再提交订单。';

  @override
  String get liveOrderSubmitting => '正在提交实盘订单…';

  @override
  String get liveOrderMarkPrice => '参考标记价';

  @override
  String get liveOrderContextExpired => '请刷新下单配置后再确认订单，已填内容会保留。';

  @override
  String liveOrderQuantity(String asset) {
    return '数量（$asset）';
  }

  @override
  String liveOrderQuantityBounds(String minimum, String maximum, String step) {
    return '最小 $minimum；最大 $maximum；步长 $step';
  }

  @override
  String liveOrderPrice(String asset) {
    return '限价（$asset）';
  }

  @override
  String liveOrderPriceTick(String tick) {
    return '价格步长：$tick';
  }

  @override
  String get liveOrderEstimatedNotional => '参考名义价值';

  @override
  String get liveOrderReview => '核对实盘订单';

  @override
  String get liveOrderClientId => '客户端订单编号';

  @override
  String liveOrderVerifiedResult(String status, String executed, String orderId) {
    return '签名查询状态：$status；已成交数量 $executed；订单 $orderId。';
  }

  @override
  String get liveOrderQueryScope => '以上为查询时的快照。只有 FILLED 代表所请求数量全部成交；后续变更需再次读取账户核对。';

  @override
  String get liveOrderOutcomeUnknown => '请求可能已到达 Aster，请使用此客户端编号查询核对。当前禁止再次下单；查询不会重新提交订单。';

  @override
  String get liveOrderRecheck => '签名查询此订单';

  @override
  String get liveOrderConfirmTitle => '提交此实盘合约订单？';

  @override
  String get liveOrderConfirmHint =>
      '此操作会提交真实订单。先签名下单，再另行签名查询状态。市价单实际成交价可能不同；限价单按下方所示策略执行。本操作不修改杠杆或保证金配置。';

  @override
  String get liveOrderPolicy => '限价成交策略';

  @override
  String get liveOrderConditional => '条件委托';

  @override
  String get liveOrderPositionTriggers => '仓位止盈止损';

  @override
  String get liveOrderStop => '止损／突破';

  @override
  String get liveOrderTakeProfit => '止盈';

  @override
  String get liveOrderTriggerBasis => '触发价格依据';

  @override
  String get liveOrderTriggerReference => '读取时的参考价格';

  @override
  String get liveOrderTriggerRises => '当所选依据价格上涨至触发价或更高时触发。';

  @override
  String get liveOrderTriggerFalls => '当所选依据价格下跌至触发价或更低时触发。';

  @override
  String get liveOrderTriggerProtect => '触发价格保护';

  @override
  String get liveOrderProtectOn => '开启';

  @override
  String get liveOrderProtectOff => '关闭';

  @override
  String get liveOrderProtectHint => '开启后，触发时标记价与最新价的价差还需满足交易对阈值，可能延迟或阻止触发；该保护不保证成交价格。';

  @override
  String liveOrderProtectThreshold(String percent) {
    return '触发时允许的价差比例：$percent%。';
  }

  @override
  String get liveOrderConditionalHint =>
      '本次提交一笔指定数量的独立条件单。触发不保证成交；分别设置的止盈和止损不会自动互撤。后续仓位变化可能影响执行，请另行核对已有挂单。';

  @override
  String get liveOrderConditionalEstimateHint =>
      '仅供参考：条件市价单按触发价估算，条件限价单按委托价估算。触发前仓位、杠杆及可用资金可能变化；不含手续费、资金费、深度滑点及执行时校验，不代表已实现盈亏或保证金承诺。';

  @override
  String get liveOrderTypeUnavailable => '最新交易对规则不支持此订单类型，请刷新规则或选择支持的类型。';

  @override
  String get liveOrderInvalidTrigger => '请输入正数十进制触发价格。';

  @override
  String get liveOrderTriggerFilter => '触发价格须满足交易所的价格范围及步长。';

  @override
  String get liveOrderProtectUnavailable => '当前交易对规则未提供触发保护阈值，请刷新或明确关闭保护后再确认。';

  @override
  String get liveOrderTriggerReferenceUnavailable => '所选触发依据的参考价不可用，请刷新或明确选择其他依据；不会自动替换价格。';

  @override
  String get liveOrderTriggerImmediate => '按本次读取的参考价，触发条件已达到。请按显示的方向调整触发价后重新确认；提交时实际价格由 Aster 校验。';

  @override
  String get liveOrderPolicyChoose => '请选择支持的策略';

  @override
  String get liveOrderPolicyGtc => 'GTC';

  @override
  String get liveOrderPolicyIoc => 'IOC';

  @override
  String get liveOrderPolicyPostOnly => '只做 Maker（GTX）';

  @override
  String get liveOrderPolicyHidden => '隐藏单（HIDDEN）';

  @override
  String get liveOrderPolicyGtcHint => 'GTC：未成交数量持续挂单，直到成交或取消。';

  @override
  String get liveOrderPolicyIocHint => 'IOC：立即成交当前可成交数量，取消剩余部分，可能仅部分成交。';

  @override
  String get liveOrderPolicyPostOnlyHint =>
      '只做 Maker：订单必须以挂单方身份参与撮合。若会立即吃单，不按普通限价单执行；是否接受及成交须以交易所核对结果为准。';

  @override
  String get liveOrderPolicyHiddenHint => '隐藏单：不在公开订单簿展示；不保证 Maker 成交、成交结果或撮合优先级。';

  @override
  String get liveOrderTimeInForceUnavailable => '最新交易对规则不支持当前限价策略。请选择支持的策略或改用市价，再重新确认。';

  @override
  String get liveOrderSide => '方向';

  @override
  String get liveOrderType => '订单类型';

  @override
  String get liveOrderSignSubmit => '签名并提交实盘订单';

  @override
  String get liveOrderInvalidQuantity => '请输入正数十进制数量。';

  @override
  String get liveOrderInvalidPrice => '请输入正数十进制限价。';

  @override
  String get liveOrderQuantityFilter => '数量须符合当前订单类型显示的最小值、最大值及步长。';

  @override
  String get liveOrderPriceFilter => '限价须符合交易所价格范围及步长。';

  @override
  String get liveOrderPercentFilter => '限价超出参考标记价下该方向允许的价格范围，请刷新配置或调整价格。';

  @override
  String get liveOrderNotionalFilter => '订单价值低于交易所最小名义价值；市价单以参考标记价计算。';

  @override
  String get liveCloseTitle => '实盘平仓';

  @override
  String get liveCloseScope =>
      '选择普通或跟踪平仓前，请读取当前钱包的最新仓位。仓位止盈止损支持固定数量或触发时全部平仓。单向固定数量平仓只减少持仓；双向保留原 LONG／SHORT 方向。比例数量按步长向下取整，100% 仍可能有剩余。已有挂单不会自动撤销。';

  @override
  String get liveClosePositionChanged => '所选仓位或配置已缺失或发生变化，请刷新下单配置后重新核对。';

  @override
  String get liveCloseTooLarge => '平仓数量不能超过已读取的该方向仓位数量。';

  @override
  String get liveCloseLong => '平多 · 卖出';

  @override
  String get liveCloseShort => '平空 · 买入';

  @override
  String get liveClosePositionAmount => '上次读取的仓位数量';

  @override
  String get liveCloseEstimatedPnl => '预计平仓盈亏';

  @override
  String get liveCloseEstimateHint =>
      '仅为估算：市价平多取读取时买一、平空取卖一；限价按输入价格计算。不含手续费、资金费及深度滑点，缺少盘口时显示 —，不代表已实现盈亏。';

  @override
  String get liveCloseConfirmTitle => '提交此次减仓订单？';

  @override
  String get liveCloseConfirmHint =>
      '此操作将提交真实减仓订单。先签名复核仓位，再签名下单，并另行签名查询。数量、开仓均价或配置变化时停止提交。市价可能变化；限价按下方所示策略执行。并发变化由交易所最终校验。';

  @override
  String get liveCloseResultScope => '订单状态不能证明整个仓位已平掉。请另行签名读取剩余仓位；此操作不撤销其他挂单，后续交易仍可能改变仓位。';

  @override
  String get liveCloseReadRemaining => '签名读取剩余仓位';

  @override
  String get liveCloseRemaining => '本次读取的剩余数量';

  @override
  String get liveOrderReduceHint => '仅减少已有仓位，不主动开出反向仓位。包含并发挂单在内的可减仓数量由 Aster 校验。';

  @override
  String get liveOrderReduceHedge => '双向模式不支持 reduceOnly 参数。请使用仓位的平仓入口减少对应多仓或空仓。';

  @override
  String get batchCloseAll => '平掉全部已列实盘仓位';

  @override
  String get batchCloseCurrent => '平掉当前交易对全部实盘仓位';

  @override
  String get batchCloseTitle => '按市价平掉这些实盘仓位？';

  @override
  String get batchCloseHint =>
      '仅包含列出的钱包、交易对、仓位方向与精确数量。逐个非零仓位提交反向市价单：单向仅减仓，双向保留原方向。不含已有挂单和 Spot。每仓需分别签名读取配置、复核仓位、下单及查询，最后再签名读取仓位。仓位变化、数量不符合规则、拒签或结果未确认时停止后续提交，不自动调整数量或重试下单。后续活动仍可能改变仓位。';

  @override
  String get batchCloseReadFirst => '全部平仓前请完整读取最新实盘仓位；若有未确认的交易或配置修改，须先核对结果。';

  @override
  String batchCloseCount(int count) {
    return '已确认范围：$count 个仓位';
  }

  @override
  String get batchCloseConfirm => '签名并逐仓平仓';

  @override
  String get batchCloseStopped => '已停止后续提交。未提交的仓位需要重新读取并确认。';

  @override
  String get batchCloseRecheck => '签名查询未确认的订单，不重新下单';

  @override
  String get liveOrderFundsReadHint =>
      '读取公开规则和标记价，再分别签名读取持仓模式、交易对仓位、资产模式和账户资金（4 次签名）。从标记价响应起 30 秒内有效；读取不会下单。';

  @override
  String get liveOrderReadFunds => '开仓确认前请读取资产模式和账户资金。缺失金额表示未知，不是零。';

  @override
  String get liveOrderFundsChanged => '账户资金与所选仓位或配置快照不一致，请刷新后重新确认。';

  @override
  String get liveOrderTradingDisabled => '签名账户响应显示当前禁止交易，请先核对 Aster 账户后再开仓。';

  @override
  String get liveOrderAvailableUsdt => '读取时 USDT 可用保证金';

  @override
  String get liveOrderFundsScope =>
      '该快照仅涵盖本合约账户的 USDT 可用保证金，区别于钱包余额、可提现额度、本地演示资金及读取后新增的资金占用。实际可用额度由 Aster 校验。';

  @override
  String get liveOrderFundsMultiHint => '多资产模式下，USDT 数值不是全部抵押资产合计；其他币种保留各自单位，不假设换算汇率或抵押折扣。';

  @override
  String get liveOrderFundsAssets => '各资产可用余额及抵押资格';

  @override
  String get liveOrderCollateralUnknown => '接口未提供抵押资格';

  @override
  String get liveOrderOpeningQuantity => '参考新增开仓数量';

  @override
  String get liveOrderOpeningMargin => '预计新增开仓初始保证金';

  @override
  String get liveOrderMarginEstimateHint =>
      '仅供参考：新增开仓数量 × 输入限价（市价用参考标记价）÷ 已读杠杆。单向订单先抵消已读反向仓位；双向订单开出所选方向。有效仅减仓不新增开仓敞口。手续费、资金费、已有挂单、释放保证金、实际成交价及风险档位均可能改变实际需求。';

  @override
  String get liveOrderFundsHistorical => '历史资金快照；再次开仓确认前请刷新。';

  @override
  String get liveOrderMarginAboveBalance => '估算高于已读 USDT 可用余额，请核对资金；未计释放保证金和手续费，最终由 Aster 校验。';

  @override
  String get liveEntireClose => '触发时全部平仓';

  @override
  String get liveEntireHint => '交易所按触发时的实际仓位全部平仓，可能与当前快照不同。不提交固定数量或 reduceOnly；独立止盈止损单不会自动互撤。';

  @override
  String get liveEntireMarketOnly => '全部平仓仅支持条件市价单。';

  @override
  String get liveEntireEstimateHint => '按已读取仓位数量和触发价估算；触发时数量、成交价、手续费和资金费会影响结果。';

  @override
  String get liveEntireQuantity => '触发时的全部仓位数量';

  @override
  String get liveEntireQueryScope => '此查询仅核对本笔全部平仓单及其已报告成交量。订单已成交不等于剩余仓位为零，请重新读取仓位。';

  @override
  String get liveEntireInvalid => '全部平仓须使用指定仓位方向的条件市价单，且不填写数量、限价或 reduceOnly。';

  @override
  String get triggerCalculator => '按 PnL／ROI 换算触发价';

  @override
  String get triggerCalculationHint =>
      '使用所选部分数量，或全部平仓时已读取的仓位数量。ROI 是基于开仓价与杠杆的估算，并非账户收益率。采用候选价只更新触发价，不提交订单；刷新不会覆盖触发价。';

  @override
  String get triggerCalculationQuantity => '换算参考数量';

  @override
  String get triggerCalculationRoi => '预估 ROI';

  @override
  String get triggerCalculationPnlLabel => 'PnL 目标';

  @override
  String triggerCalculationPnl(String asset) {
    return 'PnL 目标（$asset，可负数）';
  }

  @override
  String get triggerCalculationRoiTarget => 'ROI 目标（%，可负数）';

  @override
  String get triggerCalculationPrice => '候选触发价';

  @override
  String get triggerCalculationRounding =>
      '按交易所价格步长就近取整；显示的是取整后的估算，不含手续费和资金费，不保证成交。条件限价单的成交 PnL 按独立委托价估算。';

  @override
  String get triggerCalculationApply => '采用候选触发价';

  @override
  String get triggerCalculationPosition => '请先读取非零仓位，并选择有效数量与杠杆。';

  @override
  String get triggerCalculationInput => '请输入可带负号的十进制目标，不支持科学计数法。';

  @override
  String get triggerCalculationTick => '交易所价格步长不可用，无法换算候选价。';

  @override
  String get triggerCalculationBounds => '换算价格超出支持的正数价格范围。';

  @override
  String get liveTrailingInvalid => '跟踪委托须使用固定数量的市价单，不能同时设置固定触发价、限价或全部平仓。';

  @override
  String get liveTrailingRateInvalid => '请输入 0.1% 至 5% 的回调比例。';

  @override
  String get liveTrailingActivationInvalid => '请输入正数激活价，或留空使用交易所默认值。';

  @override
  String get liveTrailingActivationFilter => '激活价不符合交易所价格范围或步长。';

  @override
  String get liveTrailingImmediate => '买入激活价须低于所选最新价；卖出激活价须高于所选最新价。';

  @override
  String get liveTrailingHint => '交易所跟踪有利方向的价格极值，回调达到设定比例后按市价执行。使用固定数量，不是触发时全部平仓，也不会持续修改限价挂单。';

  @override
  String get liveTrailingRate => '回调比例（%）';

  @override
  String get liveTrailingRateBounds => '范围 0.1～5；输入 1 表示 1%。';

  @override
  String get liveTrailingBasis => '跟踪价格依据';

  @override
  String liveTrailingActivation(String asset) {
    return '激活价格（$asset，选填）';
  }

  @override
  String get liveTrailingDefault => '留空时使用交易所下单时对应价格依据的最新价。不会将当前快照价作为激活价提交。';

  @override
  String get liveTrailingActivationDirection => '若填写：买入激活价低于最新价，卖出激活价高于最新价；交易所在下单时再次校验。';

  @override
  String get liveTrailingBuy => '激活后买单跟踪最低价，价格从最低点上涨达到回调比例后触发；触发不保证成交价格。';

  @override
  String get liveTrailingSell => '激活后卖单跟踪最高价，价格从最高点下跌达到回调比例后触发；触发不保证成交价格。';

  @override
  String get liveTrailingEstimateHint =>
      '没有固定成交价；名义金额及开仓保证金仅按当前标记价参考估算，不提供平仓 PnL 估算。实际数量资格、保证金和成交由交易所当时状态决定，不含手续费、资金费和滑点。';

  @override
  String get quickOrderInvalid => '快捷开仓须为普通市价单，不能包含仅减仓、固定价格或附加条件。';

  @override
  String get quickOrderTitle => 'K 线快捷市价开仓';

  @override
  String get quickOrderHint =>
      '使用真实钱包下单，数量独立于交易表单。单向模式下可能减少或反转现有仓位。报价仅供参考，不保证成交价；此订单不附加止盈止损或用户滑点设置。';

  @override
  String get quickOrderRead => '读取钱包及数量换算数据';

  @override
  String get quickOrderReadHint =>
      '需显式签署四次账户／配置读取，再分别签署费率、风险档位与挂单三次读取以支持比例换算。读取不会下单；首份价格快照 30 秒后过期。';

  @override
  String get quickOrderIndependent => '输入基础资产数量，或选择比例。初始为空，不默认选择比例。';

  @override
  String quickOrderPercentSelected(int percent) {
    return '已选择 $percent%；买卖参考数量分别显示。手输数量可替换比例。';
  }

  @override
  String get quickOrderBuyQuantity => '参考买入数量';

  @override
  String get quickOrderSellQuantity => '参考卖出数量';

  @override
  String get quickOrderSizingHint =>
      '比例使用读取时的 USDT 可用保证金、杠杆、吃单费率、风险档位、现有仓位、同向待成交量及买卖报价，按市价数量步长向下取整。不计释放保证金或其他资产抵押价值。这是参考预算，不是保证可成交的最大数量；价格、挂单及交易所限制可能变化。';

  @override
  String get quickOrderSizingFailure => '比例换算不可用。请重试读取；账户上下文有效时仍可手输数量，已有输入会保留。';

  @override
  String get quickOrderBuy => '市价买入／做多';

  @override
  String get quickOrderSell => '市价卖出／做空';

  @override
  String get quickOrderConfirmation => '快捷市价单确认';

  @override
  String get quickOrderDoNotShow => '不再显示市价单确认';

  @override
  String get quickOrderConfirmPreference => '市价开仓前确认';

  @override
  String get quickOrderPreferenceFailure => '无法读取或保存确认偏好。保留最后已保存的设置，成功保存设置前仍需确认订单。';

  @override
  String get quickOrderChartTab => 'K 线页面';

  @override
  String get attachedOrderTitle => '开仓附加止盈／止损';

  @override
  String get attachedOrderTakeProfit => '附加止盈';

  @override
  String get attachedOrderStopLoss => '附加止损';

  @override
  String get attachedOrderTriggerPrice => '触发价格（USDT）';

  @override
  String get attachedOrderBasis => '触发价格依据';

  @override
  String get attachedOrderPriceProtect => '触发价格保护';

  @override
  String get attachedOrderLifecycle =>
      '主单部分或全部成交时请求挂出退出单；一侧退出单部分或全部成交时请求撤销另一侧。每条退出单使用本次主单全量，实际激活、数量变化、撤单及成交以交易所回报为准。';

  @override
  String get attachedOrderManageScope => '当前支持创建和签名查询；尚不支持在应用内编辑或整体撤销附加策略。';

  @override
  String get attachedOrderInvalid => '请填写至少一条止盈／止损，或关闭附加保护。附加保护不能与只减仓、全部平仓、快捷下单或跟踪委托组合。';

  @override
  String get attachedOrderIocUnavailable => '附加策略不支持 IOC，请为主单选择其他支持的有效方式。';

  @override
  String get attachedOrderNoExposure => '请填写大于零的本次主单保护数量。';

  @override
  String get attachedOrderPriceDirection => '附加止盈／止损的触发价方向不正确，请按开仓方向及参考价格重新设置。';

  @override
  String get attachedOrderPositionChanged => '已有仓位或合约配置发生变化，请重新读取并确认附加保护数量。';

  @override
  String get attachedOrderRejected => '交易所返回策略拒绝代码；请按原编号查询核对结果，不要重复提交。';

  @override
  String get attachedOrderStrategyType => '关联方式';

  @override
  String get attachedOrderExitQuantity => '每条保护单的固定数量';

  @override
  String get attachedOrderVerified => '已查询并核对策略及关联条款';

  @override
  String get attachedOrderStrategyId => '策略编号';

  @override
  String get attachedOrderStrategyStatus => '交易所策略状态';

  @override
  String attachedOrderLegStatus(int sequence) {
    return '子单 $sequence 状态';
  }

  @override
  String get attachedOrderQueryScope =>
      '以上为交易所报告的策略及子单状态，不代表已核对成交数量、余额或剩余仓位。未激活子单可能没有订单编号。主单及保护单的执行仍需分别核对。';

  @override
  String get attachedOrderRefresh => '签名重新查询此策略';

  @override
  String get attachedOrderClientId => '客户端策略编号';

  @override
  String get attachedOrderConfirmHint =>
      '此操作提交真实联动策略。请复核本次主单全量保护数量、各触发条件及退出价格。主单部分或全部成交驱动挂单，一侧退出单部分或全部成交驱动互撤；实际结果需查询交易所回报。';

  @override
  String get orderRecoveryTitle => '未决订单恢复';

  @override
  String get orderRecoveryScope =>
      '这里仅显示当前钱包在此设备保存的未决合约订单或策略。查询需要重新连接同一钱包并签名，不会重新下单。查询不到不代表原单未提交；记录会继续保留。请先核对结果，再进行新的下单或配置修改。清除应用数据或卸载会丢失本地记录。';

  @override
  String get orderRecoveryStorage => '无法读取或保存本地未决记录，已暂停新的实盘下单及配置操作。记录不会自动清除，请重试。';

  @override
  String get orderRecoveryPending => '当前钱包有待核对的订单或策略，请先查询原编号。新的实盘下单及配置操作暂不可用。';

  @override
  String get orderRecoveryConnect => '登录或重新连接原钱包';

  @override
  String get orderRecoveryReload => '重新读取本地记录';

  @override
  String get orderRecoveryEmpty => '当前钱包在此设备没有未决记录；这不代表交易所没有挂单。';

  @override
  String get orderRecoveryQuery => '签名查询原编号';

  @override
  String get orderRecoveryCreated => '记录时间';

  @override
  String get orderRecoveryVerified => '原编号及条款已核对；成交和账户状态以对应查询范围为准。';

  @override
  String get orderRecoveryActiveOperation => '当前会话的操作仍在处理或待核对，请使用原操作页面的重查入口。';

  @override
  String get notificationTitle => '通知中心';

  @override
  String get notificationScope => '当前钱包的现货及合约事件。请在下方显式开启实时监听；充提状态变化在签名刷新记录时收集。不包含本地演示活动。';

  @override
  String get notificationRetention => '仅保存在本机：所有钱包合计最多 500 条近期事件，上限 4 MiB，较早事件可能移除。这不是完整账户历史。';

  @override
  String get notificationDelivery => '实时事件需要已授权的监听连接，充提记录需要手动签名刷新。后台暂停、到期及断线可能造成缺口；不提供系统推送或完整漏报补录。';

  @override
  String get notificationEmpty => '当前钱包暂无已记录通知。列表为空不代表账户未发生事件。';

  @override
  String get notificationSignIn => '登录后查看当前钱包的通知。';

  @override
  String get notificationStorageFailed => '本地通知读取或保存失败。当前可见变化暂留内存，请重试恢复保存，原存储数据不会清空。';

  @override
  String get notificationRetry => '重试本地存储';

  @override
  String get notificationMarkAllRead => '全部标为已读';

  @override
  String get notificationUnread => '未读';

  @override
  String get notificationRead => '已读';

  @override
  String get notificationCritical => '严重风险';

  @override
  String get notificationMarginTitle => '仓位保证金风险提醒';

  @override
  String get notificationLiquidationTitle => '强平订单更新';

  @override
  String get notificationAdlTitle => '自动减仓订单更新';

  @override
  String get notificationRiskScope => '此事件不能证明整个仓位已平仓。请核对实际成交，并另行读取剩余仓位。风险提醒可能在强平过程中或之后才送达。';

  @override
  String get notificationMarginScope => '下方列出本次事件报告的全部风险仓位。事件未提供风险百分比、强平价格或倒计时，也不保证在强平前送达。';

  @override
  String get notificationEventTime => '事件时间（UTC）';

  @override
  String get notificationTransactionTime => '交易时间（UTC）';

  @override
  String get notificationTradeTime => '订单成交时间（UTC）';

  @override
  String get notificationLastQuantity => '本次成交数量';

  @override
  String get notificationCumulativeQuantity => '累计成交数量';

  @override
  String get notificationOriginalQuantity => '原始委托数量';

  @override
  String get notificationLastPrice => '本次成交价格';

  @override
  String get notificationRealizedPnl => '本次报告的已实现盈亏';

  @override
  String get notificationUnits => '数量使用基础资产，价格使用计价资产；单位仅在对应市场目录核对后显示。这些数值描述本次事件，不是当前余额。';

  @override
  String get notificationMaintenanceMargin => '所需维持保证金';

  @override
  String get notificationYes => '是';

  @override
  String get notificationNo => '否';

  @override
  String notificationOrderTitle(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'NEW': '合约订单已创建',
      'PARTIALLY_FILLED': '合约订单部分成交',
      'FILLED': '合约订单已成交',
      'CANCELED': '合约订单已撤销',
      'EXPIRED': '合约订单已过期',
      'REJECTED': '合约订单被拒绝',
      'other': '合约订单更新',
    });
    return '$_temp0';
  }

  @override
  String notificationStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'NEW': '新建',
      'PARTIALLY_FILLED': '部分成交',
      'FILLED': '全部成交',
      'CANCELED': '已撤销',
      'EXPIRED': '已过期',
      'REJECTED': '已拒绝',
      'NEW_INSURANCE': '保险基金强平订单',
      'NEW_ADL': '自动减仓订单已创建',
      'other': '未知',
    });
    return '$_temp0';
  }

  @override
  String notificationExecution(String execution) {
    String _temp0 = intl.Intl.selectLogic(execution, {
      'NEW': '执行类型：新建',
      'CANCELED': '执行类型：撤销',
      'CALCULATED': '执行类型：强平计算',
      'EXPIRED': '执行类型：过期',
      'TRADE': '执行类型：成交',
      'AMENDMENT': '执行类型：修改',
      'REJECTED': '执行类型：拒绝',
      'other': '执行类型：未知',
    });
    return '$_temp0';
  }

  @override
  String notificationOrderType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'LIMIT': '限价',
      'MARKET': '市价',
      'STOP': '止损限价',
      'STOP_MARKET': '止损市价',
      'TAKE_PROFIT': '止盈限价',
      'TAKE_PROFIT_MARKET': '止盈市价',
      'TRAILING_STOP_MARKET': '跟踪止损市价',
      'LIQUIDATION': '强平',
      'other': '未知',
    });
    return '$_temp0';
  }

  @override
  String get notificationOriginalType => '原始订单类型';

  @override
  String get notificationUnitFailure => '市场单位读取失败。数值仍保留并标记单位未知；可重试读取公开市场目录。';

  @override
  String get spotAccountChangeTitle => '现货账户监听';

  @override
  String get spotAccountChangeScope =>
      '使用当前钱包签名开启或续期现货监听，最长 60 分钟。记录实时现货订单事件，并将现货快照标记为需签名刷新。不自动签名或补录历史。停止仅断开本应用连接，不作废其他客户端可能共用的密钥。';

  @override
  String get spotAccountChangeStart => '签名监听现货事件';

  @override
  String get spotAccountChangeRenew => '签名续期现货监听';

  @override
  String get spotNotificationLastQuote => '本次成交计价币金额';

  @override
  String get spotNotificationCumulativeQuote => '累计成交计价币金额';

  @override
  String get spotNotificationQuoteOrderQuantity => '申请的计价币委托金额';

  @override
  String get spotNotificationCreationTime => '订单创建时间（UTC）';

  @override
  String spotNotificationOrderTitle(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'NEW': '现货订单已创建',
      'PARTIALLY_FILLED': '现货订单部分成交',
      'FILLED': '现货订单已成交',
      'CANCELED': '现货订单已撤销',
      'EXPIRED': '现货订单已过期',
      'REJECTED': '现货订单被拒绝',
      'other': '现货订单更新',
    });
    return '$_temp0';
  }

  @override
  String get transferHistoryTitle => '充提记录';

  @override
  String get transferHistoryScope =>
      '签名读取现货及合约充提记录。首次读取不为已有记录生成通知，之后刷新时收集新发现的充提和状态变化。返回记录可能不含全部历史。';

  @override
  String get transferRefresh => '签名刷新充提记录';

  @override
  String get transferRefreshNeeded => '充提记录可能已变化，请签名刷新确认进度；余额变化本身不能证明充提完成。';

  @override
  String get transferBaselineCreated => '首次基线已建立，已有记录没有生成新通知。';

  @override
  String get transferHistoryEmpty => '返回记录中没有匹配项，不代表从未发生充提。';

  @override
  String get transferRecordScope => '状态由 Aster 返回。记录时间不是完成时间；此历史响应未提供失败原因。';

  @override
  String get transferRecordId => '充提记录编号';

  @override
  String get transferTypeLabel => '充提类型';

  @override
  String get transferDeposit => '充值';

  @override
  String get transferWithdraw => '提现';

  @override
  String get transferSpotMarket => '现货账户';

  @override
  String get transferPerpMarket => '合约账户';

  @override
  String get transferMarketLabel => '账户市场';

  @override
  String get transferAllMarkets => '全部市场';

  @override
  String get transferNetwork => '网络';

  @override
  String get transferChainId => '网络 ID';

  @override
  String get transferNetworkEthereum => 'Ethereum';

  @override
  String get transferNetworkBnb => 'BNB Chain';

  @override
  String get transferNetworkArbitrum => 'Arbitrum One';

  @override
  String transferUnknownNetwork(String chainId) {
    return '未映射网络（网络 ID $chainId）';
  }

  @override
  String get transferHash => '交易哈希';

  @override
  String get transferHashUnknown => '尚未提供';

  @override
  String get transferRecordTime => '记录时间（UTC）';

  @override
  String transferReadTime(String time) {
    return '最近读取（UTC）：$time';
  }

  @override
  String get transferStorageRequired => '充提跟踪记录无法读取或保存。请先重试本地通知存储，再刷新记录；已有记录继续保留。';

  @override
  String get transferTrackingFull => '本地充提跟踪已达到上限。已有观察记录继续保留，本次刷新未记录。';

  @override
  String transferStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'processing': '处理中',
      'success': '成功',
      'failed': '失败',
      'other': '未知',
    });
    return '$_temp0';
  }

  @override
  String transferTitle(String type, String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'processing': '充值处理中',
      'success': '充值成功',
      'failed': '充值失败',
      'other': '充值更新',
    });
    String _temp1 = intl.Intl.selectLogic(status, {
      'processing': '提现处理中',
      'success': '提现成功',
      'failed': '提现失败',
      'other': '提现更新',
    });
    String _temp2 = intl.Intl.selectLogic(type, {
      'deposit': '$_temp0',
      'withdraw': '$_temp1',
      'other': '充提更新',
    });
    return '$_temp2';
  }

  @override
  String get transferObservedTime => '观察时间（UTC）';

  @override
  String assetValueUsd(String label) {
    return '$label · 美元估值';
  }

  @override
  String assetValueBtc(String label) {
    return '$label · BTC 估值';
  }

  @override
  String get assetValueUnavailable => '部分估值不可用；缺失价格或余额不会按零处理。';

  @override
  String get assetValueStale => '估值使用较旧或待核对的账户／价格快照，请刷新后确认。';

  @override
  String get assetValueSpotScope => '现货钱包估值';

  @override
  String get assetValuePerpScope => '合约钱包估值';

  @override
  String get assetValueKnownSubtotal => '已知资产小计';

  @override
  String get assetValueWalletTotal => '钱包资产总值';

  @override
  String get assetValueBtcEstimate => '约合 BTC';

  @override
  String assetValueMissing(int count) {
    return '$count 项资产缺少美元价格，未计入此小计。';
  }

  @override
  String get assetValueScope =>
      '使用 Aster 资产美元参考指数，并按 BTC／USD 指数换算 BTC。稳定币采用实际返回价格。钱包估值不含未实现盈亏、其他账户／产品、抵押折扣或交易成本；BTC 展示值经过舍入。';

  @override
  String assetIndexReadTime(String time) {
    return '价格快照读取时间（UTC）：$time';
  }

  @override
  String get assetIndexLoading => '正在刷新参考价格…';

  @override
  String get assetIndexPaused => '参考价格更新已暂停。';

  @override
  String get assetIndexFailed => '参考价格刷新失败，已有估值可能过期。';

  @override
  String get assetIndexRefresh => '刷新公开参考价格';

  @override
  String get assetValueHideLow => '隐藏估值不超过 0.0001 BTC 的资产';

  @override
  String get assetValueHideLowScope => '按现货总余额估值筛选；估值缺失或过期的资产继续显示。';

  @override
  String get subaccountManagement => '子账户管理';

  @override
  String get subaccountListScope => '使用当前连接的钱包签名，查看关联账户。读取列表不会切换当前交易账户。';

  @override
  String get subaccountConnectedWallet => '当前签名钱包';

  @override
  String get subaccountRead => '签名读取关联账户';

  @override
  String get subaccountRefresh => '签名刷新关联账户';

  @override
  String get subaccountStopWaiting => '停止等待';

  @override
  String subaccountCount(int count) {
    return '共 $count 个子账户';
  }

  @override
  String get subaccountNoChildren => '此次读取未返回子账户。';

  @override
  String get subaccountListBoundaries => '按返回结果展示账户编号与名称，此列表未提供地址和冻结状态。创建、切换、冻结／解冻和划转请进入子账户管理逐项确认。';

  @override
  String get subaccountSearch => '搜索账户名称或编号';

  @override
  String get subaccountNoMatches => '没有匹配的账户。';

  @override
  String get subaccountParent => '主账户';

  @override
  String get subaccountChild => '子账户';

  @override
  String get subaccountUnnamed => '未命名账户';

  @override
  String get subaccountId => '账户编号';

  @override
  String get subaccountCopyId => '复制账户编号';

  @override
  String get fundingInfoTitle => '充值与提现信息';

  @override
  String get fundingInfoScope => '查看支持的资产和网络，可提额度需钱包签名读取。进入单个资产后，可分别确认充值或提现提交。';

  @override
  String get fundingEvmScope => '当前展示充提文档列出的三个 EVM 主网，不代表 Aster 的全部网络。';

  @override
  String get fundingAccount => '账户';

  @override
  String get fundingDeposit => '充值';

  @override
  String get fundingWithdraw => '提现';

  @override
  String get fundingNetwork => '网络';

  @override
  String get fundingEthereum => 'Ethereum · 1';

  @override
  String get fundingBnbChain => 'BNB Chain · 56';

  @override
  String get fundingArbitrum => 'Arbitrum · 42161';

  @override
  String get fundingCatalogLoading => '正在读取公开资产配置…';

  @override
  String get fundingCatalogFailed => '资产配置暂不可用或数据异常，请重试公开读取。';

  @override
  String get fundingCatalogStale => '配置已超过五分钟或刷新失败，使用前请重新读取。';

  @override
  String fundingCatalogTime(String time) {
    return '公开配置读取时间（UTC）：$time';
  }

  @override
  String get fundingCatalogRefresh => '刷新公开配置';

  @override
  String get fundingAssetSearch => '搜索资产名称或符号';

  @override
  String get fundingNoNetworkAssets => '此次读取未返回该账户、操作与网络下的资产。';

  @override
  String get fundingNativeAsset => '原生币';

  @override
  String get fundingTokenAsset => '代币';

  @override
  String get fundingTokenContract => '代币合约 · 不是充值收款地址';

  @override
  String get fundingWithdrawLimits => '提现额度快照';

  @override
  String get fundingWithdrawScope => '此读取不会授权提现。额度和费用可能变化，缺失金额保留未知，不以账户余额代替。';

  @override
  String get fundingReadLimits => '签名读取提现额度';

  @override
  String get fundingRefreshLimits => '签名刷新提现额度';

  @override
  String get fundingUserDailyUsd => '用户每日限额';

  @override
  String get fundingUserRemainingUsd => '用户今日剩余额度';

  @override
  String get fundingGlobalDailyUsd => '平台每日限额';

  @override
  String get fundingGlobalRemainingUsd => '平台今日剩余额度';

  @override
  String get fundingNoWithdrawBalances => '此次读取未返回非零资产可提余额；缺少记录不代表已核准为零额度。';

  @override
  String get fundingAssetTotal => '账户可提总量 · 接口值';

  @override
  String get fundingChainMaximum => '该网络可提数量 · 接口值';

  @override
  String get fundingChainLimit => '网络数量上限';

  @override
  String get fundingAssetDailyUsd => '该资产今日剩余美元额度';

  @override
  String get fundingSnapshotFee => '提现费用 · 快照';

  @override
  String get fundingLimitsUnavailable => '尚无该资产或网络匹配的签名额度，请读取或刷新。';

  @override
  String get fundingLimitUnits => '美元限额与币数量单位不同，这些字段分别展示，不合成为最终 Max。提交前需重新核对费用。';

  @override
  String get fundingNoMatches => '没有匹配的资产。';

  @override
  String get fundingFeeCheck => '查询最新提现费用';

  @override
  String get fundingFeeTitle => '提现费用估算';

  @override
  String get fundingFeeScope =>
      '按当前账户类型、网络与币种公开查询。这是平台提现费用，与钱包链上交易的 Gas 分开；不授予提现权限，也不保证最终费用。提交提现前需重新读取。';

  @override
  String get fundingFeeLoading => '正在读取公开费用估算…';

  @override
  String get fundingFeeFailed => '费用估算暂不可用或数据无效，请重试公开查询。';

  @override
  String get fundingFeeStale => '估算已超过 30 秒或刷新失败，使用前请重新读取。';

  @override
  String get fundingFeeAsset => '币种手续费估算';

  @override
  String get fundingFeeUsd => '美元手续费估算';

  @override
  String get fundingFeeAssetPrice => '资产参考价格 · 美元／单位';

  @override
  String fundingFeeTime(String time) {
    return '估算读取时间：$time';
  }

  @override
  String get fundingFeeRefresh => '刷新费用估算';

  @override
  String get depositPrecheckTitle => '充值钱包预检查';

  @override
  String get depositPrecheckScope =>
      '公开读取当前钱包的链上余额和代币授权额度。最低充值额来自配置快照；此预检查不会提交授权或充值，平台额度和交易 Gas 仍需核对。';

  @override
  String get depositReadWallet => '读取钱包余额和授权额度';

  @override
  String get depositAssetBalance => '钱包资产余额';

  @override
  String get depositNativeBalance => '钱包原生币余额 · 未扣 Gas 预留';

  @override
  String get depositAllowance => '代币对文档充值合约的授权额度';

  @override
  String get depositSpenderScope => '仅为授权额度查询对象，请勿手动向此地址转账。';

  @override
  String get depositBlock => '链上区块高度';

  @override
  String get depositMinimum => '最低充值额 · 配置快照';

  @override
  String get depositAmount => '充值数量 · 仅预检查';

  @override
  String get depositWalletMax => '填入代币钱包余额 · Max';

  @override
  String get depositWalletMaxScope => '仅填入代币余额，未计平台限制；还需另备原生币支付 Gas。';

  @override
  String get depositNativeMaxUnavailable => '原生币 Max 仍需最终交易费用及平台额度核对，不能使用全部原生币余额。';

  @override
  String get depositSmallestUnits => '精确最小单位数量';

  @override
  String get depositNativeNoApproval => '原生币无需 ERC20 授权，Gas 和平台额度仍未核对。';

  @override
  String get depositAllowanceEnough => '已读取的代币授权额度覆盖此数量，尚未提交授权或充值。';

  @override
  String get depositAllowanceNeeded => '已读取的代币授权额度不足此数量，充值前需要授权；尚未提交授权。';

  @override
  String get depositRpcInvalid => '公开链上响应不完整或无效，请重新读取。';

  @override
  String get depositRpcFailed => '公开链上服务暂无法完成读取，请重试。';

  @override
  String get depositRpcWrongChain => '服务返回了其他网络，未接纳其余额。';

  @override
  String get depositTokenDecimalsChanged => '链上代币精度与所选配置不一致，请刷新币种目录后重新打开本页。';

  @override
  String get depositRpcReorg => '读取期间区块发生变化，请刷新以获取一致快照。';

  @override
  String get depositAmountInvalid => '请输入正数，且最小单位数量应处于无符号 256 位范围内。';

  @override
  String get depositAmountPrecision => '数量的小数位超过当前资产支持的精度。';

  @override
  String get depositMinimumUnknown => '最低充值额未知，请先刷新资产配置。';

  @override
  String get depositBelowMinimum => '数量低于配置的最低充值额。';

  @override
  String get depositReadRequired => '请先读取当前钱包余额再检查数量。';

  @override
  String get depositReadStale => '钱包快照已过期，请刷新后再检查数量。';

  @override
  String get depositBalanceInsufficient => '数量超过已读取的钱包资产余额。';

  @override
  String get attachedEntryPricing => '主单定价';

  @override
  String get attachedEntryFixed => '输入限价';

  @override
  String attachedEntryCounterparty(int depth) {
    return 'BBO · 对手方第 $depth 档';
  }

  @override
  String attachedEntryQueue(int depth) {
    return 'BBO · 同侧第 $depth 档';
  }

  @override
  String get attachedEntryPegTiming => '主单只按所选盘口档位定价一次：限价主单在提交时取价，条件主单在触发时取价，不会持续追价。';

  @override
  String get attachedEntryPegEstimate =>
      '名义价值与保证金预估使用标记价（条件主单使用触发价），不代表所选盘口档位或成交价。Aster 会按实际定价复核止盈止损，可能拒绝策略。';

  @override
  String get attachedEntryPegInvalid => 'BBO 主单定价仅适用于附加止盈止损的限价或条件限价主单，且不能同时输入限价。';

  @override
  String get scaledTitle => '分段委托';

  @override
  String get scaledRule =>
      '拆为 2–110 笔独立 GTC 限价单，按价格从低到高提交。包含两个端点，价格按最小变动单位向下对齐且互不重复。数量按所选分布及数量步长拆分；签名前请核对逐笔预览。';

  @override
  String get scaledRisk =>
      '每笔分别复核账户、签名提交、签名查询，可能需要多次钱包确认。子单独立执行，可能部分成功；失败或结果未知即停止后续提交。停止或离开页面不会撤销已发送订单，未发送子单不会自动续跑。';

  @override
  String get scaledLow => '价格下限';

  @override
  String get scaledHigh => '价格上限';

  @override
  String get scaledCount => '子单数量';

  @override
  String get scaledPreview => '子单预览';

  @override
  String get scaledReview => '确认分段委托';

  @override
  String get scaledConfirm => '签名提交这些子单';

  @override
  String get scaledTotalQuantity => '总委托量';

  @override
  String get scaledTotalNotional => '限价总名义价值';

  @override
  String get scaledMarginReference => '未扣净额的保证金参考';

  @override
  String get scaledMarginHint => '参考值 = 限价总名义价值 ÷ 杠杆，未计仓位净额、已有挂单、手续费和释放保证金，不是最终占用或可执行额度；每笔由平台校验。';

  @override
  String get scaledPortion => '占总委托量（约）';

  @override
  String scaledOrderNumber(int number) {
    return '子单 $number';
  }

  @override
  String get scaledCountInvalid => '子单数量请输入 2–110 的整数。';

  @override
  String get scaledRangeInvalid => '请输入正数价格，且上限必须高于下限。';

  @override
  String get scaledRangeTooNarrow => '价格区间内的最小变动单位不足，无法为每笔生成不同价格。';

  @override
  String get scaledQuantityTooSmall => '总委托量不足以满足每笔子单的最低数量。';

  @override
  String get scaledQuantityStep => '总委托量无法按数量步长精确拆分，请调整总量；不会静默丢弃尾差。';

  @override
  String get scaledConfigurationChanged => '账户模式、杠杆或下单规则已变化，后续子单已停止；请刷新并重新确认方案。';

  @override
  String get scaledStopped => '已停止后续子单；已发送订单仍可能执行，请核对下方结果。';

  @override
  String get scaledResults => '分段委托结果';

  @override
  String get scaledRefreshRequired => '请重新读取账户并确认方案后提交。';

  @override
  String get depositGasTitle => '下一步 Gas 预估';

  @override
  String get depositGasEstimate => '估算下一步费用';

  @override
  String get depositGasScope => '仅公开模拟，不请求钱包签名或发送交易。预估只覆盖当前一步；授权、充值、回执和平台到账分别核对，用户／平台剩余额度仍未知。';

  @override
  String get depositGasDeposit => '充值交易';

  @override
  String get depositGasApprove => '授权本次充值的精确数量';

  @override
  String get depositGasReset => '先将已有授权额度清零';

  @override
  String get depositGasResetHint => '已有非零授权不足，需先清零，再重新读取并估算精确授权，之后才是充值；不会准备无限授权。';

  @override
  String get depositGasTarget => '交易目标合约';

  @override
  String get depositGasValue => '本步骤附带的原生币数量';

  @override
  String get depositGasEstimatedUnits => '估算 Gas 单位';

  @override
  String get depositGasLimit => '含预留的 Gas 上限';

  @override
  String get depositGasPrice => 'Gas 单价快照（wei）';

  @override
  String get depositGasReserve => '本步骤原生币费用预留';

  @override
  String get depositGasTotal => '原生币金额 + 费用预留';

  @override
  String get depositGasReserveHint =>
      'Gas 上限按模拟值增加 20% 并向上取整；费用预留 = Gas 上限 × legacy 单价快照，不是实际费用或执行保证。价格和链状态会变化，发送前须重新预估；后续步骤另需预留。';

  @override
  String get depositGasChangedAmount => '此预估对应下方记录的金额；当前输入已变化，请重新预估。';

  @override
  String get depositGasAmount => '本次预估对应的充值数量';

  @override
  String get depositGasRouteUnsupported => '当前充值路径无法按已确认的普通 EVM 充值合约编码。';

  @override
  String get depositGasSimulationFailed => '链节点在模拟时拒绝此步骤，未发送交易。请重新核对余额、授权额度和数量后重试。';

  @override
  String get depositGasBalanceInsufficient => '原生币余额不足以覆盖本步骤金额及费用预留；后续步骤也需另留原生币。';

  @override
  String get depositGasPendingTransactions => '钱包存在待确认交易或交易序号已变化；请等待处理后刷新并重新预估。';

  @override
  String get depositGasBlockLimit => '预留后的 Gas 上限超过当前链区块限制，无法准备发送。';

  @override
  String get depositApprovalPrepare => '准备本次授权';

  @override
  String get depositApprovalScope =>
      '仅提交这一笔代币授权，会消耗原生币 Gas，不会充值。充值提交需单独确认、重新读取，并在 Aster 外部核实可用性及额度。';

  @override
  String get depositApprovalReview => '确认代币授权';

  @override
  String get depositApprovalConfirm => '确认并打开钱包';

  @override
  String get depositApprovalCancel => '取消';

  @override
  String get depositApprovalStorage => '授权恢复记录无法读取或保存，已阻止新授权。请先重试恢复存储。';

  @override
  String get depositApprovalPending => '当前钱包存在未核对的授权，请先核对原交易再发送下一笔。';

  @override
  String get depositApprovalNotNeeded => '本次数量无需授权步骤。充值提交仍需平台额度与到账恢复能力。';

  @override
  String get depositApprovalChanged => '链状态或费用已变化，请重新准备并确认本步骤；尚未发送交易。';

  @override
  String get depositApprovalUnknown => '钱包返回结果未知，请勿重复授权。请从钱包取得原交易哈希进行核对。';

  @override
  String get depositApprovalMismatch => '此交易与保存的钱包、网络或交易序号不匹配，已保留原记录。';

  @override
  String get depositApprovalRecovery => '待核对的代币授权';

  @override
  String get depositApprovalOpenRecovery => '核对待处理授权';

  @override
  String get depositApprovalRecoveryScope =>
      '链上核对仅为只读查询，不会重发交易。钱包返回哈希不等于已有回执；本应用要求观察到两个确认区块，后续仍可能重组。授权结果不代表充值或平台到账。';

  @override
  String get depositApprovalNoPending => '当前钱包没有待核对的授权。';

  @override
  String get depositApprovalHash => '原交易哈希';

  @override
  String get depositApprovalHashHint =>
      '可粘贴钱包中的原交易哈希，或加速／取消交易的哈希。只有相同钱包、网络和交易序号才能核对本步骤；留空时查询已保存的哈希。';

  @override
  String get depositApprovalCheck => '核对链上结果';

  @override
  String get depositApprovalSent => '钱包请求已结束。请核对保存的交易，目前尚未确认回执或授权额度变化。';

  @override
  String get depositApprovalReceiptPending => '仍待链上确认。请保留记录后再次核对，不会重新发送交易。';

  @override
  String get depositApprovalReceiptSucceeded => '授权交易已在链上成功执行。请重新读取当前授权额度，并单独估算下一步；尚未发送充值。';

  @override
  String get depositApprovalReceiptReverted => '授权交易已在链上回滚，可能已消耗 Gas。请重新读取后再准备下一步。';

  @override
  String get depositApprovalConfirmations => '已观察的确认区块数';

  @override
  String get depositApprovalGasFee => '回执记录的执行 Gas 费用';

  @override
  String get depositApprovalFeeScope =>
      '此费用按回执 gasUsed × effectiveGasPrice（或返回的 legacy 单价）计算；网络可能另有费用。';

  @override
  String get depositApprovalNonce => '交易序号';

  @override
  String get depositApprovalPreparedAt => '准备时间（UTC）';

  @override
  String get walletTransactionInvalid => '钱包交易参数无效，尚未发送交易。';

  @override
  String get walletTransactionBusy => '另一笔钱包交易请求仍在等待，请先等待其结束。';

  @override
  String get walletTransactionWrongChain => '请在所选充值网络重新连接同一个钱包，再发送此步骤。';

  @override
  String get walletTransactionPermission => '当前钱包会话没有交易发送权限。请断开后重新连接同一个钱包以授予权限。';

  @override
  String get depositApprovalReceiptReplaced => '另一笔交易已在链上使用了原交易序号。原授权尚未确认，请先重新读取当前授权额度。';

  @override
  String get rebalanceTitle => '保证金 Rebalance';

  @override
  String get rebalanceScope =>
      '混合保证金的 USDT 钱包余额为负时可主动 Rebalance。转换资产与数量由 Aster 决定，请求不传金额或价格；请先读取账户再确认。';

  @override
  String get rebalanceRisk => '操作可能转换账户资产并改变保证金。转换价格、费用和资格由 Aster 决定，此处没有转换报价；不会提现或切换资产模式。';

  @override
  String get rebalanceRead => '读取／核对当前账户';

  @override
  String get rebalanceReadHint => '每次读取需要两次账户签名。确认后重新读取模式与余额，再请求独立 API 签名并用两次签名核对结果；不会自动执行。';

  @override
  String get rebalanceReview => '确认 Rebalance 条款';

  @override
  String get rebalanceConfirm => '签名请求 Rebalance';

  @override
  String get rebalanceCancel => '取消';

  @override
  String get rebalanceUsdt => 'USDT 钱包余额';

  @override
  String get rebalanceUnknownUsdt => 'USDT 钱包余额未知；完整读取前，Rebalance 和切回单资产模式均不可用。';

  @override
  String get rebalanceNotNeeded => '当前读取未显示混合保证金下的负 USDT，不提供 Rebalance 请求。';

  @override
  String get rebalanceRequired => '提现或切回单资产模式前需先处理负 USDT。请进入 Rebalance 核对当前账户，操作不会自动执行。';

  @override
  String get rebalanceChanged => '账户、配置或确认条款已变化／过期；请重新读取并确认，未发送新的请求。';

  @override
  String get rebalanceStale => '该账户快照已是历史数据，确认前请重新读取。';

  @override
  String get rebalanceStorage => '无法读取或保存 Rebalance 恢复记录；存储恢复前阻止新的 Rebalance、下单及合约配置修改。';

  @override
  String get rebalancePending => '当前钱包存在未决 Rebalance。可核对当前账户，不会自动重发请求。';

  @override
  String get rebalanceUnknown => '原请求结果未知。当前余额不能证明该请求已完成；官方未提供按 nonce 查询的协议，因此保留记录并阻止新修改，请勿重复请求。';

  @override
  String get rebalanceReplyPending => '已保存服务器响应，请读取当前账户完成核对；不会重发 Rebalance。';

  @override
  String get rebalanceNoExchange => '服务器返回空响应：未报告发生资产转换；当前账户状态另行展示。';

  @override
  String get rebalanceReported => '服务器报告发生资产转换。下列是返回余额和账户引用，不是转换报价，也不证明全部负债已清除。';

  @override
  String get rebalancePermission => '最新 USDT 非负余额本身不等于已获准提现或切换单资产模式，仍需核对其他账户条件及平台限制。';

  @override
  String get rebalanceNonce => '原请求 nonce';

  @override
  String get rebalanceAccountId => '返回账户 ID';

  @override
  String get rebalanceReportedBalance => '返回余额';

  @override
  String get rebalanceReportedTime => '返回更新时间（UTC）';

  @override
  String get rebalanceCurrentMode => '当前资产模式';

  @override
  String get rebalanceReading => '正在读取当前资产模式和余额…';

  @override
  String get rebalanceSending => '正在等待签名请求或账户核对…';

  @override
  String get rebalanceRecovery => '查看 Rebalance 恢复记录';

  @override
  String get liveOrderPricing => '限价定价方式';

  @override
  String get liveOrderPegHint =>
      'Aster 按所选买一／卖一在限价单提交时、或条件限价单触发时确定一次价格，不会持续追价。金额、保证金及平仓盈亏仅按标记价／触发价参考预估，实际定价和成交可能不同。';

  @override
  String get liveOrderPegInvalid => 'BBO 需使用限价单且不手填委托价，不能与市价、跟踪、触发时全部平仓或附加策略单混用。';

  @override
  String get internalTransferTitle => '现货 ↔ 合约划转';

  @override
  String get internalTransferScope => '使用当前钱包，将所选资产在 Aster 现货与合约账户间划转。';

  @override
  String get internalTransferReadHint =>
      '读取双方账户与资产模式需 3 次钱包签名；切换币种或方向会重新读取。完整划转通常需 10 次签名，包含确认前复核与余额刷新。';

  @override
  String get internalTransferRisk => '从合约划出抵押资产可能增加强平风险，请在签名前核对方向和金额。';

  @override
  String get internalTransferDirection => '划转方向';

  @override
  String get internalTransferToFutures => '现货 → 合约';

  @override
  String get internalTransferToSpot => '合约 → 现货';

  @override
  String get internalTransferAsset => '币种';

  @override
  String get internalTransferAmount => '划转数量';

  @override
  String get internalTransferMax => '最大';

  @override
  String get internalTransferRead => '读取可划转额度';

  @override
  String get internalTransferReading => '正在读取双方账户与资产模式…';

  @override
  String get internalTransferSending => '正在等待签名或划转结果…';

  @override
  String get internalTransferChecking => '平台已返回划转成功，正在读取双方账户余额…';

  @override
  String get internalTransferMaximum => '来源账户可划出数量';

  @override
  String get internalTransferSpotFree => '现货可用数量';

  @override
  String get internalTransferFuturesWallet => '合约钱包数量';

  @override
  String get internalTransferLimitHint => '划出上限取现货可用量或合约所选资产的最大可划出量。最大按钮按输入步长向下取整；合约钱包数量不等于可划出数量。';

  @override
  String get internalTransferPrecisionHint => '输入精度沿用官网规则：最多 8 位小数，缺失或为零时回退为 2 位；这不代表代币链上精度。';

  @override
  String get internalTransferReview => '核对划转';

  @override
  String get internalTransferConfirm => '签名并提交一次划转';

  @override
  String get internalTransferStale => '划转数据已过期或发生变化，请重新读取后核对。';

  @override
  String get internalTransferChanged => '钱包、余额、额度或资产模式发生变化，或确认已过期；请重新读取并核对划转。';

  @override
  String get internalTransferAssetUnavailable => '所选币种不在支持划转的列表中。';

  @override
  String get internalTransferPermission => '划转权限不可用：来源账户须允许划出，目标账户须允许划入。';

  @override
  String get internalTransferMaximumUnknown => '来源账户可划出数量缺失，读取成功前无法划转。';

  @override
  String get internalTransferInvalidAmount => '请输入大于零的普通十进制数量。';

  @override
  String get internalTransferPrecision => '数量超过该币种支持的输入精度。';

  @override
  String get internalTransferTooLarge => '数量超过来源账户可划出上限。';

  @override
  String get internalTransferStorage => '划转恢复存储不可用，请先重试读取存储，再提交新订单、账户设置或划转。';

  @override
  String get internalTransferPending => '有一笔划转待核对，新的划转、订单及账户设置暂不可提交。';

  @override
  String get internalTransferUnknown =>
      '划转结果未知。官方尚未提供按原客户端编号查询的接口，余额变化不能证明完成。记录将保留，此处不能重发或清除；请携带原始编号联系 Aster 核对。';

  @override
  String get internalTransferReplyPending => 'Aster 已返回 SUCCESS，请读取双方账户完成余额刷新，勿重复提交划转。';

  @override
  String get internalTransferReported => 'Aster 已返回划转 SUCCESS，并已重新读取双方账户余额；内部划转不属于链上交易。';

  @override
  String get internalTransferClientId => '原始客户端划转编号';

  @override
  String get internalTransferTransactionId => 'Aster 划转编号';

  @override
  String get internalTransferEmpty => '当前没有可供划转的币种。';

  @override
  String get internalTransferBlocked => '其他待核对请求或账户操作阻止新的划转，请先查看恢复提示。';

  @override
  String get spotOpenOrdersTitle => '现货当前挂单';

  @override
  String get spotOpenOrdersScope => '使用当前钱包读取全部现货挂单。计数和筛选仅基于这份现货快照；合约交易对不会作为现货查询范围。不会自动请求签名。';

  @override
  String get spotOpenOrdersRead => '读取现货当前挂单';

  @override
  String get spotOpenOrdersRefresh => '刷新现货当前挂单';

  @override
  String get spotOpenOrdersEmpty => '此账户暂无现货挂单。';

  @override
  String get spotOpenOrdersNoMatch => '没有符合筛选条件的现货挂单。';

  @override
  String get spotOpenOrdersFilter => '筛选现货交易对或订单编号';

  @override
  String get spotOpenOrdersUnits => '部分现货基础币／计价币信息未能加载，缺失部分的数量单位仍未知。';

  @override
  String get spotOpenOrdersEvents => '签名读取基准后，事件更新单笔现货订单。断线、事件缺失或数据过期需再次手动读取；事件不能证明账户列表完整。';

  @override
  String get spotOpenOrdersQuantityUnknown => '基础币总量未知 · 按计价币金额下单的市价单';

  @override
  String get spotOpenOrdersQuoteQuantity => '原始计价币金额';

  @override
  String get spotOpenOrdersCapacity => '现货订单事件过多，无法继续可靠保留，实时更新已停止；请重新读取基准以查看当前挂单。';

  @override
  String get spotOpenOrdersPolicy => '有效方式';

  @override
  String assetYieldUsdf(String percent) {
    return '最高参考年化收益率 $percent%';
  }

  @override
  String assetYieldAsbnb(String percent) {
    return '参考年化收益率 $percent%';
  }

  @override
  String get assetYieldUsdfScope => 'Aster 公布的基础 APY＋交易 APY，需满足交易条件；不代表个人实际收益，也不计入余额。';

  @override
  String get assetYieldAsbnbScope => 'Lista 公布的 asBNB 综合 APY，包含 Launchpool 奖励；为参考估算，不代表保证收益或钱包余额。';

  @override
  String assetYieldSourceDate(String date) {
    return '来源日期：$date';
  }

  @override
  String assetYieldParts(String base, String trade) {
    return '基础 $base%＋交易 $trade%';
  }

  @override
  String assetYieldUpdated(String time) {
    return '来源更新时间（UTC）：$time';
  }

  @override
  String assetYieldReadTime(String time) {
    return '读取时间（UTC）：$time';
  }

  @override
  String get assetYieldStale => '当前为历史或未核实收益数据，请刷新核对最新公布的收益率。';

  @override
  String get assetYieldPaused => '应用未处于前台，收益数据更新已暂停。';

  @override
  String get assetYieldInvalid => '收益来源返回的数据缺失或不一致，请重试核对。';

  @override
  String get assetYieldNetwork => '无法连接收益数据来源，请检查网络后重试。';

  @override
  String get assetYieldFailed => '收益数据来源暂不可用；保留上次数据，请重试核对。';

  @override
  String get assetYieldLoading => '正在读取公开收益数据…';

  @override
  String get assetYieldRefresh => '刷新收益数据';

  @override
  String get pointsProgramTitle => 'Vanta Genesis 积分';

  @override
  String get pointsProgramScope =>
      '数据来自 Vanta 的 Orderly 经纪商积分计划，与 Aster 余额及交易独立；本应用不会默认 Aster 交易符合该计划的奖励条件。';

  @override
  String get pointsCurrentCampaign => '当前积分周期';

  @override
  String pointsCycleNumber(String number) {
    return '积分周期 $number';
  }

  @override
  String get pointsCycleId => '周期编号';

  @override
  String get pointsStatus => '公布状态';

  @override
  String get pointsStatusDraft => '草稿';

  @override
  String get pointsStatusActive => '进行中';

  @override
  String get pointsStatusEnded => '已结束';

  @override
  String get pointsStatusSettled => '已结算';

  @override
  String get pointsStatusUnknown => '未知';

  @override
  String get pointsPool => '积分总池';

  @override
  String get pointsPeriodStart => '开始时间（UTC）';

  @override
  String get pointsPeriodEnd => '结束时间（UTC）';

  @override
  String get pointsBroker => '经纪商编号';

  @override
  String get pointsNoCurrentCampaign => '当前未公布积分周期。';

  @override
  String get pointsNotRead => '尚无已核实数据。';

  @override
  String get pointsLoading => '正在读取积分数据…';

  @override
  String get pointsPaused => '应用未处于前台，更新已暂停。';

  @override
  String get pointsStale => '当前为历史或未完整核实的快照，请刷新核对最新数据。';

  @override
  String pointsReadTime(String time) {
    return '读取时间（UTC）：$time';
  }

  @override
  String get pointsDataInvalid => '积分服务返回的数据缺失或不一致，保留上次数据。';

  @override
  String get pointsNetwork => '无法连接积分服务，请检查网络后重试。';

  @override
  String get pointsRateLimited => '积分服务请求受限，请稍后重试。';

  @override
  String get pointsUnavailable => '积分服务暂不可用，保留上次数据，请稍后重试。';

  @override
  String get pointsWalletRequired => '连接钱包后可查询其公布积分；读取成功前不会假定个人积分数值。';

  @override
  String get pointsRefresh => '刷新本区域';

  @override
  String get pointsStop => '停止等待';

  @override
  String get pointsLeaderboard => '积分排行榜';

  @override
  String get pointsLeaderboardScope => '每页展示 20 条，最多展示返回列表的前 100 条，保留服务端报告的排名；未出现在榜单中不代表完整排名或零积分。';

  @override
  String get pointsSelectLeaderboard => '排行榜范围';

  @override
  String get pointsTotalLeaderboard => '累计积分榜';

  @override
  String get pointsNoRankings => '该范围未返回排名记录。';

  @override
  String pointsReturnedCount(int count) {
    return '展示 $count 条返回的排名记录。';
  }

  @override
  String get pointsPrevious => '上一页';

  @override
  String get pointsNext => '下一页';

  @override
  String pointsPageNumber(int page, int pages) {
    return '第 $page／$pages 页';
  }

  @override
  String pointsRankNumber(String number) {
    return '排名 #$number';
  }

  @override
  String get pointsScore => '积分';

  @override
  String get pointsSettled => '已结算积分';

  @override
  String get pointsSpecial => '特殊积分';

  @override
  String get pointsCurrentScore => '当前周期积分（服务端报告）';

  @override
  String get pointsMyPoints => '我的积分';

  @override
  String get pointsWalletReadScope => '点击查询会向 Vanta 积分服务发送此钱包地址，无需签名，也不会切换当前 Aster 账户。';

  @override
  String get pointsConnectWallet => '连接钱包';

  @override
  String get pointsMyTotal => '我的累计积分';

  @override
  String get pointsRankUnknown => '未出现在返回的累计榜单中，完整排名未知。';

  @override
  String get pointsReadWallet => '查询我的积分与历史';

  @override
  String get pointsSelectHistory => '历史积分范围';

  @override
  String get pointsAccumulated => '累计积分';

  @override
  String get pointsSelectedHistory => '所选范围积分';

  @override
  String get pointsNoHistory => '未返回周期积分历史；缺失周期的积分保持未知。';

  @override
  String get eventsTitle => '交易活动';

  @override
  String get eventsScope => 'Vanta Orderly 活动；报名、成交量和奖励属于该计划，不会默认本应用内的 Aster 交易满足活动条件。';

  @override
  String get eventsEmpty => '暂无已发布交易活动。';

  @override
  String eventsCount(int count) {
    return '已发布 $count 场活动';
  }

  @override
  String get eventDetails => '活动详情';

  @override
  String get eventRegistrationOpen => '开放报名';

  @override
  String get eventImageUnavailable => '活动图片暂不可用';

  @override
  String get eventLinkFailed => '链接未能打开，请重试。';

  @override
  String get eventOwnVolume => '个人成交量（USDC）';

  @override
  String get eventRankingScope => '展示最多 30 条返回记录，每页 10 条；排名及 USDC 成交量由 Vanta 提供，不代表完整排名。';

  @override
  String get eventMyParticipation => '我的参与情况';

  @override
  String get eventPersonalScope => '刷新会将此 EVM 钱包地址发送给 Vanta，查询报名和个人成绩，无需签名。';

  @override
  String get eventRegistrationUnknownStatus => '报名状态尚未查询。';

  @override
  String get eventRegistered => '已核实报名';

  @override
  String get eventNotRegistered => '最近查询时尚未报名';

  @override
  String get eventBlockedBlacklist => '此地址不符合活动资格规则。';

  @override
  String eventBlockedExclusive(String name) {
    return '已报名互斥活动：$name';
  }

  @override
  String get eventAnotherCampaign => '其他活动';

  @override
  String get eventBlocked => '此地址暂不能报名。';

  @override
  String get eventRegistrationReadFirst => '请先刷新报名状态；提交前会再次核对当前活动规则。';

  @override
  String get eventRegistrationConfirm => '确认报名';

  @override
  String get eventRegistrationSigningScope => '使用此钱包为 Vanta 签署报名消息，不会转账、下单或保证获得奖励。';

  @override
  String get eventCancel => '取消';

  @override
  String get eventRegister => '立即报名';

  @override
  String get eventChecking => '正在核对当前活动和报名状态…';

  @override
  String get eventSigning => '请在钱包中确认报名消息…';

  @override
  String get eventSending => '正在提交报名…';

  @override
  String get eventAcknowledged => 'Vanta 已受理请求，请刷新核实报名；奖励尚未确认。';

  @override
  String get eventRegistrationUnknown => '报名结果未知，请先刷新报名状态再尝试；本应用不会自动重发。';

  @override
  String get eventRegistrationChanged => '钱包、活动规则或报名资格已变化，请刷新后重新核对。';

  @override
  String get eventWalletReconnect => '请重新连接此钱包后再签署报名消息。';

  @override
  String get eventSignatureRejected => '钱包已拒绝签署报名消息。';

  @override
  String get eventSignatureUnavailable => '钱包暂不能签署此报名消息，请重连后重试。';

  @override
  String get eventRegistrationCount => '已报名人数';

  @override
  String get eventTotalVolume => '活动总成交量（USDC）';

  @override
  String get eventRewardPool => '核心奖励池';

  @override
  String get eventActivityRules => '活动规则';

  @override
  String get eventCampaignRules => '活动细则';

  @override
  String get eventEnded => '活动已结束';

  @override
  String eventCountdown(String stage, String days, String hours, String minutes, String seconds) {
    return '$stage：$days 天 $hours:$minutes:$seconds';
  }

  @override
  String get eventUntilEnd => '距活动结束';

  @override
  String get eventUntilStart => '距活动开始';

  @override
  String get eventRegistrationOpens => '报名开放时间（UTC）';

  @override
  String get eventTasks => '活动任务';

  @override
  String get eventNoTasks => '暂无已发布任务。';

  @override
  String get eventTaskTarget => '公布目标';

  @override
  String get eventTaskProgress => '已核实进度';

  @override
  String get eventTaskUnknown => '任务进度尚未核实。';

  @override
  String get eventTaskCompleted => '已达到公布目标；奖励仍以活动规则为准。';

  @override
  String get eventTaskPending => '尚未达到目标';

  @override
  String get eventOpenTrading => '前往 Vanta 网站交易';

  @override
  String get eventTradingEligibility => '参与活动交易需要先核实报名，并在活动有效期内进行。';

  @override
  String get eventRankingVolume => '成交量（USDC）';

  @override
  String get eventIdLabel => '活动编号';

  @override
  String get eventMyRank => '我的活动排名';

  @override
  String get authorizationTitle => 'Aster 交易授权';

  @override
  String get authorizationScope => '直接使用当前钱包作为 API signer，不创建额外钱包。地址资格和权限由 Aster 核验。';

  @override
  String get authorizationEnable => '授权当前钱包交易';

  @override
  String get authorizationCheck => '核对签名 API 权限';

  @override
  String get authorizationCheckScope => '将分别签名读取合约和现货账户，不发送订单。读取权限、账户交易状态和代理授权范围分别显示。';

  @override
  String get authorizationReview => '确认授权内容';

  @override
  String get authorizationGrant => 'Signer：当前同一钱包；允许现货和合约交易；不授予提现权限；有效期 30 天；不附加 Builder 或费用授权。';

  @override
  String get authorizationConfirm => '确认并签名授权';

  @override
  String get authorizationAcknowledged => 'Aster 已确认收到授权请求。请核对该钱包的实际读取权限及平台返回的交易状态。';

  @override
  String get authorizationUnknown => '授权结果未知。再次申请前请先核对权限。';

  @override
  String get authorizationFuturesRead => '合约签名 API 读取';

  @override
  String get authorizationSpotRead => '现货签名 API 读取';

  @override
  String get authorizationReadAccepted => '该钱包的签名读取已被接受';

  @override
  String get authorizationCanTrade => '账户返回 canTrade = true；不代表订单执行成功或全部代理权限已确认。';

  @override
  String get authorizationCannotTrade => '账户返回 canTrade = false';

  @override
  String get authorizationPermissionUnknown => '账户交易权限未知';

  @override
  String get authorizationSpotPermissionUnknown => '现货读取成功不能证明现货下单权限。';

  @override
  String get subaccountActions => '管理子账户';

  @override
  String get subaccountActionsScope => '当前钱包以主账户身份签名，Aster 核验账户关系和权限。列表不提供子钱包地址或实时冻结状态，不创建钱包或私钥。';

  @override
  String get subaccountCreate => '创建子账户';

  @override
  String get subaccountCreateExternalOnly => '仅通过外部 EOA 钱包登录的账户可创建子账户。Privy 托管钱包不支持创建子账户。';

  @override
  String get subaccountFreeze => '冻结子账户';

  @override
  String get subaccountUnfreeze => '解冻子账户';

  @override
  String get subaccountTransfer => '主子账户划转';

  @override
  String get subaccountChildAddress => '子钱包地址';

  @override
  String get subaccountName => '子账户名称';

  @override
  String get subaccountFrom => '来源钱包';

  @override
  String get subaccountTo => '目标钱包';

  @override
  String get subaccountTransferDirection => '账户市场方向';

  @override
  String get subaccountMasterToChild => '主账户 → 子账户';

  @override
  String get subaccountChildToMaster => '子账户 → 主账户';

  @override
  String get subaccountTransferScope => '仅支持主子账户地址。提交时由 Aster 核验关系、冻结状态、可用资金和资产精度。列表不提供子账户可划转额度。';

  @override
  String get subaccountActionPrepare => '读取资格并准备';

  @override
  String get subaccountActionReview => '核对账户操作';

  @override
  String get subaccountActionConfirm => '确认并签名提交';

  @override
  String get subaccountReviewExpires => '确认内容 45 秒后失效；过期后需要重新准备及签名。';

  @override
  String get subaccountChildSignatureInstructions =>
      '使用你已控制的子钱包。复制 EIP-712 签名请求，在可信钱包工具中由子钱包签名，再仅粘贴签名结果。App 核验子地址后才请求主钱包签名。不要输入私钥或助记词。';

  @override
  String get subaccountCopyChallenge => '复制子钱包签名请求';

  @override
  String get subaccountChildSignature => '子钱包签名（hex）';

  @override
  String get subaccountKnownAddresses => '已确认创建请求中的地址';

  @override
  String get subaccountSwitch => '切换钱包账户';

  @override
  String get subaccountSwitchScope => '将退出当前身份。请在钱包中选择显示的子地址并重新签名登录，地址核验成功后才切换当前账户；账户编号不能替代签名权限。';

  @override
  String get subaccountMasterRequired => 'Aster 未返回该钱包有效的主账户列表。';

  @override
  String get subaccountLimitReached => '该主账户已达到 10 个子账户的创建上限。';

  @override
  String get subaccountInputInvalid => '请核对子地址、名称、资产和正数金额（最多 18 位小数），主子地址必须不同。';

  @override
  String get subaccountChildSignatureInvalid => '子钱包签名与该地址及本次请求不匹配。';

  @override
  String get walletOperationHistory => '已保存的账户与资金请求';

  @override
  String get walletOperationReload => '重新读取本地记录';

  @override
  String get walletOperationReference => '请求 nonce';

  @override
  String get walletOperationStorage => '请求记录存储不可用，已阻止新提交；请重新读取存储。';

  @override
  String get walletOperationPending => '该钱包有结果未知的请求。请勿重复提交；联系 Aster 核对结果后再继续。';

  @override
  String get walletOperationUnknown => '请求可能已被接受，结果未知，已保留未签名的操作内容；不会自动重试。';

  @override
  String get walletOperationAcknowledged => 'Aster 已确认该请求；这不代表已取得最新状态、余额或链上确认。';

  @override
  String get withdrawalSubmit => '提现';

  @override
  String get withdrawalScope => '仅提现到当前钱包自己的注册地址。需要重新签名核验主账户列表、提现额度和手续费；现货与合约余额独立处理。';

  @override
  String get withdrawalPrepare => '核对额度并准备提现';

  @override
  String get withdrawalReview => '核对提现内容';

  @override
  String get withdrawalFee => '提现手续费（资产单位）';

  @override
  String get withdrawalMarket => '来源账户';

  @override
  String get withdrawalChain => '目标链 ID';

  @override
  String get withdrawalReceiver => '接收地址';

  @override
  String get withdrawalConfirmScope =>
      '确认后会重新核验资格、额度和费率，再请求业务签名和 API 签名。费率变化需要重新确认；按“金额加手续费”保守核对平台额度。结果未知时不会重复发送。';

  @override
  String get withdrawalConfirm => '确认提现并签名';

  @override
  String get withdrawalAcknowledged => 'Aster 已返回提现请求编号，请查询记录核对完成状态；返回的签名摘要不是交易哈希。';

  @override
  String get withdrawalAmountInvalid => '请输入符合代币精度的正数金额，并选择支持自动提现的资产路径。';

  @override
  String get withdrawalAssetChanged => '资产可用性、合约或精度已变化，请刷新资产列表后重新准备。';

  @override
  String get withdrawalFeeChanged => '手续费已变化，请重新准备并确认。';

  @override
  String get withdrawalLimitsUnknown => '必要的提现额度或资产美元价格不可用，已阻止提交。';

  @override
  String get withdrawalLimitExceeded => '金额加手续费超过平台返回的资产、链或美元额度。';

  @override
  String get withdrawalRecovery => '核对提现完成状态';

  @override
  String get withdrawalRecoveryScope =>
      '签名读取历史记录后，按返回的请求编号、账户、链、币种和金额精确匹配。未返回编号的未知请求，不能通过余额变化或相似记录判断完成。';

  @override
  String get withdrawalOpenHistory => '打开并刷新签名记录';

  @override
  String get withdrawalNotReconciled => '尚未读取到精确匹配的完成记录。';

  @override
  String get withdrawalHistoryStale => '匹配记录来自历史快照，请刷新核对当前状态。';

  @override
  String get withdrawalProcessing => 'Aster 返回该提现处理中。';

  @override
  String get withdrawalCompleted => 'Aster 返回该提现已完成。';

  @override
  String get withdrawalFailed => 'Aster 返回该提现失败。';

  @override
  String get depositSubmissionScope =>
      '由当前钱包调用 depositFor，充值到其自己的现货或合约账户。每笔交易单独确认及签名，ERC-20 授权是独立步骤。';

  @override
  String get depositPlatformLimitsUnknown =>
      '用户和平台剩余充值额度需要 Aster 官网登录态，此处无法读取；额度未知不代表无限。继续前请在 Aster 官网核验当前可充状态及额度。Gas 模拟不代表平台入账。';

  @override
  String get depositLimitsAcknowledgement => '我已在 Aster 官网核对该金额当前可充及额度足够。';

  @override
  String get depositSubmissionPrepare => '准备充值交易';

  @override
  String get depositSubmissionReview => '核对充值交易';

  @override
  String get depositSubmissionConfirm => '确认充值并打开钱包';

  @override
  String get depositSubmissionSent => '已保存钱包交易响应。请进入恢复页面核对链上状态和平台入账，钱包响应不代表完成。';

  @override
  String get depositSubmissionRecovery => '恢复待确认充值';

  @override
  String get depositSubmissionRecoveryScope =>
      '先核对原交易或相同意图的替换交易及规范链回执。链上成功后仍保留待确认，直到签名读取的 Aster 记录在哈希、账户、链、币种和精确金额上匹配且状态为 SUCCESS；不会自动重发或删除未知请求。';

  @override
  String get depositSubmissionStorage => '充值恢复存储不可用，已阻止新充值，请重新读取保存记录。';

  @override
  String get depositSubmissionPending => '该钱包仍有充值需要核对链上或平台状态。';

  @override
  String get depositSubmissionNoPending => '该钱包暂无待确认充值。';

  @override
  String get depositSubmissionUnknown => '钱包可能已提交交易，请保留记录并恢复状态后再充值。';

  @override
  String get depositSubmissionChanged => '余额、授权、交易内容或 Gas 已变化，请重新准备及确认。';

  @override
  String get depositSubmissionApprovalNeeded => 'ERC-20 授权额度不足，请先完成独立授权并核对额度。';

  @override
  String get depositSubmissionHashNeeded => '请先读取并绑定匹配的交易哈希，再核对平台入账。';

  @override
  String get depositSubmissionChainPending => '需要匹配且成功的链上回执，并至少观察到 2 次区块确认。';

  @override
  String get depositSubmissionCreditPending => '尚无精确匹配的 SUCCESS 平台入账记录，继续保留充值恢复记录。';

  @override
  String get depositSubmissionCheckChain => '核对链上回执';

  @override
  String get depositSubmissionCheckCredit => '签名核对平台入账';

  @override
  String get depositSubmissionChainSucceeded => '链上交易成功，平台入账仍未确认。';

  @override
  String get depositSubmissionCredited => '已观察到链上成功及精确匹配的 Aster SUCCESS 充值记录。';

  @override
  String get depositVerifiedMinimumScope =>
      '公开资产列表未返回最低充值额。请在 Aster 官网核验后填写资产单位的最低额；仅当官网明确无正数最低额时填 0。此值由你外部核验，并非 App 查询结果。';

  @override
  String get depositVerifiedMinimum => '在 Aster 核验的最低额（资产单位）';

  @override
  String get depositTransactionBusy => '另一笔授权或充值的钱包请求仍在进行，请待其结束后再提交。';

  @override
  String get subaccountSwitchEntered => '切换到填写的钱包地址';

  @override
  String get authorizationWithdrawOption => '同时申请提现权限';

  @override
  String get authorizationWithdrawScope =>
      'Aster 要求提现授权配置非空 IP／CIDR 白名单。请仅填写已核实的钱包／API 出口 IP，移动网络 IP 可能变化。此授权不会提交提现。';

  @override
  String get authorizationIpWhitelist => 'IP／CIDR 白名单（空格分隔）';

  @override
  String get authorizationWithdrawGrant =>
      'Signer：当前同一钱包；允许现货交易、合约交易和提现；受下方 IP 白名单限制；有效期 30 天；不附加 Builder 或费用授权。';

  @override
  String get authorizationCanWithdraw => '账户返回 canWithdraw = true；不代表全部代理／IP 权限或提现执行已确认。';

  @override
  String get authorizationCannotWithdraw => '账户返回 canWithdraw = false';

  @override
  String get authorizationWithdrawUnknown => '账户提现权限未知';

  @override
  String get authorizationIpInvalid => '请输入 1–16 个有效的 IP 地址或 CIDR，以空格分隔；提现权限必须配置非空白名单。';

  @override
  String get assetMetadataTitle => '资产资料';

  @override
  String get assetMetadataRefresh => '刷新资产名称与图标';

  @override
  String get assetMetadataNamesFailed => '资产名称刷新失败，仍可查看资产标识。';

  @override
  String get assetMetadataIconsFailed => '资产图标刷新失败，余额仍可查看。';

  @override
  String get assetMetadataStale => '正在显示之前加载的资产资料，可刷新获取更新。';

  @override
  String get assetMetadataPaused => '应用未激活，资产资料刷新已暂停。';

  @override
  String get assetMetadataEmpty => '暂无额外资产资料。';

  @override
  String get assetMetadataNoIcon => '资产图标不可用';

  @override
  String get assetMetadataRetryIcon => '重新加载资产图标';

  @override
  String get eventRetailTab => '普通活动';

  @override
  String get eventChannelTab => '频道活动';

  @override
  String get eventChannelName => '频道';

  @override
  String get eventChannelRankingScope => '频道榜单最多展示前 10 条；不推算榜外排名。';

  @override
  String get eventEngagementTitle => '频道任务进度';

  @override
  String get eventEngagementScope =>
      '手动查询会向 Vanta 活动服务发送当前钱包地址。任务基于 Vanta Orderly 活动，不计入 Aster 交易或充值。';

  @override
  String get eventEngagementVerified => '已核实任务完成状态。';

  @override
  String get eventEngagementAcknowledged => '请求已受理，任务完成尚未核实；请查询进度。';

  @override
  String get eventEngagementUnknown => '此前任务提交结果未知；仅查询原任务进度，不重复提交。';

  @override
  String get eventEngagementReadFirst => '请刷新活动、参与状态及任务进度，再确认符合条件的任务。';

  @override
  String get eventEngagementIneligible => '任务条件或活动时间已变化，请刷新后重试。';

  @override
  String get eventEngagementStorage => '无法保存或读取任务日志，未继续提交；请检查设备存储后查询进度。';

  @override
  String get eventEngagementBusy => '另一个活动任务正在处理，请等待。';

  @override
  String get eventEngagementReconcileFailed => '未能核对任务进度；原有未决状态保留，请重试查询。';

  @override
  String get eventDailyDate => '任务日期（UTC）';

  @override
  String get eventDailyVolume => '当日交易量（USDC）';

  @override
  String get eventCheckedIn => '今日已签到';

  @override
  String get eventNotCheckedIn => '今日尚未签到';

  @override
  String eventCheckedDays(int count) {
    return '已签到 $count 天';
  }

  @override
  String get eventDailyExpired => '任务日期已过期，请刷新当日进度。';

  @override
  String get eventTrackedMetric => '统计指标';

  @override
  String get eventMilestoneCurrent => '累计指标进度';

  @override
  String get eventMilestoneUnlocked => '已达到任务里程碑';

  @override
  String get eventMilestoneRemaining => '距下一目标';

  @override
  String get eventNewRegistration => '完成活动注册';

  @override
  String get eventNewWallet => '钱包连接任务';

  @override
  String get eventNewDeposit => '净充值任务';

  @override
  String get eventDepositRequired => '服务端充值目标';

  @override
  String get eventDepositCurrent => '已统计净充值';

  @override
  String get eventDepositRemaining => '尚需净充值';

  @override
  String get eventDepositChain => '充值链 ID';

  @override
  String get eventWebsiteDeposit => '在 Vanta 官网充值';

  @override
  String get eventRewardNotCredit => '任务达标或公布奖励不代表奖励已发放。';

  @override
  String get eventCheckIn => '确认每日签到';

  @override
  String get eventRecordWallet => '确认钱包连接任务';

  @override
  String get eventEngagementSigningScope => '将使用当前钱包签署本次 Vanta 活动任务消息并提交。不会创建钱包或发送资金；签名后会重新核对任务条件。';

  @override
  String get eventNetworkVolume => '推荐网络交易量（USDC）';

  @override
  String get eventPersonalTotalVolume => '本人＋推荐网络交易量（USDC）';

  @override
  String get eventWhitelistCount => '公布白名单数量';

  @override
  String get eventUpcoming => '即将开始';

  @override
  String get assistantTitle => 'Vanta AI';

  @override
  String get assistantIntro => '探索行情、比较情景与理解风险。提问时可提供交易对和时间周期。';

  @override
  String get assistantScope => 'AI 回复可能不准确。此对话不会下单，也不会自动附带账户余额。';

  @override
  String get assistantAuthorize => '使用钱包授权';

  @override
  String get assistantRestore => '恢复已保存会话';

  @override
  String get assistantReady => 'AI 钱包身份已验证';

  @override
  String get assistantAuthHint => '使用当前连接的钱包授权，或恢复此设备保存的会话。签名消息需要单独确认。';

  @override
  String get assistantReview => '确认登录消息';

  @override
  String get assistantReviewHint => '请核对下方完整消息。确认后将使用当前钱包签署 AI 登录消息，不授予交易权限。请求在 5 分钟后过期。';

  @override
  String get assistantSign => '确认并签名';

  @override
  String get assistantCancel => '取消';

  @override
  String get assistantStop => '停止';

  @override
  String get assistantSend => '发送';

  @override
  String get assistantPrompt => '向 Vanta AI 提问…';

  @override
  String get assistantInputHint => '最多 12,000 个 UTF-16 字符。发送会将本条问题和最近的完整对话提交给 Vanta AI。';

  @override
  String get assistantGuide => '例如：比较 BTC 四小时图的不同情景，并说明风险和失效条件。';

  @override
  String get assistantEmpty => '对话将显示在这里。';

  @override
  String get assistantYou => '你';

  @override
  String get assistantReply => 'Vanta AI';

  @override
  String get assistantExplanation => '返回的解释';

  @override
  String get assistantCopy => '复制消息';

  @override
  String get assistantCopied => '已复制';

  @override
  String get assistantCopyFailed => '复制失败，请选中文字手动复制。';

  @override
  String get assistantCopyAddress => '复制钱包地址';

  @override
  String get assistantRemoteImage => '已隐藏远程图片';

  @override
  String get assistantStreaming => '正在接收回复…';

  @override
  String get assistantInterrupted => '已停止或中断。部分内容已保存，不会自动续传。';

  @override
  String get assistantTruncated => '回复已达到长度上限。';

  @override
  String get assistantReplyFailed => '回复未完成。请先查看已有内容，再决定是否重新提问。';

  @override
  String get assistantClear => '清空对话';

  @override
  String get assistantClearConfirm => '清空此钱包在本设备上的对话和草稿？此操作无法撤销，也不会删除服务端记录。';

  @override
  String get assistantForget => '移除已保存的 AI 会话';

  @override
  String get assistantForgetConfirm => '从本设备移除此钱包保存的 AI 凭据？对话历史会保留，此操作不会撤销服务端会话。';

  @override
  String get assistantRetryHistory => '重新读取历史';

  @override
  String get assistantRetrySave => '重试保存';

  @override
  String get assistantHistoryBlocked => '无法安全读取历史。请重新读取或明确清空后再发送。';

  @override
  String get assistantUsage => '每日用量（UTC）';

  @override
  String get assistantReadUsage => '读取用量';

  @override
  String get assistantUsageUnknown => '尚未读取用量，剩余额度未知。';

  @override
  String get assistantQuotaStale => '此用量快照已过期，请重新读取以核对当前 UTC 日期。';

  @override
  String get assistantUnknown => '未知';

  @override
  String get assistantPreparing => '正在请求登录消息…';

  @override
  String get assistantSigning => '正在等待钱包签名与验证…';

  @override
  String get assistantRestoring => '正在核对已保存会话…';

  @override
  String get assistantLoadingHistory => '正在读取已保存对话…';

  @override
  String get assistantReadingUsage => '正在读取每日用量…';

  @override
  String get assistantClearing => '正在更新本地存储…';

  @override
  String get assistantWalletRequired => '请先连接 EVM 钱包以使用 Vanta AI。';

  @override
  String get assistantUnavailable => 'Vanta AI 暂不可用。已保留输入，请稍后重试。';

  @override
  String get assistantAuthorization => '无法验证 AI 会话，请恢复会话或重新授权。';

  @override
  String get assistantBinding => '服务端未确认此钱包与 AI 账户的绑定。';

  @override
  String get assistantBusy => '另一项 AI 请求尚未结束，请稍后重试。';

  @override
  String get assistantCancelled => '请求已停止。';

  @override
  String get assistantChallengeExpired => '登录请求已过期，请重新获取消息。';

  @override
  String get assistantChallengeInvalid => '无法核对登录消息，未发起签名。';

  @override
  String get assistantSessionChanged => '钱包或会话已变化，请重新发起操作。';

  @override
  String get assistantConfiguration => 'AI 服务配置不可用，请稍后重试。';

  @override
  String get assistantInvalidInput => '请输入问题，且不超过 12,000 个 UTF-16 字符。';

  @override
  String get assistantInvalidResponse => 'AI 服务返回了无法读取的响应，已保留输入。';

  @override
  String get assistantEmptyReply => '未收到答案，已保留问题。';

  @override
  String get assistantQuotaExceeded => 'AI 服务提示今日额度已用尽。';

  @override
  String get assistantTimeout => 'AI 请求超时，已保留部分回复和输入。';

  @override
  String get assistantTooLarge => '回复超过可处理的大小，已保留部分内容。';

  @override
  String get assistantStorage => '无法访问此钱包保存的 AI 数据，请重试。';

  @override
  String get assistantStorageCapacity => '仅能保留本设备存储容量允许的最近对话。';

  @override
  String get assistantNoSavedSession => '此钱包在本设备上没有保存的 AI 会话，请先使用钱包授权。';

  @override
  String get assistantClearFailed => '无法清空此对话，请重试。';

  @override
  String get assistantLinkUnavailable => '无法打开此链接，仅支持 HTTPS 链接。';

  @override
  String get assistantLocalHistoryHint => '最近对话和草稿按钱包隔离，保存在本设备的安全存储中。';

  @override
  String assistantCharacterCount(int count) {
    return '$count / 12,000 个 UTF-16 字符';
  }

  @override
  String assistantUsageValues(String day, String used, String remaining) {
    return '日期 $day · 已用 $used · 剩余 $remaining';
  }

  @override
  String get collateralContribution => '资产抵押贡献（参考）';

  @override
  String get collateralCalculation => '抵押贡献计算';

  @override
  String get collateralFormula =>
      '全仓权益 = 全仓钱包余额 + 全仓未实现盈亏。抵押贡献 = min（权益 × bid 价格率，权益 × ask 价格率）。权益为负时取更负的值。';

  @override
  String get collateralCrossEquity => '全仓权益';

  @override
  String get collateralBidRate => 'Bid 价格率（每币美元）';

  @override
  String get collateralAskRate => 'Ask 价格率（每币美元）';

  @override
  String get collateralScope =>
      '基于签名账户快照与公开抵押价格率，估算可用于多资产保证金的资产贡献。不确认当前资产模式，也不等于可下单资金、提现额度或 Portfolio 总值。';

  @override
  String get collateralEligibilityUnknown => '抵押资格未知，请重新读取账户核对。';

  @override
  String get collateralEquityUnknown => '缺少全仓钱包余额或全仓未实现盈亏，请重新读取账户；缺失值不会按零计算。';

  @override
  String get collateralEventsNeedRead => '账户事件已改变此快照，请重新读取账户以核对全仓权益。';

  @override
  String get collateralRatesUnknown => '抵押 bid／ask 价格率不可用，请刷新公开资产价格重试。';

  @override
  String get collateralStale => '抵押贡献使用了陈旧快照，请重新读取账户余额并刷新公开价格后再参考。';

  @override
  String collateralAccountTime(String time) {
    return '账户快照（UTC）：$time';
  }

  @override
  String collateralRateTime(String time) {
    return '价格率时间（UTC）：$time';
  }

  @override
  String get collateralLiveMarks => '全仓盈亏按公开标记价格重算。';

  @override
  String get collateralSnapshotPnl => '使用签名读取的全仓盈亏快照；完整标记价格或仓位字段尚不可用。';

  @override
  String collateralMarkTime(String time) {
    return '最早标记价格时间（UTC）：$time';
  }

  @override
  String get marginAdjustTitle => '调整逐仓保证金';

  @override
  String get marginAdjustScope => '使用当前钱包读取并确认单个逐仓仓位。签名权限与最终可调整额度由 Aster 校验。';

  @override
  String get marginAdjustRead => '读取保证金与额度';

  @override
  String get marginAdjustReadHint => '将分别签名读取账户、仓位和风险档位，确认前不提交调整。额度在 30 秒后过期。';

  @override
  String get marginAdjustAdd => '追加保证金';

  @override
  String get marginAdjustRemove => '移除保证金';

  @override
  String get marginAdjustAmountLabel => '保证金数量';

  @override
  String get marginAdjustAmount => '请输入当前额度内的正数，最多 8 位小数。';

  @override
  String get marginAdjustMaximum => '当前最大额度';

  @override
  String get marginAdjustMax => '最大值（2 位小数）';

  @override
  String get marginAdjustWallet => '当前逐仓钱包保证金';

  @override
  String get marginAdjustNextWallet => '调整后逐仓钱包保证金';

  @override
  String get marginAdjustLiquidation => '调整后预估强平价';

  @override
  String get marginAdjustPreviewHint => '仅按签名快照标记价和风险档位预估，仓位数量与开仓均价不变；调整后重新读取实际强平价。';

  @override
  String get marginAdjustReview => '确认调整条款';

  @override
  String get marginAdjustConfirm => '签名并提交调整';

  @override
  String get marginAdjustConfirmHint =>
      '重新读取额度后，签名并提交一次。按原编号和完整条款核对结果，不用余额变化判断成功。后续签名将刷新仓位、账户和风险档位。';

  @override
  String get marginAdjustReference => '调整编号';

  @override
  String get marginAdjustHistory => '保证金调整记录';

  @override
  String get marginAdjustHistoryEmpty => '当前钱包暂无保证金调整记录。';

  @override
  String get marginAdjustCheck => '核对原调整编号';

  @override
  String get marginAdjustVerified => '已在 Aster 历史中核对到该笔调整。';

  @override
  String get marginAdjustUnknown => '结果尚未确认。保留原编号并再次查询，请勿重新提交。';

  @override
  String get marginAdjustRejected => 'Aster 已明确拒绝本次调整，未认定调整成功。';

  @override
  String get marginAdjustStorage => '保证金记录不可用或保存失败，已阻止提交，请重新读取记录。';

  @override
  String get marginAdjustReload => '重新读取已存记录';

  @override
  String get marginAdjustExpired => '保证金信息已过期或发生变化，请重新读取额度后确认。';

  @override
  String get marginAdjustChanged => '仓位、保证金或风险档位已变化，请重新读取并确认新条款。';

  @override
  String get marginAdjustClosed => '该仓位已关闭或数量为零，无法调整保证金。';

  @override
  String get marginAdjustUnsupported => '仅支持单位明确、数量非零的线性逐仓仓位。';

  @override
  String get marginAdjustInsufficient => 'Aster 提示可用余额或逐仓保证金不足，请重新读取额度。';

  @override
  String get marginAdjustSubmitting => '正在提交已确认的调整，不会重复发送…';

  @override
  String get marginAdjustChecking => '正在核对历史、实际仓位和账户…';

  @override
  String get marginAdjustStop => '停止等待';

  @override
  String get marginAdjustStopHint => '离开或停止等待不会取消已发送请求。已保存的未决记录只恢复查询，不重新提交。';

  @override
  String get marginAdjustActualLiquidation => '最新实际强平价';

  @override
  String get marginAdjustRatio => '逐仓保证金率';

  @override
  String get marginAdjustEquityRisk => '保证金权益为零或负值，存在较高强平风险。';

  @override
  String get marginAdjustRatioHint => '维持保证金 ÷（逐仓钱包保证金 + 浮动盈亏），均取自同一账户快照。';

  @override
  String get marginAdjustOverMaximum => '金额超过可用额度。';

  @override
  String get attachedOrderAdvanced => '专业退出设置';

  @override
  String get attachedOrderInputMode => '输入方式';

  @override
  String get attachedOrderPnlMode => '盈亏金额';

  @override
  String get attachedOrderPriceMode => '触发价格';

  @override
  String get attachedOrderRoiMode => '保证金收益率（%）';

  @override
  String attachedOrderPnlInput(String asset) {
    return '盈亏金额（$asset）';
  }

  @override
  String get attachedOrderExecution => '退出执行方式';

  @override
  String get attachedOrderManualLimit => '手动限价';

  @override
  String get attachedOrderAutomaticLimit => '自动限价（等于触发价）';

  @override
  String attachedOrderLimitPrice(String asset) {
    return '退出委托价（$asset）';
  }

  @override
  String get attachedOrderTriggerPreview => '预估触发条件';

  @override
  String get attachedOrderGrossPnl => '预估毛盈亏';

  @override
  String get attachedOrderGrossRoi => '预估毛收益率';

  @override
  String get attachedOrderRoundedPreview => '换算触发价按最接近的价格步长对齐，请复核最终价格。';

  @override
  String get attachedOrderEstimateScope => '按本次主单数量与预估开仓价计算，未计费用和滑点。限价退出触发后可能一直未成交。';

  @override
  String attachedOrderExitIssue(String exit, String reason) {
    return '$exit：$reason';
  }

  @override
  String get attachedOrderCheckExits => '请先复核附加止盈／止损中提示的字段。';

  @override
  String get attachedOrderTargetSign => '止盈金额／收益率请输入正数，止损请输入负数；目标不能为零。';

  @override
  String get attachedOrderPreviewUnavailable => '请填写有效主单数量和价格，并读取开仓参考行情及杠杆后再换算。';

  @override
  String get attachedOrderLimitRequired => '请填写大于零的退出委托价。';

  @override
  String get attachedOrderExecutionInvalid => '请复核附加退出方式与限价。';

  @override
  String get attachedOrderLegacyLifecycle => '该已保存策略沿用原有完全成交后激活／互撤规则，原保护数量保持不变。';

  @override
  String attachedOrderDirectionHint(String relation, String price, String asset) {
    return '触发价须 $relation 预估开仓价 $price $asset。';
  }

  @override
  String get strategyExecutionTitle => '策略成交详情';

  @override
  String get strategyExecutionScope => '独立读取普通订单的实际数量和成交金额，每条订单分别标注快照时间。这些记录不证明当前余额或剩余仓位。';

  @override
  String get strategyExecutionSignHint => '签名核对原策略后，再逐条读取已有交易所编号的子单，可能需要多次钱包确认。读取失败后停止后续签名，可手动重试。';

  @override
  String get strategyExecutionRead => '签名读取成交详情';

  @override
  String get strategyExecutionCheckingStrategy => '正在核对原策略…';

  @override
  String strategyExecutionCheckingLeg(int sequence) {
    return '正在读取第 $sequence 条订单…';
  }

  @override
  String get strategyExecutionStop => '停止等待';

  @override
  String get strategyExecutionStopped => '已停止等待。保留已有快照，未撤销任何订单。';

  @override
  String get strategyExecutionSkipped => '此前读取失败后已停止后续读取，请手动重读核对本单。';

  @override
  String get strategyExecutionStale => '此快照可能已过期，请签名重新读取。';

  @override
  String get strategyExecutionStrategyTime => '策略读取时间（UTC）';

  @override
  String get strategyExecutionOrderTime => '普通订单读取时间（UTC）';

  @override
  String get strategyExecutionEntry => '主单';

  @override
  String get strategyExecutionStrategyLegStatus => '策略快照中的状态';

  @override
  String get strategyExecutionOrderStatus => '普通订单快照中的状态';

  @override
  String get strategyExecutionNoOrder => '策略尚未返回本腿普通订单编号，成交数量及金额未知。';

  @override
  String get strategyExecutionTriggered => '普通订单回报显示已触发或已执行；仅触发不代表成交。';

  @override
  String get strategyExecutionTriggerUnconfirmed => '此普通订单快照未确认触发状态。';

  @override
  String get strategyExecutionOriginalSize => '当前普通订单数量';

  @override
  String get strategyExecutionFilledSize => '实际成交数量';

  @override
  String get strategyExecutionFilledValue => '实际成交金额';

  @override
  String get strategyExecutionAveragePrice => '回报成交均价';

  @override
  String get strategyExecutionTermsChanged => '当前数量或价格与原策略条款不同。以上展示普通订单回报，不推断发生了自动增补。';

  @override
  String get liveAmountUnit => '委托数量单位';

  @override
  String liveAmountInput(String asset) {
    return '委托金额（$asset）';
  }

  @override
  String get liveAmountHint => '填写委托金额，不是保证金；换算时不再乘杠杆。';

  @override
  String get liveAmountInvalid => '请输入有效的正数委托金额。';

  @override
  String get liveAmountBelowStep => '金额换算后不足最小委托数量或一个数量步长。';

  @override
  String get liveAmountReferenceUnavailable => '换算所需的价格不可用，请刷新下单快照或改填基础币数量。';

  @override
  String get liveAmountLimitReference => '填写的限价';

  @override
  String get liveAmountAskReference => '卖一价快照';

  @override
  String get liveAmountBidReference => '买一价快照';

  @override
  String get liveAmountTriggerReference => '触发价估算';

  @override
  String get liveAmountBboReference => '参考 Mark，非引擎实际 BBO 价格';

  @override
  String liveAmountConversionPrice(String basis) {
    return '换算参考：$basis';
  }

  @override
  String get liveAmountResolvedQuantity => '拟提交的基础币数量';

  @override
  String get liveAmountSnapshotTime => '下单快照时间（UTC）';

  @override
  String get liveAmountEstimateHint =>
      '数量按适用步长向下取整，并在确认时固定。市价、触发及 BBO 价格可能变化，实际成交金额可能超过估算；输入金额不代表支出上限。';

  @override
  String get futuresHistoryTitle => '合约历史';

  @override
  String get futuresHistoryScope => '分别读取当前钱包的合约订单、逐笔成交与资金流水。仅凭买卖方向不能判断开仓或平仓；读取不会下单或撤单。';

  @override
  String get futuresHistoryIncome => '资金流水';

  @override
  String get futuresHistorySymbol => '合约交易对（选填）';

  @override
  String get futuresHistoryTradeSymbol => '合约交易对（成交记录必填）';

  @override
  String get futuresHistoryFilterHint =>
      '输入准确交易对代码，可查询已下架合约。订单和流水可留空读取全部交易对；逐笔成交必须指定交易对。修改条件清空展示结果，不自动签名。';

  @override
  String get futuresHistoryInvalidSymbol => '请输入准确的合约交易对代码。逐笔成交必须指定交易对，不接受空格或查询语法。';

  @override
  String get futuresHistoryInvalidType => '请选择支持的流水类型，或选择全部。';

  @override
  String get futuresHistoryInvalidWindow => '请选择有效的 UTC 日期范围。每次签名读取少于7天，更长范围需手动分批读取。';

  @override
  String get futuresHistoryCapacity => '当前视图达到10000条上限，已读结果保留。请缩小时间或交易对范围后重新读取，未静默丢弃记录。';

  @override
  String get futuresHistoryRetention =>
      'Aster 不返回创建超过7天且完全未成交的已撤销／已过期订单。部分成交后撤销的订单仍保留回报的成交数量；更早记录受接口保留期限制。';

  @override
  String get futuresHistoryAllTypes => '全部流水类型';

  @override
  String get futuresHistoryOriginalType => '原始订单类型';

  @override
  String get futuresHistoryExecuted => '回报的已成交数量';

  @override
  String get futuresHistoryPnlHint => '回报的已实现盈亏与手续费、资金流水独立展示；不将这些记录相加作为净收益或资产统计。';

  @override
  String get futuresHistoryIncomeAmount => '回报的资金变动';

  @override
  String futuresHistoryIncomeType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'TRANSFER': '划转',
      'WITHDRAW': '提现',
      'DEPOSIT': '充值',
      'WELCOME_BONUS': '新用户奖励',
      'REALIZED_PNL': '已实现盈亏',
      'FUNDING_FEE': '资金费用',
      'COMMISSION': '手续费',
      'INSURANCE_CLEAR': '保险清算',
      'MARKET_MERCHANT_RETURN_REWARD': '市场商户返还奖励',
      'REFERRAL_KICKBACK': '推荐返佣',
      'COMMISSION_REBATE': '手续费返还',
      'MARKET_MAKER_REBATE': '做市返还',
      'API_REBATE': 'API返还',
      'CONTEST_REWARD': '竞赛奖励',
      'CROSS_COLLATERAL_TRANSFER': '跨抵押品划转',
      'INTERNAL_TRANSFER': '内部划转',
      'AUTO_EXCHANGE': '自动兑换',
      'other': '未知类型（$type）',
    });
    return '$_temp0';
  }

  @override
  String get orderConfirmLimit => '限价／只做 Maker 开仓前确认';

  @override
  String get orderConfirmStopLimit => '条件限价开仓前确认';

  @override
  String get orderConfirmStopMarket => '条件市价开仓前确认';

  @override
  String get orderConfirmTrailing => '跟踪委托开仓前确认';

  @override
  String get orderConfirmLimitShared => '限价与只做 Maker 共用此设置。';

  @override
  String get orderConfirmDoNotShow => '此订单类型不再显示确认';

  @override
  String get orderConfirmWalletHint => '此设置控制应用内确认。提交前检查和钱包签名仍会执行。';

  @override
  String get scaledTotalAmount => '总委托金额';

  @override
  String get scaledAmountInvalid => '请输入正数总委托金额。';

  @override
  String get scaledDistribution => '数量分布';

  @override
  String get scaledEqual => '等量';

  @override
  String get scaledIncreasing => '递增';

  @override
  String get scaledDecreasing => '递减';

  @override
  String get scaledRandom => '随机';

  @override
  String get scaledConstant => '分布常数方式';

  @override
  String get scaledDifference => '等差';

  @override
  String get scaledRatio => '等比';

  @override
  String get scaledDifferenceHint => '递增按价格从低到高使用 1:2:3… 数量权重，递减反向排列。实际分布受数量步长取整影响。';

  @override
  String get scaledRatioHint => '递增按价格从低到高使用 1:2:4… 数量权重，递减反向排列。每笔均需满足最小数量；子单较多时可能需要很大的总量。';

  @override
  String get scaledVariance => '随机偏差';

  @override
  String get scaledVarianceInvalid => '随机偏差请输入 0%–10%。';

  @override
  String get scaledVarianceStep => '当前数量步长无法在所选偏差内表示该随机分布。请增加总量、调整偏差或重新分配。';

  @override
  String get scaledRandomRequired => '请先生成随机分配方案，再确认。';

  @override
  String get scaledRandomHint => '每笔数量与平均数量的偏差不超过所填比例。当前方案保持固定，修改输入或重新分配才会变化；切换语言不会重新抽样。';

  @override
  String get scaledReshuffle => '重新随机分配';

  @override
  String get scaledUnallocatedQuote => '未分配委托金额';

  @override
  String get scaledAmountHint =>
      '委托金额为各子单限价 × 数量之和，不乘杠杆。计价币输入向下取整为有效基础币数量，尾差显示为未分配金额。不含手续费，不是保证金或最终成交支出上限。';

  @override
  String get scaledBaseRemainderHint => '输入的基础币总量保持不变。尾差按小数余量从大到小分配，相同余量按价格从低到高分配。';

  @override
  String get scaledPreviousChildren => '上一组子单';

  @override
  String get scaledNextChildren => '下一组子单';

  @override
  String get scaledChildType => '子单类型';

  @override
  String get scaledEnteredSize => '输入总量／金额';

  @override
  String scaledPage(int start, int end, int total) {
    return '子单 $start–$end，共 $total 笔';
  }

  @override
  String get scaledCountRange => '2–110';

  @override
  String get assistantNavigation => 'AI';

  @override
  String get orderModeLabel => '下单模式';

  @override
  String get orderModeMore => '更多下单模式';

  @override
  String get orderModeStopLimit => '限价止盈止损';

  @override
  String get orderModeStopMarket => '市价止盈止损';

  @override
  String get orderModeChase => '追逐限价委托';

  @override
  String get orderModeTwap => '分时委托（TWAP）';

  @override
  String get orderModeChaseUnavailable => '追逐委托暂未开放。';

  @override
  String get orderModeTwapUnavailable => '暂不可用，分时委托不在本阶段支持范围内。';

  @override
  String get apiRequestTimeout => '请求超时。';

  @override
  String get apiConnectionFailed => '无法连接服务器，请检查网络连接。';

  @override
  String get apiRequestCancelled => '请求已取消。';

  @override
  String get apiInvalidResponse => '服务器返回的数据格式无效。';

  @override
  String get assistantRateLimited => '请求过于频繁，请稍后重试。';
}
