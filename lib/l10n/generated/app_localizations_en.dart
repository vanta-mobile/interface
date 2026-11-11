// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get demoOrdersTitle => 'Local demo positions and orders';

  @override
  String get connectExternalWallet => 'Connect EOA wallet';

  @override
  String get externalWallet => 'External EOA wallet';

  @override
  String get embeddedWallet => 'Privy embedded wallet';

  @override
  String get reconnectExternalWallet => 'Connect wallet';

  @override
  String get externalWalletLoginHint =>
      'Connect and sign in with your existing wallet. No extra wallet is created. Sign-in does not enable live trading.';

  @override
  String get walletConnectStep => 'Confirm the connection in your wallet.';

  @override
  String get authWalletConfiguration => 'External wallet sign-in is not available.';

  @override
  String get authWalletCancelled => 'Wallet connection cancelled. You can retry.';

  @override
  String get authWalletRejected => 'Wallet request rejected. You can retry.';

  @override
  String get authWalletUnavailable =>
      'Wallet connection failed. Check your wallet app and network, then retry.';

  @override
  String get authWalletBusy => 'Another wallet request is pending. Finish it before continuing.';

  @override
  String get authWalletSigningNetwork =>
      'Approve BNB Chain (56) in your wallet and reconnect before enabling trading.';

  @override
  String get authWalletConnectionTimeout =>
      'Wallet connection setup timed out. Check your network and retry.';

  @override
  String get authWalletUnsupported =>
      'Select Ethereum, BNB Chain, Arbitrum, or Base in your wallet.';

  @override
  String get authWalletChanged => 'Wallet account or network changed. Reconnect and sign in again.';

  @override
  String get authWalletReconnect => 'Connect your wallet to continue.';

  @override
  String get authWalletSignature => 'Your wallet did not return a valid signature. Please retry.';

  @override
  String get quotesConnecting => 'Connecting live quotes';

  @override
  String get quotesLive => 'Live quotes';

  @override
  String get quotesPartial => 'Some quotes are reconnecting';

  @override
  String get quotesOffline => 'Quotes offline. Showing recent data';

  @override
  String get quotesUpdatedAt => 'Updated';

  @override
  String get quotesSnapshotFailure =>
      'Quote refresh failed. Available data is retained. Check your connection and retry.';

  @override
  String get quotesDataFailure =>
      'Some quotes are invalid or missing. Showing the last valid values.';

  @override
  String get done => 'Done';

  @override
  String get chartType => 'Chart type';

  @override
  String get loadingChart => 'Loading chart';

  @override
  String get more => 'More';

  @override
  String get moreTimeframes => 'All intervals';

  @override
  String get typeCandles => 'Candles';

  @override
  String get typeHollowCandles => 'Hollow candles';

  @override
  String get typeBars => 'Bars';

  @override
  String get typeLine => 'Line';

  @override
  String get typeLineWithMarkers => 'Line with markers';

  @override
  String get typeStepLine => 'Step line';

  @override
  String get typeArea => 'Area';

  @override
  String get typeBaseline => 'Baseline';

  @override
  String get typeColumns => 'Columns';

  @override
  String get typeHighLow => 'High-low';

  @override
  String get typeHeikinAshi => 'Heikin Ashi';

  @override
  String get heikinAshiHint => 'Heikin Ashi is derived; quotes and details use source prices';

  @override
  String get priceScale => 'Price scale';

  @override
  String get scaleRegular => 'Regular';

  @override
  String get scaleLogarithmic => 'Logarithmic';

  @override
  String get scalePercentage => 'Percentage';

  @override
  String get scaleIndexed => 'Indexed to 100';

  @override
  String get relativeScaleHint => 'Based on the first visible bar’s open';

  @override
  String get loadingHistory => 'Loading history…';

  @override
  String get historyEnd => 'No earlier history';

  @override
  String get indicatorParameters => 'Indicator parameters';

  @override
  String get period => 'Period';

  @override
  String get period1 => 'Period 1';

  @override
  String get period2 => 'Period 2';

  @override
  String get period3 => 'Period 3';

  @override
  String get period4 => 'Period 4';

  @override
  String get deviations => 'Standard deviations';

  @override
  String get fastPeriod => 'Fast period';

  @override
  String get slowPeriod => 'Slow period';

  @override
  String get signalPeriod => 'Signal period';

  @override
  String get smoothK => 'K smoothing';

  @override
  String get smoothD => 'D smoothing';

  @override
  String get invalidChartParameter => 'Enter a valid value in range';

  @override
  String get invalidMacdPeriods => 'Fast period must be smaller than slow period';

  @override
  String get resetDefaults => 'Reset defaults';

  @override
  String get apply => 'Apply';

  @override
  String get mainIndicators => 'Main overlays';

  @override
  String get secondaryIndicators => 'Lower indicator';

  @override
  String get volumeBars => 'Volume';

  @override
  String get indicatorHint =>
      'Overlays share the price pane. Show one lower indicator at a time, switch or hide it whenever you need.';

  @override
  String get exitFullscreen => 'Exit fullscreen';

  @override
  String get marketDetails => 'Market details';

  @override
  String get depth => 'Depth';

  @override
  String get candles => 'Candles';

  @override
  String get lineChart => 'Line';

  @override
  String get sync => 'Market cache';

  @override
  String get syncing => 'History loading / gap repair';

  @override
  String get closedCandle => 'Closed';

  @override
  String get formingCandle => 'Forming';

  @override
  String get eventTime => 'Event time';

  @override
  String get startTime => 'Candle start';

  @override
  String get chartSource => 'Aster Perpetuals · USDT';

  @override
  String get chartSourceShort => 'Aster · USDT';

  @override
  String get marketSource => 'Aster Perpetuals';

  @override
  String get poweredBy => 'VANTA  /  POWERED BY ASTER';

  @override
  String get gap => 'Candle gap detected. Backfilling';

  @override
  String get connect => 'Connect wallet';

  @override
  String get loginTitle => 'Sign in to Vanta';

  @override
  String get loginDescription =>
      'Connect an existing EOA wallet, or sign in with an email code to use a Privy wallet.';

  @override
  String get emailAddress => 'Email address';

  @override
  String get sendCode => 'Send verification code';

  @override
  String get verificationCode => '6-digit verification code';

  @override
  String get verifyAndLogin => 'Verify and sign in';

  @override
  String get resendCode => 'Resend code';

  @override
  String get changeEmail => 'Change email';

  @override
  String get logout => 'Log out';

  @override
  String get copyAddress => 'Copy wallet address';

  @override
  String get createWallet => 'Create embedded wallet';

  @override
  String get tradingNotEnabled =>
      'Wallet signed in. Use the separate live-order entry to review a real order; Aster authorization is required.';

  @override
  String get loginInProgress => 'Processing sign-in…';

  @override
  String get walletInProgress => 'Processing wallet session…';

  @override
  String get demoAccountHint =>
      'Try trading with separate local demo funds. Your Privy wallet is unaffected.';

  @override
  String get authConfiguration =>
      'Privy sign-in is not configured in this build. Contact the app provider.';

  @override
  String get authInvalidEmail => 'Enter a valid email address.';

  @override
  String get authInvalidCode => 'The code is invalid or expired. Check it or request a new code.';

  @override
  String get authNetwork => 'Sign-in connection failed. Check your network and retry.';

  @override
  String get authRateLimited => 'Too many requests. Try again shortly.';

  @override
  String get authSessionUnavailable => 'Your session has expired. Sign in again.';

  @override
  String get authUnavailable => 'Sign-in is unavailable. Please retry.';

  @override
  String get demo => 'Demo account';

  @override
  String get perpetual => 'Perpetual';

  @override
  String get perps => 'Perps';

  @override
  String get markets => 'Markets';

  @override
  String get portfolio => 'Portfolio';

  @override
  String get points => 'Points';

  @override
  String get trade => 'Trade';

  @override
  String get chart => 'Chart';

  @override
  String get data => 'Data';

  @override
  String get change => '24h change';

  @override
  String get volume => '24h volume';

  @override
  String get high => '24h high';

  @override
  String get low => '24h low';

  @override
  String get mark => 'Mark price';

  @override
  String get index => 'Index price';

  @override
  String get funding => 'Funding / countdown';

  @override
  String get book => 'Order book';

  @override
  String get trades => 'Recent trades';

  @override
  String get price => 'Price';

  @override
  String get quantity => 'Quantity';

  @override
  String get total => 'Total';

  @override
  String get time => 'Time';

  @override
  String get buy => 'Buy / Long';

  @override
  String get sell => 'Sell / Short';

  @override
  String get long => 'Long';

  @override
  String get short => 'Short';

  @override
  String get cross => 'Cross';

  @override
  String get leverage => 'Leverage';

  @override
  String get leverageHint => 'Higher leverage increases the risk from price movements.';

  @override
  String get limit => 'Limit';

  @override
  String get market => 'Market';

  @override
  String get available => 'Available';

  @override
  String get marketPrice => 'Execute at current market price';

  @override
  String get orderValue => 'Order value';

  @override
  String get margin => 'Required margin';

  @override
  String get tradeEstimatedLiquidation => 'Est. Liq. Price';

  @override
  String get tradeMargin => 'Margin';

  @override
  String get fees => 'Estimated fee';

  @override
  String get reduceOnly => 'Reduce only';

  @override
  String get positions => 'Positions';

  @override
  String get orders => 'Open orders';

  @override
  String get history => 'History';

  @override
  String get pnl => 'Unrealized PnL';

  @override
  String get noPositions => 'No open positions';

  @override
  String get noPositionsHint => 'Your next opportunity starts with your first trade.';

  @override
  String get noOrders => 'No open orders';

  @override
  String get noHistory => 'No trade history';

  @override
  String get walletTitle => 'Your gateway to trading';

  @override
  String get walletHint =>
      'Explore local demo trading or use the separate live-order entry with your wallet. Fund transfers are not enabled.';

  @override
  String get enterDemo => 'Try demo account';

  @override
  String get demoBalance => '10,000 USDT demo funds · No real execution';

  @override
  String get demoActive => 'Local demo · No real execution';

  @override
  String get review => 'Review order';

  @override
  String get confirm => 'Confirm demo order';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get entry => 'Entry price';

  @override
  String get size => 'Position size';

  @override
  String get invalidQuantity => 'Enter a positive quantity aligned to the market quantity step.';

  @override
  String get invalidPrice => 'Enter a positive price aligned to the market price tick.';

  @override
  String get insufficient => 'Insufficient margin. Reduce quantity or adjust leverage.';

  @override
  String get reduceHint =>
      'Reduce only requires a sufficient opposite position in the same market.';

  @override
  String get submitted => 'Demo order submitted';

  @override
  String get closed => 'Demo position closed';

  @override
  String get canceled => 'Demo order canceled';

  @override
  String get filled => 'Filled';

  @override
  String get pending => 'Pending';

  @override
  String get canceledStatus => 'Canceled';

  @override
  String get offline => 'History · reconnecting';

  @override
  String get live => 'Live market';

  @override
  String get retry => 'Reconnect';

  @override
  String get statusLoadFailedTitle => 'Unable to Load';

  @override
  String get statusLoadFailedMessage => 'Something went wrong. Please try again.';

  @override
  String get statusRetry => 'Retry';

  @override
  String get statusEmptyTitle => 'No Data Yet';

  @override
  String get statusEmptyMessage => 'There\'s nothing to display here right now.';

  @override
  String get statusNoResultsTitle => 'No results found';

  @override
  String get statusNoResultsMessage => 'Try searching with another term.';

  @override
  String get statusNoAssetsTitle => 'No Assets Yet';

  @override
  String get statusNoAssetsMessage => 'Deposit funds to get started with trading.';

  @override
  String get snapshotHint => 'Realtime disconnected. Showing recent history.';

  @override
  String get marketUnavailable => 'Market unavailable. Please retry.';

  @override
  String get search => 'Search markets';

  @override
  String get selectMarket => 'Select market';

  @override
  String get favorites => 'Favorites';

  @override
  String get allMarkets => 'All perpetuals';

  @override
  String get lastPrice => 'Last price';

  @override
  String get fundingRate => 'Funding rate';

  @override
  String get volume24h => '24h volume';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get emptyFavorites => 'No favorite markets yet';

  @override
  String get noMarketsFound => 'No matching markets';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get equity => 'Total equity';

  @override
  String get usedMargin => 'Used margin';

  @override
  String get overview => 'Account overview';

  @override
  String get portfolioHint => 'Connect your account to start trading.';

  @override
  String get pointsTitle => 'Every trade takes you further.';

  @override
  String get pointsHint =>
      'Vanta Genesis rewards live trading and ecosystem participation. Demo trades do not earn points.';

  @override
  String get yourPoints => 'Your Genesis points';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get aiTitle => 'A little insight for your next move.';

  @override
  String get aiHint =>
      'Market analysis is planned for a future version. Explore live prices, charts and the order book on the trading page.';

  @override
  String get backToTrade => 'Explore the market';

  @override
  String get language => 'Language';

  @override
  String get settings => 'Settings';

  @override
  String get indicators => 'Indicators';

  @override
  String get none => 'None';

  @override
  String get fullscreen => 'Expand chart';

  @override
  String get chartHint => 'Hold for details · Pinch to zoom';

  @override
  String get network => 'Market connection';

  @override
  String get demoReset => 'Leave demo account';

  @override
  String get demoExitHint => 'Leaving clears this session’s local demo positions and orders.';

  @override
  String get minOrder => 'Minimum size';

  @override
  String get feeHint => 'Demo fee of 0.05%, for simulation only.';

  @override
  String get orderReviewHint => 'This local demo order will not be sent to the exchange.';

  @override
  String get refresh => 'Refresh market';

  @override
  String get account => 'Account';

  @override
  String get bookWaiting => 'Connecting to order book…';

  @override
  String get bookError => 'Order book disconnected. Reconnecting.';

  @override
  String get noTrades => 'Waiting for recent trades…';

  @override
  String get spot => 'Spot';

  @override
  String get open => 'O';

  @override
  String get candleHigh => 'H';

  @override
  String get candleLow => 'L';

  @override
  String get candleClose => 'C';

  @override
  String get orderId => 'Order ID';

  @override
  String get tapPrice => 'Tap a book price to fill your order';

  @override
  String get followSystem => 'Follow system';

  @override
  String get languageSaveFailed => 'Language could not be saved. Please retry.';

  @override
  String get saveLanguage => 'Save language';

  @override
  String get midPrice => 'Mid';

  @override
  String resendCountdown(int seconds) {
    return 'Resend code (${seconds}s)';
  }

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get asterAccountTitle => 'Aster perpetual account';

  @override
  String get asterAccountTab => 'Aster account';

  @override
  String get asterAccountScope =>
      'Account data belongs to the wallet below. An authorized device signing key signs queries automatically.';

  @override
  String get asterUsdtSummary => 'USDT account summary';

  @override
  String get asterMarginBalance => 'Margin balance';

  @override
  String get asterUsdtScope =>
      'USDT only. Other assets retain their own units below; this is not the total value of Spot, staking, vaults, or sub-accounts.';

  @override
  String accountSnapshotTime(String time) {
    return 'Snapshot received: $time';
  }

  @override
  String get accountSnapshotStale =>
      'Previous snapshot. Sign to refresh before relying on these values.';

  @override
  String get accountSignInToRead => 'Sign in to view account';

  @override
  String get accountReadWithWallet => 'Read Aster account';

  @override
  String get accountRefreshWithWallet => 'Refresh account';

  @override
  String get accountReadPreparing => 'Preparing account request…';

  @override
  String get accountReadSigning => 'Signing the account query…';

  @override
  String get accountReadLoading => 'Reading account data from Aster…';

  @override
  String get accountReadNotice =>
      'Read-only account query using the authorized device signing key. No order, transfer, or additional authorization is submitted. Data belongs to the selected account.';

  @override
  String accountErrorCode(int code) {
    return 'Aster error code: $code';
  }

  @override
  String get accountAssetBalances => 'Perpetual asset balances';

  @override
  String get accountSearchAsset => 'Search assets';

  @override
  String get accountHideZero => 'Hide zero balances';

  @override
  String get accountNoAssets => 'No asset balances returned for this account.';

  @override
  String get accountNoMatchingAssets => 'No assets match the current filters.';

  @override
  String get accountCollateralEligible => 'Eligible as collateral in Multi-Assets mode';

  @override
  String get accountCollateralIneligible => 'Not eligible as collateral in Multi-Assets mode';

  @override
  String get accountLivePositions => 'Aster positions';

  @override
  String get accountNoPositions => 'No open perpetual positions.';

  @override
  String get accountPositionMargin => 'Position initial margin';

  @override
  String get accountWalletBalance => 'Wallet balance';

  @override
  String get accountUnrealizedPnl => 'Unrealized PnL';

  @override
  String get accountPositionDirection => 'Direction';

  @override
  String get accountMarginMode => 'Margin mode';

  @override
  String get accountDataInvalid =>
      'Aster returned incomplete or invalid account data. Retry to refresh.';

  @override
  String get accountRateLimited => 'Aster has limited account requests. Wait before trying again.';

  @override
  String get accountNetwork => 'Account data could not be read. Check your connection and retry.';

  @override
  String get accountReadFailed =>
      'Aster could not complete the account query. Retry or check the account permissions.';

  @override
  String get accountSignatureExpired =>
      'The account signature expired. Retry and confirm the new wallet request promptly.';

  @override
  String get accountSignatureRejected =>
      'Aster rejected the account signature. Check your wallet and account authorization.';

  @override
  String get accountPermissionRequired =>
      'Aster has not accepted this wallet’s account access. Check its Aster API authorization; signing in to Vanta does not grant it.';

  @override
  String get accountUnitUnavailable => '(unit unavailable)';

  @override
  String get accountIsolatedMode => 'Isolated';

  @override
  String get marketCategoryTop => 'Top';

  @override
  String get marketCategoryRwa => 'USD1-RWA';

  @override
  String get marketCategoryMeme => 'Meme';

  @override
  String get marketCategoryAi => 'AI';

  @override
  String get marketCategoryPreLaunch => 'Pre-launch';

  @override
  String get marketCategoryStocks => 'Stocks';

  @override
  String get marketCategoryEtf => 'ETF';

  @override
  String get marketCategoryCommodities => 'Commodities';

  @override
  String get marketCategorySemiconductors => 'Semiconductors';

  @override
  String get marketNoCategoryResults => 'No contracts in this category match your filters.';

  @override
  String marketResultsCount(int shown, int total) {
    return '$shown of $total perpetuals';
  }

  @override
  String get marketCategories => 'Market categories';

  @override
  String get marketCategoryAll => 'All categories';

  @override
  String get accountPerpetualTab => 'Perpetual';

  @override
  String get accountSpotTab => 'Spot';

  @override
  String get spotAccountTitle => 'Aster spot account';

  @override
  String get spotBalanceScope =>
      'Balances are asset quantities. Total = available + locked. Spot and perpetual balances are shown separately.';

  @override
  String get spotAssetBalances => 'Spot asset balances';

  @override
  String get spotNoAssets => 'No assets in this spot account.';

  @override
  String get spotTotalBalance => 'Total balance';

  @override
  String get spotLockedBalance => 'Locked balance';

  @override
  String get asterOpenOrdersTitle => 'Aster open perpetual orders';

  @override
  String get asterOpenOrdersScope =>
      'Live-account futures orders, separate from the demo orders above. Reading and cancellation require wallet signatures and Aster authorization.';

  @override
  String get openOrdersReadWithWallet => 'Sign to read open orders';

  @override
  String get openOrdersRefreshWithWallet => 'Sign to refresh open orders';

  @override
  String get openOrdersCurrentSymbol => 'Hide other symbols';

  @override
  String openOrdersCount(int count) {
    return 'Open orders ($count)';
  }

  @override
  String get openOrdersEmpty => 'No open perpetual orders in this account.';

  @override
  String get openOrdersNoCurrentSymbol => 'No open orders for the current symbol.';

  @override
  String get openOrdersBuy => 'Buy';

  @override
  String get openOrdersSell => 'Sell';

  @override
  String get openOrdersLongSide => 'Long side';

  @override
  String get openOrdersShortSide => 'Short side';

  @override
  String get openOrdersOneWay => 'One-way';

  @override
  String get openOrdersOrderType => 'Order type';

  @override
  String get openOrdersStatus => 'Status';

  @override
  String get openOrdersNew => 'New';

  @override
  String get openOrdersPartiallyFilled => 'Partially filled';

  @override
  String get openOrdersCreatedLocal => 'Placed (local time)';

  @override
  String get openOrdersFilledTotal => 'Filled / total';

  @override
  String get openOrdersRemaining => 'Remaining';

  @override
  String get openOrdersClosePosition => 'Close entire position';

  @override
  String get openOrdersOrderPrice => 'Order price';

  @override
  String get openOrdersOrderValue => 'Order value';

  @override
  String get openOrdersActivationPrice => 'Activation price';

  @override
  String get openOrdersCallbackRate => 'Callback rate';

  @override
  String get openOrdersTriggerPrice => 'Trigger price';

  @override
  String get openOrdersMarkPrice => 'Mark';

  @override
  String get openOrdersLastPrice => 'Last';

  @override
  String get openOrdersUnknownTrigger => 'Trigger basis unavailable';

  @override
  String get openOrdersReduceOnly => 'Reduce only';

  @override
  String get openOrdersHidden => 'Hidden';

  @override
  String get openOrdersLimit => 'Limit';

  @override
  String get openOrdersMarket => 'Market';

  @override
  String get openOrdersStopLimit => 'Stop limit';

  @override
  String get openOrdersStopMarket => 'Stop market';

  @override
  String get openOrdersTakeProfitLimit => 'Take-profit limit';

  @override
  String get openOrdersTakeProfitMarket => 'Take-profit market';

  @override
  String get openOrdersTrailingStop => 'Trailing stop';

  @override
  String get openOrdersOtherType => 'Other order type';

  @override
  String get openOrdersBbo => 'BBO peg';

  @override
  String get accountDepositRequired =>
      'Aster requires the main wallet linked to this account to complete a deposit before V3 private account or order queries can be used.';

  @override
  String get orderCancelTitle => 'Cancel order';

  @override
  String get orderCancelKeep => 'Keep order';

  @override
  String get orderCancelConfirm => 'Sign cancellation';

  @override
  String get orderCancelConfirmHint =>
      'Cancel only the unfilled remainder of this perpetual order. Filled positions remain. Your current wallet will sign the cancellation, then a separate status query. Aster authorization is required.';

  @override
  String get orderCancelSigning => 'Confirm the cancellation signature in your wallet.';

  @override
  String get orderCancelSubmitting => 'Submitting cancellation. The outcome is not confirmed yet.';

  @override
  String get orderCancelChecking => 'Checking the final order status.';

  @override
  String get orderCancelCheckSigning =>
      'Sign the status query in your wallet to verify the cancellation outcome.';

  @override
  String get orderCancelUnknown =>
      'Cancellation outcome is unconfirmed. The order is retained until its status is verified. Check status before sending another cancellation.';

  @override
  String get orderCancelRecheck => 'Sign and check status';

  @override
  String get orderCancelVerified =>
      'Aster confirmed this order is cancelled. Any filled position remains; account balances need refreshing.';

  @override
  String get orderCancelFilled =>
      'Aster reports this order is fully filled. It was not cancelled. Refresh positions and balances.';

  @override
  String get orderCancelExpired =>
      'Aster reports this order has expired. Refresh positions and balances.';

  @override
  String get orderCancelRejected =>
      'Aster reports this order was rejected. Refresh positions and balances.';

  @override
  String get orderCancelStillOpen =>
      'Aster reports this order is still open. Review its current filled amount before retrying.';

  @override
  String get batchCancelAll => 'Cancel all listed orders';

  @override
  String get batchCancelCurrent => 'Cancel all current-symbol orders';

  @override
  String get batchCancelTitle => 'Cancel all perpetual orders?';

  @override
  String get batchCancelHint =>
      'Cancel all orders on the listed futures symbols when Aster processes each request, including orders added on other devices. Other symbols and Spot orders are outside this scope. Each symbol requires cancellation and status-query signatures. Filled positions remain.';

  @override
  String batchCancelScopeCount(int orders, int symbols) {
    String _temp0 = intl.Intl.pluralLogic(
      orders,
      locale: localeName,
      other: '$orders orders',
      one: '1 order',
    );
    String _temp1 = intl.Intl.pluralLogic(
      symbols,
      locale: localeName,
      other: '$symbols symbols',
      one: '1 symbol',
    );
    return 'Snapshot: $_temp0 across $_temp1';
  }

  @override
  String get batchCancelConfirm => 'Sign and cancel by symbol';

  @override
  String get batchCancelNotSubmitted => 'Not submitted';

  @override
  String get batchCancelUnknown => 'Outcome unconfirmed. Check status before retrying.';

  @override
  String get batchCancelNoOpen => 'No open orders at last check';

  @override
  String batchCancelRemaining(int count) {
    return '$count open orders remain';
  }

  @override
  String get batchCancelRecheck => 'Sign and check unconfirmed symbols';

  @override
  String get batchCancelStop => 'Stop further submissions';

  @override
  String get batchCancelStopped => 'Further submissions stopped. Check each symbol’s result.';

  @override
  String get batchCancelReadFirst => 'Read your live open orders before cancelling all.';

  @override
  String get batchCancelInProgress => 'Processing; outcome not yet verified';

  @override
  String get historyTitle => 'Spot history';

  @override
  String get historyOrders => 'Order history';

  @override
  String get historyTrades => 'Trade history';

  @override
  String get historyTransactions => 'Transaction history';

  @override
  String get historyScope =>
      'History for the selected Spot wallet. Orders, individual fills and balance changes are separate records.';

  @override
  String get historySymbolFilter => 'Spot symbol (optional)';

  @override
  String get historyAssetFilter => 'Asset (optional)';

  @override
  String get historyFilterHint =>
      'Use the exact identifier; leave empty for all. Editing filters clears the previous results without signing.';

  @override
  String get historyWindowLabel => 'Query window (UTC)';

  @override
  String get historyDay => 'Last 24 hours';

  @override
  String get historyWeek => 'Last 7 days';

  @override
  String get historyCustom => 'Choose dates';

  @override
  String get historyRead => 'Sign and read selected range';

  @override
  String get historyRefresh => 'Sign and reread selected range';

  @override
  String get historyContinue => 'Sign and check next time window';

  @override
  String get historyPartial =>
      'The selected range is not fully checked. Each request covers at most seven days and 1,000 rows. Continue signing to read the remaining time windows.';

  @override
  String get historyTruncated =>
      'At least one millisecond reached the API row limit. These results are incomplete; narrow the symbol or asset filter.';

  @override
  String get historyComplete => 'Selected time range checked within the API’s retention limits.';

  @override
  String get historyEmpty => 'No records were returned for the selected range and filters.';

  @override
  String get historyRetention =>
      'The Spot orders API does not return orders created more than seven days ago.';

  @override
  String get historyNotAtomic =>
      'Results may change between reads. Continuing checks preserves the first response time and merges records by their identifiers.';

  @override
  String get historyInvalidScope =>
      'Enter an exact symbol or asset identifier of up to 50 letters, digits, dots, underscores or hyphens.';

  @override
  String get historyInvalidWindow =>
      'Select a valid date range. Order history is limited to seven days.';

  @override
  String historyLoaded(int count) {
    return 'Loaded records: $count';
  }

  @override
  String historyPage(int page, int pages) {
    return 'Page $page of $pages loaded pages';
  }

  @override
  String get historyPrev => 'Previous';

  @override
  String get historyNext => 'Next';

  @override
  String get historyCreatedUTC => 'Created (UTC)';

  @override
  String get historyUpdatedUTC => 'Updated (UTC)';

  @override
  String get historyExecutionUTC => 'Executed (UTC)';

  @override
  String get historyEventUTC => 'Time (UTC)';

  @override
  String get historyAveragePrice => 'Average fill price';

  @override
  String get historyExecutedQuote => 'Filled quote amount';

  @override
  String get historyTradeId => 'Trade ID';

  @override
  String get historyTransactionId => 'Transaction reference';

  @override
  String get historyCommission => 'Commission / rebate';

  @override
  String get historyLiquidity => 'Liquidity role';

  @override
  String get historyMaker => 'Maker';

  @override
  String get historyTaker => 'Taker';

  @override
  String get historyBalanceChange => 'Balance change';

  @override
  String get historyTransactionType => 'Transaction type';

  @override
  String historyUnknownCode(String code) {
    return 'Other ($code)';
  }

  @override
  String get historyFilled => 'Filled';

  @override
  String get historyCanceled => 'Cancelled';

  @override
  String get historyExpired => 'Expired';

  @override
  String get historyRejected => 'Rejected';

  @override
  String get historyPendingCancel => 'Pending cancellation';

  @override
  String get historyDeposit => 'Deposit';

  @override
  String get historyWithdraw => 'Withdrawal';

  @override
  String get historyTransfer => 'Transfer';

  @override
  String get historyTradeSource => 'Trade debit';

  @override
  String get historyTradeTarget => 'Trade credit';

  @override
  String get historyAirdrop => 'Airdrop';

  @override
  String get historyDividend => 'Dividend';

  @override
  String get historySwap => 'Swap';

  @override
  String get historyRebate => 'Commission rebate';

  @override
  String get historyTradeQuantity => 'Filled quantity';

  @override
  String get historyStop => 'Stop waiting';

  @override
  String get historyReadStopped => 'This read was stopped. You can try again.';

  @override
  String get positionRiskTitle => 'Position risk';

  @override
  String get positionRiskScope =>
      'Read positions for the connected wallet. A signed snapshot is the baseline; enabled account monitoring can update individual positions. Public mark prices update estimates separately. Read account balances separately. Closing requires its own confirmation and signatures; TP/SL is not available yet.';

  @override
  String get positionRiskRead => 'Sign to read position risk';

  @override
  String get positionRiskRefresh => 'Sign to refresh position risk';

  @override
  String positionRiskCount(int count) {
    return 'Position records ($count)';
  }

  @override
  String get positionRiskNoCurrent => 'No position records for the selected symbol.';

  @override
  String get positionRiskBalanceOnly => 'Negative isolated balance';

  @override
  String get positionRiskSide => 'Position side';

  @override
  String get positionRiskNotional => 'Signed notional';

  @override
  String get positionRiskLiquidation => 'Liquidation price';

  @override
  String get positionRiskIsolatedWallet => 'Isolated wallet balance';

  @override
  String get positionRiskIsolatedMargin => 'Isolated margin';

  @override
  String get positionRiskUpdated => 'Position update (UTC)';

  @override
  String get positionRiskLiquidationHint =>
      'A missing or zero liquidation price is shown as —. This does not mean the position is free of liquidation risk.';

  @override
  String get positionRiskBalanceHint =>
      'The position quantity is zero, but its isolated wallet balance is negative. This record remains visible for review.';

  @override
  String get positionAdlTitle => 'ADL queue';

  @override
  String get positionAdlScope =>
      'Read ADL separately with your wallet. Levels range from 0 to 4, low to high, and the exchange updates them every 30 seconds. Four lit bars indicate the highest queue level. This is not a margin ratio or a liquidation countdown. Refresh positions and ADL to review matching snapshots.';

  @override
  String get positionAdlRead => 'Sign to read ADL';

  @override
  String get positionAdlRefresh => 'Sign to refresh ADL';

  @override
  String get positionAdlUnknown => 'Unknown — read or refresh matching ADL data';

  @override
  String get positionAdlNotApplicable => 'Not applicable to a zero-quantity balance record';

  @override
  String positionAdlLevel(int level) {
    return 'Level $level / 4';
  }

  @override
  String positionAdlHistorical(int level) {
    return 'Historical level $level / 4 — refresh';
  }

  @override
  String get positionAdlEmpty => 'No ADL records returned. Missing positions remain unknown.';

  @override
  String get positionMarkReadFirst => 'Read positions to start public mark prices.';

  @override
  String get positionMarkScope =>
      'Estimates use the displayed position quantity and entry price with public mark prices. Fees and funding are excluded. Prices expire after 10 seconds; refreshing prices does not verify the complete position list, margin or liquidation prices.';

  @override
  String positionMarkCoverage(int fresh, int total) {
    return 'Fresh mark prices: $fresh / $total symbols';
  }

  @override
  String get positionMarkSnapshot => 'Snapshot mark price';

  @override
  String get positionMarkCurrent => 'Current mark price';

  @override
  String get positionMarkHistorical => 'Historical mark price';

  @override
  String get positionMarkTime => 'Mark event (UTC)';

  @override
  String get positionEstimatedNotional => 'Estimated signed notional';

  @override
  String get positionEstimatedPnl => 'Estimated unrealized PnL';

  @override
  String get positionEstimateStale =>
      'Historical estimate: positions or mark prices need refreshing.';

  @override
  String get positionSnapshotNotional => 'Snapshot signed notional';

  @override
  String get positionSnapshotPnl => 'Snapshot unrealized PnL';

  @override
  String get positionMarkUnavailable =>
      'Some mark prices are unavailable or stale. Retained values are historical.';

  @override
  String get positionMarkRetry => 'Retry public mark prices';

  @override
  String get accountChangeTitle => 'Futures change monitor';

  @override
  String get accountChangeScope =>
      'Wallet-signed monitoring for this futures account. Validated events update individual orders, wallet balances and position quantities after a complete signed read. Events do not prove complete lists or recover missed updates. Totals, available funds, leverage, liquidation prices and ADL need signed verification; Spot needs a separate read. Starting or renewing needs one signature, with no automatic wallet prompts. The lease lasts up to 60 minutes. Stopping closes this device’s connection only.';

  @override
  String get accountChangeStopped => 'Not monitoring';

  @override
  String get accountChangeConnecting => 'Connecting change monitor…';

  @override
  String get accountChangeConnected =>
      'Change monitor connected · snapshots still need verification';

  @override
  String get accountChangeDisconnected => 'Disconnected · changes may have been missed';

  @override
  String get accountChangePaused => 'Paused in background · verify snapshots on return';

  @override
  String get accountChangeExpired => 'Monitoring expired · sign again to continue';

  @override
  String get accountChangeStart => 'Sign to start monitoring';

  @override
  String get accountChangeRenew => 'Sign to renew monitoring';

  @override
  String get accountChangeReconnect => 'Reconnect without signing';

  @override
  String get accountChangeStop => 'Stop monitoring on this device';

  @override
  String get accountChangeRenewalDue =>
      'Monitoring expires soon. Renew manually with your wallet to continue.';

  @override
  String accountChangeExpiry(String time) {
    return 'Local monitoring deadline: $time';
  }

  @override
  String accountChangeLastEvent(String time) {
    return 'Latest event time: $time. Read snapshots again to verify.';
  }

  @override
  String get openOrdersCreationUnknown => 'Unknown · read orders to verify';

  @override
  String get openOrdersUpdatedUTC => 'Order updated (UTC)';

  @override
  String openOrdersEventTime(String time) {
    return 'Latest applied order event (UTC): $time';
  }

  @override
  String get openOrdersEventScope =>
      'Validated order events update this list, including partial fills and final removals. The REST timestamp remains the last complete read. Reconnect or missing events can leave the list incomplete; refresh with your wallet to verify.';

  @override
  String get orderEventsCapacity =>
      'Order event history is full. Sign out and reconnect your wallet, then read orders again to verify.';

  @override
  String get orderCancelEventsDuringCheck =>
      'Order events arrived during verification. The query may reflect an earlier state; review the updated order list before any further action.';

  @override
  String get accountEventsCapacity =>
      'Account event history is full. Sign out and reconnect your wallet, then read balances and positions again to verify.';

  @override
  String accountEventTime(String time) {
    return 'Last applied account event: $time UTC';
  }

  @override
  String get accountEventScope =>
      'Individual records include event updates. Totals and fields missing from events show — until a signed read. Unchanged rows may be historical. Missing rows do not mean closed positions; verify complete lists after interruptions.';

  @override
  String get accountEventRowTime => 'Record event time (UTC)';

  @override
  String get accountCrossWalletBalance => 'Cross wallet balance';

  @override
  String get positionEventPnl => 'Event unrealized PnL';

  @override
  String get positionEventFieldsHint =>
      'Leverage, liquidation price, mark, notional and isolated margin are not provided by this event. Read positions to verify. Public mark estimates use the displayed quantity and entry price; they do not confirm the complete account.';

  @override
  String get positionAllocatedMargin => 'Allocated isolated wallet';

  @override
  String get positionEstimatedCrossMargin => 'Estimated cross position margin';

  @override
  String get positionEstimatedInitialMargin => 'Estimated initial margin basis';

  @override
  String get positionEstimatedRoe => 'Estimated ROE (%)';

  @override
  String get positionSnapshotRoe => 'Snapshot ROE estimate (%)';

  @override
  String get positionReturnScope =>
      'Linear contracts: initial margin basis = absolute quantity × mark price ÷ leverage; ROE = unrealized PnL ÷ that basis × 100. Isolated margin allocation uses its wallet balance, not the ROE basis. These estimates exclude fees and funding, are not account returns or available funds, and remain historical when position data or prices are stale. Unknown leverage or units shows —.';

  @override
  String get leverageSettings => 'Futures leverage';

  @override
  String get leverageSettingsScope =>
      'Set initial leverage for this symbol. In hedge mode both directions share the setting. Changing leverage affects margin requirements and risk.';

  @override
  String get leverageReadSettings => 'Read leverage settings (2 signatures)';

  @override
  String get leverageSettingsReadHint =>
      'Sign to read the leverage limits and symbol configuration. No change is submitted by reading.';

  @override
  String get leverageCurrentSetting => 'Leverage at last read';

  @override
  String get leverageTarget => 'Target leverage';

  @override
  String leverageInputHint(int maximum) {
    return 'Enter a different whole number from 1 to $maximum. Exposure may impose a lower limit; Aster validates the request.';
  }

  @override
  String get leverageContextExpired =>
      'Settings require a fresh read before changing leverage. Your input is preserved.';

  @override
  String get leverageInvalidTarget =>
      'Enter a different whole-number leverage within the displayed limit.';

  @override
  String get leverageReviewChange => 'Review leverage change';

  @override
  String get leverageConfirmTitle => 'Change futures leverage?';

  @override
  String get leverageConfirmHint =>
      'This changes the selected wallet’s leverage for the symbol below, including both hedge directions. Sign once to submit and again to query the result. Higher leverage increases risk.';

  @override
  String leverageRequestedChange(int previous, int target) {
    return '$previous× → $target×';
  }

  @override
  String get leverageSignChange => 'Sign leverage change';

  @override
  String get leverageSubmitting => 'Submitting leverage change…';

  @override
  String get leverageCheckSigning => 'Sign to verify leverage';

  @override
  String get leverageChecking => 'Querying leverage…';

  @override
  String leverageVerified(int value) {
    return 'Query verified the requested leverage: $value×.';
  }

  @override
  String leverageObservedDifferent(int observed, int target) {
    return 'Query shows $observed×; requested $target×. Refresh settings before reviewing another change.';
  }

  @override
  String get leverageOutcomeUnknown =>
      'The request may have reached Aster; the result is unverified. Query again to check the setting. No change is resubmitted by querying.';

  @override
  String get leverageRecheck => 'Sign to query result';

  @override
  String get leverageResultScope =>
      'This is a query snapshot. Read positions and balances again to verify margin and risk fields.';

  @override
  String get leverageExposureLimit =>
      'The position exceeds the maximum allowed at this leverage. Choose a lower leverage and refresh settings.';

  @override
  String get leverageMarginInsufficient =>
      'Insufficient margin for this leverage. Refresh balances and settings before trying again.';

  @override
  String get leverageNotAllowed =>
      'Aster rejected this leverage. Refresh the symbol limits and current setting.';

  @override
  String get marginModeSettings => 'Futures margin mode';

  @override
  String get marginModeSettingsScope =>
      'Choose cross or isolated margin for this symbol. Both hedge directions share the setting. This changes real account configuration and margin risk.';

  @override
  String get marginModeCrossHint =>
      'Cross margin shares eligible account collateral across cross positions.';

  @override
  String get marginModeIsolatedHint =>
      'Isolated margin allocates collateral to each position. Changing mode does not switch single / multi-asset or one-way / hedge position mode.';

  @override
  String get marginModeReadSettings => 'Read mode and open orders (2 signatures)';

  @override
  String get marginModeReadHint =>
      'Sign to read this symbol’s configuration and open orders. Reading submits no changes. Settings expire after 30 seconds, including time spent on the second signature.';

  @override
  String get marginModeCurrentSetting => 'Margin mode at last read';

  @override
  String get marginModeTarget => 'Target margin mode';

  @override
  String get marginModeContextExpired =>
      'Refresh mode and open orders before reviewing a change. Your selection is preserved.';

  @override
  String get marginModeChangeBlocked =>
      'Choose a different mode. Close positions and cancel open orders before switching.';

  @override
  String get marginModeHasPosition =>
      'This symbol has a position. Close it and refresh settings before switching margin mode.';

  @override
  String get marginModeOpenOrders =>
      'This symbol has open orders. Cancel them and refresh settings before switching margin mode.';

  @override
  String get marginModeAlreadySet =>
      'Aster reports that this mode is already set. The signed query below shows the observed mode.';

  @override
  String get marginModeConfirmTitle => 'Change futures margin mode?';

  @override
  String get marginModeConfirmHint =>
      'This changes the selected wallet’s configuration for the symbol below, including both hedge directions. Sign once to submit, then again to query the result. Aster validates positions, open orders and asset-mode restrictions.';

  @override
  String get marginModeSignChange => 'Sign margin mode change';

  @override
  String get marginModeReviewChange => 'Review mode change';

  @override
  String get marginModeSubmitting => 'Submitting margin mode change…';

  @override
  String get marginModeCheckSigning => 'Sign to verify margin mode';

  @override
  String get marginModeChecking => 'Querying margin mode…';

  @override
  String marginModeVerified(String mode) {
    return 'Query verified the requested mode: $mode.';
  }

  @override
  String marginModeObservedDifferent(String observed, String target) {
    return 'Query shows $observed; requested $target. Refresh settings before reviewing another change.';
  }

  @override
  String get marginModeOutcomeUnknown =>
      'The request may have reached Aster. Its result is unverified; sign to query again. Querying never resubmits the change.';

  @override
  String get symbolSettingsOtherPending =>
      'Complete the pending futures setting on its settings page before starting another.';

  @override
  String get positionModeSettings => 'Futures position mode';

  @override
  String get positionModeAllSymbols => 'All futures symbols';

  @override
  String get positionModeSettingsScope =>
      'Choose one-way or hedge mode for every futures symbol in this wallet’s account. This changes real account configuration.';

  @override
  String get positionModeOneWay => 'One-way';

  @override
  String get positionModeHedge => 'Hedge';

  @override
  String get positionModeOneWayHint => 'One-way mode keeps a single net position per symbol.';

  @override
  String get positionModeHedgeHint =>
      'Hedge mode separates long and short positions. Positions and open orders across all symbols must be cleared before switching. This action does not close positions, cancel orders or change margin or asset modes.';

  @override
  String get positionModeReadSettings => 'Read mode, positions and orders (3 signatures)';

  @override
  String get positionModeReadHint =>
      'Sign separately to read position mode, all futures positions and all open orders. Reading submits no changes. The 30-second validity starts at the first response and includes the remaining signatures.';

  @override
  String get positionModeCurrentSetting => 'Position mode at last read';

  @override
  String get positionModeTarget => 'Target position mode';

  @override
  String get positionModeContextExpired =>
      'Refresh mode, positions and orders before reviewing a change. Your selection is preserved.';

  @override
  String get positionModeChangeBlocked =>
      'Choose a different mode. Close all futures positions and cancel all open orders before switching.';

  @override
  String get positionModeHasPosition =>
      'This account has futures positions. Close them and refresh settings before switching position mode.';

  @override
  String get positionModeOpenOrders =>
      'This account has futures open orders. Cancel them and refresh settings before switching position mode.';

  @override
  String get positionModeAlreadySet =>
      'Aster reports that this position mode is already set. The signed query below shows the observed mode.';

  @override
  String get positionModeConfirmTitle => 'Change position mode for all futures symbols?';

  @override
  String get positionModeConfirmHint =>
      'This changes position mode for ALL futures symbols in the wallet below. Sign to submit, then sign again to query the result. Aster validates all positions and open orders; this read is not an atomic lock against changes elsewhere.';

  @override
  String get positionModeSignChange => 'Sign position mode change';

  @override
  String get positionModeReviewChange => 'Review mode change';

  @override
  String get positionModeSubmitting => 'Submitting position mode change…';

  @override
  String get positionModeCheckSigning => 'Sign to verify position mode';

  @override
  String get positionModeChecking => 'Querying position mode…';

  @override
  String positionModeVerified(String mode) {
    return 'Query verified the requested position mode: $mode.';
  }

  @override
  String positionModeObservedDifferent(String observed, String target) {
    return 'Query shows $observed; requested $target. Refresh settings before reviewing another change.';
  }

  @override
  String get positionModeOutcomeUnknown =>
      'The request may have reached Aster. Its result is unverified; sign to query again. Querying never resubmits the change.';

  @override
  String get assetModeSettings => 'Futures asset mode';

  @override
  String get assetModeAllSymbols => 'All futures symbols';

  @override
  String get assetModeSettingsScope =>
      'Choose single-asset or multi-assets margin for every futures symbol in this wallet’s account. This changes collateral and margin risk.';

  @override
  String get assetModeSingle => 'Single-asset';

  @override
  String get assetModeMulti => 'Multi-assets';

  @override
  String get assetModeSingleHint => 'Single-asset mode uses each contract’s margin asset.';

  @override
  String get assetModeMultiHint =>
      'Multi-assets mode shares eligible collateral across cross-margin positions. Isolated positions or retained isolated collateral must be handled first. Supported assets, valuations, balance requirements and final eligibility are determined by Aster.';

  @override
  String get assetModeReadSettings => 'Read asset mode and positions (2 signatures)';

  @override
  String get assetModeReadHint =>
      'Sign separately to read asset mode and all futures position configurations. Reading submits no changes. The 30-second validity starts at the first response and includes the second signature.';

  @override
  String get assetModeCurrentSetting => 'Asset mode at last read';

  @override
  String get assetModeTarget => 'Target asset mode';

  @override
  String get assetModeContextExpired =>
      'Refresh asset mode and positions before reviewing a change. Your selection is preserved.';

  @override
  String get assetModeChangeBlocked =>
      'Choose a different asset mode. Resolve isolated positions or collateral before enabling multi-assets mode.';

  @override
  String get assetModeIsolatedBlocker =>
      'These symbols have isolated positions or retained isolated collateral. Review them before enabling multi-assets mode. No margin modes are changed automatically.';

  @override
  String get assetModeConfirmTitle => 'Change asset mode for all futures symbols?';

  @override
  String get assetModeConfirmHint =>
      'This changes collateral and margin risk for ALL futures symbols in the wallet below. Sign to submit, then sign again to query the result. Aster validates balances and restrictions; this read cannot lock changes elsewhere. Position, symbol margin and demo modes are not changed by this request.';

  @override
  String get assetModeSignChange => 'Sign asset mode change';

  @override
  String get assetModeReviewChange => 'Review asset mode change';

  @override
  String get assetModeSubmitting => 'Submitting asset mode change…';

  @override
  String get assetModeCheckSigning => 'Sign to verify asset mode';

  @override
  String get assetModeChecking => 'Querying asset mode…';

  @override
  String assetModeVerified(String mode) {
    return 'Query verified the requested asset mode: $mode.';
  }

  @override
  String assetModeObservedDifferent(String observed, String target) {
    return 'Query shows $observed; requested $target. Refresh settings before reviewing another change.';
  }

  @override
  String get assetModeOutcomeUnknown =>
      'The request may have reached Aster. Its result is unverified; sign to query again. Querying never resubmits the change.';

  @override
  String get liveOrderEntry => 'Place a live futures order';

  @override
  String get liveOrderEntryHint =>
      'The form above uses local demo funds. Live orders have a separate wallet confirmation.';

  @override
  String get liveOrderTitle => 'Live futures order';

  @override
  String get liveOrderScope =>
      'Use this wallet to place real ordinary, conditional or trailing orders. Limit orders use a supported execution policy. In one-way mode, buying or selling can reduce or reverse an existing position. Hedge mode operates on the selected long or short side. Aster checks fees, available margin and final eligibility.';

  @override
  String get liveOrderReadContext => 'Read order settings (2 signatures)';

  @override
  String get liveOrderReadHint =>
      'Read public trading rules and mark price, then sign separately for position mode and symbol configuration. Settings expire 30 seconds after the mark-price response. Reading places no order.';

  @override
  String get liveOrderSettingsBusy =>
      'Finish the pending futures settings operation before placing an order.';

  @override
  String get liveOrderSubmitting => 'Submitting the live order…';

  @override
  String get liveOrderMarkPrice => 'Reference mark price';

  @override
  String get liveOrderContextExpired =>
      'Refresh order settings before reviewing an order. Your input is preserved.';

  @override
  String liveOrderQuantity(String asset) {
    return 'Quantity ($asset)';
  }

  @override
  String liveOrderQuantityBounds(String minimum, String maximum, String step) {
    return 'Minimum $minimum; maximum $maximum; step $step';
  }

  @override
  String liveOrderPrice(String asset) {
    return 'Limit price ($asset)';
  }

  @override
  String liveOrderPriceTick(String tick) {
    return 'Price increment: $tick';
  }

  @override
  String get liveOrderEstimatedNotional => 'Reference notional';

  @override
  String get liveOrderReview => 'Review live order';

  @override
  String get liveOrderClientId => 'Client order reference';

  @override
  String liveOrderVerifiedResult(String status, String executed, String orderId) {
    return 'Signed query: $status; executed quantity $executed; order $orderId.';
  }

  @override
  String get liveOrderQueryScope =>
      'This is the query snapshot. Only FILLED confirms the complete requested quantity; later changes need another account read.';

  @override
  String get liveOrderOutcomeUnknown =>
      'The request may have reached Aster. Query this client reference to verify. Another order is blocked; querying never places it again.';

  @override
  String get liveOrderRecheck => 'Sign to query this order';

  @override
  String get liveOrderConfirmTitle => 'Place this live futures order?';

  @override
  String get liveOrderConfirmHint =>
      'This submits a real order. Sign to place it, then sign separately to query its status. A market order can execute at a different price. Limit execution follows the policy shown below. No leverage or margin setting is changed.';

  @override
  String get liveOrderPolicy => 'Limit execution policy';

  @override
  String get liveOrderConditional => 'Conditional order';

  @override
  String get liveOrderPositionTriggers => 'Position TP/SL';

  @override
  String get liveOrderStop => 'Stop';

  @override
  String get liveOrderTakeProfit => 'Take profit';

  @override
  String get liveOrderTriggerBasis => 'Trigger price basis';

  @override
  String get liveOrderTriggerReference => 'Reference price at read';

  @override
  String get liveOrderTriggerRises =>
      'Triggers when the selected price rises to or above the trigger price.';

  @override
  String get liveOrderTriggerFalls =>
      'Triggers when the selected price falls to or below the trigger price.';

  @override
  String get liveOrderTriggerProtect => 'Trigger price protection';

  @override
  String get liveOrderProtectOn => 'On';

  @override
  String get liveOrderProtectOff => 'Off';

  @override
  String get liveOrderProtectHint =>
      'When enabled, the mark/last price difference must also satisfy the symbol’s threshold at trigger time. This can delay or prevent triggering; it does not protect the execution price.';

  @override
  String liveOrderProtectThreshold(String percent) {
    return 'Allowed price difference at trigger: $percent%.';
  }

  @override
  String get liveOrderConditionalHint =>
      'This submits one independent conditional order for the specified quantity. Triggering does not guarantee a fill. Separate TP and SL orders do not cancel each other automatically. Later position changes can affect execution; review active orders separately.';

  @override
  String get liveOrderConditionalEstimateHint =>
      'Reference estimate only: conditional market orders use the trigger price, conditional limit orders use the limit price. Position, leverage and available funds can change before triggering. Fees, funding, depth slippage and execution-time checks are excluded; this is not realized PnL or guaranteed required margin.';

  @override
  String get liveOrderTypeUnavailable =>
      'The latest symbol rules do not support this order type. Refresh the rules or choose a supported type.';

  @override
  String get liveOrderInvalidTrigger => 'Enter a positive decimal trigger price.';

  @override
  String get liveOrderTriggerFilter =>
      'Trigger price must satisfy the exchange price range and increment.';

  @override
  String get liveOrderProtectUnavailable =>
      'The trigger-protection threshold is unavailable in the current symbol rules. Refresh or turn protection off before reviewing.';

  @override
  String get liveOrderTriggerReferenceUnavailable =>
      'The selected trigger reference is unavailable. Refresh or explicitly choose another price basis; no price is substituted.';

  @override
  String get liveOrderTriggerImmediate =>
      'The trigger price is already reached at this read. Adjust it according to the displayed direction and review again. Aster checks the actual price at submission.';

  @override
  String get liveOrderPolicyChoose => 'Choose a supported policy';

  @override
  String get liveOrderPolicyGtc => 'GTC';

  @override
  String get liveOrderPolicyIoc => 'IOC';

  @override
  String get liveOrderPolicyPostOnly => 'Post Only (GTX)';

  @override
  String get liveOrderPolicyHidden => 'Hidden (HIDDEN)';

  @override
  String get liveOrderPolicyGtcHint =>
      'GTC: any unfilled quantity remains open until filled or cancelled.';

  @override
  String get liveOrderPolicyIocHint =>
      'IOC: fill immediately available quantity and cancel the remainder. A partial fill is possible.';

  @override
  String get liveOrderPolicyPostOnlyHint =>
      'Post Only: the order must add liquidity. An order that would immediately take liquidity will not execute as an ordinary limit order. Placement and fills require exchange verification.';

  @override
  String get liveOrderPolicyHiddenHint =>
      'Hidden: the order is not visible in the public order book. This does not guarantee maker execution, a fill or execution priority.';

  @override
  String get liveOrderTimeInForceUnavailable =>
      'The selected limit policy is unavailable in the latest symbol rules. Choose a supported policy or use a market order, then review again.';

  @override
  String get liveOrderSide => 'Direction';

  @override
  String get liveOrderType => 'Order type';

  @override
  String get liveOrderSignSubmit => 'Sign and place live order';

  @override
  String get liveOrderInvalidQuantity => 'Enter a positive decimal quantity.';

  @override
  String get liveOrderInvalidPrice => 'Enter a positive decimal limit price.';

  @override
  String get liveOrderQuantityFilter =>
      'Quantity must satisfy the displayed minimum, maximum and increment for this order type.';

  @override
  String get liveOrderPriceFilter =>
      'Limit price must satisfy the exchange price range and increment.';

  @override
  String get liveOrderPercentFilter =>
      'Limit price is outside the permitted range for this side at the reference mark price. Refresh settings or adjust the price.';

  @override
  String get liveOrderNotionalFilter =>
      'Order value is below the exchange minimum notional. Market orders use the reference mark price.';

  @override
  String get liveCloseTitle => 'Close a live position';

  @override
  String get liveCloseScope =>
      'Read this wallet’s current position before choosing an ordinary or trailing close. Position TP/SL supports fixed quantity or entire close at trigger. One-way fixed-quantity closes only reduce positions; hedge closes retain the original LONG/SHORT side. Percentage quantities round down to the order step; 100% can leave a remainder. Existing orders are not cancelled.';

  @override
  String get liveClosePositionChanged =>
      'The selected position or its configuration is missing or changed. Refresh order settings and review again.';

  @override
  String get liveCloseTooLarge =>
      'Close quantity cannot exceed the position quantity read for this side.';

  @override
  String get liveCloseLong => 'Close long · sell';

  @override
  String get liveCloseShort => 'Close short · buy';

  @override
  String get liveClosePositionAmount => 'Position quantity at last read';

  @override
  String get liveCloseEstimatedPnl => 'Estimated close PnL';

  @override
  String get liveCloseEstimateHint =>
      'Estimate only: market closes use the read best bid for longs or best ask for shorts; limit closes use the entered price. Fees, funding and depth slippage are excluded. Missing book data shows —. This is not realized PnL.';

  @override
  String get liveCloseConfirmTitle => 'Submit this position reduction?';

  @override
  String get liveCloseConfirmHint =>
      'This submits a real reduction order. Sign to recheck the position first, then sign to place the order and separately to query it. A changed quantity, entry price or configuration stops submission. Market price can move; limit execution follows the policy shown below. The exchange validates concurrent activity.';

  @override
  String get liveCloseResultScope =>
      'An order status does not prove that the entire position is closed. Sign separately to read the remaining position. This does not cancel other orders, and later activity can change the position again.';

  @override
  String get liveCloseReadRemaining => 'Sign to read remaining positions';

  @override
  String get liveCloseRemaining => 'Remaining quantity at this read';

  @override
  String get liveOrderReduceHint =>
      'Only reduce an existing position; never intentionally open the opposite side. Aster checks the available reducible quantity, including concurrent orders.';

  @override
  String get liveOrderReduceHedge =>
      'The reduceOnly parameter is unavailable in hedge mode. Use the position’s close action to reduce its LONG or SHORT side.';

  @override
  String get batchCloseAll => 'Close all listed live positions';

  @override
  String get batchCloseCurrent => 'Close all current-symbol live positions';

  @override
  String get batchCloseTitle => 'Close these live positions at market?';

  @override
  String get batchCloseHint =>
      'Only the listed wallet, symbols, sides and exact quantities are included. Submit an opposite MARKET order for each nonzero position, using reduce-only in one-way mode or the original side in hedge mode. Existing orders and Spot are excluded. Each position needs separate setting-read, position-recheck, order and query signatures, followed by a final position-read signature. Changed positions, invalid quantities, refused signatures or unknown results stop further submissions. No automatic resizing or order retry. Later activity can change positions again.';

  @override
  String get batchCloseReadFirst =>
      'Read a fresh, complete live position snapshot before closing all. An unresolved trade or configuration change must be checked first.';

  @override
  String batchCloseCount(int count) {
    return 'Confirmed scope: $count positions';
  }

  @override
  String get batchCloseConfirm => 'Sign and close each position';

  @override
  String get batchCloseStopped =>
      'Further submissions stopped. Unsubmitted positions require a fresh read and confirmation.';

  @override
  String get batchCloseRecheck => 'Sign to query unconfirmed orders only';

  @override
  String get liveOrderFundsReadHint =>
      'Read public rules and mark price, then sign separately for position mode, symbol positions, asset mode and account funds (4 signatures). Read validity is 30 seconds from the mark-price response. No order is submitted.';

  @override
  String get liveOrderReadFunds =>
      'Read asset mode and account funds before reviewing an opening order. Missing amounts are unknown, not zero.';

  @override
  String get liveOrderFundsChanged =>
      'Account funds and the selected position or configuration do not agree. Refresh and review again.';

  @override
  String get liveOrderTradingDisabled =>
      'The signed account response reports trading disabled. Check your Aster account before placing an opening order.';

  @override
  String get liveOrderAvailableUsdt => 'Available USDT margin at read';

  @override
  String get liveOrderFundsScope =>
      'This snapshot covers available USDT margin in this futures account. It is separate from wallet balance, withdrawal limits, demo funds and funds reserved after this read. Aster validates actual availability.';

  @override
  String get liveOrderFundsMultiHint =>
      'Multi-assets mode: the USDT amount is not a combined collateral total. Other assets retain their own units; no conversion rates or collateral discounts are assumed.';

  @override
  String get liveOrderFundsAssets => 'Available balances and collateral eligibility by asset';

  @override
  String get liveOrderCollateralUnknown => 'Collateral eligibility not provided';

  @override
  String get liveOrderOpeningQuantity => 'Reference new opening quantity';

  @override
  String get liveOrderOpeningMargin => 'Estimated additional opening initial margin';

  @override
  String get liveOrderMarginEstimateHint =>
      'Reference only: new opening quantity × entered limit price (or reference mark) ÷ read leverage. One-way orders first offset the read opposite position; hedge orders open the selected side. Valid reduce-only closes add no opening exposure. Fees, funding, existing orders, released margin, execution price and risk tiers can change actual requirements.';

  @override
  String get liveOrderFundsHistorical =>
      'Historical funds snapshot. Refresh before reviewing another opening order.';

  @override
  String get liveOrderMarginAboveBalance =>
      'The estimate exceeds the read USDT available balance. Review your funds; released margin and fees are excluded, and Aster makes the final check.';

  @override
  String get liveEntireClose => 'Close entire position at trigger';

  @override
  String get liveEntireHint =>
      'The exchange uses the position size at trigger time, which may differ from this snapshot. No fixed quantity or reduceOnly is sent. Independent TP/SL orders do not cancel each other.';

  @override
  String get liveEntireMarketOnly =>
      'Entire close is available for conditional market orders only.';

  @override
  String get liveEntireEstimateHint =>
      'Estimated using the reviewed position quantity and trigger price. Trigger-time size, execution price, fees and funding may change the result.';

  @override
  String get liveEntireQuantity => 'Entire position size at trigger time';

  @override
  String get liveEntireQueryScope =>
      'This query verifies this entire-close order and its reported execution only. A filled order does not prove the remaining position is zero; read positions again.';

  @override
  String get liveEntireInvalid =>
      'Entire close requires a position-side conditional market order without quantity, limit price or reduceOnly.';

  @override
  String get triggerCalculator => 'Calculate trigger price from PnL / ROI';

  @override
  String get triggerCalculationHint =>
      'Uses the selected partial quantity, or the reviewed position quantity for entire close. ROI is an entry-price estimate with leverage, not account yield. Applying a candidate only updates the trigger field; it does not submit an order. Refreshing does not overwrite that field.';

  @override
  String get triggerCalculationQuantity => 'Calculation quantity';

  @override
  String get triggerCalculationRoi => 'Estimated ROI';

  @override
  String get triggerCalculationPnlLabel => 'PnL target';

  @override
  String triggerCalculationPnl(String asset) {
    return 'PnL target ($asset, signed)';
  }

  @override
  String get triggerCalculationRoiTarget => 'ROI target (%, signed)';

  @override
  String get triggerCalculationPrice => 'Candidate trigger price';

  @override
  String get triggerCalculationRounding =>
      'Rounded to the nearest exchange price step. Estimates reflect the rounded price, exclude fees and funding, and do not guarantee execution. For conditional limit orders, execution PnL uses the separate limit price.';

  @override
  String get triggerCalculationApply => 'Use candidate trigger price';

  @override
  String get triggerCalculationPosition =>
      'Read a nonzero position and choose a valid quantity and leverage first.';

  @override
  String get triggerCalculationInput => 'Enter a signed decimal target without exponent notation.';

  @override
  String get triggerCalculationTick =>
      'The exchange price step is unavailable; cannot calculate a candidate.';

  @override
  String get triggerCalculationBounds =>
      'The calculated price is outside the supported positive price range.';

  @override
  String get liveTrailingInvalid =>
      'Trailing stop requires a market order with fixed quantity, no fixed trigger or limit price, and no entire-close flag.';

  @override
  String get liveTrailingRateInvalid => 'Enter a callback rate from 0.1% to 5%.';

  @override
  String get liveTrailingActivationInvalid =>
      'Enter a positive decimal activation price, or leave it empty for the exchange default.';

  @override
  String get liveTrailingActivationFilter =>
      'The activation price does not match the exchange price range or step.';

  @override
  String get liveTrailingImmediate =>
      'A buy activation price must be below the selected latest price; a sell activation price must be above it.';

  @override
  String get liveTrailingHint =>
      'The exchange tracks favorable price extremes, then submits market execution after the configured pullback. This uses a fixed quantity, not entire close. It does not continuously reprice a limit order.';

  @override
  String get liveTrailingRate => 'Callback rate (%)';

  @override
  String get liveTrailingRateBounds => '0.1–5; entering 1 means 1%.';

  @override
  String get liveTrailingBasis => 'Tracking price basis';

  @override
  String liveTrailingActivation(String asset) {
    return 'Activation price ($asset, optional)';
  }

  @override
  String get liveTrailingDefault =>
      'Leave empty to use the selected price basis at exchange placement time. This snapshot is not submitted as the activation price.';

  @override
  String get liveTrailingActivationDirection =>
      'If specified: buy activation below the latest price; sell activation above it. The exchange rechecks at placement.';

  @override
  String get liveTrailingBuy =>
      'After activation, a buy follows the lowest price and triggers on a rise by the callback percentage. Triggering does not guarantee an execution price.';

  @override
  String get liveTrailingSell =>
      'After activation, a sell follows the highest price and triggers on a fall by the callback percentage. Triggering does not guarantee an execution price.';

  @override
  String get liveTrailingEstimateHint =>
      'There is no fixed execution price. Notional and opening margin use the current mark only as a reference; closing PnL is unavailable. Actual size eligibility, margin and execution depend on exchange state. Fees, funding and slippage are excluded.';

  @override
  String get quickOrderInvalid =>
      'Quick entry must be an ordinary market order without reduction, a fixed price or attached conditions.';

  @override
  String get quickOrderTitle => 'Chart quick market entry';

  @override
  String get quickOrderHint =>
      'Real wallet orders. Quantity is independent of the trade form. One-way orders can reduce or reverse an existing position. Quotes are references, not execution prices. This order has no attached TP/SL or user slippage setting.';

  @override
  String get quickOrderRead => 'Read wallet and sizing inputs';

  @override
  String get quickOrderReadHint =>
      'Explicitly sign four account/configuration reads, then three separate fee, risk-bracket and open-order reads for percentage sizing. No order is sent by reading. The first price snapshot expires in 30 seconds.';

  @override
  String get quickOrderIndependent =>
      'Enter base-asset quantity, or choose a percentage. Starts empty; no default percentage.';

  @override
  String quickOrderPercentSelected(int percent) {
    return '$percent% selected. Buy and sell reference quantities are shown separately. Type a quantity to replace the percentage.';
  }

  @override
  String get quickOrderBuyQuantity => 'Reference buy quantity';

  @override
  String get quickOrderSellQuantity => 'Reference sell quantity';

  @override
  String get quickOrderSizingHint =>
      'Percentages use the read-time USDT available margin, leverage, taker fee, risk brackets, existing positions, same-direction pending quantity and bid/ask, rounded down to the market step. They exclude released margin and other-asset collateral. These are reference budgets, not guaranteed maximum quantities; prices, orders and exchange limits can change.';

  @override
  String get quickOrderSizingFailure =>
      'Percentage sizing is unavailable. Retry the read, or enter a quantity if the account context is valid. Inputs are preserved.';

  @override
  String get quickOrderBuy => 'Market Buy / Long';

  @override
  String get quickOrderSell => 'Market Sell / Short';

  @override
  String get quickOrderConfirmation => 'Quick market order confirmation';

  @override
  String get quickOrderDoNotShow => 'Do not show market order confirmation again';

  @override
  String get quickOrderConfirmPreference => 'Confirm market entries';

  @override
  String get quickOrderPreferenceFailure =>
      'Confirmation preference could not be read or saved. The last saved choice is retained; orders require review until a choice is saved successfully.';

  @override
  String get quickOrderChartTab => 'Chart view';

  @override
  String get attachedOrderTitle => 'Attach take profit / stop loss';

  @override
  String get attachedOrderTakeProfit => 'Attached take profit';

  @override
  String get attachedOrderStopLoss => 'Attached stop loss';

  @override
  String get attachedOrderTriggerPrice => 'Trigger price (USDT)';

  @override
  String get attachedOrderBasis => 'Trigger price basis';

  @override
  String get attachedOrderPriceProtect => 'Trigger price protection';

  @override
  String get attachedOrderLifecycle =>
      'Entry partial or full fills request placement of the exits. A partial or full exit fill requests cancellation of its peer. Each exit uses the full main-order quantity. Actual activation, quantity changes, cancellations and fills require exchange reports.';

  @override
  String get attachedOrderManageScope =>
      'Creation and signed queries are supported. Editing and canceling the complete attached strategy in the app are not yet available.';

  @override
  String get attachedOrderInvalid =>
      'Fill at least one TP/SL exit or turn attached protection off. It cannot be combined with reduce-only, entire close, quick entry or trailing orders.';

  @override
  String get attachedOrderIocUnavailable =>
      'Attached strategies do not support IOC. Choose another supported time in force for the entry.';

  @override
  String get attachedOrderNoExposure => 'Enter a positive main-order quantity to protect.';

  @override
  String get attachedOrderPriceDirection =>
      'The attached TP/SL trigger is on the wrong side of the entry reference. Check the entry direction and trigger price.';

  @override
  String get attachedOrderPositionChanged =>
      'The position or symbol configuration changed. Read again and review the attached exit quantity.';

  @override
  String get attachedOrderRejected =>
      'The exchange returned a strategy rejection code. Query the original ID to check the outcome; do not submit it again.';

  @override
  String get attachedOrderStrategyType => 'Linked strategy';

  @override
  String get attachedOrderExitQuantity => 'Fixed quantity per exit';

  @override
  String get attachedOrderVerified => 'Strategy and linked terms checked by query';

  @override
  String get attachedOrderStrategyId => 'Strategy ID';

  @override
  String get attachedOrderStrategyStatus => 'Exchange strategy status';

  @override
  String attachedOrderLegStatus(int sequence) {
    return 'Leg $sequence status';
  }

  @override
  String get attachedOrderQueryScope =>
      'These are exchange-reported strategy and leg statuses, not verified executed quantities, balances or remaining positions. An inactive leg may have no order ID. Check entry and exit execution separately.';

  @override
  String get attachedOrderRefresh => 'Sign to query this strategy again';

  @override
  String get attachedOrderClientId => 'Client strategy reference';

  @override
  String get attachedOrderConfirmHint =>
      'This submits a real linked strategy. Review the full main-order protection quantity, each trigger and exit price. Entry partial or full fills drive placement; partial or full exit fills drive peer cancellation. Query exchange reports to check the actual outcome.';

  @override
  String get orderRecoveryTitle => 'Pending order recovery';

  @override
  String get orderRecoveryScope =>
      'Only pending futures orders or strategies saved for this wallet on this device appear here. Reconnect the same wallet and sign to query; recovery never submits an order. A missing result does not prove the original was not sent; its record stays pending. Check the outcome before placing new orders or changing settings. Clearing app data or uninstalling removes local records.';

  @override
  String get orderRecoveryStorage =>
      'Pending records could not be read or saved. New live orders and configuration changes are paused. Records are not cleared automatically; retry storage access.';

  @override
  String get orderRecoveryPending =>
      'This wallet has an order or strategy to check. Query its original reference first. New live orders and configuration changes are temporarily unavailable.';

  @override
  String get orderRecoveryConnect => 'Sign in or reconnect the original wallet';

  @override
  String get orderRecoveryReload => 'Retry local records';

  @override
  String get orderRecoveryEmpty =>
      'No pending records for this wallet on this device. This does not mean the exchange has no open orders.';

  @override
  String get orderRecoveryQuery => 'Sign to query the original reference';

  @override
  String get orderRecoveryCreated => 'Recorded at';

  @override
  String get orderRecoveryVerified =>
      'Original reference and terms checked. Execution and account state remain limited to what the query reports.';

  @override
  String get orderRecoveryActiveOperation =>
      'An operation in this session is still active or unresolved. Use its original page to recheck.';

  @override
  String get notificationTitle => 'Notifications';

  @override
  String get notificationEmpty =>
      'No recorded notifications for this wallet. An empty inbox does not prove there were no account events.';

  @override
  String get notificationSignIn => 'Sign in to view this wallet’s notifications.';

  @override
  String get notificationStorageFailed =>
      'Local notifications could not be loaded or saved. Visible changes remain in memory; retry to restore persistence. Existing stored data is not cleared.';

  @override
  String get notificationRetry => 'Retry local storage';

  @override
  String get notificationMarkAllRead => 'Mark all as read';

  @override
  String get notificationUnread => 'Unread';

  @override
  String get notificationCritical => 'Critical';

  @override
  String get notificationMarginTitle => 'Margin Call';

  @override
  String get notificationLiquidationTitle => 'Liquidation Order Update';

  @override
  String get notificationAdlTitle => 'ADL Order Update';

  @override
  String get notificationRiskScope =>
      'This event does not prove the whole position was closed. Review actual fills and read remaining positions separately. Risk warnings may arrive during or after liquidation.';

  @override
  String get notificationMarginScope =>
      'All risk positions reported in this event are listed below. The event supplies no risk percentage, liquidation price or countdown. Delivery before liquidation is not guaranteed.';

  @override
  String get notificationEventTime => 'Event time (UTC)';

  @override
  String get notificationTransactionTime => 'Transaction time (UTC)';

  @override
  String get notificationTradeTime => 'Order trade time (UTC)';

  @override
  String get notificationLastQuantity => 'Last filled quantity';

  @override
  String get notificationCumulativeQuantity => 'Cumulative filled quantity';

  @override
  String get notificationOriginalQuantity => 'Original order quantity';

  @override
  String get notificationLastPrice => 'Last fill price';

  @override
  String get notificationRealizedPnl => 'Reported realized PnL';

  @override
  String get notificationUnits =>
      'Quantities use the base asset; prices use the quote asset. Units are shown only when verified from the relevant market directory. These figures describe this event, not current balances.';

  @override
  String get notificationMaintenanceMargin => 'Maintenance margin required';

  @override
  String get notificationYes => 'Yes';

  @override
  String get notificationNo => 'No';

  @override
  String notificationOrderTitle(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'NEW': 'Perp Order · New',
      'PARTIALLY_FILLED': 'Perp Order · Partially Filled',
      'FILLED': 'Perp Order · Filled',
      'CANCELED': 'Perp Order · Canceled',
      'EXPIRED': 'Perp Order · Expired',
      'REJECTED': 'Perp Order · Rejected',
      'other': 'Perp Order · Updated',
    });
    return '$_temp0';
  }

  @override
  String notificationStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'NEW': 'New',
      'PARTIALLY_FILLED': 'Partially filled',
      'FILLED': 'Filled',
      'CANCELED': 'Canceled',
      'EXPIRED': 'Expired',
      'REJECTED': 'Rejected',
      'NEW_INSURANCE': 'Insurance fund liquidation order',
      'NEW_ADL': 'ADL order created',
      'other': 'Unknown',
    });
    return '$_temp0';
  }

  @override
  String notificationExecution(String execution) {
    String _temp0 = intl.Intl.selectLogic(execution, {
      'NEW': 'Execution: new',
      'CANCELED': 'Execution: canceled',
      'CALCULATED': 'Execution: liquidation calculation',
      'EXPIRED': 'Execution: expired',
      'TRADE': 'Execution: trade',
      'AMENDMENT': 'Execution: amendment',
      'REJECTED': 'Execution: rejected',
      'other': 'Execution: unknown',
    });
    return '$_temp0';
  }

  @override
  String notificationOrderType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'LIMIT': 'Limit',
      'MARKET': 'Market',
      'STOP': 'Stop limit',
      'STOP_MARKET': 'Stop market',
      'TAKE_PROFIT': 'Take-profit limit',
      'TAKE_PROFIT_MARKET': 'Take-profit market',
      'TRAILING_STOP_MARKET': 'Trailing stop market',
      'LIQUIDATION': 'Liquidation',
      'other': 'Unknown',
    });
    return '$_temp0';
  }

  @override
  String get notificationOriginalType => 'Original order type';

  @override
  String get notificationUnitFailure =>
      'Market units could not be loaded. Amounts remain visible with unknown units; retry the public market directory.';

  @override
  String get spotAccountChangeTitle => 'Spot account monitoring';

  @override
  String get spotAccountChangeScope =>
      'Sign with the current wallet to start or renew Spot monitoring for up to 60 minutes. It records live Spot order events and marks Spot snapshots as needing a signed refresh. No automatic signatures or historical backfill. Stopping disconnects this app; it does not invalidate a key shared by other clients.';

  @override
  String get spotAccountChangeStart => 'Sign to monitor Spot events';

  @override
  String get spotAccountChangeRenew => 'Sign to renew Spot monitoring';

  @override
  String get spotNotificationLastQuote => 'Last filled quote amount';

  @override
  String get spotNotificationCumulativeQuote => 'Cumulative filled quote amount';

  @override
  String get spotNotificationQuoteOrderQuantity => 'Requested quote-asset budget';

  @override
  String get spotNotificationCreationTime => 'Order created (UTC)';

  @override
  String spotNotificationOrderTitle(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'NEW': 'Spot Order · New',
      'PARTIALLY_FILLED': 'Spot Order · Partially Filled',
      'FILLED': 'Spot Order · Filled',
      'CANCELED': 'Spot Order · Canceled',
      'EXPIRED': 'Spot Order · Expired',
      'REJECTED': 'Spot Order · Rejected',
      'other': 'Spot Order · Updated',
    });
    return '$_temp0';
  }

  @override
  String get transferHistoryTitle => 'Deposit / withdrawal records';

  @override
  String get transferHistoryScope =>
      'Sign to read deposit / withdrawal records for both markets. The first read does not notify existing history; later refreshes notify newly observed transfers and status changes. Returned records may not include all history.';

  @override
  String get transferRefresh => 'Sign to refresh records';

  @override
  String get transferRefreshNeeded =>
      'Deposit / withdrawal records may have changed. Sign to refresh and confirm their status; balance changes alone do not prove completion.';

  @override
  String get transferBaselineCreated =>
      'Initial baseline established. Existing records did not create notifications.';

  @override
  String get transferHistoryEmpty =>
      'No matching records were returned. This does not prove there were no transfers.';

  @override
  String get transferRecordScope =>
      'Status is reported by Aster. Record time is not completion time; no failure reason is supplied by this history response.';

  @override
  String get transferRecordId => 'Transfer record ID';

  @override
  String get transferTypeLabel => 'Transfer type';

  @override
  String get transferDeposit => 'Deposit';

  @override
  String get transferWithdraw => 'Withdrawal';

  @override
  String get transferSpotMarket => 'Spot';

  @override
  String get transferPerpMarket => 'Perpetuals';

  @override
  String get transferMarketLabel => 'Market';

  @override
  String get transferAllMarkets => 'All markets';

  @override
  String get transferNetwork => 'Network';

  @override
  String get transferChainId => 'Chain ID';

  @override
  String get transferNetworkEthereum => 'Ethereum';

  @override
  String get transferNetworkBnb => 'BNB Chain';

  @override
  String get transferNetworkArbitrum => 'Arbitrum One';

  @override
  String transferUnknownNetwork(String chainId) {
    return 'Unmapped network (chain ID $chainId)';
  }

  @override
  String get transferHash => 'Transaction hash';

  @override
  String get transferHashUnknown => 'Not provided';

  @override
  String get transferRecordTime => 'Record time (UTC)';

  @override
  String transferReadTime(String time) {
    return 'Last read (UTC): $time';
  }

  @override
  String get transferStorageRequired =>
      'Transfer tracking could not be loaded or saved. Retry local notification storage before refreshing. Existing records are retained.';

  @override
  String get transferTrackingFull =>
      'Local transfer tracking has reached its limit. Existing observations are retained; this refresh was not recorded.';

  @override
  String transferStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'processing': 'Processing',
      'success': 'Successful',
      'failed': 'Failed',
      'other': 'Unknown',
    });
    return '$_temp0';
  }

  @override
  String transferTitle(String type, String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'processing': 'Deposit processing',
      'success': 'Deposit successful',
      'failed': 'Deposit failed',
      'other': 'Deposit update',
    });
    String _temp1 = intl.Intl.selectLogic(status, {
      'processing': 'Withdrawal processing',
      'success': 'Withdrawal successful',
      'failed': 'Withdrawal failed',
      'other': 'Withdrawal update',
    });
    String _temp2 = intl.Intl.selectLogic(type, {
      'deposit': '$_temp0',
      'withdraw': '$_temp1',
      'other': 'Transfer update',
    });
    return '$_temp2';
  }

  @override
  String get transferObservedTime => 'Observed at (UTC)';

  @override
  String assetValueUsd(String label) {
    return '$label · USD estimate';
  }

  @override
  String assetValueBtc(String label) {
    return '$label · BTC estimate';
  }

  @override
  String get assetValueUnavailable =>
      'Some estimates are unavailable. Missing prices or balances are not treated as zero.';

  @override
  String get assetValueStale =>
      'Estimate uses an older or incomplete account / price snapshot. Refresh before relying on it.';

  @override
  String get assetValueSpotScope => 'Spot wallet estimate';

  @override
  String get assetValuePerpScope => 'Perpetual wallet estimate';

  @override
  String get assetValueKnownSubtotal => 'Known asset subtotal';

  @override
  String get assetValueWalletTotal => 'Wallet asset value';

  @override
  String get assetValueBtcEstimate => 'Approximate BTC equivalent';

  @override
  String assetValueMissing(int count) {
    return '$count asset(s) have no USD price and are excluded from this subtotal.';
  }

  @override
  String get assetValueScope =>
      'Reference USD asset indices from Aster; BTC equivalents use the BTC/USD index. Stablecoins use their reported price. Wallet estimates exclude unrealized PnL and other accounts, products, collateral discounts and execution costs. BTC values are rounded for display.';

  @override
  String assetIndexReadTime(String time) {
    return 'Price snapshot read (UTC): $time';
  }

  @override
  String get assetIndexLoading => 'Refreshing reference prices…';

  @override
  String get assetIndexPaused => 'Reference price updates are paused.';

  @override
  String get assetIndexFailed =>
      'Reference prices could not be refreshed. Previous estimates may be stale.';

  @override
  String get assetIndexRefresh => 'Refresh public reference prices';

  @override
  String get assetValueHideLow => 'Hide assets worth 0.0001 BTC or less';

  @override
  String get assetValueHideLowScope =>
      'Uses total Spot balance. Assets with missing or stale estimates remain visible.';

  @override
  String get subaccountManagement => 'Sub-account management';

  @override
  String get subaccountListScope =>
      'Sign with the connected wallet to view its linked accounts. Reading this list does not change the account used for trading.';

  @override
  String get subaccountConnectedWallet => 'Connected signing wallet';

  @override
  String get subaccountRead => 'Read linked accounts';

  @override
  String get subaccountRefresh => 'Refresh linked accounts';

  @override
  String get subaccountStopWaiting => 'Stop waiting';

  @override
  String subaccountCount(int count) {
    return '$count sub-account(s)';
  }

  @override
  String get subaccountNoChildren => 'No sub-accounts were returned.';

  @override
  String get subaccountListBoundaries =>
      'Account IDs and names are shown as returned. This list does not provide addresses or freeze status. Open account management for explicit creation, switching, freeze/unfreeze and transfers.';

  @override
  String get subaccountSearch => 'Search by account name or ID';

  @override
  String get subaccountNoMatches => 'No matching accounts.';

  @override
  String get subaccountParent => 'Master account';

  @override
  String get subaccountChild => 'Sub-account';

  @override
  String get subaccountUnnamed => 'Unnamed account';

  @override
  String get subaccountId => 'Account ID';

  @override
  String get subaccountCopyId => 'Copy account ID';

  @override
  String get fundingInfoTitle => 'Deposit and withdrawal information';

  @override
  String get fundingInfoScope =>
      'View supported assets and networks. Withdrawal limits require a wallet signature. Open an asset to review deposit or withdrawal submission separately.';

  @override
  String get fundingEvmScope =>
      'Currently shows the three EVM mainnets in the funding documentation. This is not a complete directory of all Aster networks.';

  @override
  String get fundingAccount => 'Account';

  @override
  String get fundingDeposit => 'Deposit';

  @override
  String get fundingWithdraw => 'Withdraw';

  @override
  String get fundingNetwork => 'Network';

  @override
  String get fundingEthereum => 'Ethereum · 1';

  @override
  String get fundingBnbChain => 'BNB Chain · 56';

  @override
  String get fundingArbitrum => 'Arbitrum · 42161';

  @override
  String get fundingCatalogLoading => 'Reading public asset configuration…';

  @override
  String get fundingCatalogFailed =>
      'Asset configuration is unavailable or invalid. Retry the public read.';

  @override
  String get fundingCatalogStale =>
      'Configuration is older than five minutes or a refresh failed. Refresh before relying on it.';

  @override
  String fundingCatalogTime(String time) {
    return 'Public configuration read (UTC): $time';
  }

  @override
  String get fundingCatalogRefresh => 'Refresh public configuration';

  @override
  String get fundingAssetSearch => 'Search asset name or symbol';

  @override
  String get fundingNoNetworkAssets =>
      'No assets were returned for this account, operation and network.';

  @override
  String get fundingNativeAsset => 'Native asset';

  @override
  String get fundingTokenAsset => 'Token';

  @override
  String get fundingTokenContract => 'Token contract · not a deposit destination';

  @override
  String get fundingWithdrawLimits => 'Withdrawal limit snapshot';

  @override
  String get fundingWithdrawScope =>
      'This read does not authorize a withdrawal. Limits and fees can change. Missing amounts remain unknown; the account balance is not used as a substitute.';

  @override
  String get fundingReadLimits => 'Sign to read withdrawal limits';

  @override
  String get fundingRefreshLimits => 'Sign to refresh withdrawal limits';

  @override
  String get fundingUserDailyUsd => 'User daily limit';

  @override
  String get fundingUserRemainingUsd => 'User remaining daily limit';

  @override
  String get fundingGlobalDailyUsd => 'Platform daily limit';

  @override
  String get fundingGlobalRemainingUsd => 'Platform remaining daily limit';

  @override
  String get fundingNoWithdrawBalances =>
      'No non-zero asset withdrawal balances were returned. Missing entries are not treated as an approved zero allowance.';

  @override
  String get fundingAssetTotal => 'Account withdrawable balance · reported';

  @override
  String get fundingChainMaximum => 'Network withdrawable amount · reported';

  @override
  String get fundingChainLimit => 'Network amount limit';

  @override
  String get fundingAssetDailyUsd => 'Asset remaining daily USD limit';

  @override
  String get fundingSnapshotFee => 'Withdrawal fee · snapshot';

  @override
  String get fundingLimitsUnavailable =>
      'No matching signed limit for this asset or network. Read or refresh the limits.';

  @override
  String get fundingLimitUnits =>
      'USD limits and asset amounts have different units. These fields are shown separately and do not form a final Max amount. Fees require a fresh check before submission.';

  @override
  String get fundingNoMatches => 'No matching assets.';

  @override
  String get fundingFeeCheck => 'Check latest withdrawal fee';

  @override
  String get fundingFeeTitle => 'Withdrawal fee estimate';

  @override
  String get fundingFeeScope =>
      'Public estimate for this account type, network and asset. This is the platform withdrawal fee, separate from wallet transaction gas. It does not authorize a withdrawal or guarantee the final fee. Refresh before submitting a withdrawal.';

  @override
  String get fundingFeeLoading => 'Reading public fee estimate…';

  @override
  String get fundingFeeFailed =>
      'The fee estimate is unavailable or invalid. Retry the public read.';

  @override
  String get fundingFeeStale =>
      'The estimate is older than 30 seconds or a refresh failed. Read it again before relying on it.';

  @override
  String get fundingFeeAsset => 'Estimated fee in asset units';

  @override
  String get fundingFeeUsd => 'Estimated fee in USD';

  @override
  String get fundingFeeAssetPrice => 'Asset reference price · USD per unit';

  @override
  String fundingFeeTime(String time) {
    return 'Estimate received: $time';
  }

  @override
  String get fundingFeeRefresh => 'Refresh fee estimate';

  @override
  String get depositPrecheckTitle => 'Deposit wallet precheck';

  @override
  String get depositPrecheckScope =>
      'Read public chain balances and token allowance for this wallet. Minimum deposit is a configuration snapshot. This precheck does not submit an approval or a deposit; platform limits and transaction gas still need verification.';

  @override
  String get depositReadWallet => 'Read wallet balance and allowance';

  @override
  String get depositAssetBalance => 'Wallet asset balance';

  @override
  String get depositNativeBalance => 'Wallet native balance · gas reserve not deducted';

  @override
  String get depositAllowance => 'Token allowance for the documented vault';

  @override
  String get depositSpenderScope =>
      'Allowance spender only. Do not manually send funds to this address.';

  @override
  String get depositBlock => 'Chain block number';

  @override
  String get depositMinimum => 'Minimum deposit · configuration snapshot';

  @override
  String get depositAmount => 'Deposit amount · precheck only';

  @override
  String get depositWalletMax => 'Fill token wallet balance · Max';

  @override
  String get depositWalletMaxScope =>
      'Fills only the token balance, without platform limits. Native currency is still required for gas.';

  @override
  String get depositNativeMaxUnavailable =>
      'Native Max remains unavailable until final transaction fees and platform limits can be checked. Do not use the full native balance.';

  @override
  String get depositSmallestUnits => 'Exact amount in the smallest token unit';

  @override
  String get depositNativeNoApproval =>
      'Native currency does not need ERC20 allowance. Gas and platform limits remain unverified.';

  @override
  String get depositAllowanceEnough =>
      'The read token allowance covers this amount. No approval or deposit has been submitted.';

  @override
  String get depositAllowanceNeeded =>
      'The read token allowance does not cover this amount. Approval is required before a deposit; no approval has been submitted.';

  @override
  String get depositRpcInvalid =>
      'The public chain response is incomplete or invalid. Retry the read.';

  @override
  String get depositRpcFailed => 'The public chain provider could not complete the read. Retry.';

  @override
  String get depositRpcWrongChain =>
      'The provider returned another network. No balance was accepted.';

  @override
  String get depositTokenDecimalsChanged =>
      'On-chain token decimals differ from the selected configuration. Refresh the asset directory and reopen this page.';

  @override
  String get depositRpcReorg =>
      'The chain block changed during the read. Refresh to obtain a consistent snapshot.';

  @override
  String get depositAmountInvalid =>
      'Enter a positive amount within the supported unsigned 256-bit range.';

  @override
  String get depositAmountPrecision =>
      'The amount has more decimal places than this asset supports.';

  @override
  String get depositMinimumUnknown =>
      'The minimum deposit is unknown. Refresh the asset configuration before proceeding.';

  @override
  String get depositBelowMinimum => 'The amount is below the configured minimum deposit.';

  @override
  String get depositReadRequired => 'Read the current wallet balance before checking the amount.';

  @override
  String get depositReadStale =>
      'The wallet snapshot is historical. Refresh before checking the amount.';

  @override
  String get depositBalanceInsufficient => 'The amount exceeds the read wallet asset balance.';

  @override
  String get attachedEntryPricing => 'Entry pricing';

  @override
  String get attachedEntryFixed => 'Enter a limit price';

  @override
  String attachedEntryCounterparty(int depth) {
    return 'BBO · Opposite side, level $depth';
  }

  @override
  String attachedEntryQueue(int depth) {
    return 'BBO · Same side, level $depth';
  }

  @override
  String get attachedEntryPegTiming =>
      'The entry takes the selected order-book level once: at placement for a limit entry, or at trigger for a conditional entry. It does not keep chasing the book.';

  @override
  String get attachedEntryPegEstimate =>
      'Notional and margin estimates use Mark price (the trigger price for conditional entries), not the selected book level or an execution price. Aster checks TP/SL against its resolved entry price and may reject the strategy.';

  @override
  String get attachedEntryPegInvalid =>
      'BBO entry pricing requires a limit or stop-limit entry with attached TP/SL and no entered limit price. Post Only BBO supports same-side level 1 only.';

  @override
  String get scaledTitle => 'Scaled orders';

  @override
  String get scaledRule =>
      '2–110 independent GTC limit orders, submitted from low to high price. Prices include both endpoints and are rounded down to distinct ticks. Quantities follow the selected distribution and valid quantity steps; review every child before signing.';

  @override
  String get scaledRisk =>
      'Each order requires a fresh account check, a submission signature and a query signature. Orders are independent and may only partly succeed. A failure or unknown result stops the remaining orders. Stopping or leaving this page does not cancel orders already sent. Unsent orders are never resumed automatically.';

  @override
  String get scaledLow => 'Lowest price';

  @override
  String get scaledHigh => 'Highest price';

  @override
  String get scaledCount => 'Number of orders';

  @override
  String get scaledPreview => 'Order breakdown';

  @override
  String get scaledReview => 'Review scaled orders';

  @override
  String get scaledConfirm => 'Sign and submit these orders';

  @override
  String get scaledTotalQuantity => 'Total quantity';

  @override
  String get scaledTotalNotional => 'Total limit notional';

  @override
  String get scaledMarginReference => 'Margin reference before netting';

  @override
  String get scaledMarginHint =>
      'Reference = total limit notional ÷ leverage. It excludes position netting, existing orders, fees and released margin. It is not the final margin requirement or an executable allowance. Aster checks each order.';

  @override
  String get scaledPortion => 'Share of total quantity (approx.)';

  @override
  String scaledOrderNumber(int number) {
    return 'Order $number';
  }

  @override
  String get scaledCountInvalid => 'Enter a whole number from 2 to 110.';

  @override
  String get scaledRangeInvalid => 'Enter positive prices with the highest price above the lowest.';

  @override
  String get scaledRangeTooNarrow => 'The price range has too few ticks for distinct child orders.';

  @override
  String get scaledQuantityTooSmall =>
      'The total quantity cannot cover the minimum quantity of every child order.';

  @override
  String get scaledQuantityStep =>
      'The total quantity cannot be split exactly into valid quantity steps. Adjust it without rounding away quantity.';

  @override
  String get scaledConfigurationChanged =>
      'Account mode, leverage or order rules changed. Remaining orders were stopped; refresh and review a new plan.';

  @override
  String get scaledStopped =>
      'Remaining orders stopped. Orders already sent stay active; check their results below.';

  @override
  String get scaledResults => 'Scaled order results';

  @override
  String get scaledRefreshRequired =>
      'Refresh the account and review the plan again before submitting.';

  @override
  String get depositGasTitle => 'Next-step gas estimate';

  @override
  String get depositGasEstimate => 'Estimate next step';

  @override
  String get depositGasScope =>
      'Public simulation only: no wallet signature or transaction is sent. Estimates cover this step only. Approval, deposit, receipts and platform credit are separate steps. User/platform limits are still unknown.';

  @override
  String get depositGasDeposit => 'Deposit transaction';

  @override
  String get depositGasApprove => 'Approve the exact deposit amount';

  @override
  String get depositGasReset => 'Reset the existing allowance to zero';

  @override
  String get depositGasResetHint =>
      'A nonzero allowance is below the requested amount. Reset it first, then re-read and estimate exact approval, then deposit. No unlimited approval is prepared.';

  @override
  String get depositGasTarget => 'Transaction target contract';

  @override
  String get depositGasValue => 'Native token sent with this step';

  @override
  String get depositGasEstimatedUnits => 'Estimated gas units';

  @override
  String get depositGasLimit => 'Gas limit with reserve';

  @override
  String get depositGasPrice => 'Quoted gas price (wei)';

  @override
  String get depositGasReserve => 'Native fee reserve for this step';

  @override
  String get depositGasTotal => 'Native value + fee reserve';

  @override
  String get depositGasReserveHint =>
      'The gas limit rounds the simulation estimate up by 20%. Fee reserve = gas limit × quoted legacy gas price. It is not the actual fee or a guarantee of execution. Prices and chain state can change; re-estimate before sending. Later steps need separate reserves.';

  @override
  String get depositGasChangedAmount =>
      'This estimate belongs to the amount shown below. The input changed; estimate again.';

  @override
  String get depositGasAmount => 'Deposit amount used for this estimate';

  @override
  String get depositGasRouteUnsupported =>
      'This deposit route cannot be encoded from the documented normal EVM deposit contract.';

  @override
  String get depositGasSimulationFailed =>
      'The chain node rejected this step during simulation. No transaction was sent. Refresh balances, allowance and amount before retrying.';

  @override
  String get depositGasBalanceInsufficient =>
      'Native balance cannot cover this step’s value and fee reserve. Keep native tokens for subsequent steps too.';

  @override
  String get depositGasPendingTransactions =>
      'The wallet has pending transactions or its nonce changed. Wait for them to settle, then refresh and estimate again.';

  @override
  String get depositGasBlockLimit =>
      'The padded gas limit exceeds this chain block’s gas limit. No transaction is prepared for sending.';

  @override
  String get depositApprovalPrepare => 'Prepare this approval';

  @override
  String get depositApprovalScope =>
      'Only this token approval will be sent. It costs native gas and does not deposit funds. Deposit submission requires a separate review, fresh reads and external verification of Aster availability and limits.';

  @override
  String get depositApprovalReview => 'Review token approval';

  @override
  String get depositApprovalConfirm => 'Confirm and open wallet';

  @override
  String get depositApprovalCancel => 'Cancel';

  @override
  String get depositApprovalStorage =>
      'The approval recovery record cannot be read or saved. New approvals are blocked. Retry storage recovery before continuing.';

  @override
  String get depositApprovalPending =>
      'This wallet has an unresolved approval. Check that transaction before sending another one.';

  @override
  String get depositApprovalNotNeeded =>
      'This amount needs no approval step. Deposit submission still requires verified platform limits and credit recovery.';

  @override
  String get depositApprovalChanged =>
      'Chain state or fees changed. Prepare and review the step again; nothing was sent.';

  @override
  String get depositApprovalUnknown =>
      'The wallet result is unknown. Do not repeat the approval. Use the original transaction hash from your wallet to check it.';

  @override
  String get depositApprovalMismatch =>
      'This transaction does not match the saved wallet, chain or nonce. The saved record was kept.';

  @override
  String get depositApprovalRecovery => 'Pending token approvals';

  @override
  String get depositApprovalOpenRecovery => 'Review pending approvals';

  @override
  String get depositApprovalRecoveryScope =>
      'Read-only chain checks never resend a transaction. A reported hash is not a receipt. Two observed confirmations are required here; later reorgs remain possible. No approval result proves a deposit or platform credit.';

  @override
  String get depositApprovalNoPending => 'No pending approvals for this wallet.';

  @override
  String get depositApprovalHash => 'Original transaction hash';

  @override
  String get depositApprovalHashHint =>
      'Paste the original hash, or a speed-up/cancellation hash from your wallet. Only the same wallet, chain and nonce can resolve this saved step. Leave blank to check the saved hash.';

  @override
  String get depositApprovalCheck => 'Check on-chain result';

  @override
  String get depositApprovalSent =>
      'The wallet request finished. Check the saved transaction; no receipt or allowance change has been confirmed yet.';

  @override
  String get depositApprovalReceiptPending =>
      'Chain confirmation is pending. Keep the saved record and check again; no transaction will be resent.';

  @override
  String get depositApprovalReceiptSucceeded =>
      'The approval transaction succeeded on-chain. Re-read the current allowance and estimate the next step separately. No deposit was sent.';

  @override
  String get depositApprovalReceiptReverted =>
      'The approval transaction reverted on-chain. Gas may have been spent. Re-read before preparing another step.';

  @override
  String get depositApprovalConfirmations => 'Observed confirmations';

  @override
  String get depositApprovalGasFee => 'Recorded execution gas fee';

  @override
  String get depositApprovalFeeScope =>
      'This fee uses receipt gasUsed × effectiveGasPrice (or the reported legacy price). Additional network fees may be separate.';

  @override
  String get depositApprovalNonce => 'Transaction nonce';

  @override
  String get depositApprovalPreparedAt => 'Prepared at (UTC)';

  @override
  String get walletTransactionInvalid =>
      'The wallet transaction details are invalid. Nothing was sent.';

  @override
  String get walletTransactionBusy =>
      'Another wallet transaction request is still pending. Wait for it to finish.';

  @override
  String get walletTransactionWrongChain =>
      'Reconnect the same wallet on the selected deposit network before sending this step.';

  @override
  String get walletTransactionPermission =>
      'This wallet session has no transaction sending permission. Disconnect and reconnect the same wallet to grant it.';

  @override
  String get depositApprovalReceiptReplaced =>
      'Another transaction consumed the saved nonce on-chain. The original approval is not confirmed. Re-read the current allowance before preparing anything else.';

  @override
  String get rebalanceTitle => 'Rebalance collateral';

  @override
  String get rebalanceScope =>
      'Use this when Multi-Assets Mode has a negative USDT wallet balance. Aster decides the asset conversion; this request has no amount or price parameter. Read the account before reviewing.';

  @override
  String get rebalanceRisk =>
      'This can convert account assets and change collateral. Conversion rates, costs and eligibility are determined by Aster; no conversion quote is available here. It does not withdraw funds or switch asset mode.';

  @override
  String get rebalanceRead => 'Read / check current account';

  @override
  String get rebalanceReadHint =>
      'Each read asks for two account signatures. Confirmation reads the mode and balances again, then requests a separate API signature and two result checks. Nothing runs automatically.';

  @override
  String get rebalanceReview => 'Review Rebalance';

  @override
  String get rebalanceConfirm => 'Sign and request Rebalance';

  @override
  String get rebalanceCancel => 'Cancel';

  @override
  String get rebalanceUsdt => 'USDT wallet balance';

  @override
  String get rebalanceUnknownUsdt =>
      'USDT wallet balance is unavailable. Rebalance and switching to Single-Asset Mode remain blocked until a complete read.';

  @override
  String get rebalanceNotNeeded =>
      'The current read does not show negative USDT in Multi-Assets Mode. No Rebalance request is available.';

  @override
  String get rebalanceRequired =>
      'Negative USDT must be handled before withdrawing or returning to Single-Asset Mode. Open Rebalance to review the current account; no action will run automatically.';

  @override
  String get rebalanceChanged =>
      'The account, configuration or review expired or changed. Read and review again; no new request was sent.';

  @override
  String get rebalanceStale => 'This account read is historical. Read again before reviewing.';

  @override
  String get rebalanceStorage =>
      'The Rebalance recovery record cannot be read or saved. New Rebalance requests, order submissions and contract setting changes are blocked until storage recovers.';

  @override
  String get rebalancePending =>
      'This wallet has an unresolved Rebalance. Check the current account; the request will never be resent automatically.';

  @override
  String get rebalanceUnknown =>
      'The original request result is unknown. Current balances cannot prove that request completed. The API has no documented lookup by nonce, so the record and mutation block remain. Do not repeat the request.';

  @override
  String get rebalanceReplyPending =>
      'The server response was saved. Read the current account to finish checking; this will not resend Rebalance.';

  @override
  String get rebalanceNoExchange =>
      'The server returned an empty response: no asset exchange was reported. The current account is shown separately.';

  @override
  String get rebalanceReported =>
      'The server reported an asset exchange. These are its returned balance and account reference, not a conversion quote or proof that all debt is cleared.';

  @override
  String get rebalancePermission =>
      'A fresh nonnegative USDT balance alone is not withdrawal permission or proof that Single-Asset Mode is allowed. Other account and platform checks still apply.';

  @override
  String get rebalanceNonce => 'Original request nonce';

  @override
  String get rebalanceAccountId => 'Reported account ID';

  @override
  String get rebalanceReportedBalance => 'Reported balance';

  @override
  String get rebalanceReportedTime => 'Reported update time (UTC)';

  @override
  String get rebalanceCurrentMode => 'Current asset mode';

  @override
  String get rebalanceReading => 'Reading current mode and balances…';

  @override
  String get rebalanceSending => 'Waiting for the signed request or account check…';

  @override
  String get rebalanceRecovery => 'Review Rebalance recovery';

  @override
  String get liveOrderPricing => 'Limit pricing';

  @override
  String get liveOrderPegHint =>
      'Aster sets the price once from the selected best bid or ask: when placing a limit order, or when a conditional limit order triggers. It does not keep chasing the book. Estimates use the selected current bid or ask; the engine price and fill may differ, especially at a future trigger.';

  @override
  String get liveOrderBbo => 'BBO';

  @override
  String get liveOrderPegInvalid =>
      'BBO requires a limit order with no manual price. It cannot be combined with a market, trailing, entire-close or attached-strategy order. Post Only BBO supports same-side level 1 only.';

  @override
  String get internalTransferTitle => 'Spot ↔ Futures transfer';

  @override
  String get internalTransferScope =>
      'Transfer the selected asset between your Aster Spot and Futures accounts using the current wallet.';

  @override
  String get internalTransferReadHint =>
      'Read both accounts and asset mode with 3 wallet signatures. Changing asset or direction reads them again. A full transfer normally needs 10 signatures, including confirmation checks and balance refresh.';

  @override
  String get internalTransferRisk =>
      'Moving collateral out of Futures can increase liquidation risk. Review the direction and amount before signing.';

  @override
  String get internalTransferDirection => 'Direction';

  @override
  String get internalTransferToFutures => 'Spot → Futures';

  @override
  String get internalTransferToSpot => 'Futures → Spot';

  @override
  String get internalTransferAsset => 'Asset';

  @override
  String get internalTransferAmount => 'Transfer amount';

  @override
  String get internalTransferMax => 'Max';

  @override
  String get internalTransferRead => 'Read transfer limits';

  @override
  String get internalTransferReading => 'Reading both accounts and asset mode…';

  @override
  String get internalTransferSending => 'Waiting for signatures or the transfer result…';

  @override
  String get internalTransferChecking =>
      'Transfer reported successful. Reading both account balances…';

  @override
  String get internalTransferMaximum => 'Source transferable amount';

  @override
  String get internalTransferSpotFree => 'Spot free amount';

  @override
  String get internalTransferFuturesWallet => 'Futures wallet amount';

  @override
  String get internalTransferLimitHint =>
      'The source limit is Spot free amount or the selected Futures asset’s maximum transferable amount. Max rounds down to the input step; Futures wallet amount is not a transfer limit.';

  @override
  String get internalTransferPrecisionHint =>
      'Input precision follows the website policy: at most 8 decimal places, with a 2-place fallback. This is not the token’s on-chain precision.';

  @override
  String get internalTransferReview => 'Review transfer';

  @override
  String get internalTransferConfirm => 'Sign and transfer once';

  @override
  String get internalTransferStale => 'Transfer data is stale. Read it again before reviewing.';

  @override
  String get internalTransferChanged =>
      'The wallet, balances, limits or asset mode changed, or the review expired. Read again and review the transfer.';

  @override
  String get internalTransferAssetUnavailable =>
      'The selected asset is not in the supported transfer list.';

  @override
  String get internalTransferPermission =>
      'Transfer permission is unavailable: the source must allow withdrawals and the destination must allow deposits.';

  @override
  String get internalTransferMaximumUnknown =>
      'The source transferable amount is missing. Transfer is unavailable until it can be read.';

  @override
  String get internalTransferInvalidAmount =>
      'Enter a positive amount using ordinary decimal notation.';

  @override
  String get internalTransferPrecision =>
      'The amount exceeds this asset’s supported input precision.';

  @override
  String get internalTransferTooLarge => 'The amount exceeds the source transferable amount.';

  @override
  String get internalTransferStorage =>
      'Transfer recovery storage is unavailable. Retry reading storage before submitting new orders, settings or transfers.';

  @override
  String get internalTransferPending =>
      'A previous transfer needs review. New transfers, orders and account settings are blocked.';

  @override
  String get internalTransferUnknown =>
      'The transfer outcome is unknown. The original client ID cannot be queried through a documented API. Balance changes do not prove completion. This record is retained and cannot be retried or cleared here; contact Aster with the original identifiers.';

  @override
  String get internalTransferReplyPending =>
      'Aster reported SUCCESS. Read both accounts to finish refreshing balances; do not resubmit the transfer.';

  @override
  String get internalTransferReported =>
      'Aster reported transfer SUCCESS; both account balances were read again. This internal transfer is not an on-chain transaction.';

  @override
  String get internalTransferClientId => 'Original client transfer ID';

  @override
  String get internalTransferTransactionId => 'Aster transfer ID';

  @override
  String get internalTransferEmpty => 'No assets are currently available for transfer.';

  @override
  String get internalTransferBlocked =>
      'Another pending request or account operation blocks new transfers. Review recovery notices before continuing.';

  @override
  String get spotOpenOrdersTitle => 'Spot open orders';

  @override
  String get spotOpenOrdersScope =>
      'Read all current Spot orders with the current wallet. Counts and filters use this Spot snapshot; a Perp symbol is not a Spot query scope. No automatic signatures.';

  @override
  String get spotOpenOrdersRead => 'Read Spot open orders';

  @override
  String get spotOpenOrdersRefresh => 'Refresh Spot open orders';

  @override
  String get spotOpenOrdersEmpty => 'No open Spot orders in this account.';

  @override
  String get spotOpenOrdersNoMatch => 'No Spot orders match this filter.';

  @override
  String get spotOpenOrdersFilter => 'Filter by Spot symbol or order reference';

  @override
  String get spotOpenOrdersUnits =>
      'Some Spot base/quote metadata could not be loaded. Amount units remain unknown until metadata is available.';

  @override
  String get spotOpenOrdersEvents =>
      'Events update individual Spot orders after a signed baseline. Disconnection, missing events or stale data require another explicit read; events cannot prove a complete account list.';

  @override
  String get spotOpenOrdersQuantityUnknown => 'Base total unknown · quote-sized market order';

  @override
  String get spotOpenOrdersQuoteQuantity => 'Original quote amount';

  @override
  String get spotOpenOrdersCapacity =>
      'Too many Spot order events to retain safely. Live updates stopped; read a fresh baseline to inspect current orders.';

  @override
  String get spotOpenOrdersPolicy => 'Time in force';

  @override
  String assetYieldUsdf(String percent) {
    return 'APY up to $percent%';
  }

  @override
  String assetYieldAsbnb(String percent) {
    return 'Reference APY $percent%';
  }

  @override
  String get assetYieldUsdfScope =>
      'Aster published base + trading APY. Trading requirements apply; this is not your realized return and is not added to balances.';

  @override
  String get assetYieldAsbnbScope =>
      'Lista published comprehensive APY for asBNB, including launchpool rewards. An estimate, not a guaranteed return or wallet balance.';

  @override
  String assetYieldSourceDate(String date) {
    return 'Source date: $date';
  }

  @override
  String assetYieldParts(String base, String trade) {
    return 'Base $base% + trading $trade%';
  }

  @override
  String assetYieldUpdated(String time) {
    return 'Publisher updated (UTC): $time';
  }

  @override
  String assetYieldReadTime(String time) {
    return 'Read (UTC): $time';
  }

  @override
  String get assetYieldStale =>
      'Historical or unverified yield data. Refresh to check the latest published rate.';

  @override
  String get assetYieldPaused => 'Yield updates paused while the app is inactive.';

  @override
  String get assetYieldInvalid =>
      'The yield source returned missing or inconsistent data. Retry to check again.';

  @override
  String get assetYieldNetwork =>
      'Could not reach the yield source. Check your connection and retry.';

  @override
  String get assetYieldFailed =>
      'The yield source is unavailable. The previous quote is retained; retry to check again.';

  @override
  String get assetYieldLoading => 'Reading public yield data…';

  @override
  String get assetYieldRefresh => 'Refresh yield data';

  @override
  String get pointsProgramTitle => 'Vanta Genesis Points';

  @override
  String get pointsProgramScope =>
      'Published by Vanta for its Orderly broker program. These points are separate from Aster balances and trading; this app does not assume Aster activity qualifies for rewards.';

  @override
  String get pointsCurrentCampaign => 'Current campaign';

  @override
  String pointsCycleNumber(String number) {
    return 'Campaign $number';
  }

  @override
  String get pointsCycleId => 'Campaign ID';

  @override
  String get pointsStatus => 'Published status';

  @override
  String get pointsStatusDraft => 'Draft';

  @override
  String get pointsStatusActive => 'Active';

  @override
  String get pointsStatusEnded => 'Ended';

  @override
  String get pointsStatusSettled => 'Settled';

  @override
  String get pointsStatusUnknown => 'Unknown';

  @override
  String get pointsPool => 'Total points pool';

  @override
  String get pointsPeriodStart => 'Start (UTC)';

  @override
  String get pointsPeriodEnd => 'End (UTC)';

  @override
  String get pointsBroker => 'Broker ID';

  @override
  String get pointsNoCurrentCampaign => 'No current campaign is published.';

  @override
  String get pointsNotRead => 'No verified data yet.';

  @override
  String get pointsLoading => 'Reading points data…';

  @override
  String get pointsPaused => 'Updates paused while the app is inactive.';

  @override
  String get pointsStale =>
      'This is an older or incomplete snapshot. Refresh to check the current data.';

  @override
  String pointsReadTime(String time) {
    return 'Read (UTC): $time';
  }

  @override
  String get pointsDataInvalid =>
      'The points service returned missing or inconsistent data. Previous data is retained.';

  @override
  String get pointsNetwork =>
      'Could not connect to the points service. Check your connection and retry.';

  @override
  String get pointsRateLimited => 'The points service is rate limiting requests. Try again later.';

  @override
  String get pointsUnavailable =>
      'The points service is unavailable. Previous data is retained; try again later.';

  @override
  String get pointsWalletRequired =>
      'Connect a wallet to read its published points. No personal score is assumed before a successful read.';

  @override
  String get pointsRefresh => 'Refresh this section';

  @override
  String get pointsStop => 'Stop waiting';

  @override
  String get pointsLeaderboard => 'Points leaderboard';

  @override
  String get pointsLeaderboardScope =>
      'Shows up to the first 100 returned rows, 20 per page, with ranks reported by the service. Absence does not establish a full ranking or zero points.';

  @override
  String get pointsSelectLeaderboard => 'Leaderboard scope';

  @override
  String get pointsTotalLeaderboard => 'Total points leaderboard';

  @override
  String get pointsNoRankings => 'No ranking rows were returned for this scope.';

  @override
  String pointsReturnedCount(int count) {
    return 'Showing $count returned ranking row(s).';
  }

  @override
  String get pointsPrevious => 'Previous';

  @override
  String get pointsNext => 'Next';

  @override
  String pointsPageNumber(int page, int pages) {
    return 'Page $page of $pages';
  }

  @override
  String pointsRankNumber(String number) {
    return 'Rank #$number';
  }

  @override
  String get pointsScore => 'Points';

  @override
  String get pointsSettled => 'Settled points';

  @override
  String get pointsSpecial => 'Special points';

  @override
  String get pointsCurrentScore => 'Current campaign points (as reported)';

  @override
  String get pointsMyPoints => 'My points';

  @override
  String get pointsWalletReadScope =>
      'Read sends this wallet address to Vanta’s points service without a signature. It does not change the active Aster account.';

  @override
  String get pointsConnectWallet => 'Connect wallet';

  @override
  String get pointsMyTotal => 'My total points';

  @override
  String get pointsRankUnknown =>
      'Not found in the returned total leaderboard; the full rank is unknown.';

  @override
  String get pointsReadWallet => 'Read my points and history';

  @override
  String get pointsSelectHistory => 'Past points scope';

  @override
  String get pointsAccumulated => 'Accumulated points';

  @override
  String get pointsSelectedHistory => 'Points in selected scope';

  @override
  String get pointsNoHistory =>
      'No campaign history was returned. Missing campaign rows remain unknown.';

  @override
  String get eventsTitle => 'Trading events';

  @override
  String get eventsScope =>
      'Vanta Orderly campaigns. Registration, trading volume and rewards belong to this program; Aster trades in this app are not assumed eligible.';

  @override
  String get eventsEmpty => 'No published trading events.';

  @override
  String eventsCount(int count) {
    return '$count published events';
  }

  @override
  String get eventDetails => 'Event details';

  @override
  String get eventRegistrationOpen => 'Registration open';

  @override
  String get eventImageUnavailable => 'Event image unavailable';

  @override
  String get eventLinkFailed => 'Could not open this link. Please try again.';

  @override
  String get eventOwnVolume => 'Your trading volume (USDC)';

  @override
  String get eventRankingScope =>
      'Up to 30 returned participants, 10 per page. Ranks and USDC trading volumes come from Vanta; this is not the complete ranking.';

  @override
  String get eventMyParticipation => 'My participation';

  @override
  String get eventPersonalScope =>
      'Refresh sends this EVM wallet address to Vanta to check registration and performance, without signing.';

  @override
  String get eventRegistrationUnknownStatus => 'Registration has not been checked.';

  @override
  String get eventRegistered => 'Registration verified';

  @override
  String get eventNotRegistered => 'Not registered at the last check';

  @override
  String get eventBlockedBlacklist =>
      'This address is excluded by the campaign’s eligibility rules.';

  @override
  String eventBlockedExclusive(String name) {
    return 'Already registered for an exclusive event: $name';
  }

  @override
  String get eventAnotherCampaign => 'another event';

  @override
  String get eventBlocked => 'Registration is unavailable for this address.';

  @override
  String get eventRegistrationReadFirst =>
      'Refresh registration status before joining. Current campaign rules will be checked again before submission.';

  @override
  String get eventRegistrationConfirm => 'Confirm registration';

  @override
  String get eventRegistrationSigningScope =>
      'Sign a registration message with this wallet for Vanta. This does not transfer funds, place an order or guarantee rewards.';

  @override
  String get eventCancel => 'Cancel';

  @override
  String get eventRegister => 'Register now';

  @override
  String get eventChecking => 'Checking current campaign and registration…';

  @override
  String get eventSigning => 'Confirm the registration message in your wallet…';

  @override
  String get eventSending => 'Submitting registration…';

  @override
  String get eventAcknowledged =>
      'Vanta accepted the request. Refresh to verify registration; rewards are not confirmed.';

  @override
  String get eventRegistrationUnknown =>
      'The registration result is unknown. Refresh registration status before trying again; this app will not resend automatically.';

  @override
  String get eventRegistrationChanged =>
      'The wallet, campaign rules or registration eligibility changed. Refresh and review again.';

  @override
  String get eventWalletReconnect =>
      'Reconnect this wallet before signing the registration message.';

  @override
  String get eventSignatureRejected => 'The wallet declined the registration message.';

  @override
  String get eventSignatureUnavailable =>
      'The wallet could not sign this registration message. Please reconnect and try again.';

  @override
  String get eventRegistrationCount => 'Registered participants';

  @override
  String get eventTotalVolume => 'Total event trading volume (USDC)';

  @override
  String get eventRewardPool => 'Core reward pool';

  @override
  String get eventActivityRules => 'Activity rules';

  @override
  String get eventCampaignRules => 'Campaign rules';

  @override
  String get eventEnded => 'Event ended';

  @override
  String eventCountdown(String stage, String days, String hours, String minutes, String seconds) {
    return '$stage: ${days}d $hours:$minutes:$seconds';
  }

  @override
  String get eventUntilEnd => 'Time until end';

  @override
  String get eventUntilStart => 'Time until start';

  @override
  String get eventRegistrationOpens => 'Registration opens (UTC)';

  @override
  String get eventTasks => 'Tasks';

  @override
  String get eventNoTasks => 'No tasks published.';

  @override
  String get eventTaskTarget => 'Published target';

  @override
  String get eventTaskProgress => 'Verified progress';

  @override
  String get eventTaskUnknown => 'Task progress has not been verified.';

  @override
  String get eventTaskCompleted =>
      'Published target reached; rewards remain subject to campaign rules.';

  @override
  String get eventTaskPending => 'Target not yet reached';

  @override
  String get eventOpenTrading => 'Trade on Vanta website';

  @override
  String get eventTradingEligibility =>
      'Registration and the active event period are required before trading for this campaign.';

  @override
  String get eventRankingVolume => 'Trading volume (USDC)';

  @override
  String get eventIdLabel => 'Event ID';

  @override
  String get eventMyRank => 'My campaign rank';

  @override
  String get authorizationTitle => 'Aster trading authorization';

  @override
  String get authorizationScope =>
      'Authorize a device signing key for the connected account. Account queries and trading requests use this key without repeated wallet prompts. Aster validates the grant.';

  @override
  String get authorizationEnable => 'Enable trading with this wallet';

  @override
  String get authorizationCheck => 'Check signed API access';

  @override
  String get authorizationCheckScope =>
      'Read Futures and Spot accounts with the device agent. This sends no orders. Accepted reads do not prove trading permissions.';

  @override
  String get authorizationReview => 'Review authorization';

  @override
  String get authorizationGrant =>
      'Signer: device agent. Spot and Futures trading: allowed. Withdrawal: not granted. Valid for 30 days. No builder or fee grant.';

  @override
  String get authorizationConfirm => 'Confirm and sign authorization';

  @override
  String get authorizationAcknowledged =>
      'Aster acknowledged the request. Run the access check to confirm what this wallet can read and the reported trading status.';

  @override
  String get authorizationUnknown =>
      'The authorization result is unknown. Check access before making another explicit request.';

  @override
  String get authorizationFuturesRead => 'Futures signed API read';

  @override
  String get authorizationSpotRead => 'Spot signed API read';

  @override
  String get authorizationReadAccepted => 'Signed read accepted for this wallet';

  @override
  String get authorizationCanTrade =>
      'Account reports canTrade = true. This does not prove order execution or all agent permissions.';

  @override
  String get authorizationCannotTrade => 'Account reports canTrade = false';

  @override
  String get authorizationPermissionUnknown => 'Account trading permission is unknown';

  @override
  String get authorizationSpotPermissionUnknown =>
      'Spot read acceptance does not confirm permission to place Spot orders.';

  @override
  String get subaccountActions => 'Manage subaccounts';

  @override
  String get subaccountActionsScope =>
      'Manage linked accounts using the connected master wallet. Generated subaccount keys are kept in device secure storage.';

  @override
  String get subaccountCreate => 'Create subaccount';

  @override
  String get subaccountCreateExternalOnly =>
      'Only accounts signed in with an external EOA wallet can create subaccounts. Privy embedded wallets cannot create subaccounts.';

  @override
  String get subaccountFreeze => 'Freeze subaccount';

  @override
  String get subaccountUnfreeze => 'Unfreeze subaccount';

  @override
  String get subaccountTransfer => 'Transfer between master and child';

  @override
  String get subaccountChildAddress => 'Child wallet address';

  @override
  String get subaccountName => 'Subaccount name';

  @override
  String get subaccountFrom => 'Source wallet';

  @override
  String get subaccountTo => 'Destination wallet';

  @override
  String get subaccountTransferDirection => 'Market direction';

  @override
  String get subaccountMasterToChild => 'Master → Child';

  @override
  String get subaccountChildToMaster => 'Child → Master';

  @override
  String get subaccountTransferScope =>
      'Only master/child addresses are supported. Aster validates the relationship, freeze status, available funds and asset precision at submission. Available child funds are not supplied by the directory.';

  @override
  String get subaccountActionPrepare => 'Read qualification and prepare';

  @override
  String get subaccountActionReview => 'Review account operation';

  @override
  String get subaccountActionConfirm => 'Confirm and sign submission';

  @override
  String get subaccountReviewExpires =>
      'This review expires after 45 seconds. Expiry requires preparing and signing again.';

  @override
  String get subaccountChildSignatureInstructions =>
      'Use a wallet you already control. Copy this EIP-712 request and sign it with the child wallet using a trusted wallet tool, then paste only the resulting signature. The app verifies the child address before asking the master to sign. Never enter a private key or seed phrase.';

  @override
  String get subaccountCopyChallenge => 'Copy child signing request';

  @override
  String get subaccountChildSignature => 'Child signature (hex)';

  @override
  String get subaccountKnownAddresses => 'Addresses from acknowledged creation requests';

  @override
  String get subaccountSwitch => 'Switch wallet account';

  @override
  String get subaccountSwitchScope =>
      'Connect the selected wallet to switch accounts. If the connection is declined, your current account remains active.';

  @override
  String get subaccountMasterRequired =>
      'Aster did not return a valid master-account directory for this wallet.';

  @override
  String get subaccountLimitReached => 'This master already has ten subaccounts.';

  @override
  String get subaccountInputInvalid =>
      'Check the child address, name, asset and positive amount (up to 18 decimal places). Master and child must differ.';

  @override
  String get subaccountChildSignatureInvalid =>
      'The child signature does not match this address and signing request.';

  @override
  String get walletOperationHistory => 'Saved account and funding requests';

  @override
  String get walletOperationReload => 'Reload saved requests';

  @override
  String get walletOperationReference => 'Request nonce';

  @override
  String get walletOperationStorage =>
      'Saved request storage is unavailable. New submissions are blocked; retry loading storage.';

  @override
  String get walletOperationPending =>
      'An earlier request from this wallet has an unknown result. Do not submit it again. Resolve it with Aster before another submission.';

  @override
  String get walletOperationUnknown =>
      'The request may have been accepted. Its result is unknown and its unsigned terms remain saved. No automatic retry will be sent.';

  @override
  String get walletOperationAcknowledged =>
      'Aster acknowledged this request. This is not a fresh status, balance or on-chain confirmation.';

  @override
  String get withdrawalSubmit => 'Withdraw';

  @override
  String get withdrawalScope =>
      'Withdraw to this wallet’s own registered address. A fresh signed master-account directory, withdrawal limits and fee estimate are required. Spot and Futures balances remain separate.';

  @override
  String get withdrawalPrepare => 'Check limits and prepare withdrawal';

  @override
  String get withdrawalReview => 'Review withdrawal';

  @override
  String get withdrawalFee => 'Withdrawal fee (asset units)';

  @override
  String get withdrawalMarket => 'Source account';

  @override
  String get withdrawalChain => 'Destination chain ID';

  @override
  String get withdrawalReceiver => 'Receiving address';

  @override
  String get withdrawalConfirmScope =>
      'Confirmation refreshes qualification, limits and fees, then requests a business signature and an API signature. A changed fee requires a new review. Amount plus fee is checked conservatively against the reported limits. No request is resent after an unknown result.';

  @override
  String get withdrawalConfirm => 'Confirm withdrawal and sign';

  @override
  String get withdrawalAcknowledged =>
      'Aster returned a withdrawal request ID. Check history for completion; the returned signature digest is not a transaction hash.';

  @override
  String get withdrawalAmountInvalid =>
      'Enter a positive amount within the selected token precision and a supported automatic withdrawal route.';

  @override
  String get withdrawalAssetChanged =>
      'Asset availability, contract or precision changed. Reload the asset list and prepare again.';

  @override
  String get withdrawalFeeChanged => 'The fee changed. Prepare a new review before signing.';

  @override
  String get withdrawalLimitsUnknown =>
      'A required withdrawal limit or asset USD price is unavailable. Submission is blocked.';

  @override
  String get withdrawalLimitExceeded =>
      'Amount plus fee exceeds a reported asset, chain or USD limit.';

  @override
  String get withdrawalRecovery => 'Check withdrawal completion';

  @override
  String get withdrawalRecoveryScope =>
      'Read signed history and match the exact returned request ID, account, chain, asset and amount. A request without a returned ID cannot be resolved from a balance change or a similar history row.';

  @override
  String get withdrawalOpenHistory => 'Open and refresh signed history';

  @override
  String get withdrawalNotReconciled => 'No exact matching completion record has been read.';

  @override
  String get withdrawalHistoryStale =>
      'The matching history snapshot is historical; refresh to confirm current status.';

  @override
  String get withdrawalProcessing => 'Aster reports this withdrawal is processing.';

  @override
  String get withdrawalCompleted => 'Aster reports this withdrawal completed.';

  @override
  String get withdrawalFailed => 'Aster reports this withdrawal failed.';

  @override
  String get depositSubmissionScope =>
      'Submit depositFor from this wallet to its own Spot or Futures account. Each transaction is reviewed and signed separately. Approval is a separate step.';

  @override
  String get depositPlatformLimitsUnknown =>
      'User and platform remaining deposit caps require Aster website login and are unavailable here. They are unknown, not unlimited. Verify current availability and caps on Aster before proceeding. Gas estimation does not prove platform credit.';

  @override
  String get depositLimitsAcknowledgement =>
      'I checked current deposit availability and limits on Aster for this amount.';

  @override
  String get depositSubmissionPrepare => 'Prepare deposit transaction';

  @override
  String get depositSubmissionReview => 'Review deposit transaction';

  @override
  String get depositSubmissionConfirm => 'Confirm deposit and open wallet';

  @override
  String get depositSubmissionSent =>
      'Transaction response saved. Open recovery to check the chain and platform credit. A wallet response does not prove completion.';

  @override
  String get depositSubmissionRecovery => 'Recover pending deposit';

  @override
  String get depositSubmissionRecoveryScope =>
      'Check the original or matching replacement transaction and its canonical receipt. Chain success stays pending until signed Aster history matches the transaction hash, account, chain, asset and exact amount with SUCCESS. No automatic resend or deletion of unknown requests.';

  @override
  String get depositSubmissionStorage =>
      'Deposit recovery storage is unavailable. New deposits are blocked; reload saved records.';

  @override
  String get depositSubmissionPending =>
      'A deposit from this wallet still needs chain or platform confirmation.';

  @override
  String get depositSubmissionNoPending => 'No pending deposit for this wallet.';

  @override
  String get depositSubmissionUnknown =>
      'The wallet may have submitted the transaction. Keep the saved record and recover its status before another deposit.';

  @override
  String get depositSubmissionChanged =>
      'Balance, allowance, transaction or Gas changed. Prepare and review again.';

  @override
  String get depositSubmissionApprovalNeeded =>
      'ERC-20 allowance is insufficient. Complete and verify the separate approval step first.';

  @override
  String get depositSubmissionHashNeeded =>
      'Read and bind a matching transaction hash before checking platform credit.';

  @override
  String get depositSubmissionChainPending =>
      'A matching successful chain receipt with at least two observed confirmations is required.';

  @override
  String get depositSubmissionCreditPending =>
      'Platform credit has not been confirmed by an exact SUCCESS record. The deposit remains saved.';

  @override
  String get depositSubmissionCheckChain => 'Check chain receipt';

  @override
  String get depositSubmissionCheckCredit => 'Sign and check platform credit';

  @override
  String get depositSubmissionChainSucceeded =>
      'Chain transaction succeeded; platform credit is still unconfirmed.';

  @override
  String get depositSubmissionCredited =>
      'Chain success and exact Aster SUCCESS deposit record were observed.';

  @override
  String get depositVerifiedMinimumScope =>
      'The public catalog does not report a minimum. Enter the minimum in asset units after verifying it on Aster; enter 0 only if Aster explicitly reports no positive minimum. This is your external check, not a value read by the app.';

  @override
  String get depositVerifiedMinimum => 'Minimum verified on Aster (asset units)';

  @override
  String get depositTransactionBusy =>
      'Another approval or deposit wallet request is still active. Wait for it to finish before submitting.';

  @override
  String get subaccountSwitchEntered => 'Switch to entered wallet address';

  @override
  String get authorizationWithdrawOption => 'Also request withdrawal permission';

  @override
  String get authorizationWithdrawScope =>
      'Aster requires a nonempty IP/CIDR whitelist for this permission. Only use verified wallet/API egress IPs; a mobile network IP may change. This grant does not submit a withdrawal.';

  @override
  String get authorizationIpWhitelist => 'IP/CIDR whitelist (space separated)';

  @override
  String get authorizationWithdrawGrant =>
      'Signer: same wallet. Spot trading, Futures trading and withdrawal: allowed. IP restricted as shown. Valid for 30 days. No builder or fee grant.';

  @override
  String get authorizationCanWithdraw =>
      'Account reports canWithdraw = true; this does not confirm every agent/IP permission or a completed withdrawal.';

  @override
  String get authorizationCannotWithdraw => 'Account reports canWithdraw = false';

  @override
  String get authorizationWithdrawUnknown => 'Account withdrawal permission is unknown';

  @override
  String get authorizationIpInvalid =>
      'Enter 1–16 valid literal IP addresses or CIDRs, separated by spaces. Withdrawal permission requires a nonempty whitelist.';

  @override
  String get assetMetadataTitle => 'Asset details';

  @override
  String get assetMetadataRefresh => 'Refresh asset names and icons';

  @override
  String get assetMetadataNamesFailed =>
      'Asset names could not be refreshed. Asset identifiers remain available.';

  @override
  String get assetMetadataIconsFailed =>
      'Asset icons could not be refreshed. Balances remain available.';

  @override
  String get assetMetadataStale =>
      'Showing previously loaded asset details. Refresh to check for updates.';

  @override
  String get assetMetadataPaused => 'Asset detail refresh is paused while the app is inactive.';

  @override
  String get assetMetadataEmpty => 'No additional asset details are available.';

  @override
  String get assetMetadataNoIcon => 'Asset icon unavailable';

  @override
  String get assetMetadataRetryIcon => 'Reload asset icon';

  @override
  String get eventRetailTab => 'Trading events';

  @override
  String get eventChannelTab => 'Channel events';

  @override
  String get eventChannelName => 'Channel';

  @override
  String get eventChannelRankingScope =>
      'Channel ranking shows up to 10 entries; ranks outside this list remain unknown.';

  @override
  String get eventEngagementTitle => 'Channel task progress';

  @override
  String get eventEngagementScope =>
      'Manual refresh shares your current wallet address with the Vanta campaign service. Tasks belong to Vanta Orderly campaigns; Aster trades and deposits do not count.';

  @override
  String get eventEngagementVerified => 'Task completion verified.';

  @override
  String get eventEngagementAcknowledged =>
      'Request acknowledged; task completion is unverified. Refresh progress.';

  @override
  String get eventEngagementUnknown =>
      'A previous task submission has an unknown result. Query its progress without submitting again.';

  @override
  String get eventEngagementReadFirst =>
      'Refresh the event, participation and task progress before confirming an eligible task.';

  @override
  String get eventEngagementIneligible =>
      'Task eligibility or event time changed. Refresh before trying again.';

  @override
  String get eventEngagementStorage =>
      'Could not save or read the task journal. Submission stopped. Check device storage and refresh progress.';

  @override
  String get eventEngagementBusy => 'Another campaign task is in progress. Please wait.';

  @override
  String get eventEngagementReconcileFailed =>
      'Could not reconcile task progress. Pending status is preserved; retry the query.';

  @override
  String get eventDailyDate => 'Task date (UTC)';

  @override
  String get eventDailyVolume => 'Daily volume (USDC)';

  @override
  String get eventCheckedIn => 'Checked in today';

  @override
  String get eventNotCheckedIn => 'Not checked in today';

  @override
  String eventCheckedDays(int count) {
    return 'Days checked in: $count';
  }

  @override
  String get eventDailyExpired => 'Task date is stale. Refresh today’s progress.';

  @override
  String get eventTrackedMetric => 'Tracked metric';

  @override
  String get eventMilestoneCurrent => 'Cumulative metric progress';

  @override
  String get eventMilestoneUnlocked => 'Task milestone reached';

  @override
  String get eventMilestoneRemaining => 'Remaining to target';

  @override
  String get eventNewRegistration => 'Complete campaign registration';

  @override
  String get eventNewWallet => 'Wallet connection task';

  @override
  String get eventNewDeposit => 'Net deposit task';

  @override
  String get eventDepositRequired => 'Server deposit target';

  @override
  String get eventDepositCurrent => 'Recorded net deposit';

  @override
  String get eventDepositRemaining => 'Remaining net deposit';

  @override
  String get eventDepositChain => 'Deposit chain ID';

  @override
  String get eventWebsiteDeposit => 'Deposit on Vanta website';

  @override
  String get eventRewardNotCredit =>
      'Task completion or a published reward does not prove a reward was paid.';

  @override
  String get eventCheckIn => 'Confirm daily check-in';

  @override
  String get eventRecordWallet => 'Confirm wallet connection task';

  @override
  String get eventEngagementSigningScope =>
      'Sign and submit this Vanta campaign task message with your current wallet. No wallet is created or funds sent. Eligibility is checked again after signing.';

  @override
  String get eventNetworkVolume => 'Network volume (USDC)';

  @override
  String get eventPersonalTotalVolume => 'Own + network volume (USDC)';

  @override
  String get eventWhitelistCount => 'Published allowlist count';

  @override
  String get eventUpcoming => 'Upcoming';

  @override
  String get assistantTitle => 'Vanta AI';

  @override
  String get assistantIntro =>
      'Explore markets, compare scenarios, and understand risk. Include a symbol and timeframe for a more useful answer.';

  @override
  String get assistantScope =>
      'AI responses may be inaccurate. This conversation does not place orders or attach your account balances.';

  @override
  String get assistantAuthorize => 'Authorize with wallet';

  @override
  String get assistantRestore => 'Restore saved session';

  @override
  String get assistantReady => 'Wallet verified for AI';

  @override
  String get assistantAuthHint =>
      'Authorize with your connected wallet, or restore a session saved on this device. A message signature requires your separate confirmation.';

  @override
  String get assistantReview => 'Review sign-in message';

  @override
  String get assistantReviewHint =>
      'Review the exact message below. Confirmation opens your current wallet to sign this AI login message. This does not authorize trading. The request expires after 5 minutes.';

  @override
  String get assistantSign => 'Confirm and sign';

  @override
  String get assistantCancel => 'Cancel';

  @override
  String get assistantStop => 'Stop';

  @override
  String get assistantSend => 'Send';

  @override
  String get assistantPrompt => 'Ask Vanta AI…';

  @override
  String get assistantInputHint =>
      'Up to 12,000 UTF-16 characters. Sending shares this prompt and recent completed messages with Vanta AI.';

  @override
  String get assistantGuide =>
      'Try: compare BTC scenarios on the 4-hour chart, with risks and invalidation levels.';

  @override
  String get assistantEmpty => 'Your conversation will appear here.';

  @override
  String get assistantYou => 'You';

  @override
  String get assistantReply => 'Vanta AI';

  @override
  String get assistantExplanation => 'Returned explanation';

  @override
  String get assistantCopy => 'Copy message';

  @override
  String get assistantCopied => 'Copied';

  @override
  String get assistantCopyFailed => 'Could not copy. Select the text to copy it manually.';

  @override
  String get assistantCopyAddress => 'Copy wallet address';

  @override
  String get assistantRemoteImage => 'Remote image hidden';

  @override
  String get assistantStreaming => 'Receiving response…';

  @override
  String get assistantInterrupted =>
      'Stopped or interrupted. Partial content is saved; nothing will resume automatically.';

  @override
  String get assistantTruncated => 'Response reached its length limit.';

  @override
  String get assistantReplyFailed =>
      'Response incomplete. Review partial content before sending another question.';

  @override
  String get assistantClear => 'Clear conversation';

  @override
  String get assistantClearConfirm =>
      'Clear this wallet’s conversation and draft on this device? This cannot be undone and does not delete server records.';

  @override
  String get assistantForget => 'Forget saved AI session';

  @override
  String get assistantForgetConfirm =>
      'Remove this wallet’s saved AI credentials from this device? Conversation history is retained. This does not revoke the server session.';

  @override
  String get assistantRetryHistory => 'Read history again';

  @override
  String get assistantRetrySave => 'Retry saving';

  @override
  String get assistantHistoryBlocked =>
      'History could not be read safely. Read it again or explicitly clear it before sending.';

  @override
  String get assistantUsage => 'Daily usage (UTC)';

  @override
  String get assistantReadUsage => 'Read usage';

  @override
  String get assistantUsageUnknown => 'Usage has not been read. Remaining quota is unknown.';

  @override
  String get assistantQuotaStale =>
      'This usage snapshot is stale. Read again to check the current UTC day.';

  @override
  String get assistantUnknown => 'Unknown';

  @override
  String get assistantPreparing => 'Requesting sign-in message…';

  @override
  String get assistantSigning => 'Waiting for wallet and verification…';

  @override
  String get assistantRestoring => 'Checking saved session…';

  @override
  String get assistantLoadingHistory => 'Reading saved conversation…';

  @override
  String get assistantReadingUsage => 'Reading daily usage…';

  @override
  String get assistantClearing => 'Updating local storage…';

  @override
  String get assistantWalletRequired => 'Connect an EVM wallet to use Vanta AI.';

  @override
  String get assistantUnavailable =>
      'Vanta AI is unavailable. Your input is preserved; try again later.';

  @override
  String get assistantAuthorization =>
      'AI session could not be verified. Restore it or authorize again.';

  @override
  String get assistantBinding => 'The server did not confirm this wallet’s link to the AI account.';

  @override
  String get assistantBusy => 'Another AI request is still finishing. Please try again shortly.';

  @override
  String get assistantCancelled => 'Request stopped.';

  @override
  String get assistantChallengeExpired => 'The sign-in request expired. Request a new message.';

  @override
  String get assistantChallengeInvalid =>
      'The sign-in message could not be verified. Nothing was signed.';

  @override
  String get assistantSessionChanged => 'Wallet or session changed. Start this action again.';

  @override
  String get assistantConfiguration =>
      'AI service configuration is unavailable. Please try again later.';

  @override
  String get assistantInvalidInput => 'Enter a question of at most 12,000 UTF-16 characters.';

  @override
  String get assistantInvalidResponse =>
      'The AI service returned an unreadable response. Your input is preserved.';

  @override
  String get assistantEmptyReply => 'No answer was returned. Your question is preserved.';

  @override
  String get assistantQuotaExceeded =>
      'The AI service reported that your daily quota is exhausted.';

  @override
  String get assistantTimeout =>
      'The AI request timed out. Partial content and input are preserved.';

  @override
  String get assistantTooLarge =>
      'The reply exceeded the supported size. Partial content is preserved.';

  @override
  String get assistantStorage => 'Could not access this wallet’s saved AI data. Please retry.';

  @override
  String get assistantStorageCapacity =>
      'Only the most recent conversation that fits device storage can be saved.';

  @override
  String get assistantNoSavedSession =>
      'No AI session is saved for this wallet on this device. Authorize with your wallet first.';

  @override
  String get assistantClearFailed => 'Could not clear this conversation. Please try again.';

  @override
  String get assistantLinkUnavailable =>
      'This link could not be opened. Only HTTPS links are supported.';

  @override
  String get assistantLocalHistoryHint =>
      'Recent conversation and draft are stored securely on this device for this wallet.';

  @override
  String assistantCharacterCount(int count) {
    return '$count / 12,000 UTF-16 characters';
  }

  @override
  String assistantUsageValues(String day, String used, String remaining) {
    return 'Date $day · Used $used · Remaining $remaining';
  }

  @override
  String get collateralContribution => 'Asset contribution (reference)';

  @override
  String get collateralCalculation => 'Contribution calculation';

  @override
  String get collateralFormula =>
      'Cross equity = cross wallet balance + crossed unrealized PnL. Contribution = min(equity × bid rate, equity × ask rate). Negative equity uses the more negative value.';

  @override
  String get collateralCrossEquity => 'Cross equity';

  @override
  String get collateralBidRate => 'Bid rate (USD per asset)';

  @override
  String get collateralAskRate => 'Ask rate (USD per asset)';

  @override
  String get collateralScope =>
      'Reference for assets eligible as multi-asset margin, using the signed account snapshot and public collateral rates. This does not confirm the active margin mode or represent order funds, withdrawal limits, or total portfolio value.';

  @override
  String get collateralEligibilityUnknown =>
      'Collateral eligibility is unknown. Read the account again to check.';

  @override
  String get collateralEquityUnknown =>
      'Cross wallet balance or crossed unrealized PnL is missing. Read the account again; missing values are not treated as zero.';

  @override
  String get collateralEventsNeedRead =>
      'Account events changed this snapshot. Read the account again to verify cross equity.';

  @override
  String get collateralRatesUnknown =>
      'Collateral bid/ask rates are unavailable. Refresh public asset prices to retry.';

  @override
  String get collateralStale =>
      'Contribution uses a stale snapshot. Refresh account balances and public prices before relying on it.';

  @override
  String collateralAccountTime(String time) {
    return 'Account snapshot (UTC): $time';
  }

  @override
  String collateralRateTime(String time) {
    return 'Rate timestamp (UTC): $time';
  }

  @override
  String get collateralLiveMarks => 'Crossed PnL recomputed from public mark prices.';

  @override
  String get collateralSnapshotPnl =>
      'Using signed crossed-PnL snapshot; complete live marks or position fields are unavailable.';

  @override
  String collateralMarkTime(String time) {
    return 'Oldest mark timestamp (UTC): $time';
  }

  @override
  String get marginAdjustTitle => 'Adjust isolated margin';

  @override
  String get marginAdjustScope =>
      'Use the connected wallet to read and confirm one isolated position. Signing and final amounts remain subject to Aster permissions and validation.';

  @override
  String get marginAdjustRead => 'Read margin and limits';

  @override
  String get marginAdjustReadHint =>
      'Reads the account, position and risk tiers with separate signatures. Nothing is submitted until you confirm. Limits expire after 30 seconds.';

  @override
  String get marginAdjustAdd => 'Add margin';

  @override
  String get marginAdjustRemove => 'Remove margin';

  @override
  String get marginAdjustAmountLabel => 'Margin amount';

  @override
  String get marginAdjustAmount =>
      'Enter a positive amount within the current limit, with up to 8 decimal places.';

  @override
  String get marginAdjustMaximum => 'Current maximum';

  @override
  String get marginAdjustMax => 'Max (2 decimals)';

  @override
  String get marginAdjustWallet => 'Current isolated wallet margin';

  @override
  String get marginAdjustNextWallet => 'Isolated wallet margin after adjustment';

  @override
  String get marginAdjustLiquidation => 'Estimated liquidation price after adjustment';

  @override
  String get marginAdjustPreviewHint =>
      'Reference only, using the signed mark price and risk tiers. Quantity and entry price stay the same. Actual liquidation price is read again after confirmation.';

  @override
  String get marginAdjustReview => 'Review adjustment';

  @override
  String get marginAdjustConfirm => 'Sign and submit adjustment';

  @override
  String get marginAdjustConfirmHint =>
      'Re-read limits, then sign and submit once. The result is checked by the original reference and exact terms; balances alone cannot prove success. Further signatures refresh the position, account and risk tiers.';

  @override
  String get marginAdjustReference => 'Adjustment reference';

  @override
  String get marginAdjustHistory => 'Margin adjustment records';

  @override
  String get marginAdjustHistoryEmpty => 'No margin adjustment records for this wallet.';

  @override
  String get marginAdjustCheck => 'Check original reference';

  @override
  String get marginAdjustVerified => 'Exact adjustment found in Aster history.';

  @override
  String get marginAdjustUnknown =>
      'Outcome unconfirmed. Keep the original reference and check again; do not resubmit.';

  @override
  String get marginAdjustRejected =>
      'Aster explicitly rejected this adjustment. No successful adjustment is claimed.';

  @override
  String get marginAdjustStorage =>
      'Margin records are unavailable or could not be saved. Submission is blocked; reload the records.';

  @override
  String get marginAdjustReload => 'Reload saved records';

  @override
  String get marginAdjustExpired =>
      'Margin information expired or changed. Read the limits again before confirming.';

  @override
  String get marginAdjustChanged =>
      'The position, margin or risk tiers changed. Read again and review the new terms.';

  @override
  String get marginAdjustClosed =>
      'This position is closed or has zero quantity. It cannot be adjusted.';

  @override
  String get marginAdjustUnsupported =>
      'Only a nonzero isolated linear position with known units supports this adjustment.';

  @override
  String get marginAdjustInsufficient =>
      'Aster reports insufficient available or isolated margin. Read the limits again.';

  @override
  String get marginAdjustSubmitting => 'Submitting the confirmed adjustment once…';

  @override
  String get marginAdjustChecking => 'Checking history, actual position and account…';

  @override
  String get marginAdjustStop => 'Stop waiting';

  @override
  String get marginAdjustStopHint =>
      'Leaving or stopping does not cancel a sent request. Saved pending records are recovered without resubmission.';

  @override
  String get marginAdjustActualLiquidation => 'Latest actual liquidation price';

  @override
  String get marginAdjustRatio => 'Isolated margin ratio';

  @override
  String get marginAdjustEquityRisk =>
      'Margin equity is zero or negative; liquidation risk is elevated.';

  @override
  String get marginAdjustRatioHint =>
      'Maintenance margin ÷ (isolated wallet margin + unrealized PnL), from the same account snapshot.';

  @override
  String get marginAdjustOverMaximum => 'Amount exceeds the available limit.';

  @override
  String get attachedOrderAdvanced => 'Advanced exit settings';

  @override
  String get attachedOrderInputMode => 'Input mode';

  @override
  String get attachedOrderPnlMode => 'PnL amount';

  @override
  String get attachedOrderPriceMode => 'Trigger price';

  @override
  String get attachedOrderRoiMode => 'Margin ROI (%)';

  @override
  String attachedOrderPnlInput(String asset) {
    return 'PnL amount ($asset)';
  }

  @override
  String get attachedOrderExecution => 'Exit execution';

  @override
  String get attachedOrderManualLimit => 'Manual limit';

  @override
  String get attachedOrderAutomaticLimit => 'Limit at trigger price';

  @override
  String attachedOrderLimitPrice(String asset) {
    return 'Exit limit price ($asset)';
  }

  @override
  String get attachedOrderTriggerPreview => 'Indicative trigger';

  @override
  String get attachedOrderGrossPnl => 'Estimated gross PnL';

  @override
  String get attachedOrderGrossRoi => 'Estimated gross ROI';

  @override
  String get attachedOrderRoundedPreview =>
      'Converted trigger prices are rounded to the nearest price tick. Review the resulting price.';

  @override
  String get attachedOrderEstimateScope =>
      'Estimates use the main-order quantity and indicative entry price, before fees and slippage. A limit exit may remain unfilled after triggering.';

  @override
  String attachedOrderExitIssue(String exit, String reason) {
    return '$exit: $reason';
  }

  @override
  String get attachedOrderCheckExits =>
      'Review the highlighted attached TP/SL fields before continuing.';

  @override
  String get attachedOrderTargetSign =>
      'Enter a positive take-profit or negative stop-loss amount / ROI. Zero is not a target.';

  @override
  String get attachedOrderPreviewUnavailable =>
      'Enter a valid main-order quantity and price, and read the entry quote and leverage before converting.';

  @override
  String get attachedOrderLimitRequired => 'Enter a positive exit limit price.';

  @override
  String get attachedOrderExecutionInvalid => 'Review the attached exit execution and limit price.';

  @override
  String get attachedOrderLegacyLifecycle =>
      'This saved strategy uses its original full-fill activation and peer-cancellation rules. Its original protected quantity is unchanged.';

  @override
  String attachedOrderDirectionHint(String relation, String price, String asset) {
    return 'Trigger must be $relation the indicative entry price $price $asset.';
  }

  @override
  String get strategyExecutionTitle => 'Strategy execution details';

  @override
  String get strategyExecutionScope =>
      'Read actual order quantities and filled value separately from strategy terms. Each order has its own snapshot time. These records do not prove current balances or remaining positions.';

  @override
  String get strategyExecutionSignHint =>
      'Sign to recheck the original strategy, then each child order with an exchange order ID. This may require several wallet confirmations. A failure stops further prompts; retry is manual.';

  @override
  String get strategyExecutionRead => 'Sign to read executions';

  @override
  String get strategyExecutionCheckingStrategy => 'Checking the original strategy…';

  @override
  String strategyExecutionCheckingLeg(int sequence) {
    return 'Reading order $sequence…';
  }

  @override
  String get strategyExecutionStop => 'Stop waiting';

  @override
  String get strategyExecutionStopped =>
      'Reading stopped. Any previous snapshot is retained; no orders were canceled.';

  @override
  String get strategyExecutionSkipped =>
      'Not read after an earlier failure. Read again to check this order.';

  @override
  String get strategyExecutionStale => 'This snapshot may be out of date. Sign to read again.';

  @override
  String get strategyExecutionStrategyTime => 'Strategy checked (UTC)';

  @override
  String get strategyExecutionOrderTime => 'Order checked (UTC)';

  @override
  String get strategyExecutionEntry => 'Main order';

  @override
  String get strategyExecutionStrategyLegStatus => 'Status in strategy snapshot';

  @override
  String get strategyExecutionOrderStatus => 'Status in order snapshot';

  @override
  String get strategyExecutionNoOrder =>
      'The strategy has no ordinary order ID for this leg. Filled quantity and value are unknown.';

  @override
  String get strategyExecutionTriggered =>
      'The order report shows triggering or execution. A trigger alone does not confirm a fill.';

  @override
  String get strategyExecutionTriggerUnconfirmed =>
      'Triggering is not confirmed by this order snapshot.';

  @override
  String get strategyExecutionOriginalSize => 'Current order quantity';

  @override
  String get strategyExecutionFilledSize => 'Actual filled quantity';

  @override
  String get strategyExecutionFilledValue => 'Actual filled value';

  @override
  String get strategyExecutionAveragePrice => 'Reported average fill price';

  @override
  String get strategyExecutionTermsChanged =>
      'The current quantity or price differs from the original strategy terms. Values above are from this order report; automatic replenishment is not inferred.';

  @override
  String get liveAmountUnit => 'Order size unit';

  @override
  String liveAmountInput(String asset) {
    return 'Order amount ($asset)';
  }

  @override
  String get liveAmountHint =>
      'Enter order notional, not margin. The amount is not multiplied by leverage.';

  @override
  String get liveAmountInvalid => 'Enter a positive order amount using decimal digits.';

  @override
  String get liveAmountBelowStep =>
      'This amount converts to less than the minimum order quantity or one quantity step.';

  @override
  String get liveAmountReferenceUnavailable =>
      'The required conversion price is unavailable. Refresh the order snapshot or enter a base-asset quantity.';

  @override
  String get liveAmountLimitReference => 'entered limit price';

  @override
  String get liveAmountAskReference => 'best ask snapshot';

  @override
  String get liveAmountBidReference => 'best bid snapshot';

  @override
  String get liveAmountTriggerReference => 'trigger price estimate';

  @override
  String get liveAmountBboReference => 'indicative Mark, not an engine BBO price';

  @override
  String liveAmountConversionPrice(String basis) {
    return 'Conversion reference: $basis';
  }

  @override
  String get liveAmountResolvedQuantity => 'Base quantity to submit';

  @override
  String get liveAmountSnapshotTime => 'Order snapshot (UTC)';

  @override
  String get liveAmountEstimateHint =>
      'Quantity is rounded down to the applicable step and fixed for confirmation. Market, trigger and BBO prices may change; actual spending can exceed this estimate. This amount is not a spending cap.';

  @override
  String get futuresHistoryTitle => 'Futures history';

  @override
  String get futuresHistoryScope =>
      'Read this wallet’s futures orders, individual fills and income ledger separately. BUY/SELL alone does not identify opening or closing. Reading never submits or cancels an order.';

  @override
  String get futuresHistoryIncome => 'Income ledger';

  @override
  String get futuresHistorySymbol => 'Futures symbol (optional)';

  @override
  String get futuresHistoryTradeSymbol => 'Futures symbol (required for fills)';

  @override
  String get futuresHistoryFilterHint =>
      'Use the exact symbol, including delisted contracts. Orders and income allow all symbols; individual fills require one symbol. Editing clears the displayed results without signing.';

  @override
  String get futuresHistoryInvalidSymbol =>
      'Enter an exact futures symbol. Individual fills require a symbol; spaces and query syntax are not accepted.';

  @override
  String get futuresHistoryInvalidType => 'Choose a supported income type, or all types.';

  @override
  String get futuresHistoryInvalidWindow =>
      'Select a valid UTC date range. Each signed request reads less than seven days; longer ranges are read in separate manual batches.';

  @override
  String get futuresHistoryCapacity =>
      'This view reached 10,000 records. Earlier results remain; narrow the date range or symbol and read again. No records were silently discarded.';

  @override
  String get futuresHistoryRetention =>
      'Aster omits canceled or expired orders with no fills once their creation is more than seven days old. Partly filled canceled orders keep their reported fills. API retention can limit older records.';

  @override
  String get futuresHistoryAllTypes => 'All income types';

  @override
  String get futuresHistoryOriginalType => 'Original order type';

  @override
  String get futuresHistoryExecuted => 'Reported filled quantity';

  @override
  String get futuresHistoryPnlHint =>
      'Reported realized PnL is separate from commission and income-ledger entries. These records are not summed into a net return or portfolio statistic.';

  @override
  String get futuresHistoryIncomeAmount => 'Reported income change';

  @override
  String futuresHistoryIncomeType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'TRANSFER': 'Transfer',
      'WITHDRAW': 'Withdrawal',
      'DEPOSIT': 'Deposit',
      'WELCOME_BONUS': 'Welcome bonus',
      'REALIZED_PNL': 'Realized PnL',
      'FUNDING_FEE': 'Funding fee',
      'COMMISSION': 'Commission',
      'INSURANCE_CLEAR': 'Insurance clearing',
      'MARKET_MERCHANT_RETURN_REWARD': 'Market merchant return reward',
      'REFERRAL_KICKBACK': 'Referral kickback',
      'COMMISSION_REBATE': 'Commission rebate',
      'MARKET_MAKER_REBATE': 'Market maker rebate',
      'API_REBATE': 'API rebate',
      'CONTEST_REWARD': 'Contest reward',
      'CROSS_COLLATERAL_TRANSFER': 'Cross-collateral transfer',
      'INTERNAL_TRANSFER': 'Internal transfer',
      'AUTO_EXCHANGE': 'Automatic exchange',
      'other': 'Unknown ($type)',
    });
    return '$_temp0';
  }

  @override
  String get orderConfirmLimit => 'Confirm limit and Post Only entries';

  @override
  String get orderConfirmStopLimit => 'Confirm conditional limit entries';

  @override
  String get orderConfirmStopMarket => 'Confirm conditional market entries';

  @override
  String get orderConfirmTrailing => 'Confirm trailing stop entries';

  @override
  String get orderConfirmLimitShared => 'Limit and Post Only share this setting.';

  @override
  String get orderConfirmDoNotShow => 'Do not show confirmation again for this order type';

  @override
  String get orderConfirmWalletHint =>
      'This setting controls the app review. Wallet signatures and checks before submission still apply.';

  @override
  String get scaledTotalAmount => 'Total order amount';

  @override
  String get scaledAmountInvalid => 'Enter a positive total order amount.';

  @override
  String get scaledDistribution => 'Quantity distribution';

  @override
  String get scaledEqual => 'Equal';

  @override
  String get scaledIncreasing => 'Increasing';

  @override
  String get scaledDecreasing => 'Decreasing';

  @override
  String get scaledRandom => 'Random';

  @override
  String get scaledConstant => 'Distribution constant';

  @override
  String get scaledDifference => 'Difference';

  @override
  String get scaledRatio => 'Ratio';

  @override
  String get scaledDifferenceHint =>
      'Quantity weights are 1:2:3… from low to high price for Increasing, reversed for Decreasing. Quantity steps may round the pattern.';

  @override
  String get scaledRatioHint =>
      'Quantity weights are 1:2:4… from low to high price for Increasing, reversed for Decreasing. Every child must meet the minimum size; high counts may require a very large total.';

  @override
  String get scaledVariance => 'Random variance';

  @override
  String get scaledVarianceInvalid => 'Enter a variance from 0% to 10%.';

  @override
  String get scaledVarianceStep =>
      'The quantity step cannot represent this random distribution within the selected variance. Increase the total, change the variance or reshuffle.';

  @override
  String get scaledRandomRequired => 'Generate a random breakdown before reviewing.';

  @override
  String get scaledRandomHint =>
      'Each quantity stays within the selected percentage of the mean quantity. This breakdown stays fixed until you edit its inputs or reshuffle; changing language never redraws it.';

  @override
  String get scaledReshuffle => 'Reshuffle quantities';

  @override
  String get scaledUnallocatedQuote => 'Unallocated order amount';

  @override
  String get scaledAmountHint =>
      'Order amount is the sum of child limit price × quantity, without leverage multiplication. Quote input is rounded down to valid base quantities; the unallocated amount is shown. This excludes fees and is not a margin or final execution-cost limit.';

  @override
  String get scaledBaseRemainderHint =>
      'The entered base quantity is conserved exactly. Remaining steps go to the largest fractional remainders, with ties assigned from low to high price.';

  @override
  String get scaledPreviousChildren => 'Previous orders';

  @override
  String get scaledNextChildren => 'Next orders';

  @override
  String get scaledChildType => 'Child order type';

  @override
  String get scaledEnteredSize => 'Entered total';

  @override
  String scaledPage(int start, int end, int total) {
    return 'Orders $start–$end of $total';
  }

  @override
  String get scaledCountRange => '2–110';

  @override
  String get assistantNavigation => 'AI';

  @override
  String get orderModeLabel => 'Order type';

  @override
  String get orderModeMore => 'More order types';

  @override
  String get orderModeStopLimit => 'TP/SL Limit';

  @override
  String get orderModeStopMarket => 'TP/SL Market';

  @override
  String get orderModeChase => 'Chase';

  @override
  String get orderModeTwap => 'TWAP';

  @override
  String get orderModeChaseUnavailable => 'Chase orders are not available yet.';

  @override
  String get orderModeTwapUnavailable =>
      'Currently unavailable. TWAP is not included in this release.';

  @override
  String get liveCapacityChanged =>
      'Account settings, positions or reserved margin changed. Refresh the order data before calculating capacity.';

  @override
  String get liveCapacityPriceUnavailable =>
      'A reliable price reference for this order is unavailable. Refresh market data or review the pricing mode.';

  @override
  String get liveCapacityTitle => 'Directional capacity reference';

  @override
  String liveAllocationPercent(int percent) {
    return 'Order percentage: $percent%';
  }

  @override
  String get liveAllocationManual => 'Manual amount';

  @override
  String get liveAllocationManualHint =>
      'Review checks the selected side’s latest capacity with up to six wallet signatures. Your entered amount is preserved and the quantity you click stays fixed.';

  @override
  String liveAllocationMaximumChanged(String direction, String maximum, String asset) {
    return '$direction: the latest maximum is $maximum $asset. Adjust the amount and try again.';
  }

  @override
  String get liveAllocationHint =>
      'Read capacity before choosing a percentage. Each side uses its own maximum. Review refreshes limits with up to six wallet signatures and freezes the quantity you clicked.';

  @override
  String get liveAllocationChecking => 'Refreshing limits for the selected direction…';

  @override
  String get liveAllocationChanged =>
      'Order inputs, account data or capacity changed. Review the current values and try again.';

  @override
  String get liveAllocationFrozen =>
      'This direction, order type and quantity are frozen for confirmation. Changed or expired data blocks submission.';

  @override
  String get liveAllocationReviewBuy => 'Review long';

  @override
  String get liveAllocationReviewSell => 'Review short';

  @override
  String get liveCapacityRead => 'Read capacity';

  @override
  String get liveCapacityReadHint =>
      'Reading your latest account and order limits requires up to six wallet signatures. No order is placed.';

  @override
  String get liveCapacityMaximum => 'Maximum quantity reference';

  @override
  String get liveCapacityCost => 'Opening cost reference';

  @override
  String get liveCapacityAboveMaximum =>
      'The quantity exceeds this side’s current capacity reference. Reduce the quantity and refresh before placing an order.';

  @override
  String get liveCapacityStale =>
      'Capacity is out of date. Refresh order data, then read capacity again.';

  @override
  String get liveCapacityEstimateHint =>
      'Both sides independently assume a full fill using the same account and current prices. Opening cost includes incremental margin and opening loss. Liquidation estimates use the signed taker fee and risk tiers, holding other prices and collateral rates fixed; actual fills, fees and funding can differ. Missing facts or no positive estimate show —.';

  @override
  String get liveCapacityPendingUnknown =>
      'Capacity is unavailable because the reserved notional of a pending order cannot be verified.';

  @override
  String get liveCapacityRatesUnavailable =>
      'Fresh collateral conversion rates are unavailable. Refresh before calculating capacity.';

  @override
  String get liveCapacityRefreshAccount => 'Refresh trading account and limits';

  @override
  String get liveCapacityRefreshAccountHint =>
      'Sign separately to read configuration, balances, positions, orders, risk tiers and the symbol fee, with up to ten wallet signatures; also refresh public prices and collateral rates. No order is submitted.';

  @override
  String get liveCapacityLiquidation => 'Estimated liquidation price after fill';

  @override
  String get apiRequestTimeout => 'The request timed out.';

  @override
  String get apiConnectionFailed =>
      'Unable to connect to the server. Check your network connection.';

  @override
  String get apiRequestCancelled => 'The request was cancelled.';

  @override
  String get apiInvalidResponse => 'The server returned an invalid response.';

  @override
  String get authConnectTitle => 'Connect wallet';

  @override
  String get authVerifyTitle => 'Verify email';

  @override
  String get authWelcome => 'Welcome to Vanta';

  @override
  String get authWelcomeDescription => 'Connect your account to manage assets and trade.';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailPlaceholder => 'Enter your email address';

  @override
  String get authEmailContinue => 'Continue with email';

  @override
  String get authGoogleContinue => 'Continue with Google';

  @override
  String get authXContinue => 'Continue with X';

  @override
  String get authWalletContinue => 'Connect a wallet';

  @override
  String get authAlternative => 'or';

  @override
  String authLegalNotice(String termsOfUse, String privacyPolicy) {
    return 'By continuing, you agree to the $termsOfUse and $privacyPolicy.';
  }

  @override
  String get authTermsOfUse => 'Terms of Use';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authCheckEmail => 'Check your email';

  @override
  String get authCodeDelivery => 'Enter the verification code sent to';

  @override
  String get authCodeExpired => 'Code expired. Request a new code.';

  @override
  String get authBack => 'Back';

  @override
  String get authClose => 'Close';

  @override
  String get assistantRateLimited => 'Too many requests. Please wait before trying again.';

  @override
  String get authVerifyContinue => 'Verify and continue';

  @override
  String get authSpamHint => 'Check your spam folder if the email hasn’t arrived.';

  @override
  String authResendCountdown(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get enableTradingTitle => 'Enable trading';

  @override
  String get enableTradingHeading => 'One more signature';

  @override
  String get enableTradingWalletHint =>
      'Confirm the signature in your wallet. Check your wallet app or browser extensions if nothing pops up.';

  @override
  String get enableTradingEmbeddedHint =>
      'Confirm one more signature with your connected wallet to enable trading.';

  @override
  String get enableTradingWalletConnected => 'Wallet connected';

  @override
  String get enableTradingUseAnother => 'Use another wallet';

  @override
  String get enableTradingStep => '2';

  @override
  String get enableTradingSignHint => 'Sign in your wallet to continue.';

  @override
  String get enableTradingEmbeddedSignHint => 'Sign to continue.';

  @override
  String get enableTradingScope =>
      'Authorize a device signing key for 30 days of account queries and gas-free Spot and Futures trading without repeated wallet prompts. Withdrawal access is not granted.';

  @override
  String get enableTradingReturnHint =>
      'If nothing opens, check your wallet app and return here after signing.';

  @override
  String get enableTradingEmbeddedReturnHint =>
      'Your connected embedded wallet will sign this trading authorization.';

  @override
  String get enableTradingOpenWallet => 'Open wallet to sign';

  @override
  String get enableTradingSign => 'Sign to enable trading';

  @override
  String get enableTradingContinue => 'Continue';

  @override
  String get enableTradingWalletSetup => 'Wallet setup';

  @override
  String get tradeNavigation => 'Trade';

  @override
  String get exploreNavigation => 'Explore';

  @override
  String get portfolioTotalValue => 'Total value';

  @override
  String get portfolioLoginHint => 'Log in to view your assets and performance.';

  @override
  String get portfolioLoginBalances => 'Log in to view your balances';

  @override
  String get portfolioPerformance => 'Performance';

  @override
  String get portfolioFuturesAssets => 'Futures assets';

  @override
  String get portfolioPnlDetails => 'PnL details';

  @override
  String get portfolioTodayPnl => 'Today’s PnL';

  @override
  String get portfolioPnl7d => 'PnL · 7D';

  @override
  String get portfolioVolume7d => 'Volume · 7D';

  @override
  String get portfolioTransfer => 'Transfer between accounts';

  @override
  String get portfolioMainAccount => 'Main account';

  @override
  String get portfolioPreviewAccount => 'Demo · Static preview';

  @override
  String get portfolioPreviewNotice => 'Static design sample. No real funds or orders.';

  @override
  String get portfolioPreviewAction =>
      'This is a static preview. Switch to your account to continue.';

  @override
  String get portfolioAccountSelector => 'Select account';

  @override
  String get portfolioHideBalance => 'Hide balances';

  @override
  String get portfolioShowBalance => 'Show balances';

  @override
  String get portfolioValueHistory => 'Total value history';

  @override
  String get portfolioCollapseHistory => 'Collapse value history';

  @override
  String get portfolioOpenHistory => 'Expand value history';

  @override
  String get portfolioMissingPnl => 'PnL data unavailable for this account';

  @override
  String get portfolioMissingDay => 'Daily PnL unavailable';

  @override
  String get portfolioMissingValue => 'Value history unavailable for this account';

  @override
  String get portfolioPnlNote =>
      'Historical figures may update after settlement. Missing data is shown as unavailable.';

  @override
  String get portfolioCalendar => 'Calendar';

  @override
  String get portfolioMonthlyPnl => 'Monthly PnL';

  @override
  String get portfolioCalendarNote => 'Daily PnL uses UTC · Values in USD';

  @override
  String get portfolioPreviousMonth => 'Previous month';

  @override
  String get portfolioNextMonth => 'Next month';

  @override
  String get portfolioHideOtherSymbols => 'Hide other symbols';

  @override
  String get portfolioHideLowBalances => 'Hide low balance assets';

  @override
  String get portfolioNoPositions => 'No open positions';

  @override
  String get portfolioNoAssets => 'No assets to display';

  @override
  String get portfolioAssets => 'Assets';

  @override
  String get portfolioLast7Days => 'PnL · Last 7 days';

  @override
  String portfolioPnlPeriod(String period) {
    return 'PnL · $period';
  }

  @override
  String portfolioVolumePeriod(String period) {
    return 'Volume · $period';
  }

  @override
  String portfolioHistoryPeriod(String period) {
    return 'Total value history · $period';
  }

  @override
  String portfolioDayUnavailable(String date) {
    return '$date · Daily PnL unavailable';
  }

  @override
  String portfolioPositionsCount(int count) {
    return 'Positions($count)';
  }

  @override
  String portfolioAvailable(String amount) {
    return 'Avbl. $amount';
  }

  @override
  String get portfolioLiquidation => 'Liq.';

  @override
  String portfolioSize(String unit) {
    return 'Size ($unit)';
  }

  @override
  String portfolioPnlUnit(String unit) {
    return 'PnL ($unit)';
  }

  @override
  String get portfolioPreview7d => '7D sample only';

  @override
  String get portfolioLogIn => 'Log in';

  @override
  String get portfolioCloseAll => 'Close all';

  @override
  String get portfolioMark => 'Mark';

  @override
  String get portfolioTpsl => 'TP/SL';

  @override
  String get portfolioAll => 'All';

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get accountsSwitchTitle => 'Switch account';

  @override
  String get accountsManage => 'Manage accounts';

  @override
  String get accountsListTitle => 'Sub-accounts';

  @override
  String get accountsYourChildren => 'Your sub-accounts';

  @override
  String get accountsSeparateStrategies =>
      'Keep strategies separate. Each account has its own address and balance.';

  @override
  String get accountsDetailsTitle => 'Sub-account details';

  @override
  String get accountsStatusUnverified => 'Status unavailable';

  @override
  String get accountsFreezeRequested => 'Freeze request accepted';

  @override
  String get accountsUnfreezeRequested => 'Unfreeze request accepted';

  @override
  String get accountsBalance => 'Balance';

  @override
  String get accountsStatus => 'Status';

  @override
  String get accountsAddress => 'Address';

  @override
  String get accountsOwnerWallet => 'Owner wallet';

  @override
  String get accountsAssets => 'Assets';

  @override
  String get accountsFreeze => 'Freeze account';

  @override
  String get accountsUnfreeze => 'Unfreeze account';

  @override
  String accountsFreezeTitle(String name) {
    return 'Freeze $name?';
  }

  @override
  String get accountsFreezeNotice =>
      'Cross-account transfers to and from this sub-account will be blocked.';

  @override
  String get accountsReviewOrders => 'Review open positions and orders before continuing.';

  @override
  String get accountsIndependentKey =>
      'This sub-account has a separate private key. Manage access carefully.';

  @override
  String get accountsFrozenNotice =>
      'Transfers remain unavailable while a freeze request is pending or accepted. Confirm the current status with Aster.';

  @override
  String get accountsFreezeBoundary =>
      'This does not confirm that positions, orders or TP/SL have been stopped.';

  @override
  String get accountsSwitchTo => 'Switch to this account';

  @override
  String accountsSwitchHeading(String name) {
    return 'Switch to $name';
  }

  @override
  String get accountsSwitchNotice =>
      'Your current account remains active until the switch is confirmed.';

  @override
  String get accountsSwitchConnection =>
      'Confirm the account switch with a signature from your current wallet.';

  @override
  String get accountsSwitchConfirm => 'Confirm switch';

  @override
  String get accountsCreate => 'Create sub-account';

  @override
  String get accountsNameHeading => 'Name your account';

  @override
  String get accountsNameHint => 'Use a name that helps you identify this strategy.';

  @override
  String get accountsName => 'Account name';

  @override
  String get accountsOwner => 'Owner';

  @override
  String get accountsNewWallet => 'Independent wallet';

  @override
  String get accountsNewAccount => 'New account';

  @override
  String get accountsSlots => 'Sub-account slots';

  @override
  String get accountsCreateNotice =>
      'Your wallet will ask you to sign. You’ll need to save the new account’s private key.';

  @override
  String get accountsSignCreate => 'Sign and create';

  @override
  String get accountsBackupTitle => 'Save your private key';

  @override
  String get accountsCreated => 'Account created';

  @override
  String get accountsBackupNotice => 'Save the private key before continuing.';

  @override
  String get accountsPrivateKey => 'Private key';

  @override
  String get accountsHiddenKey => 'Hidden by default';

  @override
  String get accountsRevealKey => 'Show private key';

  @override
  String get accountsHideKey => 'Hide private key';

  @override
  String get accountsKeyWarning =>
      'Anyone with this key can control the account. Keep it private and store it safely.';

  @override
  String get accountsSavedKey => 'I have saved my private key.';

  @override
  String get accountsContinue => 'Continue';

  @override
  String get accountsBackupPending => 'Back up this wallet';

  @override
  String get accountsTransferTitle => 'Transfer between accounts';

  @override
  String get accountsFrom => 'From';

  @override
  String get accountsTo => 'To';

  @override
  String get accountsAsset => 'Asset';

  @override
  String get accountsAmount => 'Amount';

  @override
  String get accountsAvailable => 'Available';

  @override
  String get accountsMax => 'Max';

  @override
  String get accountsFutures => 'Futures';

  @override
  String get accountsReviewTransfer => 'Review transfer';

  @override
  String get accountsTransferReviewTitle => 'Review transfer';

  @override
  String get accountsTransferSubmit => 'Transfer';

  @override
  String get accountsTransferSubmitted => 'Transfer submitted';

  @override
  String get accountsTransferWaiting =>
      'Awaiting final status. Account balances update after confirmation.';

  @override
  String get accountsBackPortfolio => 'Back to Portfolio';

  @override
  String get accountsChooseAccount => 'Select account';

  @override
  String get accountsChooseAsset => 'Select asset';

  @override
  String get accountsNoDestination => 'Create a sub-account before transferring between accounts.';

  @override
  String get accountsUnknownAddress =>
      'The directory does not provide this account’s wallet address. Manage it through Aster.';

  @override
  String get accountsTransferBalanceNotice =>
      'Refresh your Futures balance before reviewing the transfer.';

  @override
  String get subaccountSecureStorageFailed =>
      'Cannot access the device’s secure wallet storage. No new creation request will be sent.';

  @override
  String get subaccountSecureStorageFull =>
      'The device wallet storage is full. Back up your wallets before continuing.';

  @override
  String get subaccountLocalKeyMissing =>
      'The private key is unavailable on this device. Import your backup into an external wallet to use this account.';

  @override
  String get subaccountCreationFailed =>
      'The sub-account could not be created. Your generated wallet remains available for backup.';

  @override
  String get subaccountNativeTransactionUnavailable =>
      'Import this account into an external wallet to send on-chain transactions.';

  @override
  String get accountsTransferInsufficient => 'The amount exceeds the available Futures balance.';

  @override
  String get accountsLocalWallets => 'Created on this device';

  @override
  String get accountsRemoteDirectory => 'Aster account directory';

  @override
  String get accountsCreatedBadge => 'Created';

  @override
  String get accountsTotalAssets => 'Total assets';

  @override
  String accountsSlotsUsed(int count) {
    return '$count of 10 used';
  }

  @override
  String get accountsUnfreezeNotice =>
      'Cross-account transfers can resume after Aster confirms that the account is unfrozen.';

  @override
  String get tradeAskAi => 'Ask AI';

  @override
  String get tradeHigh24h => '24h High';

  @override
  String get tradeLow24h => '24h Low';

  @override
  String get tradeFutures => 'Futures';

  @override
  String get tradeSymbols => 'Symbols';

  @override
  String get accountsSelect => 'Select';

  @override
  String get accountsDifferentSource => 'Choose a different account from the source.';

  @override
  String get accountsTransferUnavailable => 'Transfer unavailable';

  @override
  String get accountsTransferFreezeHeading => 'A selected account has a freeze request';

  @override
  String get accountsBackTransfer => 'Back to transfer';

  @override
  String get accountsDone => 'Done';

  @override
  String get accountsSwitchRetry => 'Try switching again';

  @override
  String accountsSwitchFailed(String message, String account) {
    return '$message $account is still active.';
  }

  @override
  String get accountsAccount => 'Account';

  @override
  String get accountsOpenWallet => 'Open wallet';

  @override
  String get accountsConfirmCreation => 'Confirm account creation';

  @override
  String accountsCreateSummary(String name) {
    return 'Create $name';
  }

  @override
  String get accountsAuthorizeCreation =>
      'Authorize creation with your main account wallet. Save the new private key after creation.';

  @override
  String get accountsConfirmFreeze => 'Confirm freeze in wallet';

  @override
  String get accountsConfirmUnfreeze => 'Confirm unfreeze in wallet';

  @override
  String get accountsFreezeAction => 'Freeze';

  @override
  String get accountsUnfreezeAction => 'Unfreeze';

  @override
  String get accountsAuthorizeFreeze =>
      'Authorize this change with the main account wallet. Cross-account transfers will be restricted.';

  @override
  String get accountsAuthorizeUnfreeze =>
      'Authorize this change with the main account wallet to restore the account status.';

  @override
  String get accountsWithdrawMainOnly => 'Main account only';

  @override
  String get authorizationSecureStorageFailed =>
      'The device signing key could not be read or saved securely. Check device secure storage and try again.';

  @override
  String get authorizationRequired =>
      'Trading authorization is missing or expired. Enable trading to read this account without repeated wallet prompts.';

  @override
  String get fundingAccountTitle => 'Account';

  @override
  String get fundingDepositTo => 'Deposit to';

  @override
  String get fundingWithdrawFrom => 'Withdraw from';

  @override
  String get fundingNetworkLabel => 'Network';

  @override
  String get fundingAmountLabel => 'Amount';

  @override
  String get fundingBalance => 'Balance';

  @override
  String get fundingMax => 'Max';

  @override
  String get fundingNetworkBnb => 'BNB Chain';

  @override
  String get fundingNetworkEthereum => 'Ethereum';

  @override
  String get fundingNetworkArbitrum => 'Arbitrum';

  @override
  String get fundingSelectNetwork => 'Select network';

  @override
  String get fundingSelectAsset => 'Select asset';

  @override
  String fundingDepositTime(String network) {
    return 'Estimated deposit time for $network is 1–3 minutes.';
  }

  @override
  String fundingApproveAsset(String asset) {
    return 'Approve $asset';
  }

  @override
  String fundingGasInsufficient(String asset) {
    return 'Insufficient $asset for network fees. Enter a smaller amount.';
  }

  @override
  String get fundingConfirmDepositTitle => 'Confirm deposit in wallet';

  @override
  String get fundingConfirmDepositHint => 'Confirm the transaction in your wallet to continue.';

  @override
  String fundingApproveTitle(String asset) {
    return 'Approve $asset in wallet';
  }

  @override
  String get fundingApproveSummary => 'Spending permission';

  @override
  String fundingApproveHint(String asset) {
    return 'Approve $asset spending in your wallet before making a deposit.';
  }

  @override
  String get fundingConfirmWithdrawTitle => 'Confirm withdrawal in wallet';

  @override
  String get fundingConfirmWithdrawHint =>
      'Sign the withdrawal request in your wallet to continue.';

  @override
  String get fundingOpenWallet => 'Open wallet';

  @override
  String get fundingTransactions => 'Transactions';

  @override
  String fundingFuturesAmount(String amount) {
    return '$amount · Futures Account';
  }

  @override
  String get fundingDepositProcessing => 'Deposit processing';

  @override
  String get fundingStepChainPending => 'On-chain transaction';

  @override
  String get fundingStepChainConfirmed => 'On-chain transaction confirmed';

  @override
  String get fundingStepCrediting => 'Crediting account';

  @override
  String get fundingStepCreditingHint => 'Waiting for your account to be credited.';

  @override
  String get fundingTrackHint => 'You can close this page and continue tracking in Transactions.';

  @override
  String get fundingViewTransactions => 'View Transactions';

  @override
  String get fundingWithdrawable => 'Withdrawable Amount';

  @override
  String get fundingTransactionFee => 'Transaction Fee';

  @override
  String fundingFeeWithUsd(String amount, String usd) {
    return '$amount ($usd USD)';
  }

  @override
  String get fundingViewHistory => 'View History in Portfolio';

  @override
  String get fundingWithdrawChainHint =>
      'Deposited tokens must be withdrawn on the same chain. USDT profits can use any supported chain.';

  @override
  String get fundingWithdrawProcessing => 'Withdrawal processing';

  @override
  String get fundingWithdrawCompleted => 'Withdrawal completed';

  @override
  String get fundingWithdrawFailedTitle => 'Withdrawal failed';

  @override
  String get fundingStepNetwork => 'Network confirmation';

  @override
  String get fundingStepNetworkHint => 'Waiting for network confirmation.';

  @override
  String get fundingStepWithdrawCompletion => 'Withdrawal completion';

  @override
  String get fundingStepWithdrawCompletionHint => 'Waiting for the withdrawal to complete.';

  @override
  String get fundingWithdrawalId => 'Withdrawal ID';

  @override
  String get fundingStatus => 'Status';

  @override
  String get fundingStatusFailed => 'Failed';

  @override
  String get fundingWithdrawFailedHint =>
      'This withdrawal was not completed. Check its final status before trying again.';

  @override
  String get fundingRebalanceRequired => 'Rebalance to withdraw';

  @override
  String fundingUsdtBalanceValue(String amount) {
    return 'USDT balance: $amount';
  }

  @override
  String get fundingRebalance => 'Rebalance';

  @override
  String get fundingRebalanceHint => 'Use other assets to clear the USDT deficit.';

  @override
  String get fundingUsdtBalance => 'USDT balance';

  @override
  String get fundingRebalanceConfirm => 'Confirm Rebalance';

  @override
  String get fundingRebalancing => 'Rebalancing…';

  @override
  String get fundingRebalancingHint => 'Updating your balance. Please wait.';

  @override
  String get assetHistoryFutures => 'Futures';

  @override
  String get assetHistoryTitle => 'Transactions';

  @override
  String get assetHistoryDetails => 'Transaction details';

  @override
  String get assetHistoryEmpty => 'No records';

  @override
  String get assetHistoryLoaded => 'All records loaded';

  @override
  String assetHistoryAmountNetwork(String amount, String network) {
    return '$amount on $network';
  }

  @override
  String assetHistoryStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'processing': 'Processing',
      'success': 'Success',
      'failed': 'Failed',
      'other': 'Unknown',
    });
    return '$_temp0';
  }

  @override
  String get assetHistoryTime => 'Time';

  @override
  String get assetHistoryTransactionId => 'Transaction ID';

  @override
  String get assetHistoryUnavailable => 'Unavailable';

  @override
  String get assetHistoryProgress => 'Progress';

  @override
  String get assetHistoryConfirmed => 'On-chain transaction confirmed';

  @override
  String get assetHistoryConfirmationUnavailable => 'On-chain confirmation unavailable';

  @override
  String get assetHistoryDepositCompleted => 'Deposit completed';

  @override
  String get assetHistoryWithdrawCompleted => 'Withdrawal completed';

  @override
  String get assetHistoryCrediting => 'Crediting account';

  @override
  String get assetHistoryWithdrawPending => 'Withdrawal pending';

  @override
  String portfolioFundingPending(String amount, String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'deposit': 'Waiting to be credited',
      'withdraw': 'Waiting for completion',
      'other': 'Processing',
    });
    return '$amount · $_temp0';
  }

  @override
  String fundingBalanceInsufficient(String asset) {
    return 'Insufficient $asset balance. Enter a smaller amount.';
  }

  @override
  String fundingGasTopUp(String asset) {
    return 'Insufficient $asset for network fees. Add $asset to your wallet.';
  }

  @override
  String fundingWithdrawalFeeInsufficient(String asset) {
    return 'Insufficient $asset for the withdrawal amount and fee. Enter a smaller amount.';
  }

  @override
  String tradeOrderPrice(String asset) {
    return 'Price ($asset)';
  }

  @override
  String get tradeOrderSize => 'Size';

  @override
  String get tradeAdvanced => 'Advanced';

  @override
  String get tradePriceDown => 'Decrease price';

  @override
  String get tradePriceUp => 'Increase price';

  @override
  String get tradeTpSl => 'TP/SL';

  @override
  String get tradeHiddenOrder => 'Hidden Order';

  @override
  String get tradeSelectPriceType => 'Select Price Type';

  @override
  String get tradeSelectUnitType => 'Select Unit Type';

  @override
  String get tradeTriggerByLast => 'Trigger by Last Price';

  @override
  String get tradeTriggerByMark => 'Trigger by Mark Price';

  @override
  String get tradeTakeProfit => 'Take Profit';

  @override
  String get tradeStopLoss => 'Stop Loss';

  @override
  String get tradeTp => 'TP';

  @override
  String get tradeSl => 'SL';

  @override
  String get tradeSelectExitMode => 'Select Input Type';

  @override
  String tradeExitPnl(String asset) {
    return 'PnL ($asset)';
  }

  @override
  String tradeExitPrice(String asset) {
    return 'Price ($asset)';
  }

  @override
  String get tradeExitRoi => 'ROI (%)';

  @override
  String get notificationFilterAll => 'All';

  @override
  String get notificationFilterTransfers => 'Transfers';

  @override
  String get notificationFilterOrders => 'Orders';

  @override
  String get notificationUnreadOnly => 'Unread only';

  @override
  String get notificationToday => 'Today';

  @override
  String get notificationPerp => 'Perp';

  @override
  String get notificationAdlChip => 'ADL';

  @override
  String notificationUnreadCount(int count) {
    return '$count unread';
  }

  @override
  String notificationOrderSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'BUY': 'buy order',
      'SELL': 'sell order',
      'other': 'order',
    });
    return '$_temp0';
  }

  @override
  String notificationOrderSummary(
    String status,
    String symbol,
    String side,
    String last,
    String progress,
    String average,
  ) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'NEW': '$symbol $side created, awaiting fill.',
      'PARTIALLY_FILLED': '$symbol $side filled $last this time; $progress filled in total.',
      'FILLED': '$symbol $side fully filled at an average price of $average.',
      'CANCELED': '$symbol $side canceled; fills before cancellation remain in history.',
      'EXPIRED': '$symbol $side expired; the unfilled part will no longer execute.',
      'REJECTED': '$symbol $side was rejected. Check your order records.',
      'other': '$symbol $side updated. See details.',
    });
    return '$_temp0';
  }

  @override
  String notificationLiquidationSummary(String symbol) {
    return '$symbol liquidation order updated. See details for the filled quantity.';
  }

  @override
  String notificationAdlSummary(String symbol) {
    return '$symbol ADL order has a new execution. Review your positions and fills.';
  }

  @override
  String notificationMarginSummary(String symbols) {
    return '$symbols position risk is high. Check your margin and positions promptly.';
  }

  @override
  String notificationTransferSummary(String kind, String amount, String market, String network) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'deposit_processing':
          '$amount deposit to the $market account is processing. Network: $network.',
      'deposit_success': '$amount deposited to the $market account. Network: $network.',
      'deposit_failed': 'Your $amount deposit failed. See details.',
      'withdraw_processing': '$amount withdrawal is processing. Check progress in funding records.',
      'withdraw_success': '$amount withdrawn from the $market account. Network: $network.',
      'withdraw_failed': 'Your $amount withdrawal failed. See details.',
      'other': '$amount transfer updated.',
    });
    return '$_temp0';
  }

  @override
  String notificationTransferTitle(String type, String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'processing': 'Deposit Processing',
      'success': 'Deposit Successful',
      'failed': 'Deposit Failed',
      'other': 'Deposit Update',
    });
    String _temp1 = intl.Intl.selectLogic(status, {
      'processing': 'Withdrawal Processing',
      'success': 'Withdrawal Successful',
      'failed': 'Withdrawal Failed',
      'other': 'Withdrawal Update',
    });
    String _temp2 = intl.Intl.selectLogic(type, {
      'deposit': '$_temp0',
      'withdraw': '$_temp1',
      'other': 'Transfer Update',
    });
    return '$_temp2';
  }
}
