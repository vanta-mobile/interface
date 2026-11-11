import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('zh')];

  /// No description provided for @demoOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Local demo positions and orders'**
  String get demoOrdersTitle;

  /// No description provided for @connectExternalWallet.
  ///
  /// In en, this message translates to:
  /// **'Connect EOA wallet'**
  String get connectExternalWallet;

  /// No description provided for @externalWallet.
  ///
  /// In en, this message translates to:
  /// **'External EOA wallet'**
  String get externalWallet;

  /// No description provided for @embeddedWallet.
  ///
  /// In en, this message translates to:
  /// **'Privy embedded wallet'**
  String get embeddedWallet;

  /// No description provided for @reconnectExternalWallet.
  ///
  /// In en, this message translates to:
  /// **'Connect wallet'**
  String get reconnectExternalWallet;

  /// No description provided for @externalWalletLoginHint.
  ///
  /// In en, this message translates to:
  /// **'Connect and sign in with your existing wallet. No extra wallet is created. Sign-in does not enable live trading.'**
  String get externalWalletLoginHint;

  /// No description provided for @walletConnectStep.
  ///
  /// In en, this message translates to:
  /// **'Confirm the connection in your wallet.'**
  String get walletConnectStep;

  /// No description provided for @authWalletConfiguration.
  ///
  /// In en, this message translates to:
  /// **'External wallet sign-in is not available.'**
  String get authWalletConfiguration;

  /// No description provided for @authWalletCancelled.
  ///
  /// In en, this message translates to:
  /// **'Wallet connection cancelled. You can retry.'**
  String get authWalletCancelled;

  /// No description provided for @authWalletRejected.
  ///
  /// In en, this message translates to:
  /// **'Wallet request rejected. You can retry.'**
  String get authWalletRejected;

  /// No description provided for @authWalletUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Wallet connection failed. Check your wallet app and network, then retry.'**
  String get authWalletUnavailable;

  /// No description provided for @walletResponseReason.
  ///
  /// In en, this message translates to:
  /// **'Wallet response: {reason}'**
  String walletResponseReason(String reason);

  /// No description provided for @authWalletBusy.
  ///
  /// In en, this message translates to:
  /// **'Another wallet request is pending. Finish it before continuing.'**
  String get authWalletBusy;

  /// No description provided for @authWalletSigningNetwork.
  ///
  /// In en, this message translates to:
  /// **'Enable and select BNB Chain (chain ID 56) in your wallet, allow this app to connect to it, then reconnect before enabling trading.'**
  String get authWalletSigningNetwork;

  /// No description provided for @authWalletConnectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Wallet connection setup timed out. Check your network and retry.'**
  String get authWalletConnectionTimeout;

  /// No description provided for @authWalletUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Select Ethereum, BNB Chain, Arbitrum, or Base in your wallet.'**
  String get authWalletUnsupported;

  /// No description provided for @authWalletChanged.
  ///
  /// In en, this message translates to:
  /// **'Wallet account or network changed. Reconnect and sign in again.'**
  String get authWalletChanged;

  /// No description provided for @authWalletReconnect.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet to continue.'**
  String get authWalletReconnect;

  /// No description provided for @authWalletSignature.
  ///
  /// In en, this message translates to:
  /// **'Your wallet did not return a valid signature. Please retry.'**
  String get authWalletSignature;

  /// No description provided for @quotesConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting live quotes'**
  String get quotesConnecting;

  /// No description provided for @quotesLive.
  ///
  /// In en, this message translates to:
  /// **'Live quotes'**
  String get quotesLive;

  /// No description provided for @quotesPartial.
  ///
  /// In en, this message translates to:
  /// **'Some quotes are reconnecting'**
  String get quotesPartial;

  /// No description provided for @quotesOffline.
  ///
  /// In en, this message translates to:
  /// **'Quotes offline. Showing recent data'**
  String get quotesOffline;

  /// No description provided for @quotesUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get quotesUpdatedAt;

  /// No description provided for @quotesSnapshotFailure.
  ///
  /// In en, this message translates to:
  /// **'Quote refresh failed. Available data is retained. Check your connection and retry.'**
  String get quotesSnapshotFailure;

  /// No description provided for @quotesDataFailure.
  ///
  /// In en, this message translates to:
  /// **'Some quotes are invalid or missing. Showing the last valid values.'**
  String get quotesDataFailure;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @chartType.
  ///
  /// In en, this message translates to:
  /// **'Chart type'**
  String get chartType;

  /// No description provided for @loadingChart.
  ///
  /// In en, this message translates to:
  /// **'Loading chart'**
  String get loadingChart;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @moreTimeframes.
  ///
  /// In en, this message translates to:
  /// **'All intervals'**
  String get moreTimeframes;

  /// No description provided for @typeCandles.
  ///
  /// In en, this message translates to:
  /// **'Candles'**
  String get typeCandles;

  /// No description provided for @typeHollowCandles.
  ///
  /// In en, this message translates to:
  /// **'Hollow candles'**
  String get typeHollowCandles;

  /// No description provided for @typeBars.
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get typeBars;

  /// No description provided for @typeLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get typeLine;

  /// No description provided for @typeLineWithMarkers.
  ///
  /// In en, this message translates to:
  /// **'Line with markers'**
  String get typeLineWithMarkers;

  /// No description provided for @typeStepLine.
  ///
  /// In en, this message translates to:
  /// **'Step line'**
  String get typeStepLine;

  /// No description provided for @typeArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get typeArea;

  /// No description provided for @typeBaseline.
  ///
  /// In en, this message translates to:
  /// **'Baseline'**
  String get typeBaseline;

  /// No description provided for @typeColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get typeColumns;

  /// No description provided for @typeHighLow.
  ///
  /// In en, this message translates to:
  /// **'High-low'**
  String get typeHighLow;

  /// No description provided for @typeHeikinAshi.
  ///
  /// In en, this message translates to:
  /// **'Heikin Ashi'**
  String get typeHeikinAshi;

  /// No description provided for @heikinAshiHint.
  ///
  /// In en, this message translates to:
  /// **'Heikin Ashi is derived; quotes and details use source prices'**
  String get heikinAshiHint;

  /// No description provided for @priceScale.
  ///
  /// In en, this message translates to:
  /// **'Price scale'**
  String get priceScale;

  /// No description provided for @scaleRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get scaleRegular;

  /// No description provided for @scaleLogarithmic.
  ///
  /// In en, this message translates to:
  /// **'Logarithmic'**
  String get scaleLogarithmic;

  /// No description provided for @scalePercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get scalePercentage;

  /// No description provided for @scaleIndexed.
  ///
  /// In en, this message translates to:
  /// **'Indexed to 100'**
  String get scaleIndexed;

  /// No description provided for @relativeScaleHint.
  ///
  /// In en, this message translates to:
  /// **'Based on the first visible bar’s open'**
  String get relativeScaleHint;

  /// No description provided for @loadingHistory.
  ///
  /// In en, this message translates to:
  /// **'Loading history…'**
  String get loadingHistory;

  /// No description provided for @historyEnd.
  ///
  /// In en, this message translates to:
  /// **'No earlier history'**
  String get historyEnd;

  /// No description provided for @indicatorParameters.
  ///
  /// In en, this message translates to:
  /// **'Indicator parameters'**
  String get indicatorParameters;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @period1.
  ///
  /// In en, this message translates to:
  /// **'Period 1'**
  String get period1;

  /// No description provided for @period2.
  ///
  /// In en, this message translates to:
  /// **'Period 2'**
  String get period2;

  /// No description provided for @period3.
  ///
  /// In en, this message translates to:
  /// **'Period 3'**
  String get period3;

  /// No description provided for @period4.
  ///
  /// In en, this message translates to:
  /// **'Period 4'**
  String get period4;

  /// No description provided for @deviations.
  ///
  /// In en, this message translates to:
  /// **'Standard deviations'**
  String get deviations;

  /// No description provided for @fastPeriod.
  ///
  /// In en, this message translates to:
  /// **'Fast period'**
  String get fastPeriod;

  /// No description provided for @slowPeriod.
  ///
  /// In en, this message translates to:
  /// **'Slow period'**
  String get slowPeriod;

  /// No description provided for @signalPeriod.
  ///
  /// In en, this message translates to:
  /// **'Signal period'**
  String get signalPeriod;

  /// No description provided for @smoothK.
  ///
  /// In en, this message translates to:
  /// **'K smoothing'**
  String get smoothK;

  /// No description provided for @smoothD.
  ///
  /// In en, this message translates to:
  /// **'D smoothing'**
  String get smoothD;

  /// No description provided for @invalidChartParameter.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid value in range'**
  String get invalidChartParameter;

  /// No description provided for @invalidMacdPeriods.
  ///
  /// In en, this message translates to:
  /// **'Fast period must be smaller than slow period'**
  String get invalidMacdPeriods;

  /// No description provided for @resetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset defaults'**
  String get resetDefaults;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @mainIndicators.
  ///
  /// In en, this message translates to:
  /// **'Main overlays'**
  String get mainIndicators;

  /// No description provided for @secondaryIndicators.
  ///
  /// In en, this message translates to:
  /// **'Lower indicator'**
  String get secondaryIndicators;

  /// No description provided for @volumeBars.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volumeBars;

  /// No description provided for @indicatorHint.
  ///
  /// In en, this message translates to:
  /// **'Overlays share the price pane. Show one lower indicator at a time, switch or hide it whenever you need.'**
  String get indicatorHint;

  /// No description provided for @exitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get exitFullscreen;

  /// No description provided for @marketDetails.
  ///
  /// In en, this message translates to:
  /// **'Market details'**
  String get marketDetails;

  /// No description provided for @depth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get depth;

  /// No description provided for @candles.
  ///
  /// In en, this message translates to:
  /// **'Candles'**
  String get candles;

  /// No description provided for @lineChart.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get lineChart;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Market cache'**
  String get sync;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'History loading / gap repair'**
  String get syncing;

  /// No description provided for @closedCandle.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closedCandle;

  /// No description provided for @formingCandle.
  ///
  /// In en, this message translates to:
  /// **'Forming'**
  String get formingCandle;

  /// No description provided for @eventTime.
  ///
  /// In en, this message translates to:
  /// **'Event time'**
  String get eventTime;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Candle start'**
  String get startTime;

  /// No description provided for @chartSource.
  ///
  /// In en, this message translates to:
  /// **'Aster Perpetuals · USDT'**
  String get chartSource;

  /// No description provided for @chartSourceShort.
  ///
  /// In en, this message translates to:
  /// **'Aster · USDT'**
  String get chartSourceShort;

  /// No description provided for @marketSource.
  ///
  /// In en, this message translates to:
  /// **'Aster Perpetuals'**
  String get marketSource;

  /// No description provided for @poweredBy.
  ///
  /// In en, this message translates to:
  /// **'VANTA  /  POWERED BY ASTER'**
  String get poweredBy;

  /// No description provided for @gap.
  ///
  /// In en, this message translates to:
  /// **'Candle gap detected. Backfilling'**
  String get gap;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect wallet'**
  String get connect;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Vanta'**
  String get loginTitle;

  /// No description provided for @loginDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect an existing EOA wallet, or sign in with an email code to use a Privy wallet.'**
  String get loginDescription;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send verification code'**
  String get sendCode;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit verification code'**
  String get verificationCode;

  /// No description provided for @verifyAndLogin.
  ///
  /// In en, this message translates to:
  /// **'Verify and sign in'**
  String get verifyAndLogin;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmail;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy wallet address'**
  String get copyAddress;

  /// No description provided for @createWallet.
  ///
  /// In en, this message translates to:
  /// **'Create embedded wallet'**
  String get createWallet;

  /// No description provided for @tradingNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Wallet signed in. Use the separate live-order entry to review a real order; Aster authorization is required.'**
  String get tradingNotEnabled;

  /// No description provided for @loginInProgress.
  ///
  /// In en, this message translates to:
  /// **'Processing sign-in…'**
  String get loginInProgress;

  /// No description provided for @walletInProgress.
  ///
  /// In en, this message translates to:
  /// **'Processing wallet session…'**
  String get walletInProgress;

  /// No description provided for @demoAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Try trading with separate local demo funds. Your Privy wallet is unaffected.'**
  String get demoAccountHint;

  /// No description provided for @authConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Privy sign-in is not configured in this build. Contact the app provider.'**
  String get authConfiguration;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authInvalidEmail;

  /// No description provided for @authInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'The code is invalid or expired. Check it or request a new code.'**
  String get authInvalidCode;

  /// No description provided for @authNetwork.
  ///
  /// In en, this message translates to:
  /// **'Sign-in connection failed. Check your network and retry.'**
  String get authNetwork;

  /// No description provided for @authRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Try again shortly.'**
  String get authRateLimited;

  /// No description provided for @authSessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Sign in again.'**
  String get authSessionUnavailable;

  /// No description provided for @authUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is unavailable. Please retry.'**
  String get authUnavailable;

  /// No description provided for @demo.
  ///
  /// In en, this message translates to:
  /// **'Demo account'**
  String get demo;

  /// No description provided for @perpetual.
  ///
  /// In en, this message translates to:
  /// **'Perpetual'**
  String get perpetual;

  /// No description provided for @perps.
  ///
  /// In en, this message translates to:
  /// **'Perps'**
  String get perps;

  /// No description provided for @markets.
  ///
  /// In en, this message translates to:
  /// **'Markets'**
  String get markets;

  /// No description provided for @portfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get portfolio;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @trade.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get trade;

  /// No description provided for @chart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get chart;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'24h change'**
  String get change;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'24h volume'**
  String get volume;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'24h high'**
  String get high;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'24h low'**
  String get low;

  /// No description provided for @mark.
  ///
  /// In en, this message translates to:
  /// **'Mark price'**
  String get mark;

  /// No description provided for @index.
  ///
  /// In en, this message translates to:
  /// **'Index price'**
  String get index;

  /// No description provided for @funding.
  ///
  /// In en, this message translates to:
  /// **'Funding / countdown'**
  String get funding;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Order book'**
  String get book;

  /// No description provided for @trades.
  ///
  /// In en, this message translates to:
  /// **'Recent trades'**
  String get trades;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy / Long'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell / Short'**
  String get sell;

  /// No description provided for @long.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get long;

  /// No description provided for @short.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get short;

  /// No description provided for @cross.
  ///
  /// In en, this message translates to:
  /// **'Cross'**
  String get cross;

  /// No description provided for @leverage.
  ///
  /// In en, this message translates to:
  /// **'Leverage'**
  String get leverage;

  /// No description provided for @leverageHint.
  ///
  /// In en, this message translates to:
  /// **'Higher leverage increases the risk from price movements.'**
  String get leverageHint;

  /// No description provided for @limit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get limit;

  /// No description provided for @market.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get market;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @marketPrice.
  ///
  /// In en, this message translates to:
  /// **'Execute at current market price'**
  String get marketPrice;

  /// No description provided for @orderValue.
  ///
  /// In en, this message translates to:
  /// **'Order value'**
  String get orderValue;

  /// No description provided for @margin.
  ///
  /// In en, this message translates to:
  /// **'Required margin'**
  String get margin;

  /// No description provided for @tradeEstimatedLiquidation.
  ///
  /// In en, this message translates to:
  /// **'Est. Liq. Price'**
  String get tradeEstimatedLiquidation;

  /// No description provided for @tradeMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get tradeMargin;

  /// No description provided for @fees.
  ///
  /// In en, this message translates to:
  /// **'Estimated fee'**
  String get fees;

  /// No description provided for @reduceOnly.
  ///
  /// In en, this message translates to:
  /// **'Reduce only'**
  String get reduceOnly;

  /// No description provided for @positions.
  ///
  /// In en, this message translates to:
  /// **'Positions'**
  String get positions;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Open orders'**
  String get orders;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @pnl.
  ///
  /// In en, this message translates to:
  /// **'Unrealized PnL'**
  String get pnl;

  /// No description provided for @noPositions.
  ///
  /// In en, this message translates to:
  /// **'No open positions'**
  String get noPositions;

  /// No description provided for @noPositionsHint.
  ///
  /// In en, this message translates to:
  /// **'Your next opportunity starts with your first trade.'**
  String get noPositionsHint;

  /// No description provided for @noOrders.
  ///
  /// In en, this message translates to:
  /// **'No open orders'**
  String get noOrders;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No trade history'**
  String get noHistory;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Your gateway to trading'**
  String get walletTitle;

  /// No description provided for @walletHint.
  ///
  /// In en, this message translates to:
  /// **'Explore local demo trading or use the separate live-order entry with your wallet. Fund transfers are not enabled.'**
  String get walletHint;

  /// No description provided for @enterDemo.
  ///
  /// In en, this message translates to:
  /// **'Try demo account'**
  String get enterDemo;

  /// No description provided for @demoBalance.
  ///
  /// In en, this message translates to:
  /// **'10,000 USDT demo funds · No real execution'**
  String get demoBalance;

  /// No description provided for @demoActive.
  ///
  /// In en, this message translates to:
  /// **'Local demo · No real execution'**
  String get demoActive;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review order'**
  String get review;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm demo order'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @entry.
  ///
  /// In en, this message translates to:
  /// **'Entry price'**
  String get entry;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Position size'**
  String get size;

  /// No description provided for @invalidQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive quantity aligned to the market quantity step.'**
  String get invalidQuantity;

  /// No description provided for @invalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive price aligned to the market price tick.'**
  String get invalidPrice;

  /// No description provided for @insufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient margin. Reduce quantity or adjust leverage.'**
  String get insufficient;

  /// No description provided for @reduceHint.
  ///
  /// In en, this message translates to:
  /// **'Reduce only requires a sufficient opposite position in the same market.'**
  String get reduceHint;

  /// No description provided for @submitted.
  ///
  /// In en, this message translates to:
  /// **'Demo order submitted'**
  String get submitted;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Demo position closed'**
  String get closed;

  /// No description provided for @canceled.
  ///
  /// In en, this message translates to:
  /// **'Demo order canceled'**
  String get canceled;

  /// No description provided for @filled.
  ///
  /// In en, this message translates to:
  /// **'Filled'**
  String get filled;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @canceledStatus.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get canceledStatus;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'History · reconnecting'**
  String get offline;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live market'**
  String get live;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get retry;

  /// No description provided for @statusLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to Load'**
  String get statusLoadFailedTitle;

  /// No description provided for @statusLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get statusLoadFailedMessage;

  /// No description provided for @statusRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get statusRetry;

  /// No description provided for @statusEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Data Yet'**
  String get statusEmptyTitle;

  /// No description provided for @statusEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'There\'s nothing to display here right now.'**
  String get statusEmptyMessage;

  /// No description provided for @statusNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get statusNoResultsTitle;

  /// No description provided for @statusNoResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'Try searching with another term.'**
  String get statusNoResultsMessage;

  /// No description provided for @statusNoAssetsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Assets Yet'**
  String get statusNoAssetsTitle;

  /// No description provided for @statusNoAssetsMessage.
  ///
  /// In en, this message translates to:
  /// **'Deposit funds to get started with trading.'**
  String get statusNoAssetsMessage;

  /// No description provided for @snapshotHint.
  ///
  /// In en, this message translates to:
  /// **'Realtime disconnected. Showing recent history.'**
  String get snapshotHint;

  /// No description provided for @marketUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Market unavailable. Please retry.'**
  String get marketUnavailable;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search markets'**
  String get search;

  /// No description provided for @selectMarket.
  ///
  /// In en, this message translates to:
  /// **'Select market'**
  String get selectMarket;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @allMarkets.
  ///
  /// In en, this message translates to:
  /// **'All perpetuals'**
  String get allMarkets;

  /// No description provided for @lastPrice.
  ///
  /// In en, this message translates to:
  /// **'Last price'**
  String get lastPrice;

  /// No description provided for @fundingRate.
  ///
  /// In en, this message translates to:
  /// **'Funding rate'**
  String get fundingRate;

  /// No description provided for @volume24h.
  ///
  /// In en, this message translates to:
  /// **'24h volume'**
  String get volume24h;

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFavorite;

  /// No description provided for @emptyFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorite markets yet'**
  String get emptyFavorites;

  /// No description provided for @noMarketsFound.
  ///
  /// In en, this message translates to:
  /// **'No matching markets'**
  String get noMarketsFound;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @equity.
  ///
  /// In en, this message translates to:
  /// **'Total equity'**
  String get equity;

  /// No description provided for @usedMargin.
  ///
  /// In en, this message translates to:
  /// **'Used margin'**
  String get usedMargin;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Account overview'**
  String get overview;

  /// No description provided for @portfolioHint.
  ///
  /// In en, this message translates to:
  /// **'Connect your account to start trading.'**
  String get portfolioHint;

  /// No description provided for @pointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Every trade takes you further.'**
  String get pointsTitle;

  /// No description provided for @pointsHint.
  ///
  /// In en, this message translates to:
  /// **'Vanta Genesis rewards live trading and ecosystem participation. Demo trades do not earn points.'**
  String get pointsHint;

  /// No description provided for @yourPoints.
  ///
  /// In en, this message translates to:
  /// **'Your Genesis points'**
  String get yourPoints;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @aiTitle.
  ///
  /// In en, this message translates to:
  /// **'A little insight for your next move.'**
  String get aiTitle;

  /// No description provided for @aiHint.
  ///
  /// In en, this message translates to:
  /// **'Market analysis is planned for a future version. Explore live prices, charts and the order book on the trading page.'**
  String get aiHint;

  /// No description provided for @backToTrade.
  ///
  /// In en, this message translates to:
  /// **'Explore the market'**
  String get backToTrade;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @indicators.
  ///
  /// In en, this message translates to:
  /// **'Indicators'**
  String get indicators;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Expand chart'**
  String get fullscreen;

  /// No description provided for @chartHint.
  ///
  /// In en, this message translates to:
  /// **'Hold for details · Pinch to zoom'**
  String get chartHint;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Market connection'**
  String get network;

  /// No description provided for @demoReset.
  ///
  /// In en, this message translates to:
  /// **'Leave demo account'**
  String get demoReset;

  /// No description provided for @demoExitHint.
  ///
  /// In en, this message translates to:
  /// **'Leaving clears this session’s local demo positions and orders.'**
  String get demoExitHint;

  /// No description provided for @minOrder.
  ///
  /// In en, this message translates to:
  /// **'Minimum size'**
  String get minOrder;

  /// No description provided for @feeHint.
  ///
  /// In en, this message translates to:
  /// **'Demo fee of 0.05%, for simulation only.'**
  String get feeHint;

  /// No description provided for @orderReviewHint.
  ///
  /// In en, this message translates to:
  /// **'This local demo order will not be sent to the exchange.'**
  String get orderReviewHint;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh market'**
  String get refresh;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @bookWaiting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to order book…'**
  String get bookWaiting;

  /// No description provided for @bookError.
  ///
  /// In en, this message translates to:
  /// **'Order book disconnected. Reconnecting.'**
  String get bookError;

  /// No description provided for @noTrades.
  ///
  /// In en, this message translates to:
  /// **'Waiting for recent trades…'**
  String get noTrades;

  /// No description provided for @spot.
  ///
  /// In en, this message translates to:
  /// **'Spot'**
  String get spot;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'O'**
  String get open;

  /// No description provided for @candleHigh.
  ///
  /// In en, this message translates to:
  /// **'H'**
  String get candleHigh;

  /// No description provided for @candleLow.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get candleLow;

  /// No description provided for @candleClose.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get candleClose;

  /// No description provided for @orderId.
  ///
  /// In en, this message translates to:
  /// **'Order ID'**
  String get orderId;

  /// No description provided for @tapPrice.
  ///
  /// In en, this message translates to:
  /// **'Tap a book price to fill your order'**
  String get tapPrice;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @languageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Language could not be saved. Please retry.'**
  String get languageSaveFailed;

  /// No description provided for @saveLanguage.
  ///
  /// In en, this message translates to:
  /// **'Save language'**
  String get saveLanguage;

  /// No description provided for @midPrice.
  ///
  /// In en, this message translates to:
  /// **'Mid'**
  String get midPrice;

  /// No description provided for @resendCountdown.
  ///
  /// In en, this message translates to:
  /// **'Resend code ({seconds}s)'**
  String resendCountdown(int seconds);

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @asterAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Aster perpetual account'**
  String get asterAccountTitle;

  /// No description provided for @asterAccountTab.
  ///
  /// In en, this message translates to:
  /// **'Aster account'**
  String get asterAccountTab;

  /// No description provided for @asterAccountScope.
  ///
  /// In en, this message translates to:
  /// **'Account data belongs to the wallet below. An authorized device signing key signs queries automatically.'**
  String get asterAccountScope;

  /// No description provided for @asterUsdtSummary.
  ///
  /// In en, this message translates to:
  /// **'USDT account summary'**
  String get asterUsdtSummary;

  /// No description provided for @asterMarginBalance.
  ///
  /// In en, this message translates to:
  /// **'Margin balance'**
  String get asterMarginBalance;

  /// No description provided for @asterUsdtScope.
  ///
  /// In en, this message translates to:
  /// **'USDT only. Other assets retain their own units below; this is not the total value of Spot, staking, vaults, or sub-accounts.'**
  String get asterUsdtScope;

  /// Local receipt time of the Aster account snapshot
  ///
  /// In en, this message translates to:
  /// **'Snapshot received: {time}'**
  String accountSnapshotTime(String time);

  /// No description provided for @accountSnapshotStale.
  ///
  /// In en, this message translates to:
  /// **'Previous snapshot. Sign to refresh before relying on these values.'**
  String get accountSnapshotStale;

  /// No description provided for @accountSignInToRead.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view account'**
  String get accountSignInToRead;

  /// No description provided for @accountReadWithWallet.
  ///
  /// In en, this message translates to:
  /// **'Read Aster account'**
  String get accountReadWithWallet;

  /// No description provided for @accountRefreshWithWallet.
  ///
  /// In en, this message translates to:
  /// **'Refresh account'**
  String get accountRefreshWithWallet;

  /// No description provided for @accountReadPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing account request…'**
  String get accountReadPreparing;

  /// No description provided for @accountReadSigning.
  ///
  /// In en, this message translates to:
  /// **'Signing the account query…'**
  String get accountReadSigning;

  /// No description provided for @accountReadLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading account data from Aster…'**
  String get accountReadLoading;

  /// No description provided for @accountReadNotice.
  ///
  /// In en, this message translates to:
  /// **'Read-only account query using the authorized device signing key. No order, transfer, or additional authorization is submitted. Data belongs to the selected account.'**
  String get accountReadNotice;

  /// Numeric error code returned by Aster; no raw server payload
  ///
  /// In en, this message translates to:
  /// **'Aster error code: {code}'**
  String accountErrorCode(int code);

  /// No description provided for @accountAssetBalances.
  ///
  /// In en, this message translates to:
  /// **'Perpetual asset balances'**
  String get accountAssetBalances;

  /// No description provided for @accountSearchAsset.
  ///
  /// In en, this message translates to:
  /// **'Search assets'**
  String get accountSearchAsset;

  /// No description provided for @accountHideZero.
  ///
  /// In en, this message translates to:
  /// **'Hide zero balances'**
  String get accountHideZero;

  /// No description provided for @accountNoAssets.
  ///
  /// In en, this message translates to:
  /// **'No asset balances returned for this account.'**
  String get accountNoAssets;

  /// No description provided for @accountNoMatchingAssets.
  ///
  /// In en, this message translates to:
  /// **'No assets match the current filters.'**
  String get accountNoMatchingAssets;

  /// No description provided for @accountCollateralEligible.
  ///
  /// In en, this message translates to:
  /// **'Eligible as collateral in Multi-Assets mode'**
  String get accountCollateralEligible;

  /// No description provided for @accountCollateralIneligible.
  ///
  /// In en, this message translates to:
  /// **'Not eligible as collateral in Multi-Assets mode'**
  String get accountCollateralIneligible;

  /// No description provided for @accountLivePositions.
  ///
  /// In en, this message translates to:
  /// **'Aster positions'**
  String get accountLivePositions;

  /// No description provided for @accountNoPositions.
  ///
  /// In en, this message translates to:
  /// **'No open perpetual positions.'**
  String get accountNoPositions;

  /// No description provided for @accountPositionMargin.
  ///
  /// In en, this message translates to:
  /// **'Position initial margin'**
  String get accountPositionMargin;

  /// No description provided for @accountWalletBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance'**
  String get accountWalletBalance;

  /// No description provided for @accountUnrealizedPnl.
  ///
  /// In en, this message translates to:
  /// **'Unrealized PnL'**
  String get accountUnrealizedPnl;

  /// No description provided for @accountPositionDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get accountPositionDirection;

  /// No description provided for @accountMarginMode.
  ///
  /// In en, this message translates to:
  /// **'Margin mode'**
  String get accountMarginMode;

  /// No description provided for @accountDataInvalid.
  ///
  /// In en, this message translates to:
  /// **'Aster returned incomplete or invalid account data. Retry to refresh.'**
  String get accountDataInvalid;

  /// No description provided for @accountRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Aster has limited account requests. Wait before trying again.'**
  String get accountRateLimited;

  /// No description provided for @accountNetwork.
  ///
  /// In en, this message translates to:
  /// **'Account data could not be read. Check your connection and retry.'**
  String get accountNetwork;

  /// No description provided for @accountReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Aster could not complete the account query. Retry or check the account permissions.'**
  String get accountReadFailed;

  /// No description provided for @accountSignatureExpired.
  ///
  /// In en, this message translates to:
  /// **'The account signature expired. Retry and confirm the new wallet request promptly.'**
  String get accountSignatureExpired;

  /// No description provided for @accountSignatureRejected.
  ///
  /// In en, this message translates to:
  /// **'Aster rejected the account signature. Check your wallet and account authorization.'**
  String get accountSignatureRejected;

  /// No description provided for @accountPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Aster has not accepted this wallet’s account access. Check its Aster API authorization; signing in to Vanta does not grant it.'**
  String get accountPermissionRequired;

  /// No description provided for @accountUnitUnavailable.
  ///
  /// In en, this message translates to:
  /// **'(unit unavailable)'**
  String get accountUnitUnavailable;

  /// No description provided for @accountIsolatedMode.
  ///
  /// In en, this message translates to:
  /// **'Isolated'**
  String get accountIsolatedMode;

  /// No description provided for @marketResultsCount.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} perpetuals'**
  String marketResultsCount(int shown, int total);

  /// No description provided for @accountPerpetualTab.
  ///
  /// In en, this message translates to:
  /// **'Perpetual'**
  String get accountPerpetualTab;

  /// No description provided for @accountSpotTab.
  ///
  /// In en, this message translates to:
  /// **'Spot'**
  String get accountSpotTab;

  /// No description provided for @spotAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Aster spot account'**
  String get spotAccountTitle;

  /// No description provided for @spotBalanceScope.
  ///
  /// In en, this message translates to:
  /// **'Balances are asset quantities. Total = available + locked. Spot and perpetual balances are shown separately.'**
  String get spotBalanceScope;

  /// No description provided for @spotAssetBalances.
  ///
  /// In en, this message translates to:
  /// **'Spot asset balances'**
  String get spotAssetBalances;

  /// No description provided for @spotNoAssets.
  ///
  /// In en, this message translates to:
  /// **'No assets in this spot account.'**
  String get spotNoAssets;

  /// No description provided for @spotTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get spotTotalBalance;

  /// No description provided for @spotLockedBalance.
  ///
  /// In en, this message translates to:
  /// **'Locked balance'**
  String get spotLockedBalance;

  /// No description provided for @asterOpenOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Aster open perpetual orders'**
  String get asterOpenOrdersTitle;

  /// No description provided for @asterOpenOrdersScope.
  ///
  /// In en, this message translates to:
  /// **'Live-account futures orders, separate from the demo orders above. Reading and cancellation require wallet signatures and Aster authorization.'**
  String get asterOpenOrdersScope;

  /// No description provided for @openOrdersReadWithWallet.
  ///
  /// In en, this message translates to:
  /// **'Sign to read open orders'**
  String get openOrdersReadWithWallet;

  /// No description provided for @openOrdersRefreshWithWallet.
  ///
  /// In en, this message translates to:
  /// **'Sign to refresh open orders'**
  String get openOrdersRefreshWithWallet;

  /// No description provided for @openOrdersCurrentSymbol.
  ///
  /// In en, this message translates to:
  /// **'Hide other symbols'**
  String get openOrdersCurrentSymbol;

  /// No description provided for @openOrdersCount.
  ///
  /// In en, this message translates to:
  /// **'Open orders ({count})'**
  String openOrdersCount(int count);

  /// No description provided for @openOrdersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open perpetual orders in this account.'**
  String get openOrdersEmpty;

  /// No description provided for @openOrdersNoCurrentSymbol.
  ///
  /// In en, this message translates to:
  /// **'No open orders for the current symbol.'**
  String get openOrdersNoCurrentSymbol;

  /// No description provided for @openOrdersBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get openOrdersBuy;

  /// No description provided for @openOrdersSell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get openOrdersSell;

  /// No description provided for @openOrdersLongSide.
  ///
  /// In en, this message translates to:
  /// **'Long side'**
  String get openOrdersLongSide;

  /// No description provided for @openOrdersShortSide.
  ///
  /// In en, this message translates to:
  /// **'Short side'**
  String get openOrdersShortSide;

  /// No description provided for @openOrdersOneWay.
  ///
  /// In en, this message translates to:
  /// **'One-way'**
  String get openOrdersOneWay;

  /// No description provided for @openOrdersOrderType.
  ///
  /// In en, this message translates to:
  /// **'Order type'**
  String get openOrdersOrderType;

  /// No description provided for @openOrdersStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get openOrdersStatus;

  /// No description provided for @openOrdersNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get openOrdersNew;

  /// No description provided for @openOrdersPartiallyFilled.
  ///
  /// In en, this message translates to:
  /// **'Partially filled'**
  String get openOrdersPartiallyFilled;

  /// No description provided for @openOrdersCreatedLocal.
  ///
  /// In en, this message translates to:
  /// **'Placed (local time)'**
  String get openOrdersCreatedLocal;

  /// No description provided for @openOrdersFilledTotal.
  ///
  /// In en, this message translates to:
  /// **'Filled / total'**
  String get openOrdersFilledTotal;

  /// No description provided for @openOrdersRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get openOrdersRemaining;

  /// No description provided for @openOrdersClosePosition.
  ///
  /// In en, this message translates to:
  /// **'Close entire position'**
  String get openOrdersClosePosition;

  /// No description provided for @openOrdersOrderPrice.
  ///
  /// In en, this message translates to:
  /// **'Order price'**
  String get openOrdersOrderPrice;

  /// No description provided for @openOrdersOrderValue.
  ///
  /// In en, this message translates to:
  /// **'Order value'**
  String get openOrdersOrderValue;

  /// No description provided for @openOrdersActivationPrice.
  ///
  /// In en, this message translates to:
  /// **'Activation price'**
  String get openOrdersActivationPrice;

  /// No description provided for @openOrdersCallbackRate.
  ///
  /// In en, this message translates to:
  /// **'Callback rate'**
  String get openOrdersCallbackRate;

  /// No description provided for @openOrdersTriggerPrice.
  ///
  /// In en, this message translates to:
  /// **'Trigger price'**
  String get openOrdersTriggerPrice;

  /// No description provided for @openOrdersMarkPrice.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get openOrdersMarkPrice;

  /// No description provided for @openOrdersLastPrice.
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get openOrdersLastPrice;

  /// No description provided for @openOrdersUnknownTrigger.
  ///
  /// In en, this message translates to:
  /// **'Trigger basis unavailable'**
  String get openOrdersUnknownTrigger;

  /// No description provided for @openOrdersReduceOnly.
  ///
  /// In en, this message translates to:
  /// **'Reduce only'**
  String get openOrdersReduceOnly;

  /// No description provided for @openOrdersHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get openOrdersHidden;

  /// No description provided for @openOrdersLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get openOrdersLimit;

  /// No description provided for @openOrdersMarket.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get openOrdersMarket;

  /// No description provided for @openOrdersStopLimit.
  ///
  /// In en, this message translates to:
  /// **'Stop limit'**
  String get openOrdersStopLimit;

  /// No description provided for @openOrdersStopMarket.
  ///
  /// In en, this message translates to:
  /// **'Stop market'**
  String get openOrdersStopMarket;

  /// No description provided for @openOrdersTakeProfitLimit.
  ///
  /// In en, this message translates to:
  /// **'Take-profit limit'**
  String get openOrdersTakeProfitLimit;

  /// No description provided for @openOrdersTakeProfitMarket.
  ///
  /// In en, this message translates to:
  /// **'Take-profit market'**
  String get openOrdersTakeProfitMarket;

  /// No description provided for @openOrdersTrailingStop.
  ///
  /// In en, this message translates to:
  /// **'Trailing stop'**
  String get openOrdersTrailingStop;

  /// No description provided for @openOrdersOtherType.
  ///
  /// In en, this message translates to:
  /// **'Other order type'**
  String get openOrdersOtherType;

  /// No description provided for @openOrdersBbo.
  ///
  /// In en, this message translates to:
  /// **'BBO peg'**
  String get openOrdersBbo;

  /// No description provided for @accountDepositRequired.
  ///
  /// In en, this message translates to:
  /// **'Aster requires the main wallet linked to this account to complete a deposit before V3 private account or order queries can be used.'**
  String get accountDepositRequired;

  /// No description provided for @orderCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get orderCancelTitle;

  /// No description provided for @orderCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep order'**
  String get orderCancelKeep;

  /// No description provided for @orderCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign cancellation'**
  String get orderCancelConfirm;

  /// No description provided for @orderCancelConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Cancel only the unfilled remainder of this perpetual order. Filled positions remain. Your current wallet will sign the cancellation, then a separate status query. Aster authorization is required.'**
  String get orderCancelConfirmHint;

  /// No description provided for @orderCancelSigning.
  ///
  /// In en, this message translates to:
  /// **'Confirm the cancellation signature in your wallet.'**
  String get orderCancelSigning;

  /// No description provided for @orderCancelSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting cancellation. The outcome is not confirmed yet.'**
  String get orderCancelSubmitting;

  /// No description provided for @orderCancelChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the final order status.'**
  String get orderCancelChecking;

  /// No description provided for @orderCancelCheckSigning.
  ///
  /// In en, this message translates to:
  /// **'Sign the status query in your wallet to verify the cancellation outcome.'**
  String get orderCancelCheckSigning;

  /// No description provided for @orderCancelUnknown.
  ///
  /// In en, this message translates to:
  /// **'Cancellation outcome is unconfirmed. The order is retained until its status is verified. Check status before sending another cancellation.'**
  String get orderCancelUnknown;

  /// No description provided for @orderCancelRecheck.
  ///
  /// In en, this message translates to:
  /// **'Sign and check status'**
  String get orderCancelRecheck;

  /// No description provided for @orderCancelVerified.
  ///
  /// In en, this message translates to:
  /// **'Aster confirmed this order is cancelled. Any filled position remains; account balances need refreshing.'**
  String get orderCancelVerified;

  /// No description provided for @orderCancelFilled.
  ///
  /// In en, this message translates to:
  /// **'Aster reports this order is fully filled. It was not cancelled. Refresh positions and balances.'**
  String get orderCancelFilled;

  /// No description provided for @orderCancelExpired.
  ///
  /// In en, this message translates to:
  /// **'Aster reports this order has expired. Refresh positions and balances.'**
  String get orderCancelExpired;

  /// No description provided for @orderCancelRejected.
  ///
  /// In en, this message translates to:
  /// **'Aster reports this order was rejected. Refresh positions and balances.'**
  String get orderCancelRejected;

  /// No description provided for @orderCancelStillOpen.
  ///
  /// In en, this message translates to:
  /// **'Aster reports this order is still open. Review its current filled amount before retrying.'**
  String get orderCancelStillOpen;

  /// No description provided for @batchCancelAll.
  ///
  /// In en, this message translates to:
  /// **'Cancel all listed orders'**
  String get batchCancelAll;

  /// No description provided for @batchCancelCurrent.
  ///
  /// In en, this message translates to:
  /// **'Cancel all current-symbol orders'**
  String get batchCancelCurrent;

  /// No description provided for @batchCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel all perpetual orders?'**
  String get batchCancelTitle;

  /// No description provided for @batchCancelHint.
  ///
  /// In en, this message translates to:
  /// **'Cancel all orders on the listed futures symbols when Aster processes each request, including orders added on other devices. Other symbols and Spot orders are outside this scope. Each symbol requires cancellation and status-query signatures. Filled positions remain.'**
  String get batchCancelHint;

  /// No description provided for @batchCancelScopeCount.
  ///
  /// In en, this message translates to:
  /// **'Snapshot: {orders, plural, =1{1 order} other{{orders} orders}} across {symbols, plural, =1{1 symbol} other{{symbols} symbols}}'**
  String batchCancelScopeCount(int orders, int symbols);

  /// No description provided for @batchCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign and cancel by symbol'**
  String get batchCancelConfirm;

  /// No description provided for @batchCancelNotSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Not submitted'**
  String get batchCancelNotSubmitted;

  /// No description provided for @batchCancelUnknown.
  ///
  /// In en, this message translates to:
  /// **'Outcome unconfirmed. Check status before retrying.'**
  String get batchCancelUnknown;

  /// No description provided for @batchCancelNoOpen.
  ///
  /// In en, this message translates to:
  /// **'No open orders at last check'**
  String get batchCancelNoOpen;

  /// No description provided for @batchCancelRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} open orders remain'**
  String batchCancelRemaining(int count);

  /// No description provided for @batchCancelRecheck.
  ///
  /// In en, this message translates to:
  /// **'Sign and check unconfirmed symbols'**
  String get batchCancelRecheck;

  /// No description provided for @batchCancelStop.
  ///
  /// In en, this message translates to:
  /// **'Stop further submissions'**
  String get batchCancelStop;

  /// No description provided for @batchCancelStopped.
  ///
  /// In en, this message translates to:
  /// **'Further submissions stopped. Check each symbol’s result.'**
  String get batchCancelStopped;

  /// No description provided for @batchCancelReadFirst.
  ///
  /// In en, this message translates to:
  /// **'Read your live open orders before cancelling all.'**
  String get batchCancelReadFirst;

  /// No description provided for @batchCancelInProgress.
  ///
  /// In en, this message translates to:
  /// **'Processing; outcome not yet verified'**
  String get batchCancelInProgress;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Spot history'**
  String get historyTitle;

  /// No description provided for @historyOrders.
  ///
  /// In en, this message translates to:
  /// **'Order history'**
  String get historyOrders;

  /// No description provided for @historyTrades.
  ///
  /// In en, this message translates to:
  /// **'Trade history'**
  String get historyTrades;

  /// No description provided for @historyTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get historyTransactions;

  /// No description provided for @historyScope.
  ///
  /// In en, this message translates to:
  /// **'History for the selected Spot wallet. Orders, individual fills and balance changes are separate records.'**
  String get historyScope;

  /// No description provided for @historySymbolFilter.
  ///
  /// In en, this message translates to:
  /// **'Spot symbol (optional)'**
  String get historySymbolFilter;

  /// No description provided for @historyAssetFilter.
  ///
  /// In en, this message translates to:
  /// **'Asset (optional)'**
  String get historyAssetFilter;

  /// No description provided for @historyFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Use the exact identifier; leave empty for all. Editing filters clears the previous results without signing.'**
  String get historyFilterHint;

  /// No description provided for @historyWindowLabel.
  ///
  /// In en, this message translates to:
  /// **'Query window (UTC)'**
  String get historyWindowLabel;

  /// No description provided for @historyDay.
  ///
  /// In en, this message translates to:
  /// **'Last 24 hours'**
  String get historyDay;

  /// No description provided for @historyWeek.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get historyWeek;

  /// No description provided for @historyCustom.
  ///
  /// In en, this message translates to:
  /// **'Choose dates'**
  String get historyCustom;

  /// No description provided for @historyRead.
  ///
  /// In en, this message translates to:
  /// **'Sign and read selected range'**
  String get historyRead;

  /// No description provided for @historyRefresh.
  ///
  /// In en, this message translates to:
  /// **'Sign and reread selected range'**
  String get historyRefresh;

  /// No description provided for @historyContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign and check next time window'**
  String get historyContinue;

  /// No description provided for @historyPartial.
  ///
  /// In en, this message translates to:
  /// **'The selected range is not fully checked. Each request covers at most seven days and 1,000 rows. Continue signing to read the remaining time windows.'**
  String get historyPartial;

  /// No description provided for @historyTruncated.
  ///
  /// In en, this message translates to:
  /// **'At least one millisecond reached the API row limit. These results are incomplete; narrow the symbol or asset filter.'**
  String get historyTruncated;

  /// No description provided for @historyComplete.
  ///
  /// In en, this message translates to:
  /// **'Selected time range checked within the API’s retention limits.'**
  String get historyComplete;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records were returned for the selected range and filters.'**
  String get historyEmpty;

  /// No description provided for @historyRetention.
  ///
  /// In en, this message translates to:
  /// **'The Spot orders API does not return orders created more than seven days ago.'**
  String get historyRetention;

  /// No description provided for @historyNotAtomic.
  ///
  /// In en, this message translates to:
  /// **'Results may change between reads. Continuing checks preserves the first response time and merges records by their identifiers.'**
  String get historyNotAtomic;

  /// No description provided for @historyInvalidScope.
  ///
  /// In en, this message translates to:
  /// **'Enter an exact symbol or asset identifier of up to 50 letters, digits, dots, underscores or hyphens.'**
  String get historyInvalidScope;

  /// No description provided for @historyInvalidWindow.
  ///
  /// In en, this message translates to:
  /// **'Select a valid date range. Order history is limited to seven days.'**
  String get historyInvalidWindow;

  /// No description provided for @historyLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded records: {count}'**
  String historyLoaded(int count);

  /// No description provided for @historyPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages} loaded pages'**
  String historyPage(int page, int pages);

  /// No description provided for @historyPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get historyPrev;

  /// No description provided for @historyNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get historyNext;

  /// No description provided for @historyCreatedUTC.
  ///
  /// In en, this message translates to:
  /// **'Created (UTC)'**
  String get historyCreatedUTC;

  /// No description provided for @historyUpdatedUTC.
  ///
  /// In en, this message translates to:
  /// **'Updated (UTC)'**
  String get historyUpdatedUTC;

  /// No description provided for @historyExecutionUTC.
  ///
  /// In en, this message translates to:
  /// **'Executed (UTC)'**
  String get historyExecutionUTC;

  /// No description provided for @historyEventUTC.
  ///
  /// In en, this message translates to:
  /// **'Time (UTC)'**
  String get historyEventUTC;

  /// No description provided for @historyAveragePrice.
  ///
  /// In en, this message translates to:
  /// **'Average fill price'**
  String get historyAveragePrice;

  /// No description provided for @historyExecutedQuote.
  ///
  /// In en, this message translates to:
  /// **'Filled quote amount'**
  String get historyExecutedQuote;

  /// No description provided for @historyTradeId.
  ///
  /// In en, this message translates to:
  /// **'Trade ID'**
  String get historyTradeId;

  /// No description provided for @historyTransactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction reference'**
  String get historyTransactionId;

  /// No description provided for @historyCommission.
  ///
  /// In en, this message translates to:
  /// **'Commission / rebate'**
  String get historyCommission;

  /// No description provided for @historyLiquidity.
  ///
  /// In en, this message translates to:
  /// **'Liquidity role'**
  String get historyLiquidity;

  /// No description provided for @historyMaker.
  ///
  /// In en, this message translates to:
  /// **'Maker'**
  String get historyMaker;

  /// No description provided for @historyTaker.
  ///
  /// In en, this message translates to:
  /// **'Taker'**
  String get historyTaker;

  /// No description provided for @historyBalanceChange.
  ///
  /// In en, this message translates to:
  /// **'Balance change'**
  String get historyBalanceChange;

  /// No description provided for @historyTransactionType.
  ///
  /// In en, this message translates to:
  /// **'Transaction type'**
  String get historyTransactionType;

  /// No description provided for @historyUnknownCode.
  ///
  /// In en, this message translates to:
  /// **'Other ({code})'**
  String historyUnknownCode(String code);

  /// No description provided for @historyFilled.
  ///
  /// In en, this message translates to:
  /// **'Filled'**
  String get historyFilled;

  /// No description provided for @historyCanceled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get historyCanceled;

  /// No description provided for @historyExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get historyExpired;

  /// No description provided for @historyRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get historyRejected;

  /// No description provided for @historyPendingCancel.
  ///
  /// In en, this message translates to:
  /// **'Pending cancellation'**
  String get historyPendingCancel;

  /// No description provided for @historyDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get historyDeposit;

  /// No description provided for @historyWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get historyWithdraw;

  /// No description provided for @historyTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get historyTransfer;

  /// No description provided for @historyTradeSource.
  ///
  /// In en, this message translates to:
  /// **'Trade debit'**
  String get historyTradeSource;

  /// No description provided for @historyTradeTarget.
  ///
  /// In en, this message translates to:
  /// **'Trade credit'**
  String get historyTradeTarget;

  /// No description provided for @historyAirdrop.
  ///
  /// In en, this message translates to:
  /// **'Airdrop'**
  String get historyAirdrop;

  /// No description provided for @historyDividend.
  ///
  /// In en, this message translates to:
  /// **'Dividend'**
  String get historyDividend;

  /// No description provided for @historySwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get historySwap;

  /// No description provided for @historyRebate.
  ///
  /// In en, this message translates to:
  /// **'Commission rebate'**
  String get historyRebate;

  /// No description provided for @historyTradeQuantity.
  ///
  /// In en, this message translates to:
  /// **'Filled quantity'**
  String get historyTradeQuantity;

  /// No description provided for @historyStop.
  ///
  /// In en, this message translates to:
  /// **'Stop waiting'**
  String get historyStop;

  /// No description provided for @historyReadStopped.
  ///
  /// In en, this message translates to:
  /// **'This read was stopped. You can try again.'**
  String get historyReadStopped;

  /// No description provided for @positionRiskTitle.
  ///
  /// In en, this message translates to:
  /// **'Position risk'**
  String get positionRiskTitle;

  /// No description provided for @positionRiskScope.
  ///
  /// In en, this message translates to:
  /// **'Read positions for the connected wallet. A signed snapshot is the baseline; enabled account monitoring can update individual positions. Public mark prices update estimates separately. Read account balances separately. Closing requires its own confirmation and signatures; TP/SL is not available yet.'**
  String get positionRiskScope;

  /// No description provided for @positionRiskRead.
  ///
  /// In en, this message translates to:
  /// **'Sign to read position risk'**
  String get positionRiskRead;

  /// No description provided for @positionRiskRefresh.
  ///
  /// In en, this message translates to:
  /// **'Sign to refresh position risk'**
  String get positionRiskRefresh;

  /// No description provided for @positionRiskCount.
  ///
  /// In en, this message translates to:
  /// **'Position records ({count})'**
  String positionRiskCount(int count);

  /// No description provided for @positionRiskNoCurrent.
  ///
  /// In en, this message translates to:
  /// **'No position records for the selected symbol.'**
  String get positionRiskNoCurrent;

  /// No description provided for @positionRiskBalanceOnly.
  ///
  /// In en, this message translates to:
  /// **'Negative isolated balance'**
  String get positionRiskBalanceOnly;

  /// No description provided for @positionRiskSide.
  ///
  /// In en, this message translates to:
  /// **'Position side'**
  String get positionRiskSide;

  /// No description provided for @positionRiskNotional.
  ///
  /// In en, this message translates to:
  /// **'Signed notional'**
  String get positionRiskNotional;

  /// No description provided for @positionRiskLiquidation.
  ///
  /// In en, this message translates to:
  /// **'Liquidation price'**
  String get positionRiskLiquidation;

  /// No description provided for @positionRiskIsolatedWallet.
  ///
  /// In en, this message translates to:
  /// **'Isolated wallet balance'**
  String get positionRiskIsolatedWallet;

  /// No description provided for @positionRiskIsolatedMargin.
  ///
  /// In en, this message translates to:
  /// **'Isolated margin'**
  String get positionRiskIsolatedMargin;

  /// No description provided for @positionRiskUpdated.
  ///
  /// In en, this message translates to:
  /// **'Position update (UTC)'**
  String get positionRiskUpdated;

  /// No description provided for @positionRiskLiquidationHint.
  ///
  /// In en, this message translates to:
  /// **'A missing or zero liquidation price is shown as —. This does not mean the position is free of liquidation risk.'**
  String get positionRiskLiquidationHint;

  /// No description provided for @positionRiskBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'The position quantity is zero, but its isolated wallet balance is negative. This record remains visible for review.'**
  String get positionRiskBalanceHint;

  /// No description provided for @positionAdlTitle.
  ///
  /// In en, this message translates to:
  /// **'ADL queue'**
  String get positionAdlTitle;

  /// No description provided for @positionAdlScope.
  ///
  /// In en, this message translates to:
  /// **'Read ADL separately with your wallet. Levels range from 0 to 4, low to high, and the exchange updates them every 30 seconds. Four lit bars indicate the highest queue level. This is not a margin ratio or a liquidation countdown. Refresh positions and ADL to review matching snapshots.'**
  String get positionAdlScope;

  /// No description provided for @positionAdlRead.
  ///
  /// In en, this message translates to:
  /// **'Sign to read ADL'**
  String get positionAdlRead;

  /// No description provided for @positionAdlRefresh.
  ///
  /// In en, this message translates to:
  /// **'Sign to refresh ADL'**
  String get positionAdlRefresh;

  /// No description provided for @positionAdlUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown — read or refresh matching ADL data'**
  String get positionAdlUnknown;

  /// No description provided for @positionAdlNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Not applicable to a zero-quantity balance record'**
  String get positionAdlNotApplicable;

  /// No description provided for @positionAdlLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {level} / 4'**
  String positionAdlLevel(int level);

  /// No description provided for @positionAdlHistorical.
  ///
  /// In en, this message translates to:
  /// **'Historical level {level} / 4 — refresh'**
  String positionAdlHistorical(int level);

  /// No description provided for @positionAdlEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ADL records returned. Missing positions remain unknown.'**
  String get positionAdlEmpty;

  /// No description provided for @positionMarkReadFirst.
  ///
  /// In en, this message translates to:
  /// **'Read positions to start public mark prices.'**
  String get positionMarkReadFirst;

  /// No description provided for @positionMarkScope.
  ///
  /// In en, this message translates to:
  /// **'Estimates use the displayed position quantity and entry price with public mark prices. Fees and funding are excluded. Prices expire after 10 seconds; refreshing prices does not verify the complete position list, margin or liquidation prices.'**
  String get positionMarkScope;

  /// No description provided for @positionMarkCoverage.
  ///
  /// In en, this message translates to:
  /// **'Fresh mark prices: {fresh} / {total} symbols'**
  String positionMarkCoverage(int fresh, int total);

  /// No description provided for @positionMarkSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Snapshot mark price'**
  String get positionMarkSnapshot;

  /// No description provided for @positionMarkCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current mark price'**
  String get positionMarkCurrent;

  /// No description provided for @positionMarkHistorical.
  ///
  /// In en, this message translates to:
  /// **'Historical mark price'**
  String get positionMarkHistorical;

  /// No description provided for @positionMarkTime.
  ///
  /// In en, this message translates to:
  /// **'Mark event (UTC)'**
  String get positionMarkTime;

  /// No description provided for @positionEstimatedNotional.
  ///
  /// In en, this message translates to:
  /// **'Estimated signed notional'**
  String get positionEstimatedNotional;

  /// No description provided for @positionEstimatedPnl.
  ///
  /// In en, this message translates to:
  /// **'Estimated unrealized PnL'**
  String get positionEstimatedPnl;

  /// No description provided for @positionEstimateStale.
  ///
  /// In en, this message translates to:
  /// **'Historical estimate: positions or mark prices need refreshing.'**
  String get positionEstimateStale;

  /// No description provided for @positionSnapshotNotional.
  ///
  /// In en, this message translates to:
  /// **'Snapshot signed notional'**
  String get positionSnapshotNotional;

  /// No description provided for @positionSnapshotPnl.
  ///
  /// In en, this message translates to:
  /// **'Snapshot unrealized PnL'**
  String get positionSnapshotPnl;

  /// No description provided for @positionMarkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Some mark prices are unavailable or stale. Retained values are historical.'**
  String get positionMarkUnavailable;

  /// No description provided for @positionMarkRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry public mark prices'**
  String get positionMarkRetry;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Futures change monitor'**
  String get accountChangeTitle;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Wallet-signed monitoring for this futures account. Validated events update individual orders, wallet balances and position quantities after a complete signed read. Events do not prove complete lists or recover missed updates. Totals, available funds, leverage, liquidation prices and ADL need signed verification; Spot needs a separate read. Starting or renewing needs one signature, with no automatic wallet prompts. The lease lasts up to 60 minutes. Stopping closes this device’s connection only.'**
  String get accountChangeScope;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Not monitoring'**
  String get accountChangeStopped;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Connecting change monitor…'**
  String get accountChangeConnecting;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Change monitor connected · snapshots still need verification'**
  String get accountChangeConnected;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Disconnected · changes may have been missed'**
  String get accountChangeDisconnected;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Paused in background · verify snapshots on return'**
  String get accountChangePaused;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Monitoring expired · sign again to continue'**
  String get accountChangeExpired;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Sign to start monitoring'**
  String get accountChangeStart;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Sign to renew monitoring'**
  String get accountChangeRenew;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Reconnect without signing'**
  String get accountChangeReconnect;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Stop monitoring on this device'**
  String get accountChangeStop;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Monitoring expires soon. Renew manually with your wallet to continue.'**
  String get accountChangeRenewalDue;

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Local monitoring deadline: {time}'**
  String accountChangeExpiry(String time);

  /// Futures private account change monitor; does not merge partial event payloads into snapshots.
  ///
  /// In en, this message translates to:
  /// **'Latest event time: {time}. Read snapshots again to verify.'**
  String accountChangeLastEvent(String time);

  /// Authenticated futures order event synchronization and completeness boundaries.
  ///
  /// In en, this message translates to:
  /// **'Unknown · read orders to verify'**
  String get openOrdersCreationUnknown;

  /// Authenticated futures order event synchronization and completeness boundaries.
  ///
  /// In en, this message translates to:
  /// **'Order updated (UTC)'**
  String get openOrdersUpdatedUTC;

  /// Authenticated futures order event synchronization and completeness boundaries.
  ///
  /// In en, this message translates to:
  /// **'Latest applied order event (UTC): {time}'**
  String openOrdersEventTime(String time);

  /// Authenticated futures order event synchronization and completeness boundaries.
  ///
  /// In en, this message translates to:
  /// **'Validated order events update this list, including partial fills and final removals. The REST timestamp remains the last complete read. Reconnect or missing events can leave the list incomplete; refresh with your wallet to verify.'**
  String get openOrdersEventScope;

  /// Authenticated futures order event synchronization and completeness boundaries.
  ///
  /// In en, this message translates to:
  /// **'Order event history is full. Sign out and reconnect your wallet, then read orders again to verify.'**
  String get orderEventsCapacity;

  /// Cancellation status query raced with private order events; do not claim final current state.
  ///
  /// In en, this message translates to:
  /// **'Order events arrived during verification. The query may reflect an earlier state; review the updated order list before any further action.'**
  String get orderCancelEventsDuringCheck;

  /// No description provided for @accountEventsCapacity.
  ///
  /// In en, this message translates to:
  /// **'Account event history is full. Sign out and reconnect your wallet, then read balances and positions again to verify.'**
  String get accountEventsCapacity;

  /// No description provided for @accountEventTime.
  ///
  /// In en, this message translates to:
  /// **'Last applied account event: {time} UTC'**
  String accountEventTime(String time);

  /// No description provided for @accountEventScope.
  ///
  /// In en, this message translates to:
  /// **'Individual records include event updates. Totals and fields missing from events show — until a signed read. Unchanged rows may be historical. Missing rows do not mean closed positions; verify complete lists after interruptions.'**
  String get accountEventScope;

  /// No description provided for @accountEventRowTime.
  ///
  /// In en, this message translates to:
  /// **'Record event time (UTC)'**
  String get accountEventRowTime;

  /// No description provided for @accountCrossWalletBalance.
  ///
  /// In en, this message translates to:
  /// **'Cross wallet balance'**
  String get accountCrossWalletBalance;

  /// No description provided for @positionEventPnl.
  ///
  /// In en, this message translates to:
  /// **'Event unrealized PnL'**
  String get positionEventPnl;

  /// No description provided for @positionEventFieldsHint.
  ///
  /// In en, this message translates to:
  /// **'Leverage, liquidation price, mark, notional and isolated margin are not provided by this event. Read positions to verify. Public mark estimates use the displayed quantity and entry price; they do not confirm the complete account.'**
  String get positionEventFieldsHint;

  /// No description provided for @positionAllocatedMargin.
  ///
  /// In en, this message translates to:
  /// **'Allocated isolated wallet'**
  String get positionAllocatedMargin;

  /// No description provided for @positionEstimatedCrossMargin.
  ///
  /// In en, this message translates to:
  /// **'Estimated cross position margin'**
  String get positionEstimatedCrossMargin;

  /// No description provided for @positionEstimatedInitialMargin.
  ///
  /// In en, this message translates to:
  /// **'Estimated initial margin basis'**
  String get positionEstimatedInitialMargin;

  /// No description provided for @positionEstimatedRoe.
  ///
  /// In en, this message translates to:
  /// **'Estimated ROE (%)'**
  String get positionEstimatedRoe;

  /// No description provided for @positionSnapshotRoe.
  ///
  /// In en, this message translates to:
  /// **'Snapshot ROE estimate (%)'**
  String get positionSnapshotRoe;

  /// No description provided for @positionReturnScope.
  ///
  /// In en, this message translates to:
  /// **'Linear contracts: initial margin basis = absolute quantity × mark price ÷ leverage; ROE = unrealized PnL ÷ that basis × 100. Isolated margin allocation uses its wallet balance, not the ROE basis. These estimates exclude fees and funding, are not account returns or available funds, and remain historical when position data or prices are stale. Unknown leverage or units shows —.'**
  String get positionReturnScope;

  /// No description provided for @leverageSettings.
  ///
  /// In en, this message translates to:
  /// **'Futures leverage'**
  String get leverageSettings;

  /// No description provided for @leverageSettingsScope.
  ///
  /// In en, this message translates to:
  /// **'Set initial leverage for this symbol. In hedge mode both directions share the setting. Changing leverage affects margin requirements and risk.'**
  String get leverageSettingsScope;

  /// No description provided for @leverageReadSettings.
  ///
  /// In en, this message translates to:
  /// **'Read leverage settings (2 signatures)'**
  String get leverageReadSettings;

  /// No description provided for @leverageSettingsReadHint.
  ///
  /// In en, this message translates to:
  /// **'Sign to read the leverage limits and symbol configuration. No change is submitted by reading.'**
  String get leverageSettingsReadHint;

  /// No description provided for @leverageCurrentSetting.
  ///
  /// In en, this message translates to:
  /// **'Leverage at last read'**
  String get leverageCurrentSetting;

  /// No description provided for @leverageTarget.
  ///
  /// In en, this message translates to:
  /// **'Target leverage'**
  String get leverageTarget;

  /// No description provided for @leverageInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a different whole number from 1 to {maximum}. Exposure may impose a lower limit; Aster validates the request.'**
  String leverageInputHint(int maximum);

  /// No description provided for @leverageContextExpired.
  ///
  /// In en, this message translates to:
  /// **'Settings require a fresh read before changing leverage. Your input is preserved.'**
  String get leverageContextExpired;

  /// No description provided for @leverageInvalidTarget.
  ///
  /// In en, this message translates to:
  /// **'Enter a different whole-number leverage within the displayed limit.'**
  String get leverageInvalidTarget;

  /// No description provided for @leverageReviewChange.
  ///
  /// In en, this message translates to:
  /// **'Review leverage change'**
  String get leverageReviewChange;

  /// No description provided for @leverageConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Change futures leverage?'**
  String get leverageConfirmTitle;

  /// No description provided for @leverageConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'This changes the selected wallet’s leverage for the symbol below, including both hedge directions. Sign once to submit and again to query the result. Higher leverage increases risk.'**
  String get leverageConfirmHint;

  /// No description provided for @leverageRequestedChange.
  ///
  /// In en, this message translates to:
  /// **'{previous}× → {target}×'**
  String leverageRequestedChange(int previous, int target);

  /// No description provided for @leverageSignChange.
  ///
  /// In en, this message translates to:
  /// **'Sign leverage change'**
  String get leverageSignChange;

  /// No description provided for @leverageSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting leverage change…'**
  String get leverageSubmitting;

  /// No description provided for @leverageCheckSigning.
  ///
  /// In en, this message translates to:
  /// **'Sign to verify leverage'**
  String get leverageCheckSigning;

  /// No description provided for @leverageChecking.
  ///
  /// In en, this message translates to:
  /// **'Querying leverage…'**
  String get leverageChecking;

  /// No description provided for @leverageVerified.
  ///
  /// In en, this message translates to:
  /// **'Query verified the requested leverage: {value}×.'**
  String leverageVerified(int value);

  /// No description provided for @leverageObservedDifferent.
  ///
  /// In en, this message translates to:
  /// **'Query shows {observed}×; requested {target}×. Refresh settings before reviewing another change.'**
  String leverageObservedDifferent(int observed, int target);

  /// No description provided for @leverageOutcomeUnknown.
  ///
  /// In en, this message translates to:
  /// **'The request may have reached Aster; the result is unverified. Query again to check the setting. No change is resubmitted by querying.'**
  String get leverageOutcomeUnknown;

  /// No description provided for @leverageRecheck.
  ///
  /// In en, this message translates to:
  /// **'Sign to query result'**
  String get leverageRecheck;

  /// No description provided for @leverageResultScope.
  ///
  /// In en, this message translates to:
  /// **'This is a query snapshot. Read positions and balances again to verify margin and risk fields.'**
  String get leverageResultScope;

  /// No description provided for @leverageExposureLimit.
  ///
  /// In en, this message translates to:
  /// **'The position exceeds the maximum allowed at this leverage. Choose a lower leverage and refresh settings.'**
  String get leverageExposureLimit;

  /// No description provided for @leverageMarginInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient margin for this leverage. Refresh balances and settings before trying again.'**
  String get leverageMarginInsufficient;

  /// No description provided for @leverageNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Aster rejected this leverage. Refresh the symbol limits and current setting.'**
  String get leverageNotAllowed;

  /// No description provided for @marginModeSettings.
  ///
  /// In en, this message translates to:
  /// **'Futures margin mode'**
  String get marginModeSettings;

  /// No description provided for @marginModeSettingsScope.
  ///
  /// In en, this message translates to:
  /// **'Choose cross or isolated margin for this symbol. Both hedge directions share the setting. This changes real account configuration and margin risk.'**
  String get marginModeSettingsScope;

  /// No description provided for @marginModeCrossHint.
  ///
  /// In en, this message translates to:
  /// **'Cross margin shares eligible account collateral across cross positions.'**
  String get marginModeCrossHint;

  /// No description provided for @marginModeIsolatedHint.
  ///
  /// In en, this message translates to:
  /// **'Isolated margin allocates collateral to each position. Changing mode does not switch single / multi-asset or one-way / hedge position mode.'**
  String get marginModeIsolatedHint;

  /// No description provided for @marginModeReadSettings.
  ///
  /// In en, this message translates to:
  /// **'Read mode and open orders (2 signatures)'**
  String get marginModeReadSettings;

  /// No description provided for @marginModeReadHint.
  ///
  /// In en, this message translates to:
  /// **'Sign to read this symbol’s configuration and open orders. Reading submits no changes. Settings expire after 30 seconds, including time spent on the second signature.'**
  String get marginModeReadHint;

  /// No description provided for @marginModeCurrentSetting.
  ///
  /// In en, this message translates to:
  /// **'Margin mode at last read'**
  String get marginModeCurrentSetting;

  /// No description provided for @marginModeTarget.
  ///
  /// In en, this message translates to:
  /// **'Target margin mode'**
  String get marginModeTarget;

  /// No description provided for @marginModeContextExpired.
  ///
  /// In en, this message translates to:
  /// **'Refresh mode and open orders before reviewing a change. Your selection is preserved.'**
  String get marginModeContextExpired;

  /// No description provided for @marginModeChangeBlocked.
  ///
  /// In en, this message translates to:
  /// **'Choose a different mode. Close positions and cancel open orders before switching.'**
  String get marginModeChangeBlocked;

  /// No description provided for @marginModeHasPosition.
  ///
  /// In en, this message translates to:
  /// **'This symbol has a position. Close it and refresh settings before switching margin mode.'**
  String get marginModeHasPosition;

  /// No description provided for @marginModeOpenOrders.
  ///
  /// In en, this message translates to:
  /// **'This symbol has open orders. Cancel them and refresh settings before switching margin mode.'**
  String get marginModeOpenOrders;

  /// No description provided for @marginModeAlreadySet.
  ///
  /// In en, this message translates to:
  /// **'Aster reports that this mode is already set. The signed query below shows the observed mode.'**
  String get marginModeAlreadySet;

  /// No description provided for @marginModeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Change futures margin mode?'**
  String get marginModeConfirmTitle;

  /// No description provided for @marginModeConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'This changes the selected wallet’s configuration for the symbol below, including both hedge directions. Sign once to submit, then again to query the result. Aster validates positions, open orders and asset-mode restrictions.'**
  String get marginModeConfirmHint;

  /// No description provided for @marginModeSignChange.
  ///
  /// In en, this message translates to:
  /// **'Sign margin mode change'**
  String get marginModeSignChange;

  /// No description provided for @marginModeReviewChange.
  ///
  /// In en, this message translates to:
  /// **'Review mode change'**
  String get marginModeReviewChange;

  /// No description provided for @marginModeSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting margin mode change…'**
  String get marginModeSubmitting;

  /// No description provided for @marginModeCheckSigning.
  ///
  /// In en, this message translates to:
  /// **'Sign to verify margin mode'**
  String get marginModeCheckSigning;

  /// No description provided for @marginModeChecking.
  ///
  /// In en, this message translates to:
  /// **'Querying margin mode…'**
  String get marginModeChecking;

  /// No description provided for @marginModeVerified.
  ///
  /// In en, this message translates to:
  /// **'Query verified the requested mode: {mode}.'**
  String marginModeVerified(String mode);

  /// No description provided for @marginModeObservedDifferent.
  ///
  /// In en, this message translates to:
  /// **'Query shows {observed}; requested {target}. Refresh settings before reviewing another change.'**
  String marginModeObservedDifferent(String observed, String target);

  /// No description provided for @marginModeOutcomeUnknown.
  ///
  /// In en, this message translates to:
  /// **'The request may have reached Aster. Its result is unverified; sign to query again. Querying never resubmits the change.'**
  String get marginModeOutcomeUnknown;

  /// No description provided for @symbolSettingsOtherPending.
  ///
  /// In en, this message translates to:
  /// **'Complete the pending futures setting on its settings page before starting another.'**
  String get symbolSettingsOtherPending;

  /// No description provided for @positionModeSettings.
  ///
  /// In en, this message translates to:
  /// **'Futures position mode'**
  String get positionModeSettings;

  /// No description provided for @positionModeAllSymbols.
  ///
  /// In en, this message translates to:
  /// **'All futures symbols'**
  String get positionModeAllSymbols;

  /// No description provided for @positionModeSettingsScope.
  ///
  /// In en, this message translates to:
  /// **'Choose one-way or hedge mode for every futures symbol in this wallet’s account. This changes real account configuration.'**
  String get positionModeSettingsScope;

  /// No description provided for @positionModeOneWay.
  ///
  /// In en, this message translates to:
  /// **'One-way'**
  String get positionModeOneWay;

  /// No description provided for @positionModeHedge.
  ///
  /// In en, this message translates to:
  /// **'Hedge'**
  String get positionModeHedge;

  /// No description provided for @positionModeOneWayHint.
  ///
  /// In en, this message translates to:
  /// **'One-way mode keeps a single net position per symbol.'**
  String get positionModeOneWayHint;

  /// No description provided for @positionModeHedgeHint.
  ///
  /// In en, this message translates to:
  /// **'Hedge mode separates long and short positions. Positions and open orders across all symbols must be cleared before switching. This action does not close positions, cancel orders or change margin or asset modes.'**
  String get positionModeHedgeHint;

  /// No description provided for @positionModeReadSettings.
  ///
  /// In en, this message translates to:
  /// **'Read mode, positions and orders (3 signatures)'**
  String get positionModeReadSettings;

  /// No description provided for @positionModeReadHint.
  ///
  /// In en, this message translates to:
  /// **'Sign separately to read position mode, all futures positions and all open orders. Reading submits no changes. The 30-second validity starts at the first response and includes the remaining signatures.'**
  String get positionModeReadHint;

  /// No description provided for @positionModeCurrentSetting.
  ///
  /// In en, this message translates to:
  /// **'Position mode at last read'**
  String get positionModeCurrentSetting;

  /// No description provided for @positionModeTarget.
  ///
  /// In en, this message translates to:
  /// **'Target position mode'**
  String get positionModeTarget;

  /// No description provided for @positionModeContextExpired.
  ///
  /// In en, this message translates to:
  /// **'Refresh mode, positions and orders before reviewing a change. Your selection is preserved.'**
  String get positionModeContextExpired;

  /// No description provided for @positionModeChangeBlocked.
  ///
  /// In en, this message translates to:
  /// **'Choose a different mode. Close all futures positions and cancel all open orders before switching.'**
  String get positionModeChangeBlocked;

  /// No description provided for @positionModeHasPosition.
  ///
  /// In en, this message translates to:
  /// **'This account has futures positions. Close them and refresh settings before switching position mode.'**
  String get positionModeHasPosition;

  /// No description provided for @positionModeOpenOrders.
  ///
  /// In en, this message translates to:
  /// **'This account has futures open orders. Cancel them and refresh settings before switching position mode.'**
  String get positionModeOpenOrders;

  /// No description provided for @positionModeAlreadySet.
  ///
  /// In en, this message translates to:
  /// **'Aster reports that this position mode is already set. The signed query below shows the observed mode.'**
  String get positionModeAlreadySet;

  /// No description provided for @positionModeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Change position mode for all futures symbols?'**
  String get positionModeConfirmTitle;

  /// No description provided for @positionModeConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'This changes position mode for ALL futures symbols in the wallet below. Sign to submit, then sign again to query the result. Aster validates all positions and open orders; this read is not an atomic lock against changes elsewhere.'**
  String get positionModeConfirmHint;

  /// No description provided for @positionModeSignChange.
  ///
  /// In en, this message translates to:
  /// **'Sign position mode change'**
  String get positionModeSignChange;

  /// No description provided for @positionModeReviewChange.
  ///
  /// In en, this message translates to:
  /// **'Review mode change'**
  String get positionModeReviewChange;

  /// No description provided for @positionModeSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting position mode change…'**
  String get positionModeSubmitting;

  /// No description provided for @positionModeCheckSigning.
  ///
  /// In en, this message translates to:
  /// **'Sign to verify position mode'**
  String get positionModeCheckSigning;

  /// No description provided for @positionModeChecking.
  ///
  /// In en, this message translates to:
  /// **'Querying position mode…'**
  String get positionModeChecking;

  /// No description provided for @positionModeVerified.
  ///
  /// In en, this message translates to:
  /// **'Query verified the requested position mode: {mode}.'**
  String positionModeVerified(String mode);

  /// No description provided for @positionModeObservedDifferent.
  ///
  /// In en, this message translates to:
  /// **'Query shows {observed}; requested {target}. Refresh settings before reviewing another change.'**
  String positionModeObservedDifferent(String observed, String target);

  /// No description provided for @positionModeOutcomeUnknown.
  ///
  /// In en, this message translates to:
  /// **'The request may have reached Aster. Its result is unverified; sign to query again. Querying never resubmits the change.'**
  String get positionModeOutcomeUnknown;

  /// No description provided for @assetModeSettings.
  ///
  /// In en, this message translates to:
  /// **'Futures asset mode'**
  String get assetModeSettings;

  /// No description provided for @assetModeAllSymbols.
  ///
  /// In en, this message translates to:
  /// **'All futures symbols'**
  String get assetModeAllSymbols;

  /// No description provided for @assetModeSettingsScope.
  ///
  /// In en, this message translates to:
  /// **'Choose single-asset or multi-assets margin for every futures symbol in this wallet’s account. This changes collateral and margin risk.'**
  String get assetModeSettingsScope;

  /// No description provided for @assetModeSingle.
  ///
  /// In en, this message translates to:
  /// **'Single-asset'**
  String get assetModeSingle;

  /// No description provided for @assetModeMulti.
  ///
  /// In en, this message translates to:
  /// **'Multi-assets'**
  String get assetModeMulti;

  /// No description provided for @assetModeSingleHint.
  ///
  /// In en, this message translates to:
  /// **'Single-asset mode uses each contract’s margin asset.'**
  String get assetModeSingleHint;

  /// No description provided for @assetModeMultiHint.
  ///
  /// In en, this message translates to:
  /// **'Multi-assets mode shares eligible collateral across cross-margin positions. Isolated positions or retained isolated collateral must be handled first. Supported assets, valuations, balance requirements and final eligibility are determined by Aster.'**
  String get assetModeMultiHint;

  /// No description provided for @assetModeReadSettings.
  ///
  /// In en, this message translates to:
  /// **'Read asset mode, positions and orders'**
  String get assetModeReadSettings;

  /// No description provided for @assetModeReadHint.
  ///
  /// In en, this message translates to:
  /// **'Read asset mode, all position configurations and all open orders. Reading submits no changes. The 30-second validity starts at the first response.'**
  String get assetModeReadHint;

  /// No description provided for @assetModeCurrentSetting.
  ///
  /// In en, this message translates to:
  /// **'Asset mode at last read'**
  String get assetModeCurrentSetting;

  /// No description provided for @assetModeTarget.
  ///
  /// In en, this message translates to:
  /// **'Target asset mode'**
  String get assetModeTarget;

  /// No description provided for @assetModeContextExpired.
  ///
  /// In en, this message translates to:
  /// **'Refresh asset mode and positions before reviewing a change. Your selection is preserved.'**
  String get assetModeContextExpired;

  /// No description provided for @assetModeChangeBlocked.
  ///
  /// In en, this message translates to:
  /// **'Choose a different asset mode. Resolve isolated positions or collateral before enabling multi-assets mode.'**
  String get assetModeChangeBlocked;

  /// No description provided for @assetModeIsolatedBlocker.
  ///
  /// In en, this message translates to:
  /// **'These symbols have isolated positions or retained isolated collateral. Review them before enabling multi-assets mode. No margin modes are changed automatically.'**
  String get assetModeIsolatedBlocker;

  /// No description provided for @assetModeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Change asset mode for all futures symbols?'**
  String get assetModeConfirmTitle;

  /// No description provided for @assetModeConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'This changes collateral and margin risk for ALL futures symbols in the wallet below. Sign to submit, then sign again to query the result. Aster validates balances and restrictions; this read cannot lock changes elsewhere. Position, symbol margin and demo modes are not changed by this request.'**
  String get assetModeConfirmHint;

  /// No description provided for @assetModeSignChange.
  ///
  /// In en, this message translates to:
  /// **'Sign asset mode change'**
  String get assetModeSignChange;

  /// No description provided for @assetModeReviewChange.
  ///
  /// In en, this message translates to:
  /// **'Review asset mode change'**
  String get assetModeReviewChange;

  /// No description provided for @assetModeSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting asset mode change…'**
  String get assetModeSubmitting;

  /// No description provided for @assetModeCheckSigning.
  ///
  /// In en, this message translates to:
  /// **'Sign to verify asset mode'**
  String get assetModeCheckSigning;

  /// No description provided for @assetModeChecking.
  ///
  /// In en, this message translates to:
  /// **'Querying asset mode…'**
  String get assetModeChecking;

  /// No description provided for @assetModeVerified.
  ///
  /// In en, this message translates to:
  /// **'Query verified the requested asset mode: {mode}.'**
  String assetModeVerified(String mode);

  /// No description provided for @assetModeObservedDifferent.
  ///
  /// In en, this message translates to:
  /// **'Query shows {observed}; requested {target}. Refresh settings before reviewing another change.'**
  String assetModeObservedDifferent(String observed, String target);

  /// No description provided for @assetModeOutcomeUnknown.
  ///
  /// In en, this message translates to:
  /// **'The request may have reached Aster. Its result is unverified; sign to query again. Querying never resubmits the change.'**
  String get assetModeOutcomeUnknown;

  /// No description provided for @liveOrderEntry.
  ///
  /// In en, this message translates to:
  /// **'Place a live futures order'**
  String get liveOrderEntry;

  /// No description provided for @liveOrderEntryHint.
  ///
  /// In en, this message translates to:
  /// **'The form above uses local demo funds. Live orders have a separate wallet confirmation.'**
  String get liveOrderEntryHint;

  /// No description provided for @liveOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Live futures order'**
  String get liveOrderTitle;

  /// No description provided for @liveOrderScope.
  ///
  /// In en, this message translates to:
  /// **'Use this wallet to place real ordinary, conditional or trailing orders. Limit orders use a supported execution policy. In one-way mode, buying or selling can reduce or reverse an existing position. Hedge mode operates on the selected long or short side. Aster checks fees, available margin and final eligibility.'**
  String get liveOrderScope;

  /// No description provided for @liveOrderReadContext.
  ///
  /// In en, this message translates to:
  /// **'Read order settings (2 signatures)'**
  String get liveOrderReadContext;

  /// No description provided for @liveOrderReadHint.
  ///
  /// In en, this message translates to:
  /// **'Read public trading rules and mark price, then sign separately for position mode and symbol configuration. Settings expire 30 seconds after the mark-price response. Reading places no order.'**
  String get liveOrderReadHint;

  /// No description provided for @liveOrderSettingsBusy.
  ///
  /// In en, this message translates to:
  /// **'Finish the pending futures settings operation before placing an order.'**
  String get liveOrderSettingsBusy;

  /// No description provided for @liveOrderSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting the live order…'**
  String get liveOrderSubmitting;

  /// No description provided for @liveOrderMarkPrice.
  ///
  /// In en, this message translates to:
  /// **'Reference mark price'**
  String get liveOrderMarkPrice;

  /// No description provided for @liveOrderContextExpired.
  ///
  /// In en, this message translates to:
  /// **'Refresh order settings before reviewing an order. Your input is preserved.'**
  String get liveOrderContextExpired;

  /// No description provided for @liveOrderQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity ({asset})'**
  String liveOrderQuantity(String asset);

  /// No description provided for @liveOrderQuantityBounds.
  ///
  /// In en, this message translates to:
  /// **'Minimum {minimum}; maximum {maximum}; step {step}'**
  String liveOrderQuantityBounds(String minimum, String maximum, String step);

  /// No description provided for @liveOrderPrice.
  ///
  /// In en, this message translates to:
  /// **'Limit price ({asset})'**
  String liveOrderPrice(String asset);

  /// No description provided for @liveOrderPriceTick.
  ///
  /// In en, this message translates to:
  /// **'Price increment: {tick}'**
  String liveOrderPriceTick(String tick);

  /// No description provided for @liveOrderEstimatedNotional.
  ///
  /// In en, this message translates to:
  /// **'Reference notional'**
  String get liveOrderEstimatedNotional;

  /// No description provided for @liveOrderReview.
  ///
  /// In en, this message translates to:
  /// **'Review live order'**
  String get liveOrderReview;

  /// No description provided for @liveOrderClientId.
  ///
  /// In en, this message translates to:
  /// **'Client order reference'**
  String get liveOrderClientId;

  /// No description provided for @liveOrderVerifiedResult.
  ///
  /// In en, this message translates to:
  /// **'Signed query: {status}; executed quantity {executed}; order {orderId}.'**
  String liveOrderVerifiedResult(String status, String executed, String orderId);

  /// No description provided for @liveOrderQueryScope.
  ///
  /// In en, this message translates to:
  /// **'This is the query snapshot. Only FILLED confirms the complete requested quantity; later changes need another account read.'**
  String get liveOrderQueryScope;

  /// No description provided for @liveOrderOutcomeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Order submission was attempted, but the result is not yet confirmed. Check the original order before placing it again to avoid duplicates. Checking never resubmits the order.'**
  String get liveOrderOutcomeUnknown;

  /// No description provided for @liveOrderRecheck.
  ///
  /// In en, this message translates to:
  /// **'Sign to query this order'**
  String get liveOrderRecheck;

  /// No description provided for @liveOrderConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Place this live futures order?'**
  String get liveOrderConfirmTitle;

  /// No description provided for @liveOrderConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'This submits a real order. Sign to place it, then sign separately to query its status. A market order can execute at a different price. Limit execution follows the policy shown below. No leverage or margin setting is changed.'**
  String get liveOrderConfirmHint;

  /// No description provided for @liveOrderPolicy.
  ///
  /// In en, this message translates to:
  /// **'Limit execution policy'**
  String get liveOrderPolicy;

  /// No description provided for @timeInForceTitle.
  ///
  /// In en, this message translates to:
  /// **'Time In Force'**
  String get timeInForceTitle;

  /// No description provided for @timeInForceGtc.
  ///
  /// In en, this message translates to:
  /// **'GTC (Good till canceled)'**
  String get timeInForceGtc;

  /// No description provided for @timeInForceIoc.
  ///
  /// In en, this message translates to:
  /// **'IOC (Immediate or canceled)'**
  String get timeInForceIoc;

  /// No description provided for @liveOrderConditional.
  ///
  /// In en, this message translates to:
  /// **'Conditional order'**
  String get liveOrderConditional;

  /// No description provided for @liveOrderPositionTriggers.
  ///
  /// In en, this message translates to:
  /// **'Position TP/SL'**
  String get liveOrderPositionTriggers;

  /// No description provided for @liveOrderStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get liveOrderStop;

  /// No description provided for @liveOrderTakeProfit.
  ///
  /// In en, this message translates to:
  /// **'Take profit'**
  String get liveOrderTakeProfit;

  /// No description provided for @liveOrderTriggerBasis.
  ///
  /// In en, this message translates to:
  /// **'Trigger price basis'**
  String get liveOrderTriggerBasis;

  /// No description provided for @liveOrderTriggerReference.
  ///
  /// In en, this message translates to:
  /// **'Reference price at read'**
  String get liveOrderTriggerReference;

  /// No description provided for @liveOrderTriggerRises.
  ///
  /// In en, this message translates to:
  /// **'Triggers when the selected price rises to or above the trigger price.'**
  String get liveOrderTriggerRises;

  /// No description provided for @liveOrderTriggerFalls.
  ///
  /// In en, this message translates to:
  /// **'Triggers when the selected price falls to or below the trigger price.'**
  String get liveOrderTriggerFalls;

  /// No description provided for @liveOrderTriggerProtect.
  ///
  /// In en, this message translates to:
  /// **'Trigger price protection'**
  String get liveOrderTriggerProtect;

  /// No description provided for @liveOrderProtectOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get liveOrderProtectOn;

  /// No description provided for @liveOrderProtectOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get liveOrderProtectOff;

  /// No description provided for @liveOrderProtectHint.
  ///
  /// In en, this message translates to:
  /// **'When enabled, the mark/last price difference must also satisfy the symbol’s threshold at trigger time. This can delay or prevent triggering; it does not protect the execution price.'**
  String get liveOrderProtectHint;

  /// No description provided for @liveOrderProtectThreshold.
  ///
  /// In en, this message translates to:
  /// **'Allowed price difference at trigger: {percent}%.'**
  String liveOrderProtectThreshold(String percent);

  /// No description provided for @liveOrderConditionalHint.
  ///
  /// In en, this message translates to:
  /// **'This submits one independent conditional order for the specified quantity. Triggering does not guarantee a fill. Separate TP and SL orders do not cancel each other automatically. Later position changes can affect execution; review active orders separately.'**
  String get liveOrderConditionalHint;

  /// No description provided for @liveOrderConditionalEstimateHint.
  ///
  /// In en, this message translates to:
  /// **'Reference estimate only: conditional market orders use the trigger price, conditional limit orders use the limit price. Position, leverage and available funds can change before triggering. Fees, funding, depth slippage and execution-time checks are excluded; this is not realized PnL or guaranteed required margin.'**
  String get liveOrderConditionalEstimateHint;

  /// No description provided for @liveOrderTypeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The latest symbol rules do not support this order type. Refresh the rules or choose a supported type.'**
  String get liveOrderTypeUnavailable;

  /// No description provided for @liveOrderInvalidTrigger.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive decimal trigger price.'**
  String get liveOrderInvalidTrigger;

  /// No description provided for @liveOrderTriggerFilter.
  ///
  /// In en, this message translates to:
  /// **'Trigger price must satisfy the exchange price range and increment.'**
  String get liveOrderTriggerFilter;

  /// No description provided for @liveOrderProtectUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The trigger-protection threshold is unavailable in the current symbol rules. Refresh or turn protection off before reviewing.'**
  String get liveOrderProtectUnavailable;

  /// No description provided for @liveOrderTriggerReferenceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The selected trigger reference is unavailable. Refresh or explicitly choose another price basis; no price is substituted.'**
  String get liveOrderTriggerReferenceUnavailable;

  /// No description provided for @liveOrderTriggerImmediate.
  ///
  /// In en, this message translates to:
  /// **'The trigger price is already reached at this read. Adjust it according to the displayed direction and review again. Aster checks the actual price at submission.'**
  String get liveOrderTriggerImmediate;

  /// No description provided for @liveOrderPolicyChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a supported policy'**
  String get liveOrderPolicyChoose;

  /// No description provided for @liveOrderPolicyGtc.
  ///
  /// In en, this message translates to:
  /// **'GTC'**
  String get liveOrderPolicyGtc;

  /// No description provided for @liveOrderPolicyIoc.
  ///
  /// In en, this message translates to:
  /// **'IOC'**
  String get liveOrderPolicyIoc;

  /// No description provided for @liveOrderPolicyPostOnly.
  ///
  /// In en, this message translates to:
  /// **'Post Only (GTX)'**
  String get liveOrderPolicyPostOnly;

  /// No description provided for @liveOrderPolicyHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden (HIDDEN)'**
  String get liveOrderPolicyHidden;

  /// No description provided for @liveOrderPolicyGtcHint.
  ///
  /// In en, this message translates to:
  /// **'GTC: any unfilled quantity remains open until filled or cancelled.'**
  String get liveOrderPolicyGtcHint;

  /// No description provided for @liveOrderPolicyIocHint.
  ///
  /// In en, this message translates to:
  /// **'IOC: fill immediately available quantity and cancel the remainder. A partial fill is possible.'**
  String get liveOrderPolicyIocHint;

  /// No description provided for @liveOrderPolicyPostOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Post Only: the order must add liquidity. An order that would immediately take liquidity will not execute as an ordinary limit order. Placement and fills require exchange verification.'**
  String get liveOrderPolicyPostOnlyHint;

  /// No description provided for @liveOrderPolicyHiddenHint.
  ///
  /// In en, this message translates to:
  /// **'Hidden: the order is not visible in the public order book. This does not guarantee maker execution, a fill or execution priority.'**
  String get liveOrderPolicyHiddenHint;

  /// No description provided for @liveOrderTimeInForceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The selected limit policy is unavailable in the latest symbol rules. Choose a supported policy or use a market order, then review again.'**
  String get liveOrderTimeInForceUnavailable;

  /// No description provided for @liveOrderSide.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get liveOrderSide;

  /// No description provided for @liveOrderType.
  ///
  /// In en, this message translates to:
  /// **'Order type'**
  String get liveOrderType;

  /// No description provided for @liveOrderSignSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign and place live order'**
  String get liveOrderSignSubmit;

  /// No description provided for @liveOrderInvalidQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive decimal quantity.'**
  String get liveOrderInvalidQuantity;

  /// No description provided for @liveOrderInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive decimal limit price.'**
  String get liveOrderInvalidPrice;

  /// No description provided for @liveOrderQuantityFilter.
  ///
  /// In en, this message translates to:
  /// **'Quantity must satisfy the displayed minimum, maximum and increment for this order type.'**
  String get liveOrderQuantityFilter;

  /// No description provided for @liveOrderPriceFilter.
  ///
  /// In en, this message translates to:
  /// **'Limit price must satisfy the exchange price range and increment.'**
  String get liveOrderPriceFilter;

  /// No description provided for @liveOrderPercentFilter.
  ///
  /// In en, this message translates to:
  /// **'Limit price is outside the permitted range for this side at the reference mark price. Refresh settings or adjust the price.'**
  String get liveOrderPercentFilter;

  /// No description provided for @liveOrderNotionalFilter.
  ///
  /// In en, this message translates to:
  /// **'Order value is below the exchange minimum notional. Market orders use the reference mark price.'**
  String get liveOrderNotionalFilter;

  /// No description provided for @liveCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close a live position'**
  String get liveCloseTitle;

  /// No description provided for @liveCloseScope.
  ///
  /// In en, this message translates to:
  /// **'Read this wallet’s current position before choosing an ordinary or trailing close. Position TP/SL supports fixed quantity or entire close at trigger. One-way fixed-quantity closes only reduce positions; hedge closes retain the original LONG/SHORT side. Percentage quantities round down to the order step; 100% can leave a remainder. Existing orders are not cancelled.'**
  String get liveCloseScope;

  /// No description provided for @liveClosePositionChanged.
  ///
  /// In en, this message translates to:
  /// **'The selected position or its configuration is missing or changed. Refresh order settings and review again.'**
  String get liveClosePositionChanged;

  /// No description provided for @liveCloseTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Close quantity cannot exceed the position quantity read for this side.'**
  String get liveCloseTooLarge;

  /// No description provided for @liveCloseLong.
  ///
  /// In en, this message translates to:
  /// **'Close long · sell'**
  String get liveCloseLong;

  /// No description provided for @liveCloseShort.
  ///
  /// In en, this message translates to:
  /// **'Close short · buy'**
  String get liveCloseShort;

  /// No description provided for @liveClosePositionAmount.
  ///
  /// In en, this message translates to:
  /// **'Position quantity at last read'**
  String get liveClosePositionAmount;

  /// No description provided for @liveCloseEstimatedPnl.
  ///
  /// In en, this message translates to:
  /// **'Estimated close PnL'**
  String get liveCloseEstimatedPnl;

  /// No description provided for @liveCloseEstimateHint.
  ///
  /// In en, this message translates to:
  /// **'Estimate only: market closes use the read best bid for longs or best ask for shorts; limit closes use the entered price. Fees, funding and depth slippage are excluded. Missing book data shows —. This is not realized PnL.'**
  String get liveCloseEstimateHint;

  /// No description provided for @liveCloseConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit this position reduction?'**
  String get liveCloseConfirmTitle;

  /// No description provided for @liveCloseConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'This submits a real reduction order. Sign to recheck the position first, then sign to place the order and separately to query it. A changed quantity, entry price or configuration stops submission. Market price can move; limit execution follows the policy shown below. The exchange validates concurrent activity.'**
  String get liveCloseConfirmHint;

  /// No description provided for @liveCloseResultScope.
  ///
  /// In en, this message translates to:
  /// **'An order status does not prove that the entire position is closed. Sign separately to read the remaining position. This does not cancel other orders, and later activity can change the position again.'**
  String get liveCloseResultScope;

  /// No description provided for @liveCloseReadRemaining.
  ///
  /// In en, this message translates to:
  /// **'Sign to read remaining positions'**
  String get liveCloseReadRemaining;

  /// No description provided for @liveCloseRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining quantity at this read'**
  String get liveCloseRemaining;

  /// No description provided for @liveOrderReduceHint.
  ///
  /// In en, this message translates to:
  /// **'Only reduce an existing position; never intentionally open the opposite side. Aster checks the available reducible quantity, including concurrent orders.'**
  String get liveOrderReduceHint;

  /// No description provided for @liveOrderReduceHedge.
  ///
  /// In en, this message translates to:
  /// **'The reduceOnly parameter is unavailable in hedge mode. Use the position’s close action to reduce its LONG or SHORT side.'**
  String get liveOrderReduceHedge;

  /// No description provided for @batchCloseAll.
  ///
  /// In en, this message translates to:
  /// **'Close all listed live positions'**
  String get batchCloseAll;

  /// No description provided for @batchCloseCurrent.
  ///
  /// In en, this message translates to:
  /// **'Close all current-symbol live positions'**
  String get batchCloseCurrent;

  /// No description provided for @batchCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close these live positions at market?'**
  String get batchCloseTitle;

  /// No description provided for @batchCloseHint.
  ///
  /// In en, this message translates to:
  /// **'Only the listed wallet, symbols, sides and exact quantities are included. Submit an opposite MARKET order for each nonzero position, using reduce-only in one-way mode or the original side in hedge mode. Existing orders and Spot are excluded. Each position needs separate setting-read, position-recheck, order and query signatures, followed by a final position-read signature. Changed positions, invalid quantities, refused signatures or unknown results stop further submissions. No automatic resizing or order retry. Later activity can change positions again.'**
  String get batchCloseHint;

  /// No description provided for @batchCloseReadFirst.
  ///
  /// In en, this message translates to:
  /// **'Read a fresh, complete live position snapshot before closing all. An unresolved trade or configuration change must be checked first.'**
  String get batchCloseReadFirst;

  /// No description provided for @batchCloseCount.
  ///
  /// In en, this message translates to:
  /// **'Confirmed scope: {count} positions'**
  String batchCloseCount(int count);

  /// No description provided for @batchCloseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign and close each position'**
  String get batchCloseConfirm;

  /// No description provided for @batchCloseStopped.
  ///
  /// In en, this message translates to:
  /// **'Further submissions stopped. Unsubmitted positions require a fresh read and confirmation.'**
  String get batchCloseStopped;

  /// No description provided for @batchCloseRecheck.
  ///
  /// In en, this message translates to:
  /// **'Sign to query unconfirmed orders only'**
  String get batchCloseRecheck;

  /// No description provided for @liveOrderFundsReadHint.
  ///
  /// In en, this message translates to:
  /// **'Read public rules and mark price, then sign separately for position mode, symbol positions, asset mode and account funds (4 signatures). Read validity is 30 seconds from the mark-price response. No order is submitted.'**
  String get liveOrderFundsReadHint;

  /// No description provided for @liveOrderReadFunds.
  ///
  /// In en, this message translates to:
  /// **'Read asset mode and account funds before reviewing an opening order. Missing amounts are unknown, not zero.'**
  String get liveOrderReadFunds;

  /// No description provided for @liveOrderFundsChanged.
  ///
  /// In en, this message translates to:
  /// **'Account funds and the selected position or configuration do not agree. Refresh and review again.'**
  String get liveOrderFundsChanged;

  /// No description provided for @liveOrderTradingDisabled.
  ///
  /// In en, this message translates to:
  /// **'The signed account response reports trading disabled. Check your Aster account before placing an opening order.'**
  String get liveOrderTradingDisabled;

  /// No description provided for @liveOrderAvailableUsdt.
  ///
  /// In en, this message translates to:
  /// **'Available USDT margin at read'**
  String get liveOrderAvailableUsdt;

  /// No description provided for @liveOrderFundsScope.
  ///
  /// In en, this message translates to:
  /// **'This snapshot covers available USDT margin in this futures account. It is separate from wallet balance, withdrawal limits, demo funds and funds reserved after this read. Aster validates actual availability.'**
  String get liveOrderFundsScope;

  /// No description provided for @liveOrderFundsMultiHint.
  ///
  /// In en, this message translates to:
  /// **'Multi-assets mode: the USDT amount is not a combined collateral total. Other assets retain their own units; no conversion rates or collateral discounts are assumed.'**
  String get liveOrderFundsMultiHint;

  /// No description provided for @liveOrderFundsAssets.
  ///
  /// In en, this message translates to:
  /// **'Available balances and collateral eligibility by asset'**
  String get liveOrderFundsAssets;

  /// No description provided for @liveOrderCollateralUnknown.
  ///
  /// In en, this message translates to:
  /// **'Collateral eligibility not provided'**
  String get liveOrderCollateralUnknown;

  /// No description provided for @liveOrderOpeningQuantity.
  ///
  /// In en, this message translates to:
  /// **'Reference new opening quantity'**
  String get liveOrderOpeningQuantity;

  /// No description provided for @liveOrderOpeningMargin.
  ///
  /// In en, this message translates to:
  /// **'Estimated additional opening initial margin'**
  String get liveOrderOpeningMargin;

  /// No description provided for @liveOrderMarginEstimateHint.
  ///
  /// In en, this message translates to:
  /// **'Reference only: new opening quantity × entered limit price (or reference mark) ÷ read leverage. One-way orders first offset the read opposite position; hedge orders open the selected side. Valid reduce-only closes add no opening exposure. Fees, funding, existing orders, released margin, execution price and risk tiers can change actual requirements.'**
  String get liveOrderMarginEstimateHint;

  /// No description provided for @liveOrderFundsHistorical.
  ///
  /// In en, this message translates to:
  /// **'Historical funds snapshot. Refresh before reviewing another opening order.'**
  String get liveOrderFundsHistorical;

  /// No description provided for @liveOrderMarginAboveBalance.
  ///
  /// In en, this message translates to:
  /// **'The estimate exceeds the read USDT available balance. Review your funds; released margin and fees are excluded, and Aster makes the final check.'**
  String get liveOrderMarginAboveBalance;

  /// No description provided for @liveEntireClose.
  ///
  /// In en, this message translates to:
  /// **'Close entire position at trigger'**
  String get liveEntireClose;

  /// No description provided for @liveEntireHint.
  ///
  /// In en, this message translates to:
  /// **'The exchange uses the position size at trigger time, which may differ from this snapshot. No fixed quantity or reduceOnly is sent. Independent TP/SL orders do not cancel each other.'**
  String get liveEntireHint;

  /// No description provided for @liveEntireMarketOnly.
  ///
  /// In en, this message translates to:
  /// **'Entire close is available for conditional market orders only.'**
  String get liveEntireMarketOnly;

  /// No description provided for @liveEntireEstimateHint.
  ///
  /// In en, this message translates to:
  /// **'Estimated using the reviewed position quantity and trigger price. Trigger-time size, execution price, fees and funding may change the result.'**
  String get liveEntireEstimateHint;

  /// No description provided for @liveEntireQuantity.
  ///
  /// In en, this message translates to:
  /// **'Entire position size at trigger time'**
  String get liveEntireQuantity;

  /// No description provided for @liveEntireQueryScope.
  ///
  /// In en, this message translates to:
  /// **'This query verifies this entire-close order and its reported execution only. A filled order does not prove the remaining position is zero; read positions again.'**
  String get liveEntireQueryScope;

  /// No description provided for @liveEntireInvalid.
  ///
  /// In en, this message translates to:
  /// **'Entire close requires a position-side conditional market order without quantity, limit price or reduceOnly.'**
  String get liveEntireInvalid;

  /// No description provided for @triggerCalculator.
  ///
  /// In en, this message translates to:
  /// **'Calculate trigger price from PnL / ROI'**
  String get triggerCalculator;

  /// No description provided for @triggerCalculationHint.
  ///
  /// In en, this message translates to:
  /// **'Uses the selected partial quantity, or the reviewed position quantity for entire close. ROI is an entry-price estimate with leverage, not account yield. Applying a candidate only updates the trigger field; it does not submit an order. Refreshing does not overwrite that field.'**
  String get triggerCalculationHint;

  /// No description provided for @triggerCalculationQuantity.
  ///
  /// In en, this message translates to:
  /// **'Calculation quantity'**
  String get triggerCalculationQuantity;

  /// No description provided for @triggerCalculationRoi.
  ///
  /// In en, this message translates to:
  /// **'Estimated ROI'**
  String get triggerCalculationRoi;

  /// No description provided for @triggerCalculationPnlLabel.
  ///
  /// In en, this message translates to:
  /// **'PnL target'**
  String get triggerCalculationPnlLabel;

  /// No description provided for @triggerCalculationPnl.
  ///
  /// In en, this message translates to:
  /// **'PnL target ({asset}, signed)'**
  String triggerCalculationPnl(String asset);

  /// No description provided for @triggerCalculationRoiTarget.
  ///
  /// In en, this message translates to:
  /// **'ROI target (%, signed)'**
  String get triggerCalculationRoiTarget;

  /// No description provided for @triggerCalculationPrice.
  ///
  /// In en, this message translates to:
  /// **'Candidate trigger price'**
  String get triggerCalculationPrice;

  /// No description provided for @triggerCalculationRounding.
  ///
  /// In en, this message translates to:
  /// **'Rounded to the nearest exchange price step. Estimates reflect the rounded price, exclude fees and funding, and do not guarantee execution. For conditional limit orders, execution PnL uses the separate limit price.'**
  String get triggerCalculationRounding;

  /// No description provided for @triggerCalculationApply.
  ///
  /// In en, this message translates to:
  /// **'Use candidate trigger price'**
  String get triggerCalculationApply;

  /// No description provided for @triggerCalculationPosition.
  ///
  /// In en, this message translates to:
  /// **'Read a nonzero position and choose a valid quantity and leverage first.'**
  String get triggerCalculationPosition;

  /// No description provided for @triggerCalculationInput.
  ///
  /// In en, this message translates to:
  /// **'Enter a signed decimal target without exponent notation.'**
  String get triggerCalculationInput;

  /// No description provided for @triggerCalculationTick.
  ///
  /// In en, this message translates to:
  /// **'The exchange price step is unavailable; cannot calculate a candidate.'**
  String get triggerCalculationTick;

  /// No description provided for @triggerCalculationBounds.
  ///
  /// In en, this message translates to:
  /// **'The calculated price is outside the supported positive price range.'**
  String get triggerCalculationBounds;

  /// No description provided for @liveTrailingInvalid.
  ///
  /// In en, this message translates to:
  /// **'Trailing stop requires a market order with fixed quantity, no fixed trigger or limit price, and no entire-close flag.'**
  String get liveTrailingInvalid;

  /// No description provided for @liveTrailingRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a callback rate from 0.1% to 5%.'**
  String get liveTrailingRateInvalid;

  /// No description provided for @liveTrailingActivationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive decimal activation price, or leave it empty for the exchange default.'**
  String get liveTrailingActivationInvalid;

  /// No description provided for @liveTrailingActivationFilter.
  ///
  /// In en, this message translates to:
  /// **'The activation price does not match the exchange price range or step.'**
  String get liveTrailingActivationFilter;

  /// No description provided for @liveTrailingImmediate.
  ///
  /// In en, this message translates to:
  /// **'A buy activation price must be below the selected latest price; a sell activation price must be above it.'**
  String get liveTrailingImmediate;

  /// No description provided for @liveTrailingHint.
  ///
  /// In en, this message translates to:
  /// **'The exchange tracks favorable price extremes, then submits market execution after the configured pullback. This uses a fixed quantity, not entire close. It does not continuously reprice a limit order.'**
  String get liveTrailingHint;

  /// No description provided for @liveTrailingRate.
  ///
  /// In en, this message translates to:
  /// **'Callback rate (%)'**
  String get liveTrailingRate;

  /// No description provided for @liveTrailingRateBounds.
  ///
  /// In en, this message translates to:
  /// **'0.1–5; entering 1 means 1%.'**
  String get liveTrailingRateBounds;

  /// No description provided for @liveTrailingBasis.
  ///
  /// In en, this message translates to:
  /// **'Tracking price basis'**
  String get liveTrailingBasis;

  /// No description provided for @liveTrailingActivation.
  ///
  /// In en, this message translates to:
  /// **'Activation price ({asset}, optional)'**
  String liveTrailingActivation(String asset);

  /// No description provided for @liveTrailingDefault.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the selected price basis at exchange placement time. This snapshot is not submitted as the activation price.'**
  String get liveTrailingDefault;

  /// No description provided for @liveTrailingActivationDirection.
  ///
  /// In en, this message translates to:
  /// **'If specified: buy activation below the latest price; sell activation above it. The exchange rechecks at placement.'**
  String get liveTrailingActivationDirection;

  /// No description provided for @liveTrailingBuy.
  ///
  /// In en, this message translates to:
  /// **'After activation, a buy follows the lowest price and triggers on a rise by the callback percentage. Triggering does not guarantee an execution price.'**
  String get liveTrailingBuy;

  /// No description provided for @liveTrailingSell.
  ///
  /// In en, this message translates to:
  /// **'After activation, a sell follows the highest price and triggers on a fall by the callback percentage. Triggering does not guarantee an execution price.'**
  String get liveTrailingSell;

  /// No description provided for @liveTrailingEstimateHint.
  ///
  /// In en, this message translates to:
  /// **'There is no fixed execution price. Notional and opening margin use the current mark only as a reference; closing PnL is unavailable. Actual size eligibility, margin and execution depend on exchange state. Fees, funding and slippage are excluded.'**
  String get liveTrailingEstimateHint;

  /// No description provided for @quickOrderInvalid.
  ///
  /// In en, this message translates to:
  /// **'Quick entry must be an ordinary market order without reduction, a fixed price or attached conditions.'**
  String get quickOrderInvalid;

  /// No description provided for @quickOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Chart quick market entry'**
  String get quickOrderTitle;

  /// No description provided for @quickOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Real wallet orders. Quantity is independent of the trade form. One-way orders can reduce or reverse an existing position. Quotes are references, not execution prices. This order has no attached TP/SL or user slippage setting.'**
  String get quickOrderHint;

  /// No description provided for @quickOrderRead.
  ///
  /// In en, this message translates to:
  /// **'Read wallet and sizing inputs'**
  String get quickOrderRead;

  /// No description provided for @quickOrderReadHint.
  ///
  /// In en, this message translates to:
  /// **'Explicitly sign four account/configuration reads, then three separate fee, risk-bracket and open-order reads for percentage sizing. No order is sent by reading. The first price snapshot expires in 30 seconds.'**
  String get quickOrderReadHint;

  /// No description provided for @quickOrderIndependent.
  ///
  /// In en, this message translates to:
  /// **'Enter base-asset quantity, or choose a percentage. Starts empty; no default percentage.'**
  String get quickOrderIndependent;

  /// No description provided for @quickOrderPercentSelected.
  ///
  /// In en, this message translates to:
  /// **'{percent}% selected. Buy and sell reference quantities are shown separately. Type a quantity to replace the percentage.'**
  String quickOrderPercentSelected(int percent);

  /// No description provided for @quickOrderBuyQuantity.
  ///
  /// In en, this message translates to:
  /// **'Reference buy quantity'**
  String get quickOrderBuyQuantity;

  /// No description provided for @quickOrderSellQuantity.
  ///
  /// In en, this message translates to:
  /// **'Reference sell quantity'**
  String get quickOrderSellQuantity;

  /// No description provided for @quickOrderSizingHint.
  ///
  /// In en, this message translates to:
  /// **'Percentages use the read-time USDT available margin, leverage, taker fee, risk brackets, existing positions, same-direction pending quantity and bid/ask, rounded down to the market step. They exclude released margin and other-asset collateral. These are reference budgets, not guaranteed maximum quantities; prices, orders and exchange limits can change.'**
  String get quickOrderSizingHint;

  /// No description provided for @quickOrderSizingFailure.
  ///
  /// In en, this message translates to:
  /// **'Percentage sizing is unavailable. Retry the read, or enter a quantity if the account context is valid. Inputs are preserved.'**
  String get quickOrderSizingFailure;

  /// No description provided for @quickOrderBuy.
  ///
  /// In en, this message translates to:
  /// **'Market Buy / Long'**
  String get quickOrderBuy;

  /// No description provided for @quickOrderSell.
  ///
  /// In en, this message translates to:
  /// **'Market Sell / Short'**
  String get quickOrderSell;

  /// No description provided for @quickOrderConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Quick market order confirmation'**
  String get quickOrderConfirmation;

  /// No description provided for @quickOrderDoNotShow.
  ///
  /// In en, this message translates to:
  /// **'Do not show market order confirmation again'**
  String get quickOrderDoNotShow;

  /// No description provided for @quickOrderConfirmPreference.
  ///
  /// In en, this message translates to:
  /// **'Confirm market entries'**
  String get quickOrderConfirmPreference;

  /// No description provided for @quickOrderPreferenceFailure.
  ///
  /// In en, this message translates to:
  /// **'Confirmation preference could not be read or saved. The last saved choice is retained; orders require review until a choice is saved successfully.'**
  String get quickOrderPreferenceFailure;

  /// No description provided for @quickOrderChartTab.
  ///
  /// In en, this message translates to:
  /// **'Chart view'**
  String get quickOrderChartTab;

  /// No description provided for @attachedOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach take profit / stop loss'**
  String get attachedOrderTitle;

  /// No description provided for @attachedOrderTakeProfit.
  ///
  /// In en, this message translates to:
  /// **'Attached take profit'**
  String get attachedOrderTakeProfit;

  /// No description provided for @attachedOrderStopLoss.
  ///
  /// In en, this message translates to:
  /// **'Attached stop loss'**
  String get attachedOrderStopLoss;

  /// No description provided for @attachedOrderTriggerPrice.
  ///
  /// In en, this message translates to:
  /// **'Trigger price (USDT)'**
  String get attachedOrderTriggerPrice;

  /// No description provided for @attachedOrderBasis.
  ///
  /// In en, this message translates to:
  /// **'Trigger price basis'**
  String get attachedOrderBasis;

  /// No description provided for @attachedOrderPriceProtect.
  ///
  /// In en, this message translates to:
  /// **'Trigger price protection'**
  String get attachedOrderPriceProtect;

  /// No description provided for @attachedOrderLifecycle.
  ///
  /// In en, this message translates to:
  /// **'Entry partial or full fills request placement of the exits. A partial or full exit fill requests cancellation of its peer. Each exit uses the full main-order quantity. Actual activation, quantity changes, cancellations and fills require exchange reports.'**
  String get attachedOrderLifecycle;

  /// No description provided for @attachedOrderManageScope.
  ///
  /// In en, this message translates to:
  /// **'Creation and signed queries are supported. Editing and canceling the complete attached strategy in the app are not yet available.'**
  String get attachedOrderManageScope;

  /// No description provided for @attachedOrderInvalid.
  ///
  /// In en, this message translates to:
  /// **'Fill at least one TP/SL exit or turn attached protection off. It cannot be combined with reduce-only, entire close, quick entry or trailing orders.'**
  String get attachedOrderInvalid;

  /// No description provided for @attachedOrderIocUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Attached strategies do not support IOC. Choose another supported time in force for the entry.'**
  String get attachedOrderIocUnavailable;

  /// No description provided for @attachedOrderNoExposure.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive main-order quantity to protect.'**
  String get attachedOrderNoExposure;

  /// No description provided for @attachedOrderPriceDirection.
  ///
  /// In en, this message translates to:
  /// **'The attached TP/SL trigger is on the wrong side of the entry reference. Check the entry direction and trigger price.'**
  String get attachedOrderPriceDirection;

  /// No description provided for @attachedOrderPositionChanged.
  ///
  /// In en, this message translates to:
  /// **'The position or symbol configuration changed. Read again and review the attached exit quantity.'**
  String get attachedOrderPositionChanged;

  /// No description provided for @attachedOrderRejected.
  ///
  /// In en, this message translates to:
  /// **'The exchange returned a strategy rejection code. Query the original ID to check the outcome; do not submit it again.'**
  String get attachedOrderRejected;

  /// No description provided for @attachedOrderStrategyType.
  ///
  /// In en, this message translates to:
  /// **'Linked strategy'**
  String get attachedOrderStrategyType;

  /// No description provided for @attachedOrderExitQuantity.
  ///
  /// In en, this message translates to:
  /// **'Fixed quantity per exit'**
  String get attachedOrderExitQuantity;

  /// No description provided for @attachedOrderVerified.
  ///
  /// In en, this message translates to:
  /// **'Strategy and linked terms checked by query'**
  String get attachedOrderVerified;

  /// No description provided for @attachedOrderStrategyId.
  ///
  /// In en, this message translates to:
  /// **'Strategy ID'**
  String get attachedOrderStrategyId;

  /// No description provided for @attachedOrderStrategyStatus.
  ///
  /// In en, this message translates to:
  /// **'Exchange strategy status'**
  String get attachedOrderStrategyStatus;

  /// No description provided for @attachedOrderLegStatus.
  ///
  /// In en, this message translates to:
  /// **'Leg {sequence} status'**
  String attachedOrderLegStatus(int sequence);

  /// No description provided for @attachedOrderQueryScope.
  ///
  /// In en, this message translates to:
  /// **'These are exchange-reported strategy and leg statuses, not verified executed quantities, balances or remaining positions. An inactive leg may have no order ID. Check entry and exit execution separately.'**
  String get attachedOrderQueryScope;

  /// No description provided for @attachedOrderRefresh.
  ///
  /// In en, this message translates to:
  /// **'Sign to query this strategy again'**
  String get attachedOrderRefresh;

  /// No description provided for @attachedOrderClientId.
  ///
  /// In en, this message translates to:
  /// **'Client strategy reference'**
  String get attachedOrderClientId;

  /// No description provided for @attachedOrderConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'This submits a real linked strategy. Review the full main-order protection quantity, each trigger and exit price. Entry partial or full fills drive placement; partial or full exit fills drive peer cancellation. Query exchange reports to check the actual outcome.'**
  String get attachedOrderConfirmHint;

  /// No description provided for @orderRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending order recovery'**
  String get orderRecoveryTitle;

  /// No description provided for @orderRecoveryScope.
  ///
  /// In en, this message translates to:
  /// **'Only pending futures orders or strategies saved for this wallet on this device appear here. Reconnect the same wallet and sign to query; recovery never submits an order. A missing result does not prove the original was not sent; its record stays pending. Check the outcome before placing new orders or changing settings. Clearing app data or uninstalling removes local records.'**
  String get orderRecoveryScope;

  /// No description provided for @orderRecoveryStorage.
  ///
  /// In en, this message translates to:
  /// **'Local order records could not be read or saved. Trading remains available.'**
  String get orderRecoveryStorage;

  /// No description provided for @orderRecoveryPending.
  ///
  /// In en, this message translates to:
  /// **'This wallet has order records with unconfirmed results. You can inspect their original references; trading remains available.'**
  String get orderRecoveryPending;

  /// No description provided for @orderRecoveryConnect.
  ///
  /// In en, this message translates to:
  /// **'Sign in or reconnect the original wallet'**
  String get orderRecoveryConnect;

  /// No description provided for @orderRecoveryReload.
  ///
  /// In en, this message translates to:
  /// **'Retry local records'**
  String get orderRecoveryReload;

  /// No description provided for @orderRecoveryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending records for this wallet on this device. This does not mean the exchange has no open orders.'**
  String get orderRecoveryEmpty;

  /// No description provided for @orderRecoveryQuery.
  ///
  /// In en, this message translates to:
  /// **'Sign to query the original reference'**
  String get orderRecoveryQuery;

  /// No description provided for @orderRecoveryCreated.
  ///
  /// In en, this message translates to:
  /// **'Recorded at'**
  String get orderRecoveryCreated;

  /// No description provided for @orderRecoveryVerified.
  ///
  /// In en, this message translates to:
  /// **'Original reference and terms checked. Execution and account state remain limited to what the query reports.'**
  String get orderRecoveryVerified;

  /// No description provided for @orderRecoveryActiveOperation.
  ///
  /// In en, this message translates to:
  /// **'An operation in this session is still active or unresolved. Use its original page to recheck.'**
  String get orderRecoveryActiveOperation;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationTitle;

  /// No description provided for @notificationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recorded notifications for this wallet. An empty inbox does not prove there were no account events.'**
  String get notificationEmpty;

  /// No description provided for @notificationSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view this wallet’s notifications.'**
  String get notificationSignIn;

  /// No description provided for @notificationStorageFailed.
  ///
  /// In en, this message translates to:
  /// **'Local notifications could not be loaded or saved. Visible changes remain in memory; retry to restore persistence. Existing stored data is not cleared.'**
  String get notificationStorageFailed;

  /// No description provided for @notificationRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry local storage'**
  String get notificationRetry;

  /// No description provided for @notificationMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationMarkAllRead;

  /// No description provided for @notificationUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationUnread;

  /// No description provided for @notificationCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get notificationCritical;

  /// No description provided for @notificationMarginTitle.
  ///
  /// In en, this message translates to:
  /// **'Margin Call'**
  String get notificationMarginTitle;

  /// No description provided for @notificationLiquidationTitle.
  ///
  /// In en, this message translates to:
  /// **'Liquidation Order Update'**
  String get notificationLiquidationTitle;

  /// No description provided for @notificationAdlTitle.
  ///
  /// In en, this message translates to:
  /// **'ADL Order Update'**
  String get notificationAdlTitle;

  /// No description provided for @notificationRiskScope.
  ///
  /// In en, this message translates to:
  /// **'This event does not prove the whole position was closed. Review actual fills and read remaining positions separately. Risk warnings may arrive during or after liquidation.'**
  String get notificationRiskScope;

  /// No description provided for @notificationMarginScope.
  ///
  /// In en, this message translates to:
  /// **'All risk positions reported in this event are listed below. The event supplies no risk percentage, liquidation price or countdown. Delivery before liquidation is not guaranteed.'**
  String get notificationMarginScope;

  /// No description provided for @notificationEventTime.
  ///
  /// In en, this message translates to:
  /// **'Event time (UTC)'**
  String get notificationEventTime;

  /// No description provided for @notificationTransactionTime.
  ///
  /// In en, this message translates to:
  /// **'Transaction time (UTC)'**
  String get notificationTransactionTime;

  /// No description provided for @notificationTradeTime.
  ///
  /// In en, this message translates to:
  /// **'Order trade time (UTC)'**
  String get notificationTradeTime;

  /// No description provided for @notificationLastQuantity.
  ///
  /// In en, this message translates to:
  /// **'Last filled quantity'**
  String get notificationLastQuantity;

  /// No description provided for @notificationCumulativeQuantity.
  ///
  /// In en, this message translates to:
  /// **'Cumulative filled quantity'**
  String get notificationCumulativeQuantity;

  /// No description provided for @notificationOriginalQuantity.
  ///
  /// In en, this message translates to:
  /// **'Original order quantity'**
  String get notificationOriginalQuantity;

  /// No description provided for @notificationLastPrice.
  ///
  /// In en, this message translates to:
  /// **'Last fill price'**
  String get notificationLastPrice;

  /// No description provided for @notificationRealizedPnl.
  ///
  /// In en, this message translates to:
  /// **'Reported realized PnL'**
  String get notificationRealizedPnl;

  /// No description provided for @notificationUnits.
  ///
  /// In en, this message translates to:
  /// **'Quantities use the base asset; prices use the quote asset. Units are shown only when verified from the relevant market directory. These figures describe this event, not current balances.'**
  String get notificationUnits;

  /// No description provided for @notificationMaintenanceMargin.
  ///
  /// In en, this message translates to:
  /// **'Maintenance margin required'**
  String get notificationMaintenanceMargin;

  /// No description provided for @notificationYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get notificationYes;

  /// No description provided for @notificationNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get notificationNo;

  /// No description provided for @notificationOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'{status, select, NEW{Perp Order · New} PARTIALLY_FILLED{Perp Order · Partially Filled} FILLED{Perp Order · Filled} CANCELED{Perp Order · Canceled} EXPIRED{Perp Order · Expired} REJECTED{Perp Order · Rejected} other{Perp Order · Updated}}'**
  String notificationOrderTitle(String status);

  /// No description provided for @notificationStatus.
  ///
  /// In en, this message translates to:
  /// **'{status, select, NEW{New} PARTIALLY_FILLED{Partially filled} FILLED{Filled} CANCELED{Canceled} EXPIRED{Expired} REJECTED{Rejected} NEW_INSURANCE{Insurance fund liquidation order} NEW_ADL{ADL order created} other{Unknown}}'**
  String notificationStatus(String status);

  /// No description provided for @notificationExecution.
  ///
  /// In en, this message translates to:
  /// **'{execution, select, NEW{Execution: new} CANCELED{Execution: canceled} CALCULATED{Execution: liquidation calculation} EXPIRED{Execution: expired} TRADE{Execution: trade} AMENDMENT{Execution: amendment} REJECTED{Execution: rejected} other{Execution: unknown}}'**
  String notificationExecution(String execution);

  /// No description provided for @notificationOrderType.
  ///
  /// In en, this message translates to:
  /// **'{type, select, LIMIT{Limit} MARKET{Market} STOP{Stop limit} STOP_MARKET{Stop market} TAKE_PROFIT{Take-profit limit} TAKE_PROFIT_MARKET{Take-profit market} TRAILING_STOP_MARKET{Trailing stop market} LIQUIDATION{Liquidation} other{Unknown}}'**
  String notificationOrderType(String type);

  /// No description provided for @notificationOriginalType.
  ///
  /// In en, this message translates to:
  /// **'Original order type'**
  String get notificationOriginalType;

  /// No description provided for @notificationUnitFailure.
  ///
  /// In en, this message translates to:
  /// **'Market units could not be loaded. Amounts remain visible with unknown units; retry the public market directory.'**
  String get notificationUnitFailure;

  /// No description provided for @spotAccountChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Spot account monitoring'**
  String get spotAccountChangeTitle;

  /// No description provided for @spotAccountChangeScope.
  ///
  /// In en, this message translates to:
  /// **'Sign with the current wallet to start or renew Spot monitoring for up to 60 minutes. It records live Spot order events and marks Spot snapshots as needing a signed refresh. No automatic signatures or historical backfill. Stopping disconnects this app; it does not invalidate a key shared by other clients.'**
  String get spotAccountChangeScope;

  /// No description provided for @spotAccountChangeStart.
  ///
  /// In en, this message translates to:
  /// **'Sign to monitor Spot events'**
  String get spotAccountChangeStart;

  /// No description provided for @spotAccountChangeRenew.
  ///
  /// In en, this message translates to:
  /// **'Sign to renew Spot monitoring'**
  String get spotAccountChangeRenew;

  /// No description provided for @spotNotificationLastQuote.
  ///
  /// In en, this message translates to:
  /// **'Last filled quote amount'**
  String get spotNotificationLastQuote;

  /// No description provided for @spotNotificationCumulativeQuote.
  ///
  /// In en, this message translates to:
  /// **'Cumulative filled quote amount'**
  String get spotNotificationCumulativeQuote;

  /// No description provided for @spotNotificationQuoteOrderQuantity.
  ///
  /// In en, this message translates to:
  /// **'Requested quote-asset budget'**
  String get spotNotificationQuoteOrderQuantity;

  /// No description provided for @spotNotificationCreationTime.
  ///
  /// In en, this message translates to:
  /// **'Order created (UTC)'**
  String get spotNotificationCreationTime;

  /// No description provided for @spotNotificationOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'{status, select, NEW{Spot Order · New} PARTIALLY_FILLED{Spot Order · Partially Filled} FILLED{Spot Order · Filled} CANCELED{Spot Order · Canceled} EXPIRED{Spot Order · Expired} REJECTED{Spot Order · Rejected} other{Spot Order · Updated}}'**
  String spotNotificationOrderTitle(String status);

  /// No description provided for @transferHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposit / withdrawal records'**
  String get transferHistoryTitle;

  /// No description provided for @transferHistoryScope.
  ///
  /// In en, this message translates to:
  /// **'Sign to read deposit / withdrawal records for both markets. The first read does not notify existing history; later refreshes notify newly observed transfers and status changes. Returned records may not include all history.'**
  String get transferHistoryScope;

  /// No description provided for @transferRefresh.
  ///
  /// In en, this message translates to:
  /// **'Sign to refresh records'**
  String get transferRefresh;

  /// No description provided for @transferRefreshNeeded.
  ///
  /// In en, this message translates to:
  /// **'Deposit / withdrawal records may have changed. Sign to refresh and confirm their status; balance changes alone do not prove completion.'**
  String get transferRefreshNeeded;

  /// No description provided for @transferBaselineCreated.
  ///
  /// In en, this message translates to:
  /// **'Initial baseline established. Existing records did not create notifications.'**
  String get transferBaselineCreated;

  /// No description provided for @transferHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching records were returned. This does not prove there were no transfers.'**
  String get transferHistoryEmpty;

  /// No description provided for @transferRecordScope.
  ///
  /// In en, this message translates to:
  /// **'Status is reported by Aster. Record time is not completion time; no failure reason is supplied by this history response.'**
  String get transferRecordScope;

  /// No description provided for @transferRecordId.
  ///
  /// In en, this message translates to:
  /// **'Transfer record ID'**
  String get transferRecordId;

  /// No description provided for @transferTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Transfer type'**
  String get transferTypeLabel;

  /// No description provided for @transferDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get transferDeposit;

  /// No description provided for @transferWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get transferWithdraw;

  /// No description provided for @transferSpotMarket.
  ///
  /// In en, this message translates to:
  /// **'Spot'**
  String get transferSpotMarket;

  /// No description provided for @transferPerpMarket.
  ///
  /// In en, this message translates to:
  /// **'Perpetuals'**
  String get transferPerpMarket;

  /// No description provided for @transferMarketLabel.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get transferMarketLabel;

  /// No description provided for @transferAllMarkets.
  ///
  /// In en, this message translates to:
  /// **'All markets'**
  String get transferAllMarkets;

  /// No description provided for @transferNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get transferNetwork;

  /// No description provided for @transferChainId.
  ///
  /// In en, this message translates to:
  /// **'Chain ID'**
  String get transferChainId;

  /// No description provided for @transferNetworkEthereum.
  ///
  /// In en, this message translates to:
  /// **'Ethereum'**
  String get transferNetworkEthereum;

  /// No description provided for @transferNetworkBnb.
  ///
  /// In en, this message translates to:
  /// **'BNB Chain'**
  String get transferNetworkBnb;

  /// No description provided for @transferNetworkArbitrum.
  ///
  /// In en, this message translates to:
  /// **'Arbitrum One'**
  String get transferNetworkArbitrum;

  /// No description provided for @transferUnknownNetwork.
  ///
  /// In en, this message translates to:
  /// **'Unmapped network (chain ID {chainId})'**
  String transferUnknownNetwork(String chainId);

  /// No description provided for @transferHash.
  ///
  /// In en, this message translates to:
  /// **'Transaction hash'**
  String get transferHash;

  /// No description provided for @transferHashUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get transferHashUnknown;

  /// No description provided for @transferRecordTime.
  ///
  /// In en, this message translates to:
  /// **'Record time (UTC)'**
  String get transferRecordTime;

  /// No description provided for @transferReadTime.
  ///
  /// In en, this message translates to:
  /// **'Last read (UTC): {time}'**
  String transferReadTime(String time);

  /// No description provided for @transferStorageRequired.
  ///
  /// In en, this message translates to:
  /// **'Transfer tracking could not be loaded or saved. Retry local notification storage before refreshing. Existing records are retained.'**
  String get transferStorageRequired;

  /// No description provided for @transferTrackingFull.
  ///
  /// In en, this message translates to:
  /// **'Local transfer tracking has reached its limit. Existing observations are retained; this refresh was not recorded.'**
  String get transferTrackingFull;

  /// No description provided for @transferStatus.
  ///
  /// In en, this message translates to:
  /// **'{status, select, processing{Processing} success{Successful} failed{Failed} other{Unknown}}'**
  String transferStatus(String status);

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'{type, select, deposit{{status, select, processing{Deposit processing} success{Deposit successful} failed{Deposit failed} other{Deposit update}}} withdraw{{status, select, processing{Withdrawal processing} success{Withdrawal successful} failed{Withdrawal failed} other{Withdrawal update}}} other{Transfer update}}'**
  String transferTitle(String type, String status);

  /// No description provided for @transferObservedTime.
  ///
  /// In en, this message translates to:
  /// **'Observed at (UTC)'**
  String get transferObservedTime;

  /// No description provided for @assetValueUsd.
  ///
  /// In en, this message translates to:
  /// **'{label} · USD estimate'**
  String assetValueUsd(String label);

  /// No description provided for @assetValueBtc.
  ///
  /// In en, this message translates to:
  /// **'{label} · BTC estimate'**
  String assetValueBtc(String label);

  /// No description provided for @assetValueUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Some estimates are unavailable. Missing prices or balances are not treated as zero.'**
  String get assetValueUnavailable;

  /// No description provided for @assetValueStale.
  ///
  /// In en, this message translates to:
  /// **'Estimate uses an older or incomplete account / price snapshot. Refresh before relying on it.'**
  String get assetValueStale;

  /// No description provided for @assetValueSpotScope.
  ///
  /// In en, this message translates to:
  /// **'Spot wallet estimate'**
  String get assetValueSpotScope;

  /// No description provided for @assetValuePerpScope.
  ///
  /// In en, this message translates to:
  /// **'Perpetual wallet estimate'**
  String get assetValuePerpScope;

  /// No description provided for @assetValueKnownSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Known asset subtotal'**
  String get assetValueKnownSubtotal;

  /// No description provided for @assetValueWalletTotal.
  ///
  /// In en, this message translates to:
  /// **'Wallet asset value'**
  String get assetValueWalletTotal;

  /// No description provided for @assetValueBtcEstimate.
  ///
  /// In en, this message translates to:
  /// **'Approximate BTC equivalent'**
  String get assetValueBtcEstimate;

  /// No description provided for @assetValueMissing.
  ///
  /// In en, this message translates to:
  /// **'{count} asset(s) have no USD price and are excluded from this subtotal.'**
  String assetValueMissing(int count);

  /// No description provided for @assetValueScope.
  ///
  /// In en, this message translates to:
  /// **'Reference USD asset indices from Aster; BTC equivalents use the BTC/USD index. Stablecoins use their reported price. Wallet estimates exclude unrealized PnL and other accounts, products, collateral discounts and execution costs. BTC values are rounded for display.'**
  String get assetValueScope;

  /// No description provided for @assetIndexReadTime.
  ///
  /// In en, this message translates to:
  /// **'Price snapshot read (UTC): {time}'**
  String assetIndexReadTime(String time);

  /// No description provided for @assetIndexLoading.
  ///
  /// In en, this message translates to:
  /// **'Refreshing reference prices…'**
  String get assetIndexLoading;

  /// No description provided for @assetIndexPaused.
  ///
  /// In en, this message translates to:
  /// **'Reference price updates are paused.'**
  String get assetIndexPaused;

  /// No description provided for @assetIndexFailed.
  ///
  /// In en, this message translates to:
  /// **'Reference prices could not be refreshed. Previous estimates may be stale.'**
  String get assetIndexFailed;

  /// No description provided for @assetIndexRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh public reference prices'**
  String get assetIndexRefresh;

  /// No description provided for @assetValueHideLow.
  ///
  /// In en, this message translates to:
  /// **'Hide assets worth 0.0001 BTC or less'**
  String get assetValueHideLow;

  /// No description provided for @assetValueHideLowScope.
  ///
  /// In en, this message translates to:
  /// **'Uses total Spot balance. Assets with missing or stale estimates remain visible.'**
  String get assetValueHideLowScope;

  /// No description provided for @subaccountManagement.
  ///
  /// In en, this message translates to:
  /// **'Sub-account management'**
  String get subaccountManagement;

  /// No description provided for @subaccountListScope.
  ///
  /// In en, this message translates to:
  /// **'Sign with the connected wallet to view its linked accounts. Reading this list does not change the account used for trading.'**
  String get subaccountListScope;

  /// No description provided for @subaccountConnectedWallet.
  ///
  /// In en, this message translates to:
  /// **'Connected signing wallet'**
  String get subaccountConnectedWallet;

  /// No description provided for @subaccountRead.
  ///
  /// In en, this message translates to:
  /// **'Read linked accounts'**
  String get subaccountRead;

  /// No description provided for @subaccountRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh linked accounts'**
  String get subaccountRefresh;

  /// No description provided for @subaccountStopWaiting.
  ///
  /// In en, this message translates to:
  /// **'Stop waiting'**
  String get subaccountStopWaiting;

  /// No description provided for @subaccountCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sub-account(s)'**
  String subaccountCount(int count);

  /// No description provided for @subaccountNoChildren.
  ///
  /// In en, this message translates to:
  /// **'No sub-accounts were returned.'**
  String get subaccountNoChildren;

  /// No description provided for @subaccountListBoundaries.
  ///
  /// In en, this message translates to:
  /// **'Account IDs and names are shown as returned. This list does not provide addresses or freeze status. Open account management for explicit creation, switching, freeze/unfreeze and transfers.'**
  String get subaccountListBoundaries;

  /// No description provided for @subaccountSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by account name or ID'**
  String get subaccountSearch;

  /// No description provided for @subaccountNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching accounts.'**
  String get subaccountNoMatches;

  /// No description provided for @subaccountParent.
  ///
  /// In en, this message translates to:
  /// **'Master account'**
  String get subaccountParent;

  /// No description provided for @subaccountChild.
  ///
  /// In en, this message translates to:
  /// **'Sub-account'**
  String get subaccountChild;

  /// No description provided for @subaccountUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed account'**
  String get subaccountUnnamed;

  /// No description provided for @subaccountId.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get subaccountId;

  /// No description provided for @subaccountCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy account ID'**
  String get subaccountCopyId;

  /// No description provided for @fundingInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposit and withdrawal information'**
  String get fundingInfoTitle;

  /// No description provided for @fundingInfoScope.
  ///
  /// In en, this message translates to:
  /// **'View supported assets and networks. Withdrawal limits require a wallet signature. Open an asset to review deposit or withdrawal submission separately.'**
  String get fundingInfoScope;

  /// No description provided for @fundingEvmScope.
  ///
  /// In en, this message translates to:
  /// **'Currently shows the three EVM mainnets in the funding documentation. This is not a complete directory of all Aster networks.'**
  String get fundingEvmScope;

  /// No description provided for @fundingAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get fundingAccount;

  /// No description provided for @fundingDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get fundingDeposit;

  /// No description provided for @fundingWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get fundingWithdraw;

  /// No description provided for @fundingNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get fundingNetwork;

  /// No description provided for @fundingEthereum.
  ///
  /// In en, this message translates to:
  /// **'Ethereum · 1'**
  String get fundingEthereum;

  /// No description provided for @fundingBnbChain.
  ///
  /// In en, this message translates to:
  /// **'BNB Chain · 56'**
  String get fundingBnbChain;

  /// No description provided for @fundingArbitrum.
  ///
  /// In en, this message translates to:
  /// **'Arbitrum · 42161'**
  String get fundingArbitrum;

  /// No description provided for @fundingCatalogLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading public asset configuration…'**
  String get fundingCatalogLoading;

  /// No description provided for @fundingCatalogFailed.
  ///
  /// In en, this message translates to:
  /// **'Asset configuration is unavailable or invalid. Retry the public read.'**
  String get fundingCatalogFailed;

  /// No description provided for @fundingCatalogStale.
  ///
  /// In en, this message translates to:
  /// **'Configuration is older than five minutes or a refresh failed. Refresh before relying on it.'**
  String get fundingCatalogStale;

  /// No description provided for @fundingCatalogTime.
  ///
  /// In en, this message translates to:
  /// **'Public configuration read (UTC): {time}'**
  String fundingCatalogTime(String time);

  /// No description provided for @fundingCatalogRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh public configuration'**
  String get fundingCatalogRefresh;

  /// No description provided for @fundingAssetSearch.
  ///
  /// In en, this message translates to:
  /// **'Search asset name or symbol'**
  String get fundingAssetSearch;

  /// No description provided for @fundingNoNetworkAssets.
  ///
  /// In en, this message translates to:
  /// **'No assets were returned for this account, operation and network.'**
  String get fundingNoNetworkAssets;

  /// No description provided for @fundingNativeAsset.
  ///
  /// In en, this message translates to:
  /// **'Native asset'**
  String get fundingNativeAsset;

  /// No description provided for @fundingTokenAsset.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get fundingTokenAsset;

  /// No description provided for @fundingTokenContract.
  ///
  /// In en, this message translates to:
  /// **'Token contract · not a deposit destination'**
  String get fundingTokenContract;

  /// No description provided for @fundingWithdrawLimits.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal limit snapshot'**
  String get fundingWithdrawLimits;

  /// No description provided for @fundingWithdrawScope.
  ///
  /// In en, this message translates to:
  /// **'This read does not authorize a withdrawal. Limits and fees can change. Missing amounts remain unknown; the account balance is not used as a substitute.'**
  String get fundingWithdrawScope;

  /// No description provided for @fundingReadLimits.
  ///
  /// In en, this message translates to:
  /// **'Sign to read withdrawal limits'**
  String get fundingReadLimits;

  /// No description provided for @fundingRefreshLimits.
  ///
  /// In en, this message translates to:
  /// **'Sign to refresh withdrawal limits'**
  String get fundingRefreshLimits;

  /// No description provided for @fundingUserDailyUsd.
  ///
  /// In en, this message translates to:
  /// **'User daily limit'**
  String get fundingUserDailyUsd;

  /// No description provided for @fundingUserRemainingUsd.
  ///
  /// In en, this message translates to:
  /// **'User remaining daily limit'**
  String get fundingUserRemainingUsd;

  /// No description provided for @fundingGlobalDailyUsd.
  ///
  /// In en, this message translates to:
  /// **'Platform daily limit'**
  String get fundingGlobalDailyUsd;

  /// No description provided for @fundingGlobalRemainingUsd.
  ///
  /// In en, this message translates to:
  /// **'Platform remaining daily limit'**
  String get fundingGlobalRemainingUsd;

  /// No description provided for @fundingNoWithdrawBalances.
  ///
  /// In en, this message translates to:
  /// **'No non-zero asset withdrawal balances were returned. Missing entries are not treated as an approved zero allowance.'**
  String get fundingNoWithdrawBalances;

  /// No description provided for @fundingAssetTotal.
  ///
  /// In en, this message translates to:
  /// **'Account withdrawable balance · reported'**
  String get fundingAssetTotal;

  /// No description provided for @fundingChainMaximum.
  ///
  /// In en, this message translates to:
  /// **'Network withdrawable amount · reported'**
  String get fundingChainMaximum;

  /// No description provided for @fundingChainLimit.
  ///
  /// In en, this message translates to:
  /// **'Network amount limit'**
  String get fundingChainLimit;

  /// No description provided for @fundingAssetDailyUsd.
  ///
  /// In en, this message translates to:
  /// **'Asset remaining daily USD limit'**
  String get fundingAssetDailyUsd;

  /// No description provided for @fundingSnapshotFee.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal fee · snapshot'**
  String get fundingSnapshotFee;

  /// No description provided for @fundingLimitsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No matching signed limit for this asset or network. Read or refresh the limits.'**
  String get fundingLimitsUnavailable;

  /// No description provided for @fundingLimitUnits.
  ///
  /// In en, this message translates to:
  /// **'USD limits and asset amounts have different units. These fields are shown separately and do not form a final Max amount. Fees require a fresh check before submission.'**
  String get fundingLimitUnits;

  /// No description provided for @fundingNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching assets.'**
  String get fundingNoMatches;

  /// No description provided for @fundingFeeCheck.
  ///
  /// In en, this message translates to:
  /// **'Check latest withdrawal fee'**
  String get fundingFeeCheck;

  /// No description provided for @fundingFeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal fee estimate'**
  String get fundingFeeTitle;

  /// No description provided for @fundingFeeScope.
  ///
  /// In en, this message translates to:
  /// **'Public estimate for this account type, network and asset. This is the platform withdrawal fee, separate from wallet transaction gas. It does not authorize a withdrawal or guarantee the final fee. Refresh before submitting a withdrawal.'**
  String get fundingFeeScope;

  /// No description provided for @fundingFeeLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading public fee estimate…'**
  String get fundingFeeLoading;

  /// No description provided for @fundingFeeFailed.
  ///
  /// In en, this message translates to:
  /// **'The fee estimate is unavailable or invalid. Retry the public read.'**
  String get fundingFeeFailed;

  /// No description provided for @fundingFeeStale.
  ///
  /// In en, this message translates to:
  /// **'The estimate is older than 30 seconds or a refresh failed. Read it again before relying on it.'**
  String get fundingFeeStale;

  /// No description provided for @fundingFeeAsset.
  ///
  /// In en, this message translates to:
  /// **'Estimated fee in asset units'**
  String get fundingFeeAsset;

  /// No description provided for @fundingFeeUsd.
  ///
  /// In en, this message translates to:
  /// **'Estimated fee in USD'**
  String get fundingFeeUsd;

  /// No description provided for @fundingFeeAssetPrice.
  ///
  /// In en, this message translates to:
  /// **'Asset reference price · USD per unit'**
  String get fundingFeeAssetPrice;

  /// No description provided for @fundingFeeTime.
  ///
  /// In en, this message translates to:
  /// **'Estimate received: {time}'**
  String fundingFeeTime(String time);

  /// No description provided for @fundingFeeRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh fee estimate'**
  String get fundingFeeRefresh;

  /// No description provided for @depositPrecheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposit wallet precheck'**
  String get depositPrecheckTitle;

  /// No description provided for @depositPrecheckScope.
  ///
  /// In en, this message translates to:
  /// **'Read public chain balances and token allowance for this wallet. Minimum deposit is a configuration snapshot. This precheck does not submit an approval or a deposit; platform limits and transaction gas still need verification.'**
  String get depositPrecheckScope;

  /// No description provided for @depositReadWallet.
  ///
  /// In en, this message translates to:
  /// **'Read wallet balance and allowance'**
  String get depositReadWallet;

  /// No description provided for @depositAssetBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet asset balance'**
  String get depositAssetBalance;

  /// No description provided for @depositNativeBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet native balance · gas reserve not deducted'**
  String get depositNativeBalance;

  /// No description provided for @depositAllowance.
  ///
  /// In en, this message translates to:
  /// **'Token allowance for the documented vault'**
  String get depositAllowance;

  /// No description provided for @depositSpenderScope.
  ///
  /// In en, this message translates to:
  /// **'Allowance spender only. Do not manually send funds to this address.'**
  String get depositSpenderScope;

  /// No description provided for @depositBlock.
  ///
  /// In en, this message translates to:
  /// **'Chain block number'**
  String get depositBlock;

  /// No description provided for @depositMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum deposit · configuration snapshot'**
  String get depositMinimum;

  /// No description provided for @depositAmount.
  ///
  /// In en, this message translates to:
  /// **'Deposit amount · precheck only'**
  String get depositAmount;

  /// No description provided for @depositWalletMax.
  ///
  /// In en, this message translates to:
  /// **'Fill token wallet balance · Max'**
  String get depositWalletMax;

  /// No description provided for @depositWalletMaxScope.
  ///
  /// In en, this message translates to:
  /// **'Fills only the token balance, without platform limits. Native currency is still required for gas.'**
  String get depositWalletMaxScope;

  /// No description provided for @depositNativeMaxUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Native Max remains unavailable until final transaction fees and platform limits can be checked. Do not use the full native balance.'**
  String get depositNativeMaxUnavailable;

  /// No description provided for @depositSmallestUnits.
  ///
  /// In en, this message translates to:
  /// **'Exact amount in the smallest token unit'**
  String get depositSmallestUnits;

  /// No description provided for @depositNativeNoApproval.
  ///
  /// In en, this message translates to:
  /// **'Native currency does not need ERC20 allowance. Gas and platform limits remain unverified.'**
  String get depositNativeNoApproval;

  /// No description provided for @depositAllowanceEnough.
  ///
  /// In en, this message translates to:
  /// **'The read token allowance covers this amount. No approval or deposit has been submitted.'**
  String get depositAllowanceEnough;

  /// No description provided for @depositAllowanceNeeded.
  ///
  /// In en, this message translates to:
  /// **'The read token allowance does not cover this amount. Approval is required before a deposit; no approval has been submitted.'**
  String get depositAllowanceNeeded;

  /// No description provided for @depositRpcInvalid.
  ///
  /// In en, this message translates to:
  /// **'The public chain response is incomplete or invalid. Retry the read.'**
  String get depositRpcInvalid;

  /// No description provided for @depositRpcFailed.
  ///
  /// In en, this message translates to:
  /// **'The public chain provider could not complete the read. Retry.'**
  String get depositRpcFailed;

  /// No description provided for @depositRpcWrongChain.
  ///
  /// In en, this message translates to:
  /// **'The provider returned another network. No balance was accepted.'**
  String get depositRpcWrongChain;

  /// No description provided for @depositTokenDecimalsChanged.
  ///
  /// In en, this message translates to:
  /// **'On-chain token decimals differ from the selected configuration. Refresh the asset directory and reopen this page.'**
  String get depositTokenDecimalsChanged;

  /// No description provided for @depositRpcReorg.
  ///
  /// In en, this message translates to:
  /// **'The chain block changed during the read. Refresh to obtain a consistent snapshot.'**
  String get depositRpcReorg;

  /// No description provided for @depositAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive amount within the supported unsigned 256-bit range.'**
  String get depositAmountInvalid;

  /// No description provided for @depositAmountPrecision.
  ///
  /// In en, this message translates to:
  /// **'The amount has more decimal places than this asset supports.'**
  String get depositAmountPrecision;

  /// No description provided for @depositMinimumUnknown.
  ///
  /// In en, this message translates to:
  /// **'The minimum deposit is unknown. Refresh the asset configuration before proceeding.'**
  String get depositMinimumUnknown;

  /// No description provided for @depositBelowMinimum.
  ///
  /// In en, this message translates to:
  /// **'The amount is below the configured minimum deposit.'**
  String get depositBelowMinimum;

  /// No description provided for @depositReadRequired.
  ///
  /// In en, this message translates to:
  /// **'Read the current wallet balance before checking the amount.'**
  String get depositReadRequired;

  /// No description provided for @depositReadStale.
  ///
  /// In en, this message translates to:
  /// **'The wallet snapshot is historical. Refresh before checking the amount.'**
  String get depositReadStale;

  /// No description provided for @depositBalanceInsufficient.
  ///
  /// In en, this message translates to:
  /// **'The amount exceeds the read wallet asset balance.'**
  String get depositBalanceInsufficient;

  /// No description provided for @attachedEntryPricing.
  ///
  /// In en, this message translates to:
  /// **'Entry pricing'**
  String get attachedEntryPricing;

  /// No description provided for @attachedEntryFixed.
  ///
  /// In en, this message translates to:
  /// **'Enter a limit price'**
  String get attachedEntryFixed;

  /// No description provided for @attachedEntryCounterparty.
  ///
  /// In en, this message translates to:
  /// **'BBO · Opposite side, level {depth}'**
  String attachedEntryCounterparty(int depth);

  /// No description provided for @attachedEntryQueue.
  ///
  /// In en, this message translates to:
  /// **'BBO · Same side, level {depth}'**
  String attachedEntryQueue(int depth);

  /// No description provided for @attachedEntryPegTiming.
  ///
  /// In en, this message translates to:
  /// **'The entry takes the selected order-book level once: at placement for a limit entry, or at trigger for a conditional entry. It does not keep chasing the book.'**
  String get attachedEntryPegTiming;

  /// No description provided for @attachedEntryPegEstimate.
  ///
  /// In en, this message translates to:
  /// **'Notional and margin estimates use Mark price (the trigger price for conditional entries), not the selected book level or an execution price. Aster checks TP/SL against its resolved entry price and may reject the strategy.'**
  String get attachedEntryPegEstimate;

  /// No description provided for @attachedEntryPegInvalid.
  ///
  /// In en, this message translates to:
  /// **'BBO entry pricing requires a limit or stop-limit entry with attached TP/SL and no entered limit price. Post Only BBO supports same-side level 1 only.'**
  String get attachedEntryPegInvalid;

  /// No description provided for @scaledTitle.
  ///
  /// In en, this message translates to:
  /// **'Scaled orders'**
  String get scaledTitle;

  /// No description provided for @scaledRule.
  ///
  /// In en, this message translates to:
  /// **'2–110 independent GTC limit orders, submitted from low to high price. Prices include both endpoints and are rounded down to distinct ticks. Quantities follow the selected distribution and valid quantity steps; review every child before signing.'**
  String get scaledRule;

  /// No description provided for @scaledRisk.
  ///
  /// In en, this message translates to:
  /// **'Each order requires a fresh account check, a submission signature and a query signature. Orders are independent and may only partly succeed. A failure or unknown result stops the remaining orders. Stopping or leaving this page does not cancel orders already sent. Unsent orders are never resumed automatically.'**
  String get scaledRisk;

  /// No description provided for @scaledLow.
  ///
  /// In en, this message translates to:
  /// **'Lowest price'**
  String get scaledLow;

  /// No description provided for @scaledHigh.
  ///
  /// In en, this message translates to:
  /// **'Highest price'**
  String get scaledHigh;

  /// No description provided for @scaledCount.
  ///
  /// In en, this message translates to:
  /// **'Number of orders'**
  String get scaledCount;

  /// No description provided for @scaledPreview.
  ///
  /// In en, this message translates to:
  /// **'Order breakdown'**
  String get scaledPreview;

  /// No description provided for @scaledReview.
  ///
  /// In en, this message translates to:
  /// **'Review scaled orders'**
  String get scaledReview;

  /// No description provided for @scaledConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign and submit these orders'**
  String get scaledConfirm;

  /// No description provided for @scaledTotalQuantity.
  ///
  /// In en, this message translates to:
  /// **'Total quantity'**
  String get scaledTotalQuantity;

  /// No description provided for @scaledTotalNotional.
  ///
  /// In en, this message translates to:
  /// **'Total limit notional'**
  String get scaledTotalNotional;

  /// No description provided for @scaledMarginReference.
  ///
  /// In en, this message translates to:
  /// **'Margin reference before netting'**
  String get scaledMarginReference;

  /// No description provided for @scaledMarginHint.
  ///
  /// In en, this message translates to:
  /// **'Reference = total limit notional ÷ leverage. It excludes position netting, existing orders, fees and released margin. It is not the final margin requirement or an executable allowance. Aster checks each order.'**
  String get scaledMarginHint;

  /// No description provided for @scaledPortion.
  ///
  /// In en, this message translates to:
  /// **'Share of total quantity (approx.)'**
  String get scaledPortion;

  /// No description provided for @scaledOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String scaledOrderNumber(int number);

  /// No description provided for @scaledCountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 2 to 110.'**
  String get scaledCountInvalid;

  /// No description provided for @scaledRangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter positive prices with the highest price above the lowest.'**
  String get scaledRangeInvalid;

  /// No description provided for @scaledRangeTooNarrow.
  ///
  /// In en, this message translates to:
  /// **'The price range has too few ticks for distinct child orders.'**
  String get scaledRangeTooNarrow;

  /// No description provided for @scaledQuantityTooSmall.
  ///
  /// In en, this message translates to:
  /// **'The total quantity cannot cover the minimum quantity of every child order.'**
  String get scaledQuantityTooSmall;

  /// No description provided for @scaledQuantityStep.
  ///
  /// In en, this message translates to:
  /// **'The total quantity cannot be split exactly into valid quantity steps. Adjust it without rounding away quantity.'**
  String get scaledQuantityStep;

  /// No description provided for @scaledConfigurationChanged.
  ///
  /// In en, this message translates to:
  /// **'Account mode, leverage or order rules changed. Remaining orders were stopped; refresh and review a new plan.'**
  String get scaledConfigurationChanged;

  /// No description provided for @scaledStopped.
  ///
  /// In en, this message translates to:
  /// **'Remaining orders stopped. Orders already sent stay active; check their results below.'**
  String get scaledStopped;

  /// No description provided for @scaledResults.
  ///
  /// In en, this message translates to:
  /// **'Scaled order results'**
  String get scaledResults;

  /// No description provided for @scaledRefreshRequired.
  ///
  /// In en, this message translates to:
  /// **'Refresh the account and review the plan again before submitting.'**
  String get scaledRefreshRequired;

  /// No description provided for @depositGasTitle.
  ///
  /// In en, this message translates to:
  /// **'Next-step gas estimate'**
  String get depositGasTitle;

  /// No description provided for @depositGasEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate next step'**
  String get depositGasEstimate;

  /// No description provided for @depositGasScope.
  ///
  /// In en, this message translates to:
  /// **'Public simulation only: no wallet signature or transaction is sent. Estimates cover this step only. Approval, deposit, receipts and platform credit are separate steps. User/platform limits are still unknown.'**
  String get depositGasScope;

  /// No description provided for @depositGasDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit transaction'**
  String get depositGasDeposit;

  /// No description provided for @depositGasApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve the exact deposit amount'**
  String get depositGasApprove;

  /// No description provided for @depositGasReset.
  ///
  /// In en, this message translates to:
  /// **'Reset the existing allowance to zero'**
  String get depositGasReset;

  /// No description provided for @depositGasResetHint.
  ///
  /// In en, this message translates to:
  /// **'A nonzero allowance is below the requested amount. Reset it first, then re-read and estimate exact approval, then deposit. No unlimited approval is prepared.'**
  String get depositGasResetHint;

  /// No description provided for @depositGasTarget.
  ///
  /// In en, this message translates to:
  /// **'Transaction target contract'**
  String get depositGasTarget;

  /// No description provided for @depositGasValue.
  ///
  /// In en, this message translates to:
  /// **'Native token sent with this step'**
  String get depositGasValue;

  /// No description provided for @depositGasEstimatedUnits.
  ///
  /// In en, this message translates to:
  /// **'Estimated gas units'**
  String get depositGasEstimatedUnits;

  /// No description provided for @depositGasLimit.
  ///
  /// In en, this message translates to:
  /// **'Gas limit with reserve'**
  String get depositGasLimit;

  /// No description provided for @depositGasPrice.
  ///
  /// In en, this message translates to:
  /// **'Quoted gas price (wei)'**
  String get depositGasPrice;

  /// No description provided for @depositGasReserve.
  ///
  /// In en, this message translates to:
  /// **'Native fee reserve for this step'**
  String get depositGasReserve;

  /// No description provided for @depositGasTotal.
  ///
  /// In en, this message translates to:
  /// **'Native value + fee reserve'**
  String get depositGasTotal;

  /// No description provided for @depositGasReserveHint.
  ///
  /// In en, this message translates to:
  /// **'The gas limit rounds the simulation estimate up by 20%. Fee reserve = gas limit × quoted legacy gas price. It is not the actual fee or a guarantee of execution. Prices and chain state can change; re-estimate before sending. Later steps need separate reserves.'**
  String get depositGasReserveHint;

  /// No description provided for @depositGasChangedAmount.
  ///
  /// In en, this message translates to:
  /// **'This estimate belongs to the amount shown below. The input changed; estimate again.'**
  String get depositGasChangedAmount;

  /// No description provided for @depositGasAmount.
  ///
  /// In en, this message translates to:
  /// **'Deposit amount used for this estimate'**
  String get depositGasAmount;

  /// No description provided for @depositGasRouteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This deposit route cannot be encoded from the documented normal EVM deposit contract.'**
  String get depositGasRouteUnsupported;

  /// No description provided for @depositGasSimulationFailed.
  ///
  /// In en, this message translates to:
  /// **'The chain node rejected this step during simulation. No transaction was sent. Refresh balances, allowance and amount before retrying.'**
  String get depositGasSimulationFailed;

  /// No description provided for @depositGasBalanceInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Native balance cannot cover this step’s value and fee reserve. Keep native tokens for subsequent steps too.'**
  String get depositGasBalanceInsufficient;

  /// No description provided for @depositGasPendingTransactions.
  ///
  /// In en, this message translates to:
  /// **'The wallet has pending transactions or its nonce changed. Wait for them to settle, then refresh and estimate again.'**
  String get depositGasPendingTransactions;

  /// No description provided for @depositGasBlockLimit.
  ///
  /// In en, this message translates to:
  /// **'The padded gas limit exceeds this chain block’s gas limit. No transaction is prepared for sending.'**
  String get depositGasBlockLimit;

  /// No description provided for @depositApprovalPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare this approval'**
  String get depositApprovalPrepare;

  /// No description provided for @depositApprovalScope.
  ///
  /// In en, this message translates to:
  /// **'Only this token approval will be sent. It costs native gas and does not deposit funds. Deposit submission requires a separate review, fresh reads and external verification of Aster availability and limits.'**
  String get depositApprovalScope;

  /// No description provided for @depositApprovalReview.
  ///
  /// In en, this message translates to:
  /// **'Review token approval'**
  String get depositApprovalReview;

  /// No description provided for @depositApprovalConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm and open wallet'**
  String get depositApprovalConfirm;

  /// No description provided for @depositApprovalCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get depositApprovalCancel;

  /// No description provided for @depositApprovalStorage.
  ///
  /// In en, this message translates to:
  /// **'The approval recovery record cannot be read or saved. New approvals are blocked. Retry storage recovery before continuing.'**
  String get depositApprovalStorage;

  /// No description provided for @depositApprovalPending.
  ///
  /// In en, this message translates to:
  /// **'This wallet has an unresolved approval. Check that transaction before sending another one.'**
  String get depositApprovalPending;

  /// No description provided for @depositApprovalNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'This amount needs no approval step. Deposit submission still requires verified platform limits and credit recovery.'**
  String get depositApprovalNotNeeded;

  /// No description provided for @depositApprovalChanged.
  ///
  /// In en, this message translates to:
  /// **'Chain state or fees changed. Prepare and review the step again; nothing was sent.'**
  String get depositApprovalChanged;

  /// No description provided for @depositApprovalUnknown.
  ///
  /// In en, this message translates to:
  /// **'The wallet result is unknown. Do not repeat the approval. Use the original transaction hash from your wallet to check it.'**
  String get depositApprovalUnknown;

  /// No description provided for @depositApprovalMismatch.
  ///
  /// In en, this message translates to:
  /// **'This transaction does not match the saved wallet, chain or nonce. The saved record was kept.'**
  String get depositApprovalMismatch;

  /// No description provided for @depositApprovalRecovery.
  ///
  /// In en, this message translates to:
  /// **'Pending token approvals'**
  String get depositApprovalRecovery;

  /// No description provided for @depositApprovalOpenRecovery.
  ///
  /// In en, this message translates to:
  /// **'Review pending approvals'**
  String get depositApprovalOpenRecovery;

  /// No description provided for @depositApprovalRecoveryScope.
  ///
  /// In en, this message translates to:
  /// **'Read-only chain checks never resend a transaction. A reported hash is not a receipt. Two observed confirmations are required here; later reorgs remain possible. No approval result proves a deposit or platform credit.'**
  String get depositApprovalRecoveryScope;

  /// No description provided for @depositApprovalNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending approvals for this wallet.'**
  String get depositApprovalNoPending;

  /// No description provided for @depositApprovalHash.
  ///
  /// In en, this message translates to:
  /// **'Original transaction hash'**
  String get depositApprovalHash;

  /// No description provided for @depositApprovalHashHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the original hash, or a speed-up/cancellation hash from your wallet. Only the same wallet, chain and nonce can resolve this saved step. Leave blank to check the saved hash.'**
  String get depositApprovalHashHint;

  /// No description provided for @depositApprovalCheck.
  ///
  /// In en, this message translates to:
  /// **'Check on-chain result'**
  String get depositApprovalCheck;

  /// No description provided for @depositApprovalSent.
  ///
  /// In en, this message translates to:
  /// **'The wallet request finished. Check the saved transaction; no receipt or allowance change has been confirmed yet.'**
  String get depositApprovalSent;

  /// No description provided for @depositApprovalReceiptPending.
  ///
  /// In en, this message translates to:
  /// **'Chain confirmation is pending. Keep the saved record and check again; no transaction will be resent.'**
  String get depositApprovalReceiptPending;

  /// No description provided for @depositApprovalReceiptSucceeded.
  ///
  /// In en, this message translates to:
  /// **'The approval transaction succeeded on-chain. Re-read the current allowance and estimate the next step separately. No deposit was sent.'**
  String get depositApprovalReceiptSucceeded;

  /// No description provided for @depositApprovalReceiptReverted.
  ///
  /// In en, this message translates to:
  /// **'The approval transaction reverted on-chain. Gas may have been spent. Re-read before preparing another step.'**
  String get depositApprovalReceiptReverted;

  /// No description provided for @depositApprovalConfirmations.
  ///
  /// In en, this message translates to:
  /// **'Observed confirmations'**
  String get depositApprovalConfirmations;

  /// No description provided for @depositApprovalGasFee.
  ///
  /// In en, this message translates to:
  /// **'Recorded execution gas fee'**
  String get depositApprovalGasFee;

  /// No description provided for @depositApprovalFeeScope.
  ///
  /// In en, this message translates to:
  /// **'This fee uses receipt gasUsed × effectiveGasPrice (or the reported legacy price). Additional network fees may be separate.'**
  String get depositApprovalFeeScope;

  /// No description provided for @depositApprovalNonce.
  ///
  /// In en, this message translates to:
  /// **'Transaction nonce'**
  String get depositApprovalNonce;

  /// No description provided for @depositApprovalPreparedAt.
  ///
  /// In en, this message translates to:
  /// **'Prepared at (UTC)'**
  String get depositApprovalPreparedAt;

  /// No description provided for @walletTransactionInvalid.
  ///
  /// In en, this message translates to:
  /// **'The wallet transaction details are invalid. Nothing was sent.'**
  String get walletTransactionInvalid;

  /// No description provided for @walletTransactionBusy.
  ///
  /// In en, this message translates to:
  /// **'Another wallet transaction request is still pending. Wait for it to finish.'**
  String get walletTransactionBusy;

  /// No description provided for @walletTransactionWrongChain.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the same wallet on the selected deposit network before sending this step.'**
  String get walletTransactionWrongChain;

  /// No description provided for @walletTransactionPermission.
  ///
  /// In en, this message translates to:
  /// **'This wallet session has no transaction sending permission. Disconnect and reconnect the same wallet to grant it.'**
  String get walletTransactionPermission;

  /// No description provided for @depositApprovalReceiptReplaced.
  ///
  /// In en, this message translates to:
  /// **'Another transaction consumed the saved nonce on-chain. The original approval is not confirmed. Re-read the current allowance before preparing anything else.'**
  String get depositApprovalReceiptReplaced;

  /// No description provided for @rebalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Rebalance collateral'**
  String get rebalanceTitle;

  /// No description provided for @rebalanceScope.
  ///
  /// In en, this message translates to:
  /// **'Use this when Multi-Assets Mode has a negative USDT wallet balance. Aster decides the asset conversion; this request has no amount or price parameter. Read the account before reviewing.'**
  String get rebalanceScope;

  /// No description provided for @rebalanceRisk.
  ///
  /// In en, this message translates to:
  /// **'This can convert account assets and change collateral. Conversion rates, costs and eligibility are determined by Aster; no conversion quote is available here. It does not withdraw funds or switch asset mode.'**
  String get rebalanceRisk;

  /// No description provided for @rebalanceRead.
  ///
  /// In en, this message translates to:
  /// **'Read / check current account'**
  String get rebalanceRead;

  /// No description provided for @rebalanceReadHint.
  ///
  /// In en, this message translates to:
  /// **'Each read asks for two account signatures. Confirmation reads the mode and balances again, then requests a separate API signature and two result checks. Nothing runs automatically.'**
  String get rebalanceReadHint;

  /// No description provided for @rebalanceReview.
  ///
  /// In en, this message translates to:
  /// **'Review Rebalance'**
  String get rebalanceReview;

  /// No description provided for @rebalanceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign and request Rebalance'**
  String get rebalanceConfirm;

  /// No description provided for @rebalanceCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get rebalanceCancel;

  /// No description provided for @rebalanceUsdt.
  ///
  /// In en, this message translates to:
  /// **'USDT wallet balance'**
  String get rebalanceUsdt;

  /// No description provided for @rebalanceUnknownUsdt.
  ///
  /// In en, this message translates to:
  /// **'USDT wallet balance is unavailable. Rebalance and switching to Single-Asset Mode remain blocked until a complete read.'**
  String get rebalanceUnknownUsdt;

  /// No description provided for @rebalanceNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'The current read does not show negative USDT in Multi-Assets Mode. No Rebalance request is available.'**
  String get rebalanceNotNeeded;

  /// No description provided for @rebalanceRequired.
  ///
  /// In en, this message translates to:
  /// **'Negative USDT must be handled before withdrawing or returning to Single-Asset Mode. Open Rebalance to review the current account; no action will run automatically.'**
  String get rebalanceRequired;

  /// No description provided for @rebalanceChanged.
  ///
  /// In en, this message translates to:
  /// **'The account, configuration or review expired or changed. Read and review again; no new request was sent.'**
  String get rebalanceChanged;

  /// No description provided for @rebalanceStale.
  ///
  /// In en, this message translates to:
  /// **'This account read is historical. Read again before reviewing.'**
  String get rebalanceStale;

  /// No description provided for @rebalanceStorage.
  ///
  /// In en, this message translates to:
  /// **'The Rebalance recovery record cannot be read or saved. New Rebalance requests, order submissions and contract setting changes are blocked until storage recovers.'**
  String get rebalanceStorage;

  /// No description provided for @rebalancePending.
  ///
  /// In en, this message translates to:
  /// **'This wallet has an unresolved Rebalance. Check the current account; the request will never be resent automatically.'**
  String get rebalancePending;

  /// No description provided for @rebalanceUnknown.
  ///
  /// In en, this message translates to:
  /// **'The original request result is unknown. Current balances cannot prove that request completed. The API has no documented lookup by nonce, so the record and mutation block remain. Do not repeat the request.'**
  String get rebalanceUnknown;

  /// No description provided for @rebalanceReplyPending.
  ///
  /// In en, this message translates to:
  /// **'The server response was saved. Read the current account to finish checking; this will not resend Rebalance.'**
  String get rebalanceReplyPending;

  /// No description provided for @rebalanceNoExchange.
  ///
  /// In en, this message translates to:
  /// **'The server returned an empty response: no asset exchange was reported. The current account is shown separately.'**
  String get rebalanceNoExchange;

  /// No description provided for @rebalanceReported.
  ///
  /// In en, this message translates to:
  /// **'The server reported an asset exchange. These are its returned balance and account reference, not a conversion quote or proof that all debt is cleared.'**
  String get rebalanceReported;

  /// No description provided for @rebalancePermission.
  ///
  /// In en, this message translates to:
  /// **'A fresh nonnegative USDT balance alone is not withdrawal permission or proof that Single-Asset Mode is allowed. Other account and platform checks still apply.'**
  String get rebalancePermission;

  /// No description provided for @rebalanceNonce.
  ///
  /// In en, this message translates to:
  /// **'Original request nonce'**
  String get rebalanceNonce;

  /// No description provided for @rebalanceAccountId.
  ///
  /// In en, this message translates to:
  /// **'Reported account ID'**
  String get rebalanceAccountId;

  /// No description provided for @rebalanceReportedBalance.
  ///
  /// In en, this message translates to:
  /// **'Reported balance'**
  String get rebalanceReportedBalance;

  /// No description provided for @rebalanceReportedTime.
  ///
  /// In en, this message translates to:
  /// **'Reported update time (UTC)'**
  String get rebalanceReportedTime;

  /// No description provided for @rebalanceCurrentMode.
  ///
  /// In en, this message translates to:
  /// **'Current asset mode'**
  String get rebalanceCurrentMode;

  /// No description provided for @rebalanceReading.
  ///
  /// In en, this message translates to:
  /// **'Reading current mode and balances…'**
  String get rebalanceReading;

  /// No description provided for @rebalanceSending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the signed request or account check…'**
  String get rebalanceSending;

  /// No description provided for @rebalanceRecovery.
  ///
  /// In en, this message translates to:
  /// **'Review Rebalance recovery'**
  String get rebalanceRecovery;

  /// No description provided for @liveOrderPricing.
  ///
  /// In en, this message translates to:
  /// **'Limit pricing'**
  String get liveOrderPricing;

  /// No description provided for @liveOrderPegHint.
  ///
  /// In en, this message translates to:
  /// **'Aster sets the price once from the selected best bid or ask: when placing a limit order, or when a conditional limit order triggers. It does not keep chasing the book. Estimates use the selected current bid or ask; the engine price and fill may differ, especially at a future trigger.'**
  String get liveOrderPegHint;

  /// No description provided for @liveOrderBbo.
  ///
  /// In en, this message translates to:
  /// **'BBO'**
  String get liveOrderBbo;

  /// No description provided for @liveOrderBboModeLabel.
  ///
  /// In en, this message translates to:
  /// **'BBO mode'**
  String get liveOrderBboModeLabel;

  /// No description provided for @liveOrderBboModeTitle.
  ///
  /// In en, this message translates to:
  /// **'BBO Mode'**
  String get liveOrderBboModeTitle;

  /// No description provided for @liveOrderBboModeHint.
  ///
  /// In en, this message translates to:
  /// **'Best-bid-offer places a limit order at the best bid or ask. Post-Only may fail if it immediately takes liquidity.'**
  String get liveOrderBboModeHint;

  /// No description provided for @liveOrderBboCounterparty.
  ///
  /// In en, this message translates to:
  /// **'Counterparty {depth}'**
  String liveOrderBboCounterparty(int depth);

  /// No description provided for @liveOrderBboQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue {depth}'**
  String liveOrderBboQueue(int depth);

  /// No description provided for @liveOrderPegInvalid.
  ///
  /// In en, this message translates to:
  /// **'BBO requires a limit order with no manual price. It cannot be combined with a market, trailing, entire-close or attached-strategy order. Post Only BBO supports same-side level 1 only.'**
  String get liveOrderPegInvalid;

  /// No description provided for @internalTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Spot ↔ Futures transfer'**
  String get internalTransferTitle;

  /// No description provided for @internalTransferScope.
  ///
  /// In en, this message translates to:
  /// **'Transfer the selected asset between your Aster Spot and Futures accounts using the current wallet.'**
  String get internalTransferScope;

  /// No description provided for @internalTransferReadHint.
  ///
  /// In en, this message translates to:
  /// **'Read both accounts and asset mode with 3 wallet signatures. Changing asset or direction reads them again. A full transfer normally needs 10 signatures, including confirmation checks and balance refresh.'**
  String get internalTransferReadHint;

  /// No description provided for @internalTransferRisk.
  ///
  /// In en, this message translates to:
  /// **'Moving collateral out of Futures can increase liquidation risk. Review the direction and amount before signing.'**
  String get internalTransferRisk;

  /// No description provided for @internalTransferDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get internalTransferDirection;

  /// No description provided for @internalTransferToFutures.
  ///
  /// In en, this message translates to:
  /// **'Spot → Futures'**
  String get internalTransferToFutures;

  /// No description provided for @internalTransferToSpot.
  ///
  /// In en, this message translates to:
  /// **'Futures → Spot'**
  String get internalTransferToSpot;

  /// No description provided for @internalTransferAsset.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get internalTransferAsset;

  /// No description provided for @internalTransferAmount.
  ///
  /// In en, this message translates to:
  /// **'Transfer amount'**
  String get internalTransferAmount;

  /// No description provided for @internalTransferMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get internalTransferMax;

  /// No description provided for @internalTransferRead.
  ///
  /// In en, this message translates to:
  /// **'Read transfer limits'**
  String get internalTransferRead;

  /// No description provided for @internalTransferReading.
  ///
  /// In en, this message translates to:
  /// **'Reading both accounts and asset mode…'**
  String get internalTransferReading;

  /// No description provided for @internalTransferSending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for signatures or the transfer result…'**
  String get internalTransferSending;

  /// No description provided for @internalTransferChecking.
  ///
  /// In en, this message translates to:
  /// **'Transfer reported successful. Reading both account balances…'**
  String get internalTransferChecking;

  /// No description provided for @internalTransferMaximum.
  ///
  /// In en, this message translates to:
  /// **'Source transferable amount'**
  String get internalTransferMaximum;

  /// No description provided for @internalTransferSpotFree.
  ///
  /// In en, this message translates to:
  /// **'Spot free amount'**
  String get internalTransferSpotFree;

  /// No description provided for @internalTransferFuturesWallet.
  ///
  /// In en, this message translates to:
  /// **'Futures wallet amount'**
  String get internalTransferFuturesWallet;

  /// No description provided for @internalTransferLimitHint.
  ///
  /// In en, this message translates to:
  /// **'The source limit is Spot free amount or the selected Futures asset’s maximum transferable amount. Max rounds down to the input step; Futures wallet amount is not a transfer limit.'**
  String get internalTransferLimitHint;

  /// No description provided for @internalTransferPrecisionHint.
  ///
  /// In en, this message translates to:
  /// **'Input precision follows the website policy: at most 8 decimal places, with a 2-place fallback. This is not the token’s on-chain precision.'**
  String get internalTransferPrecisionHint;

  /// No description provided for @internalTransferReview.
  ///
  /// In en, this message translates to:
  /// **'Review transfer'**
  String get internalTransferReview;

  /// No description provided for @internalTransferConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign and transfer once'**
  String get internalTransferConfirm;

  /// No description provided for @internalTransferStale.
  ///
  /// In en, this message translates to:
  /// **'Transfer data is stale. Read it again before reviewing.'**
  String get internalTransferStale;

  /// No description provided for @internalTransferChanged.
  ///
  /// In en, this message translates to:
  /// **'The wallet, balances, limits or asset mode changed, or the review expired. Read again and review the transfer.'**
  String get internalTransferChanged;

  /// No description provided for @internalTransferAssetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The selected asset is not in the supported transfer list.'**
  String get internalTransferAssetUnavailable;

  /// No description provided for @internalTransferPermission.
  ///
  /// In en, this message translates to:
  /// **'Transfer permission is unavailable: the source must allow withdrawals and the destination must allow deposits.'**
  String get internalTransferPermission;

  /// No description provided for @internalTransferMaximumUnknown.
  ///
  /// In en, this message translates to:
  /// **'The source transferable amount is missing. Transfer is unavailable until it can be read.'**
  String get internalTransferMaximumUnknown;

  /// No description provided for @internalTransferInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive amount using ordinary decimal notation.'**
  String get internalTransferInvalidAmount;

  /// No description provided for @internalTransferPrecision.
  ///
  /// In en, this message translates to:
  /// **'The amount exceeds this asset’s supported input precision.'**
  String get internalTransferPrecision;

  /// No description provided for @internalTransferTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The amount exceeds the source transferable amount.'**
  String get internalTransferTooLarge;

  /// No description provided for @internalTransferStorage.
  ///
  /// In en, this message translates to:
  /// **'Transfer recovery storage is unavailable. Retry reading storage before submitting new orders, settings or transfers.'**
  String get internalTransferStorage;

  /// No description provided for @internalTransferPending.
  ///
  /// In en, this message translates to:
  /// **'A previous transfer needs review. New transfers, orders and account settings are blocked.'**
  String get internalTransferPending;

  /// No description provided for @internalTransferUnknown.
  ///
  /// In en, this message translates to:
  /// **'The transfer outcome is unknown. The original client ID cannot be queried through a documented API. Balance changes do not prove completion. This record is retained and cannot be retried or cleared here; contact Aster with the original identifiers.'**
  String get internalTransferUnknown;

  /// No description provided for @internalTransferReplyPending.
  ///
  /// In en, this message translates to:
  /// **'Aster reported SUCCESS. Read both accounts to finish refreshing balances; do not resubmit the transfer.'**
  String get internalTransferReplyPending;

  /// No description provided for @internalTransferReported.
  ///
  /// In en, this message translates to:
  /// **'Aster reported transfer SUCCESS; both account balances were read again. This internal transfer is not an on-chain transaction.'**
  String get internalTransferReported;

  /// No description provided for @internalTransferClientId.
  ///
  /// In en, this message translates to:
  /// **'Original client transfer ID'**
  String get internalTransferClientId;

  /// No description provided for @internalTransferTransactionId.
  ///
  /// In en, this message translates to:
  /// **'Aster transfer ID'**
  String get internalTransferTransactionId;

  /// No description provided for @internalTransferEmpty.
  ///
  /// In en, this message translates to:
  /// **'No assets are currently available for transfer.'**
  String get internalTransferEmpty;

  /// No description provided for @internalTransferBlocked.
  ///
  /// In en, this message translates to:
  /// **'Another pending request or account operation blocks new transfers. Review recovery notices before continuing.'**
  String get internalTransferBlocked;

  /// No description provided for @spotOpenOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Spot open orders'**
  String get spotOpenOrdersTitle;

  /// No description provided for @spotOpenOrdersScope.
  ///
  /// In en, this message translates to:
  /// **'Read all current Spot orders with the current wallet. Counts and filters use this Spot snapshot; a Perp symbol is not a Spot query scope. No automatic signatures.'**
  String get spotOpenOrdersScope;

  /// No description provided for @spotOpenOrdersRead.
  ///
  /// In en, this message translates to:
  /// **'Read Spot open orders'**
  String get spotOpenOrdersRead;

  /// No description provided for @spotOpenOrdersRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh Spot open orders'**
  String get spotOpenOrdersRefresh;

  /// No description provided for @spotOpenOrdersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open Spot orders in this account.'**
  String get spotOpenOrdersEmpty;

  /// No description provided for @spotOpenOrdersNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No Spot orders match this filter.'**
  String get spotOpenOrdersNoMatch;

  /// No description provided for @spotOpenOrdersFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter by Spot symbol or order reference'**
  String get spotOpenOrdersFilter;

  /// No description provided for @spotOpenOrdersUnits.
  ///
  /// In en, this message translates to:
  /// **'Some Spot base/quote metadata could not be loaded. Amount units remain unknown until metadata is available.'**
  String get spotOpenOrdersUnits;

  /// No description provided for @spotOpenOrdersEvents.
  ///
  /// In en, this message translates to:
  /// **'Events update individual Spot orders after a signed baseline. Disconnection, missing events or stale data require another explicit read; events cannot prove a complete account list.'**
  String get spotOpenOrdersEvents;

  /// No description provided for @spotOpenOrdersQuantityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Base total unknown · quote-sized market order'**
  String get spotOpenOrdersQuantityUnknown;

  /// No description provided for @spotOpenOrdersQuoteQuantity.
  ///
  /// In en, this message translates to:
  /// **'Original quote amount'**
  String get spotOpenOrdersQuoteQuantity;

  /// No description provided for @spotOpenOrdersCapacity.
  ///
  /// In en, this message translates to:
  /// **'Too many Spot order events to retain safely. Live updates stopped; read a fresh baseline to inspect current orders.'**
  String get spotOpenOrdersCapacity;

  /// No description provided for @spotOpenOrdersPolicy.
  ///
  /// In en, this message translates to:
  /// **'Time in force'**
  String get spotOpenOrdersPolicy;

  /// No description provided for @assetYieldUsdf.
  ///
  /// In en, this message translates to:
  /// **'APY up to {percent}%'**
  String assetYieldUsdf(String percent);

  /// No description provided for @assetYieldAsbnb.
  ///
  /// In en, this message translates to:
  /// **'Reference APY {percent}%'**
  String assetYieldAsbnb(String percent);

  /// No description provided for @assetYieldUsdfScope.
  ///
  /// In en, this message translates to:
  /// **'Aster published base + trading APY. Trading requirements apply; this is not your realized return and is not added to balances.'**
  String get assetYieldUsdfScope;

  /// No description provided for @assetYieldAsbnbScope.
  ///
  /// In en, this message translates to:
  /// **'Lista published comprehensive APY for asBNB, including launchpool rewards. An estimate, not a guaranteed return or wallet balance.'**
  String get assetYieldAsbnbScope;

  /// No description provided for @assetYieldSourceDate.
  ///
  /// In en, this message translates to:
  /// **'Source date: {date}'**
  String assetYieldSourceDate(String date);

  /// No description provided for @assetYieldParts.
  ///
  /// In en, this message translates to:
  /// **'Base {base}% + trading {trade}%'**
  String assetYieldParts(String base, String trade);

  /// No description provided for @assetYieldUpdated.
  ///
  /// In en, this message translates to:
  /// **'Publisher updated (UTC): {time}'**
  String assetYieldUpdated(String time);

  /// No description provided for @assetYieldReadTime.
  ///
  /// In en, this message translates to:
  /// **'Read (UTC): {time}'**
  String assetYieldReadTime(String time);

  /// No description provided for @assetYieldStale.
  ///
  /// In en, this message translates to:
  /// **'Historical or unverified yield data. Refresh to check the latest published rate.'**
  String get assetYieldStale;

  /// No description provided for @assetYieldPaused.
  ///
  /// In en, this message translates to:
  /// **'Yield updates paused while the app is inactive.'**
  String get assetYieldPaused;

  /// No description provided for @assetYieldInvalid.
  ///
  /// In en, this message translates to:
  /// **'The yield source returned missing or inconsistent data. Retry to check again.'**
  String get assetYieldInvalid;

  /// No description provided for @assetYieldNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the yield source. Check your connection and retry.'**
  String get assetYieldNetwork;

  /// No description provided for @assetYieldFailed.
  ///
  /// In en, this message translates to:
  /// **'The yield source is unavailable. The previous quote is retained; retry to check again.'**
  String get assetYieldFailed;

  /// No description provided for @assetYieldLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading public yield data…'**
  String get assetYieldLoading;

  /// No description provided for @assetYieldRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh yield data'**
  String get assetYieldRefresh;

  /// No description provided for @pointsProgramTitle.
  ///
  /// In en, this message translates to:
  /// **'Vanta Genesis Points'**
  String get pointsProgramTitle;

  /// No description provided for @pointsProgramScope.
  ///
  /// In en, this message translates to:
  /// **'Published by Vanta for its Orderly broker program. These points are separate from Aster balances and trading; this app does not assume Aster activity qualifies for rewards.'**
  String get pointsProgramScope;

  /// No description provided for @pointsCurrentCampaign.
  ///
  /// In en, this message translates to:
  /// **'Current campaign'**
  String get pointsCurrentCampaign;

  /// No description provided for @pointsCycleNumber.
  ///
  /// In en, this message translates to:
  /// **'Campaign {number}'**
  String pointsCycleNumber(String number);

  /// No description provided for @pointsCycleId.
  ///
  /// In en, this message translates to:
  /// **'Campaign ID'**
  String get pointsCycleId;

  /// No description provided for @pointsStatus.
  ///
  /// In en, this message translates to:
  /// **'Published status'**
  String get pointsStatus;

  /// No description provided for @pointsStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get pointsStatusDraft;

  /// No description provided for @pointsStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get pointsStatusActive;

  /// No description provided for @pointsStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get pointsStatusEnded;

  /// No description provided for @pointsStatusSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get pointsStatusSettled;

  /// No description provided for @pointsStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get pointsStatusUnknown;

  /// No description provided for @pointsPool.
  ///
  /// In en, this message translates to:
  /// **'Total points pool'**
  String get pointsPool;

  /// No description provided for @pointsPeriodStart.
  ///
  /// In en, this message translates to:
  /// **'Start (UTC)'**
  String get pointsPeriodStart;

  /// No description provided for @pointsPeriodEnd.
  ///
  /// In en, this message translates to:
  /// **'End (UTC)'**
  String get pointsPeriodEnd;

  /// No description provided for @pointsBroker.
  ///
  /// In en, this message translates to:
  /// **'Broker ID'**
  String get pointsBroker;

  /// No description provided for @pointsNoCurrentCampaign.
  ///
  /// In en, this message translates to:
  /// **'No current campaign is published.'**
  String get pointsNoCurrentCampaign;

  /// No description provided for @pointsNotRead.
  ///
  /// In en, this message translates to:
  /// **'No verified data yet.'**
  String get pointsNotRead;

  /// No description provided for @pointsLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading points data…'**
  String get pointsLoading;

  /// No description provided for @pointsPaused.
  ///
  /// In en, this message translates to:
  /// **'Updates paused while the app is inactive.'**
  String get pointsPaused;

  /// No description provided for @pointsStale.
  ///
  /// In en, this message translates to:
  /// **'This is an older or incomplete snapshot. Refresh to check the current data.'**
  String get pointsStale;

  /// No description provided for @pointsReadTime.
  ///
  /// In en, this message translates to:
  /// **'Read (UTC): {time}'**
  String pointsReadTime(String time);

  /// No description provided for @pointsDataInvalid.
  ///
  /// In en, this message translates to:
  /// **'The points service returned missing or inconsistent data. Previous data is retained.'**
  String get pointsDataInvalid;

  /// No description provided for @pointsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the points service. Check your connection and retry.'**
  String get pointsNetwork;

  /// No description provided for @pointsRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The points service is rate limiting requests. Try again later.'**
  String get pointsRateLimited;

  /// No description provided for @pointsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The points service is unavailable. Previous data is retained; try again later.'**
  String get pointsUnavailable;

  /// No description provided for @pointsWalletRequired.
  ///
  /// In en, this message translates to:
  /// **'Connect a wallet to read its published points. No personal score is assumed before a successful read.'**
  String get pointsWalletRequired;

  /// No description provided for @pointsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh this section'**
  String get pointsRefresh;

  /// No description provided for @pointsStop.
  ///
  /// In en, this message translates to:
  /// **'Stop waiting'**
  String get pointsStop;

  /// No description provided for @pointsLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Points leaderboard'**
  String get pointsLeaderboard;

  /// No description provided for @pointsLeaderboardScope.
  ///
  /// In en, this message translates to:
  /// **'Shows up to the first 100 returned rows, 20 per page, with ranks reported by the service. Absence does not establish a full ranking or zero points.'**
  String get pointsLeaderboardScope;

  /// No description provided for @pointsSelectLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard scope'**
  String get pointsSelectLeaderboard;

  /// No description provided for @pointsTotalLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Total points leaderboard'**
  String get pointsTotalLeaderboard;

  /// No description provided for @pointsNoRankings.
  ///
  /// In en, this message translates to:
  /// **'No ranking rows were returned for this scope.'**
  String get pointsNoRankings;

  /// No description provided for @pointsReturnedCount.
  ///
  /// In en, this message translates to:
  /// **'Showing {count} returned ranking row(s).'**
  String pointsReturnedCount(int count);

  /// No description provided for @pointsPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get pointsPrevious;

  /// No description provided for @pointsNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get pointsNext;

  /// No description provided for @pointsPageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String pointsPageNumber(int page, int pages);

  /// No description provided for @pointsRankNumber.
  ///
  /// In en, this message translates to:
  /// **'Rank #{number}'**
  String pointsRankNumber(String number);

  /// No description provided for @pointsScore.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get pointsScore;

  /// No description provided for @pointsSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled points'**
  String get pointsSettled;

  /// No description provided for @pointsSpecial.
  ///
  /// In en, this message translates to:
  /// **'Special points'**
  String get pointsSpecial;

  /// No description provided for @pointsCurrentScore.
  ///
  /// In en, this message translates to:
  /// **'Current campaign points (as reported)'**
  String get pointsCurrentScore;

  /// No description provided for @pointsMyPoints.
  ///
  /// In en, this message translates to:
  /// **'My points'**
  String get pointsMyPoints;

  /// No description provided for @pointsWalletReadScope.
  ///
  /// In en, this message translates to:
  /// **'Read sends this wallet address to Vanta’s points service without a signature. It does not change the active Aster account.'**
  String get pointsWalletReadScope;

  /// No description provided for @pointsConnectWallet.
  ///
  /// In en, this message translates to:
  /// **'Connect wallet'**
  String get pointsConnectWallet;

  /// No description provided for @pointsMyTotal.
  ///
  /// In en, this message translates to:
  /// **'My total points'**
  String get pointsMyTotal;

  /// No description provided for @pointsRankUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not found in the returned total leaderboard; the full rank is unknown.'**
  String get pointsRankUnknown;

  /// No description provided for @pointsReadWallet.
  ///
  /// In en, this message translates to:
  /// **'Read my points and history'**
  String get pointsReadWallet;

  /// No description provided for @pointsSelectHistory.
  ///
  /// In en, this message translates to:
  /// **'Past points scope'**
  String get pointsSelectHistory;

  /// No description provided for @pointsAccumulated.
  ///
  /// In en, this message translates to:
  /// **'Accumulated points'**
  String get pointsAccumulated;

  /// No description provided for @pointsSelectedHistory.
  ///
  /// In en, this message translates to:
  /// **'Points in selected scope'**
  String get pointsSelectedHistory;

  /// No description provided for @pointsNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No campaign history was returned. Missing campaign rows remain unknown.'**
  String get pointsNoHistory;

  /// No description provided for @eventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trading events'**
  String get eventsTitle;

  /// No description provided for @eventsScope.
  ///
  /// In en, this message translates to:
  /// **'Vanta Orderly campaigns. Registration, trading volume and rewards belong to this program; Aster trades in this app are not assumed eligible.'**
  String get eventsScope;

  /// No description provided for @eventsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No published trading events.'**
  String get eventsEmpty;

  /// No description provided for @eventsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} published events'**
  String eventsCount(int count);

  /// No description provided for @eventDetails.
  ///
  /// In en, this message translates to:
  /// **'Event details'**
  String get eventDetails;

  /// No description provided for @eventRegistrationOpen.
  ///
  /// In en, this message translates to:
  /// **'Registration open'**
  String get eventRegistrationOpen;

  /// No description provided for @eventImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Event image unavailable'**
  String get eventImageUnavailable;

  /// No description provided for @eventLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this link. Please try again.'**
  String get eventLinkFailed;

  /// No description provided for @eventOwnVolume.
  ///
  /// In en, this message translates to:
  /// **'Your trading volume (USDC)'**
  String get eventOwnVolume;

  /// No description provided for @eventRankingScope.
  ///
  /// In en, this message translates to:
  /// **'Up to 30 returned participants, 10 per page. Ranks and USDC trading volumes come from Vanta; this is not the complete ranking.'**
  String get eventRankingScope;

  /// No description provided for @eventMyParticipation.
  ///
  /// In en, this message translates to:
  /// **'My participation'**
  String get eventMyParticipation;

  /// No description provided for @eventPersonalScope.
  ///
  /// In en, this message translates to:
  /// **'Refresh sends this EVM wallet address to Vanta to check registration and performance, without signing.'**
  String get eventPersonalScope;

  /// No description provided for @eventRegistrationUnknownStatus.
  ///
  /// In en, this message translates to:
  /// **'Registration has not been checked.'**
  String get eventRegistrationUnknownStatus;

  /// No description provided for @eventRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registration verified'**
  String get eventRegistered;

  /// No description provided for @eventNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'Not registered at the last check'**
  String get eventNotRegistered;

  /// No description provided for @eventBlockedBlacklist.
  ///
  /// In en, this message translates to:
  /// **'This address is excluded by the campaign’s eligibility rules.'**
  String get eventBlockedBlacklist;

  /// No description provided for @eventBlockedExclusive.
  ///
  /// In en, this message translates to:
  /// **'Already registered for an exclusive event: {name}'**
  String eventBlockedExclusive(String name);

  /// No description provided for @eventAnotherCampaign.
  ///
  /// In en, this message translates to:
  /// **'another event'**
  String get eventAnotherCampaign;

  /// No description provided for @eventBlocked.
  ///
  /// In en, this message translates to:
  /// **'Registration is unavailable for this address.'**
  String get eventBlocked;

  /// No description provided for @eventRegistrationReadFirst.
  ///
  /// In en, this message translates to:
  /// **'Refresh registration status before joining. Current campaign rules will be checked again before submission.'**
  String get eventRegistrationReadFirst;

  /// No description provided for @eventRegistrationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm registration'**
  String get eventRegistrationConfirm;

  /// No description provided for @eventRegistrationSigningScope.
  ///
  /// In en, this message translates to:
  /// **'Sign a registration message with this wallet for Vanta. This does not transfer funds, place an order or guarantee rewards.'**
  String get eventRegistrationSigningScope;

  /// No description provided for @eventCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get eventCancel;

  /// No description provided for @eventRegister.
  ///
  /// In en, this message translates to:
  /// **'Register now'**
  String get eventRegister;

  /// No description provided for @eventChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking current campaign and registration…'**
  String get eventChecking;

  /// No description provided for @eventSigning.
  ///
  /// In en, this message translates to:
  /// **'Confirm the registration message in your wallet…'**
  String get eventSigning;

  /// No description provided for @eventSending.
  ///
  /// In en, this message translates to:
  /// **'Submitting registration…'**
  String get eventSending;

  /// No description provided for @eventAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Vanta accepted the request. Refresh to verify registration; rewards are not confirmed.'**
  String get eventAcknowledged;

  /// No description provided for @eventRegistrationUnknown.
  ///
  /// In en, this message translates to:
  /// **'The registration result is unknown. Refresh registration status before trying again; this app will not resend automatically.'**
  String get eventRegistrationUnknown;

  /// No description provided for @eventRegistrationChanged.
  ///
  /// In en, this message translates to:
  /// **'The wallet, campaign rules or registration eligibility changed. Refresh and review again.'**
  String get eventRegistrationChanged;

  /// No description provided for @eventWalletReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect this wallet before signing the registration message.'**
  String get eventWalletReconnect;

  /// No description provided for @eventSignatureRejected.
  ///
  /// In en, this message translates to:
  /// **'The wallet declined the registration message.'**
  String get eventSignatureRejected;

  /// No description provided for @eventSignatureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The wallet could not sign this registration message. Please reconnect and try again.'**
  String get eventSignatureUnavailable;

  /// No description provided for @eventRegistrationCount.
  ///
  /// In en, this message translates to:
  /// **'Registered participants'**
  String get eventRegistrationCount;

  /// No description provided for @eventTotalVolume.
  ///
  /// In en, this message translates to:
  /// **'Total event trading volume (USDC)'**
  String get eventTotalVolume;

  /// No description provided for @eventRewardPool.
  ///
  /// In en, this message translates to:
  /// **'Core reward pool'**
  String get eventRewardPool;

  /// No description provided for @eventActivityRules.
  ///
  /// In en, this message translates to:
  /// **'Activity rules'**
  String get eventActivityRules;

  /// No description provided for @eventCampaignRules.
  ///
  /// In en, this message translates to:
  /// **'Campaign rules'**
  String get eventCampaignRules;

  /// No description provided for @eventEnded.
  ///
  /// In en, this message translates to:
  /// **'Event ended'**
  String get eventEnded;

  /// No description provided for @eventCountdown.
  ///
  /// In en, this message translates to:
  /// **'{stage}: {days}d {hours}:{minutes}:{seconds}'**
  String eventCountdown(String stage, String days, String hours, String minutes, String seconds);

  /// No description provided for @eventUntilEnd.
  ///
  /// In en, this message translates to:
  /// **'Time until end'**
  String get eventUntilEnd;

  /// No description provided for @eventUntilStart.
  ///
  /// In en, this message translates to:
  /// **'Time until start'**
  String get eventUntilStart;

  /// No description provided for @eventRegistrationOpens.
  ///
  /// In en, this message translates to:
  /// **'Registration opens (UTC)'**
  String get eventRegistrationOpens;

  /// No description provided for @eventTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get eventTasks;

  /// No description provided for @eventNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks published.'**
  String get eventNoTasks;

  /// No description provided for @eventTaskTarget.
  ///
  /// In en, this message translates to:
  /// **'Published target'**
  String get eventTaskTarget;

  /// No description provided for @eventTaskProgress.
  ///
  /// In en, this message translates to:
  /// **'Verified progress'**
  String get eventTaskProgress;

  /// No description provided for @eventTaskUnknown.
  ///
  /// In en, this message translates to:
  /// **'Task progress has not been verified.'**
  String get eventTaskUnknown;

  /// No description provided for @eventTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Published target reached; rewards remain subject to campaign rules.'**
  String get eventTaskCompleted;

  /// No description provided for @eventTaskPending.
  ///
  /// In en, this message translates to:
  /// **'Target not yet reached'**
  String get eventTaskPending;

  /// No description provided for @eventOpenTrading.
  ///
  /// In en, this message translates to:
  /// **'Trade on Vanta website'**
  String get eventOpenTrading;

  /// No description provided for @eventTradingEligibility.
  ///
  /// In en, this message translates to:
  /// **'Registration and the active event period are required before trading for this campaign.'**
  String get eventTradingEligibility;

  /// No description provided for @eventRankingVolume.
  ///
  /// In en, this message translates to:
  /// **'Trading volume (USDC)'**
  String get eventRankingVolume;

  /// No description provided for @eventIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Event ID'**
  String get eventIdLabel;

  /// No description provided for @eventMyRank.
  ///
  /// In en, this message translates to:
  /// **'My campaign rank'**
  String get eventMyRank;

  /// No description provided for @authorizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Aster trading authorization'**
  String get authorizationTitle;

  /// No description provided for @authorizationScope.
  ///
  /// In en, this message translates to:
  /// **'Authorize a device signing key for the connected account. Account queries and trading requests use this key without repeated wallet prompts. Aster validates the grant.'**
  String get authorizationScope;

  /// No description provided for @authorizationEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable trading with this wallet'**
  String get authorizationEnable;

  /// No description provided for @authorizationCheck.
  ///
  /// In en, this message translates to:
  /// **'Check signed API access'**
  String get authorizationCheck;

  /// No description provided for @authorizationCheckScope.
  ///
  /// In en, this message translates to:
  /// **'Read Futures and Spot accounts with the device agent. This sends no orders. Accepted reads do not prove trading permissions.'**
  String get authorizationCheckScope;

  /// No description provided for @authorizationReview.
  ///
  /// In en, this message translates to:
  /// **'Review authorization'**
  String get authorizationReview;

  /// No description provided for @authorizationGrant.
  ///
  /// In en, this message translates to:
  /// **'Signer: device agent. Spot and Futures trading: allowed. Withdrawal: not granted. Valid for 30 days. No builder or fee grant.'**
  String get authorizationGrant;

  /// No description provided for @authorizationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm and sign authorization'**
  String get authorizationConfirm;

  /// No description provided for @authorizationAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Aster acknowledged the request. Run the access check to confirm what this wallet can read and the reported trading status.'**
  String get authorizationAcknowledged;

  /// No description provided for @authorizationUnknown.
  ///
  /// In en, this message translates to:
  /// **'The authorization result is unknown. Check access before making another explicit request.'**
  String get authorizationUnknown;

  /// No description provided for @authorizationFuturesRead.
  ///
  /// In en, this message translates to:
  /// **'Futures signed API read'**
  String get authorizationFuturesRead;

  /// No description provided for @authorizationSpotRead.
  ///
  /// In en, this message translates to:
  /// **'Spot signed API read'**
  String get authorizationSpotRead;

  /// No description provided for @authorizationReadAccepted.
  ///
  /// In en, this message translates to:
  /// **'Signed read accepted for this wallet'**
  String get authorizationReadAccepted;

  /// No description provided for @authorizationCanTrade.
  ///
  /// In en, this message translates to:
  /// **'Account reports canTrade = true. This does not prove order execution or all agent permissions.'**
  String get authorizationCanTrade;

  /// No description provided for @authorizationCannotTrade.
  ///
  /// In en, this message translates to:
  /// **'Account reports canTrade = false'**
  String get authorizationCannotTrade;

  /// No description provided for @authorizationPermissionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Account trading permission is unknown'**
  String get authorizationPermissionUnknown;

  /// No description provided for @authorizationSpotPermissionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Spot read acceptance does not confirm permission to place Spot orders.'**
  String get authorizationSpotPermissionUnknown;

  /// No description provided for @subaccountActions.
  ///
  /// In en, this message translates to:
  /// **'Manage subaccounts'**
  String get subaccountActions;

  /// No description provided for @subaccountActionsScope.
  ///
  /// In en, this message translates to:
  /// **'Manage linked accounts using the connected master wallet. Generated subaccount keys are kept in device secure storage.'**
  String get subaccountActionsScope;

  /// No description provided for @subaccountCreate.
  ///
  /// In en, this message translates to:
  /// **'Create subaccount'**
  String get subaccountCreate;

  /// No description provided for @subaccountCreateExternalOnly.
  ///
  /// In en, this message translates to:
  /// **'Only accounts signed in with an external EOA wallet can create subaccounts. Privy embedded wallets cannot create subaccounts.'**
  String get subaccountCreateExternalOnly;

  /// No description provided for @subaccountFreeze.
  ///
  /// In en, this message translates to:
  /// **'Freeze subaccount'**
  String get subaccountFreeze;

  /// No description provided for @subaccountUnfreeze.
  ///
  /// In en, this message translates to:
  /// **'Unfreeze subaccount'**
  String get subaccountUnfreeze;

  /// No description provided for @subaccountTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer between master and child'**
  String get subaccountTransfer;

  /// No description provided for @subaccountChildAddress.
  ///
  /// In en, this message translates to:
  /// **'Child wallet address'**
  String get subaccountChildAddress;

  /// No description provided for @subaccountName.
  ///
  /// In en, this message translates to:
  /// **'Subaccount name'**
  String get subaccountName;

  /// No description provided for @subaccountFrom.
  ///
  /// In en, this message translates to:
  /// **'Source wallet'**
  String get subaccountFrom;

  /// No description provided for @subaccountTo.
  ///
  /// In en, this message translates to:
  /// **'Destination wallet'**
  String get subaccountTo;

  /// No description provided for @subaccountTransferDirection.
  ///
  /// In en, this message translates to:
  /// **'Market direction'**
  String get subaccountTransferDirection;

  /// No description provided for @subaccountMasterToChild.
  ///
  /// In en, this message translates to:
  /// **'Master → Child'**
  String get subaccountMasterToChild;

  /// No description provided for @subaccountChildToMaster.
  ///
  /// In en, this message translates to:
  /// **'Child → Master'**
  String get subaccountChildToMaster;

  /// No description provided for @subaccountTransferScope.
  ///
  /// In en, this message translates to:
  /// **'Only master/child addresses are supported. Aster validates the relationship, freeze status, available funds and asset precision at submission. Available child funds are not supplied by the directory.'**
  String get subaccountTransferScope;

  /// No description provided for @subaccountActionPrepare.
  ///
  /// In en, this message translates to:
  /// **'Read qualification and prepare'**
  String get subaccountActionPrepare;

  /// No description provided for @subaccountActionReview.
  ///
  /// In en, this message translates to:
  /// **'Review account operation'**
  String get subaccountActionReview;

  /// No description provided for @subaccountActionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm and sign submission'**
  String get subaccountActionConfirm;

  /// No description provided for @subaccountReviewExpires.
  ///
  /// In en, this message translates to:
  /// **'This review expires after 45 seconds. Expiry requires preparing and signing again.'**
  String get subaccountReviewExpires;

  /// No description provided for @subaccountChildSignatureInstructions.
  ///
  /// In en, this message translates to:
  /// **'Use a wallet you already control. Copy this EIP-712 request and sign it with the child wallet using a trusted wallet tool, then paste only the resulting signature. The app verifies the child address before asking the master to sign. Never enter a private key or seed phrase.'**
  String get subaccountChildSignatureInstructions;

  /// No description provided for @subaccountCopyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Copy child signing request'**
  String get subaccountCopyChallenge;

  /// No description provided for @subaccountChildSignature.
  ///
  /// In en, this message translates to:
  /// **'Child signature (hex)'**
  String get subaccountChildSignature;

  /// No description provided for @subaccountKnownAddresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses from acknowledged creation requests'**
  String get subaccountKnownAddresses;

  /// No description provided for @subaccountSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch wallet account'**
  String get subaccountSwitch;

  /// No description provided for @subaccountSwitchScope.
  ///
  /// In en, this message translates to:
  /// **'Connect the selected wallet to switch accounts. If the connection is declined, your current account remains active.'**
  String get subaccountSwitchScope;

  /// No description provided for @subaccountMasterRequired.
  ///
  /// In en, this message translates to:
  /// **'Aster did not return a valid master-account directory for this wallet.'**
  String get subaccountMasterRequired;

  /// No description provided for @subaccountLimitReached.
  ///
  /// In en, this message translates to:
  /// **'This master already has ten subaccounts.'**
  String get subaccountLimitReached;

  /// No description provided for @subaccountInputInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the child address, name, asset and positive amount (up to 18 decimal places). Master and child must differ.'**
  String get subaccountInputInvalid;

  /// No description provided for @subaccountChildSignatureInvalid.
  ///
  /// In en, this message translates to:
  /// **'The child signature does not match this address and signing request.'**
  String get subaccountChildSignatureInvalid;

  /// No description provided for @walletOperationHistory.
  ///
  /// In en, this message translates to:
  /// **'Saved account and funding requests'**
  String get walletOperationHistory;

  /// No description provided for @walletOperationReload.
  ///
  /// In en, this message translates to:
  /// **'Reload saved requests'**
  String get walletOperationReload;

  /// No description provided for @walletOperationReference.
  ///
  /// In en, this message translates to:
  /// **'Request nonce'**
  String get walletOperationReference;

  /// No description provided for @walletOperationStorage.
  ///
  /// In en, this message translates to:
  /// **'Saved request storage is unavailable. New submissions are blocked; retry loading storage.'**
  String get walletOperationStorage;

  /// No description provided for @walletOperationPending.
  ///
  /// In en, this message translates to:
  /// **'An earlier request from this wallet has an unknown result. Do not submit it again. Resolve it with Aster before another submission.'**
  String get walletOperationPending;

  /// No description provided for @walletOperationUnknown.
  ///
  /// In en, this message translates to:
  /// **'The request may have been accepted. Its result is unknown and its unsigned terms remain saved. No automatic retry will be sent.'**
  String get walletOperationUnknown;

  /// No description provided for @walletOperationAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Aster acknowledged this request. This is not a fresh status, balance or on-chain confirmation.'**
  String get walletOperationAcknowledged;

  /// No description provided for @withdrawalSubmit.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdrawalSubmit;

  /// No description provided for @withdrawalScope.
  ///
  /// In en, this message translates to:
  /// **'Withdraw to this wallet’s own registered address. A fresh signed master-account directory, withdrawal limits and fee estimate are required. Spot and Futures balances remain separate.'**
  String get withdrawalScope;

  /// No description provided for @withdrawalPrepare.
  ///
  /// In en, this message translates to:
  /// **'Check limits and prepare withdrawal'**
  String get withdrawalPrepare;

  /// No description provided for @withdrawalReview.
  ///
  /// In en, this message translates to:
  /// **'Review withdrawal'**
  String get withdrawalReview;

  /// No description provided for @withdrawalFee.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal fee (asset units)'**
  String get withdrawalFee;

  /// No description provided for @withdrawalMarket.
  ///
  /// In en, this message translates to:
  /// **'Source account'**
  String get withdrawalMarket;

  /// No description provided for @withdrawalChain.
  ///
  /// In en, this message translates to:
  /// **'Destination chain ID'**
  String get withdrawalChain;

  /// No description provided for @withdrawalReceiver.
  ///
  /// In en, this message translates to:
  /// **'Receiving address'**
  String get withdrawalReceiver;

  /// No description provided for @withdrawalConfirmScope.
  ///
  /// In en, this message translates to:
  /// **'Confirmation refreshes qualification, limits and fees, then requests a business signature and an API signature. A changed fee requires a new review. Amount plus fee is checked conservatively against the reported limits. No request is resent after an unknown result.'**
  String get withdrawalConfirmScope;

  /// No description provided for @withdrawalConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm withdrawal and sign'**
  String get withdrawalConfirm;

  /// No description provided for @withdrawalAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Aster returned a withdrawal request ID. Check history for completion; the returned signature digest is not a transaction hash.'**
  String get withdrawalAcknowledged;

  /// No description provided for @withdrawalAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive amount within the selected token precision and a supported automatic withdrawal route.'**
  String get withdrawalAmountInvalid;

  /// No description provided for @withdrawalAssetChanged.
  ///
  /// In en, this message translates to:
  /// **'Asset availability, contract or precision changed. Reload the asset list and prepare again.'**
  String get withdrawalAssetChanged;

  /// No description provided for @withdrawalFeeChanged.
  ///
  /// In en, this message translates to:
  /// **'The fee changed. Prepare a new review before signing.'**
  String get withdrawalFeeChanged;

  /// No description provided for @withdrawalLimitsUnknown.
  ///
  /// In en, this message translates to:
  /// **'A required withdrawal limit or asset USD price is unavailable. Submission is blocked.'**
  String get withdrawalLimitsUnknown;

  /// No description provided for @withdrawalLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Amount plus fee exceeds a reported asset, chain or USD limit.'**
  String get withdrawalLimitExceeded;

  /// No description provided for @withdrawalRecovery.
  ///
  /// In en, this message translates to:
  /// **'Check withdrawal completion'**
  String get withdrawalRecovery;

  /// No description provided for @withdrawalRecoveryScope.
  ///
  /// In en, this message translates to:
  /// **'Read signed history and match the exact returned request ID, account, chain, asset and amount. A request without a returned ID cannot be resolved from a balance change or a similar history row.'**
  String get withdrawalRecoveryScope;

  /// No description provided for @withdrawalOpenHistory.
  ///
  /// In en, this message translates to:
  /// **'Open and refresh signed history'**
  String get withdrawalOpenHistory;

  /// No description provided for @withdrawalNotReconciled.
  ///
  /// In en, this message translates to:
  /// **'No exact matching completion record has been read.'**
  String get withdrawalNotReconciled;

  /// No description provided for @withdrawalHistoryStale.
  ///
  /// In en, this message translates to:
  /// **'The matching history snapshot is historical; refresh to confirm current status.'**
  String get withdrawalHistoryStale;

  /// No description provided for @withdrawalProcessing.
  ///
  /// In en, this message translates to:
  /// **'Aster reports this withdrawal is processing.'**
  String get withdrawalProcessing;

  /// No description provided for @withdrawalCompleted.
  ///
  /// In en, this message translates to:
  /// **'Aster reports this withdrawal completed.'**
  String get withdrawalCompleted;

  /// No description provided for @withdrawalFailed.
  ///
  /// In en, this message translates to:
  /// **'Aster reports this withdrawal failed.'**
  String get withdrawalFailed;

  /// No description provided for @depositSubmissionScope.
  ///
  /// In en, this message translates to:
  /// **'Submit depositFor from this wallet to its own Spot or Futures account. Each transaction is reviewed and signed separately. Approval is a separate step.'**
  String get depositSubmissionScope;

  /// No description provided for @depositPlatformLimitsUnknown.
  ///
  /// In en, this message translates to:
  /// **'User and platform remaining deposit caps require Aster website login and are unavailable here. They are unknown, not unlimited. Verify current availability and caps on Aster before proceeding. Gas estimation does not prove platform credit.'**
  String get depositPlatformLimitsUnknown;

  /// No description provided for @depositLimitsAcknowledgement.
  ///
  /// In en, this message translates to:
  /// **'I checked current deposit availability and limits on Aster for this amount.'**
  String get depositLimitsAcknowledgement;

  /// No description provided for @depositSubmissionPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare deposit transaction'**
  String get depositSubmissionPrepare;

  /// No description provided for @depositSubmissionReview.
  ///
  /// In en, this message translates to:
  /// **'Review deposit transaction'**
  String get depositSubmissionReview;

  /// No description provided for @depositSubmissionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm deposit and open wallet'**
  String get depositSubmissionConfirm;

  /// No description provided for @depositSubmissionSent.
  ///
  /// In en, this message translates to:
  /// **'Transaction response saved. Open recovery to check the chain and platform credit. A wallet response does not prove completion.'**
  String get depositSubmissionSent;

  /// No description provided for @depositSubmissionRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recover pending deposit'**
  String get depositSubmissionRecovery;

  /// No description provided for @depositSubmissionRecoveryScope.
  ///
  /// In en, this message translates to:
  /// **'Check the original or matching replacement transaction and its canonical receipt. Chain success stays pending until signed Aster history matches the transaction hash, account, chain, asset and exact amount with SUCCESS. No automatic resend or deletion of unknown requests.'**
  String get depositSubmissionRecoveryScope;

  /// No description provided for @depositSubmissionStorage.
  ///
  /// In en, this message translates to:
  /// **'Deposit recovery storage is unavailable. New deposits are blocked; reload saved records.'**
  String get depositSubmissionStorage;

  /// No description provided for @depositSubmissionPending.
  ///
  /// In en, this message translates to:
  /// **'A deposit from this wallet still needs chain or platform confirmation.'**
  String get depositSubmissionPending;

  /// No description provided for @depositSubmissionNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending deposit for this wallet.'**
  String get depositSubmissionNoPending;

  /// No description provided for @depositSubmissionUnknown.
  ///
  /// In en, this message translates to:
  /// **'The wallet may have submitted the transaction. Keep the saved record and recover its status before another deposit.'**
  String get depositSubmissionUnknown;

  /// No description provided for @depositSubmissionChanged.
  ///
  /// In en, this message translates to:
  /// **'Balance, allowance, transaction or Gas changed. Prepare and review again.'**
  String get depositSubmissionChanged;

  /// No description provided for @depositSubmissionApprovalNeeded.
  ///
  /// In en, this message translates to:
  /// **'ERC-20 allowance is insufficient. Complete and verify the separate approval step first.'**
  String get depositSubmissionApprovalNeeded;

  /// No description provided for @depositSubmissionHashNeeded.
  ///
  /// In en, this message translates to:
  /// **'Read and bind a matching transaction hash before checking platform credit.'**
  String get depositSubmissionHashNeeded;

  /// No description provided for @depositSubmissionChainPending.
  ///
  /// In en, this message translates to:
  /// **'A matching successful chain receipt with at least two observed confirmations is required.'**
  String get depositSubmissionChainPending;

  /// No description provided for @depositSubmissionCreditPending.
  ///
  /// In en, this message translates to:
  /// **'Platform credit has not been confirmed by an exact SUCCESS record. The deposit remains saved.'**
  String get depositSubmissionCreditPending;

  /// No description provided for @depositSubmissionCheckChain.
  ///
  /// In en, this message translates to:
  /// **'Check chain receipt'**
  String get depositSubmissionCheckChain;

  /// No description provided for @depositSubmissionCheckCredit.
  ///
  /// In en, this message translates to:
  /// **'Sign and check platform credit'**
  String get depositSubmissionCheckCredit;

  /// No description provided for @depositSubmissionChainSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Chain transaction succeeded; platform credit is still unconfirmed.'**
  String get depositSubmissionChainSucceeded;

  /// No description provided for @depositSubmissionCredited.
  ///
  /// In en, this message translates to:
  /// **'Chain success and exact Aster SUCCESS deposit record were observed.'**
  String get depositSubmissionCredited;

  /// No description provided for @depositVerifiedMinimumScope.
  ///
  /// In en, this message translates to:
  /// **'The public catalog does not report a minimum. Enter the minimum in asset units after verifying it on Aster; enter 0 only if Aster explicitly reports no positive minimum. This is your external check, not a value read by the app.'**
  String get depositVerifiedMinimumScope;

  /// No description provided for @depositVerifiedMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum verified on Aster (asset units)'**
  String get depositVerifiedMinimum;

  /// No description provided for @depositTransactionBusy.
  ///
  /// In en, this message translates to:
  /// **'Another approval or deposit wallet request is still active. Wait for it to finish before submitting.'**
  String get depositTransactionBusy;

  /// No description provided for @subaccountSwitchEntered.
  ///
  /// In en, this message translates to:
  /// **'Switch to entered wallet address'**
  String get subaccountSwitchEntered;

  /// No description provided for @authorizationWithdrawOption.
  ///
  /// In en, this message translates to:
  /// **'Also request withdrawal permission'**
  String get authorizationWithdrawOption;

  /// No description provided for @authorizationWithdrawScope.
  ///
  /// In en, this message translates to:
  /// **'Aster requires a nonempty IP/CIDR whitelist for this permission. Only use verified wallet/API egress IPs; a mobile network IP may change. This grant does not submit a withdrawal.'**
  String get authorizationWithdrawScope;

  /// No description provided for @authorizationIpWhitelist.
  ///
  /// In en, this message translates to:
  /// **'IP/CIDR whitelist (space separated)'**
  String get authorizationIpWhitelist;

  /// No description provided for @authorizationWithdrawGrant.
  ///
  /// In en, this message translates to:
  /// **'Signer: same wallet. Spot trading, Futures trading and withdrawal: allowed. IP restricted as shown. Valid for 30 days. No builder or fee grant.'**
  String get authorizationWithdrawGrant;

  /// No description provided for @authorizationCanWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Account reports canWithdraw = true; this does not confirm every agent/IP permission or a completed withdrawal.'**
  String get authorizationCanWithdraw;

  /// No description provided for @authorizationCannotWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Account reports canWithdraw = false'**
  String get authorizationCannotWithdraw;

  /// No description provided for @authorizationWithdrawUnknown.
  ///
  /// In en, this message translates to:
  /// **'Account withdrawal permission is unknown'**
  String get authorizationWithdrawUnknown;

  /// No description provided for @authorizationIpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter 1–16 valid literal IP addresses or CIDRs, separated by spaces. Withdrawal permission requires a nonempty whitelist.'**
  String get authorizationIpInvalid;

  /// No description provided for @assetMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Asset details'**
  String get assetMetadataTitle;

  /// No description provided for @assetMetadataRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh asset names and icons'**
  String get assetMetadataRefresh;

  /// No description provided for @assetMetadataNamesFailed.
  ///
  /// In en, this message translates to:
  /// **'Asset names could not be refreshed. Asset identifiers remain available.'**
  String get assetMetadataNamesFailed;

  /// No description provided for @assetMetadataIconsFailed.
  ///
  /// In en, this message translates to:
  /// **'Asset icons could not be refreshed. Balances remain available.'**
  String get assetMetadataIconsFailed;

  /// No description provided for @assetMetadataStale.
  ///
  /// In en, this message translates to:
  /// **'Showing previously loaded asset details. Refresh to check for updates.'**
  String get assetMetadataStale;

  /// No description provided for @assetMetadataPaused.
  ///
  /// In en, this message translates to:
  /// **'Asset detail refresh is paused while the app is inactive.'**
  String get assetMetadataPaused;

  /// No description provided for @assetMetadataEmpty.
  ///
  /// In en, this message translates to:
  /// **'No additional asset details are available.'**
  String get assetMetadataEmpty;

  /// No description provided for @assetMetadataNoIcon.
  ///
  /// In en, this message translates to:
  /// **'Asset icon unavailable'**
  String get assetMetadataNoIcon;

  /// No description provided for @assetMetadataRetryIcon.
  ///
  /// In en, this message translates to:
  /// **'Reload asset icon'**
  String get assetMetadataRetryIcon;

  /// No description provided for @eventRetailTab.
  ///
  /// In en, this message translates to:
  /// **'Trading events'**
  String get eventRetailTab;

  /// No description provided for @eventChannelTab.
  ///
  /// In en, this message translates to:
  /// **'Channel events'**
  String get eventChannelTab;

  /// No description provided for @eventChannelName.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get eventChannelName;

  /// No description provided for @eventChannelRankingScope.
  ///
  /// In en, this message translates to:
  /// **'Channel ranking shows up to 10 entries; ranks outside this list remain unknown.'**
  String get eventChannelRankingScope;

  /// No description provided for @eventEngagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel task progress'**
  String get eventEngagementTitle;

  /// No description provided for @eventEngagementScope.
  ///
  /// In en, this message translates to:
  /// **'Manual refresh shares your current wallet address with the Vanta campaign service. Tasks belong to Vanta Orderly campaigns; Aster trades and deposits do not count.'**
  String get eventEngagementScope;

  /// No description provided for @eventEngagementVerified.
  ///
  /// In en, this message translates to:
  /// **'Task completion verified.'**
  String get eventEngagementVerified;

  /// No description provided for @eventEngagementAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Request acknowledged; task completion is unverified. Refresh progress.'**
  String get eventEngagementAcknowledged;

  /// No description provided for @eventEngagementUnknown.
  ///
  /// In en, this message translates to:
  /// **'A previous task submission has an unknown result. Query its progress without submitting again.'**
  String get eventEngagementUnknown;

  /// No description provided for @eventEngagementReadFirst.
  ///
  /// In en, this message translates to:
  /// **'Refresh the event, participation and task progress before confirming an eligible task.'**
  String get eventEngagementReadFirst;

  /// No description provided for @eventEngagementIneligible.
  ///
  /// In en, this message translates to:
  /// **'Task eligibility or event time changed. Refresh before trying again.'**
  String get eventEngagementIneligible;

  /// No description provided for @eventEngagementStorage.
  ///
  /// In en, this message translates to:
  /// **'Could not save or read the task journal. Submission stopped. Check device storage and refresh progress.'**
  String get eventEngagementStorage;

  /// No description provided for @eventEngagementBusy.
  ///
  /// In en, this message translates to:
  /// **'Another campaign task is in progress. Please wait.'**
  String get eventEngagementBusy;

  /// No description provided for @eventEngagementReconcileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reconcile task progress. Pending status is preserved; retry the query.'**
  String get eventEngagementReconcileFailed;

  /// No description provided for @eventDailyDate.
  ///
  /// In en, this message translates to:
  /// **'Task date (UTC)'**
  String get eventDailyDate;

  /// No description provided for @eventDailyVolume.
  ///
  /// In en, this message translates to:
  /// **'Daily volume (USDC)'**
  String get eventDailyVolume;

  /// No description provided for @eventCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in today'**
  String get eventCheckedIn;

  /// No description provided for @eventNotCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Not checked in today'**
  String get eventNotCheckedIn;

  /// No description provided for @eventCheckedDays.
  ///
  /// In en, this message translates to:
  /// **'Days checked in: {count}'**
  String eventCheckedDays(int count);

  /// No description provided for @eventDailyExpired.
  ///
  /// In en, this message translates to:
  /// **'Task date is stale. Refresh today’s progress.'**
  String get eventDailyExpired;

  /// No description provided for @eventTrackedMetric.
  ///
  /// In en, this message translates to:
  /// **'Tracked metric'**
  String get eventTrackedMetric;

  /// No description provided for @eventMilestoneCurrent.
  ///
  /// In en, this message translates to:
  /// **'Cumulative metric progress'**
  String get eventMilestoneCurrent;

  /// No description provided for @eventMilestoneUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Task milestone reached'**
  String get eventMilestoneUnlocked;

  /// No description provided for @eventMilestoneRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining to target'**
  String get eventMilestoneRemaining;

  /// No description provided for @eventNewRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete campaign registration'**
  String get eventNewRegistration;

  /// No description provided for @eventNewWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet connection task'**
  String get eventNewWallet;

  /// No description provided for @eventNewDeposit.
  ///
  /// In en, this message translates to:
  /// **'Net deposit task'**
  String get eventNewDeposit;

  /// No description provided for @eventDepositRequired.
  ///
  /// In en, this message translates to:
  /// **'Server deposit target'**
  String get eventDepositRequired;

  /// No description provided for @eventDepositCurrent.
  ///
  /// In en, this message translates to:
  /// **'Recorded net deposit'**
  String get eventDepositCurrent;

  /// No description provided for @eventDepositRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining net deposit'**
  String get eventDepositRemaining;

  /// No description provided for @eventDepositChain.
  ///
  /// In en, this message translates to:
  /// **'Deposit chain ID'**
  String get eventDepositChain;

  /// No description provided for @eventWebsiteDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit on Vanta website'**
  String get eventWebsiteDeposit;

  /// No description provided for @eventRewardNotCredit.
  ///
  /// In en, this message translates to:
  /// **'Task completion or a published reward does not prove a reward was paid.'**
  String get eventRewardNotCredit;

  /// No description provided for @eventCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Confirm daily check-in'**
  String get eventCheckIn;

  /// No description provided for @eventRecordWallet.
  ///
  /// In en, this message translates to:
  /// **'Confirm wallet connection task'**
  String get eventRecordWallet;

  /// No description provided for @eventEngagementSigningScope.
  ///
  /// In en, this message translates to:
  /// **'Sign and submit this Vanta campaign task message with your current wallet. No wallet is created or funds sent. Eligibility is checked again after signing.'**
  String get eventEngagementSigningScope;

  /// No description provided for @eventNetworkVolume.
  ///
  /// In en, this message translates to:
  /// **'Network volume (USDC)'**
  String get eventNetworkVolume;

  /// No description provided for @eventPersonalTotalVolume.
  ///
  /// In en, this message translates to:
  /// **'Own + network volume (USDC)'**
  String get eventPersonalTotalVolume;

  /// No description provided for @eventWhitelistCount.
  ///
  /// In en, this message translates to:
  /// **'Published allowlist count'**
  String get eventWhitelistCount;

  /// No description provided for @eventUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get eventUpcoming;

  /// No description provided for @assistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Vanta AI'**
  String get assistantTitle;

  /// No description provided for @assistantIntro.
  ///
  /// In en, this message translates to:
  /// **'Explore markets, compare scenarios, and understand risk. Include a symbol and timeframe for a more useful answer.'**
  String get assistantIntro;

  /// No description provided for @assistantScope.
  ///
  /// In en, this message translates to:
  /// **'AI responses may be inaccurate. This conversation does not place orders or attach your account balances.'**
  String get assistantScope;

  /// No description provided for @assistantAuthorize.
  ///
  /// In en, this message translates to:
  /// **'Authorize with wallet'**
  String get assistantAuthorize;

  /// No description provided for @assistantRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore saved session'**
  String get assistantRestore;

  /// No description provided for @assistantReady.
  ///
  /// In en, this message translates to:
  /// **'Wallet verified for AI'**
  String get assistantReady;

  /// No description provided for @assistantAuthHint.
  ///
  /// In en, this message translates to:
  /// **'Authorize with your connected wallet, or restore a session saved on this device. A message signature requires your separate confirmation.'**
  String get assistantAuthHint;

  /// No description provided for @assistantReview.
  ///
  /// In en, this message translates to:
  /// **'Review sign-in message'**
  String get assistantReview;

  /// No description provided for @assistantReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Review the exact message below. Confirmation opens your current wallet to sign this AI login message. This does not authorize trading. The request expires after 5 minutes.'**
  String get assistantReviewHint;

  /// No description provided for @assistantSign.
  ///
  /// In en, this message translates to:
  /// **'Confirm and sign'**
  String get assistantSign;

  /// No description provided for @assistantCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get assistantCancel;

  /// No description provided for @assistantStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get assistantStop;

  /// No description provided for @assistantSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get assistantSend;

  /// No description provided for @assistantPrompt.
  ///
  /// In en, this message translates to:
  /// **'Ask Vanta AI…'**
  String get assistantPrompt;

  /// No description provided for @assistantInputHint.
  ///
  /// In en, this message translates to:
  /// **'Up to 12,000 UTF-16 characters. Sending shares this prompt and recent completed messages with Vanta AI.'**
  String get assistantInputHint;

  /// No description provided for @assistantGuide.
  ///
  /// In en, this message translates to:
  /// **'Try: compare BTC scenarios on the 4-hour chart, with risks and invalidation levels.'**
  String get assistantGuide;

  /// No description provided for @assistantEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your conversation will appear here.'**
  String get assistantEmpty;

  /// No description provided for @assistantYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get assistantYou;

  /// No description provided for @assistantReply.
  ///
  /// In en, this message translates to:
  /// **'Vanta AI'**
  String get assistantReply;

  /// No description provided for @assistantExplanation.
  ///
  /// In en, this message translates to:
  /// **'Returned explanation'**
  String get assistantExplanation;

  /// No description provided for @assistantCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy message'**
  String get assistantCopy;

  /// No description provided for @assistantCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get assistantCopied;

  /// No description provided for @assistantCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy. Select the text to copy it manually.'**
  String get assistantCopyFailed;

  /// No description provided for @assistantCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy wallet address'**
  String get assistantCopyAddress;

  /// No description provided for @assistantRemoteImage.
  ///
  /// In en, this message translates to:
  /// **'Remote image hidden'**
  String get assistantRemoteImage;

  /// No description provided for @assistantStreaming.
  ///
  /// In en, this message translates to:
  /// **'Receiving response…'**
  String get assistantStreaming;

  /// No description provided for @assistantInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Stopped or interrupted. Partial content is saved; nothing will resume automatically.'**
  String get assistantInterrupted;

  /// No description provided for @assistantTruncated.
  ///
  /// In en, this message translates to:
  /// **'Response reached its length limit.'**
  String get assistantTruncated;

  /// No description provided for @assistantReplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Response incomplete. Review partial content before sending another question.'**
  String get assistantReplyFailed;

  /// No description provided for @assistantClear.
  ///
  /// In en, this message translates to:
  /// **'Clear conversation'**
  String get assistantClear;

  /// No description provided for @assistantClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear this wallet’s conversation and draft on this device? This cannot be undone and does not delete server records.'**
  String get assistantClearConfirm;

  /// No description provided for @assistantForget.
  ///
  /// In en, this message translates to:
  /// **'Forget saved AI session'**
  String get assistantForget;

  /// No description provided for @assistantForgetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this wallet’s saved AI credentials from this device? Conversation history is retained. This does not revoke the server session.'**
  String get assistantForgetConfirm;

  /// No description provided for @assistantRetryHistory.
  ///
  /// In en, this message translates to:
  /// **'Read history again'**
  String get assistantRetryHistory;

  /// No description provided for @assistantRetrySave.
  ///
  /// In en, this message translates to:
  /// **'Retry saving'**
  String get assistantRetrySave;

  /// No description provided for @assistantHistoryBlocked.
  ///
  /// In en, this message translates to:
  /// **'History could not be read safely. Read it again or explicitly clear it before sending.'**
  String get assistantHistoryBlocked;

  /// No description provided for @assistantUsage.
  ///
  /// In en, this message translates to:
  /// **'Daily usage (UTC)'**
  String get assistantUsage;

  /// No description provided for @assistantReadUsage.
  ///
  /// In en, this message translates to:
  /// **'Read usage'**
  String get assistantReadUsage;

  /// No description provided for @assistantUsageUnknown.
  ///
  /// In en, this message translates to:
  /// **'Usage has not been read. Remaining quota is unknown.'**
  String get assistantUsageUnknown;

  /// No description provided for @assistantQuotaStale.
  ///
  /// In en, this message translates to:
  /// **'This usage snapshot is stale. Read again to check the current UTC day.'**
  String get assistantQuotaStale;

  /// No description provided for @assistantUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get assistantUnknown;

  /// No description provided for @assistantPreparing.
  ///
  /// In en, this message translates to:
  /// **'Requesting sign-in message…'**
  String get assistantPreparing;

  /// No description provided for @assistantSigning.
  ///
  /// In en, this message translates to:
  /// **'Waiting for wallet and verification…'**
  String get assistantSigning;

  /// No description provided for @assistantRestoring.
  ///
  /// In en, this message translates to:
  /// **'Checking saved session…'**
  String get assistantRestoring;

  /// No description provided for @assistantLoadingHistory.
  ///
  /// In en, this message translates to:
  /// **'Reading saved conversation…'**
  String get assistantLoadingHistory;

  /// No description provided for @assistantReadingUsage.
  ///
  /// In en, this message translates to:
  /// **'Reading daily usage…'**
  String get assistantReadingUsage;

  /// No description provided for @assistantClearing.
  ///
  /// In en, this message translates to:
  /// **'Updating local storage…'**
  String get assistantClearing;

  /// No description provided for @assistantWalletRequired.
  ///
  /// In en, this message translates to:
  /// **'Connect an EVM wallet to use Vanta AI.'**
  String get assistantWalletRequired;

  /// No description provided for @assistantUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Vanta AI is unavailable. Your input is preserved; try again later.'**
  String get assistantUnavailable;

  /// No description provided for @assistantAuthorization.
  ///
  /// In en, this message translates to:
  /// **'AI session could not be verified. Restore it or authorize again.'**
  String get assistantAuthorization;

  /// No description provided for @assistantBinding.
  ///
  /// In en, this message translates to:
  /// **'The server did not confirm this wallet’s link to the AI account.'**
  String get assistantBinding;

  /// No description provided for @assistantBusy.
  ///
  /// In en, this message translates to:
  /// **'Another AI request is still finishing. Please try again shortly.'**
  String get assistantBusy;

  /// No description provided for @assistantCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request stopped.'**
  String get assistantCancelled;

  /// No description provided for @assistantChallengeExpired.
  ///
  /// In en, this message translates to:
  /// **'The sign-in request expired. Request a new message.'**
  String get assistantChallengeExpired;

  /// No description provided for @assistantChallengeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The sign-in message could not be verified. Nothing was signed.'**
  String get assistantChallengeInvalid;

  /// No description provided for @assistantSessionChanged.
  ///
  /// In en, this message translates to:
  /// **'Wallet or session changed. Start this action again.'**
  String get assistantSessionChanged;

  /// No description provided for @assistantConfiguration.
  ///
  /// In en, this message translates to:
  /// **'AI service configuration is unavailable. Please try again later.'**
  String get assistantConfiguration;

  /// No description provided for @assistantInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Enter a question of at most 12,000 UTF-16 characters.'**
  String get assistantInvalidInput;

  /// No description provided for @assistantInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The AI service returned an unreadable response. Your input is preserved.'**
  String get assistantInvalidResponse;

  /// No description provided for @assistantEmptyReply.
  ///
  /// In en, this message translates to:
  /// **'No answer was returned. Your question is preserved.'**
  String get assistantEmptyReply;

  /// No description provided for @assistantQuotaExceeded.
  ///
  /// In en, this message translates to:
  /// **'The AI service reported that your daily quota is exhausted.'**
  String get assistantQuotaExceeded;

  /// No description provided for @assistantTimeout.
  ///
  /// In en, this message translates to:
  /// **'The AI request timed out. Partial content and input are preserved.'**
  String get assistantTimeout;

  /// No description provided for @assistantTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The reply exceeded the supported size. Partial content is preserved.'**
  String get assistantTooLarge;

  /// No description provided for @assistantStorage.
  ///
  /// In en, this message translates to:
  /// **'Could not access this wallet’s saved AI data. Please retry.'**
  String get assistantStorage;

  /// No description provided for @assistantStorageCapacity.
  ///
  /// In en, this message translates to:
  /// **'Only the most recent conversation that fits device storage can be saved.'**
  String get assistantStorageCapacity;

  /// No description provided for @assistantNoSavedSession.
  ///
  /// In en, this message translates to:
  /// **'No AI session is saved for this wallet on this device. Authorize with your wallet first.'**
  String get assistantNoSavedSession;

  /// No description provided for @assistantClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear this conversation. Please try again.'**
  String get assistantClearFailed;

  /// No description provided for @assistantLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This link could not be opened. Only HTTPS links are supported.'**
  String get assistantLinkUnavailable;

  /// No description provided for @assistantLocalHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Recent conversation and draft are stored securely on this device for this wallet.'**
  String get assistantLocalHistoryHint;

  /// No description provided for @assistantCharacterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} / 12,000 UTF-16 characters'**
  String assistantCharacterCount(int count);

  /// No description provided for @assistantUsageValues.
  ///
  /// In en, this message translates to:
  /// **'Date {day} · Used {used} · Remaining {remaining}'**
  String assistantUsageValues(String day, String used, String remaining);

  /// No description provided for @collateralContribution.
  ///
  /// In en, this message translates to:
  /// **'Asset contribution (reference)'**
  String get collateralContribution;

  /// No description provided for @collateralCalculation.
  ///
  /// In en, this message translates to:
  /// **'Contribution calculation'**
  String get collateralCalculation;

  /// No description provided for @collateralFormula.
  ///
  /// In en, this message translates to:
  /// **'Cross equity = cross wallet balance + crossed unrealized PnL. Contribution = min(equity × bid rate, equity × ask rate). Negative equity uses the more negative value.'**
  String get collateralFormula;

  /// No description provided for @collateralCrossEquity.
  ///
  /// In en, this message translates to:
  /// **'Cross equity'**
  String get collateralCrossEquity;

  /// No description provided for @collateralBidRate.
  ///
  /// In en, this message translates to:
  /// **'Bid rate (USD per asset)'**
  String get collateralBidRate;

  /// No description provided for @collateralAskRate.
  ///
  /// In en, this message translates to:
  /// **'Ask rate (USD per asset)'**
  String get collateralAskRate;

  /// No description provided for @collateralScope.
  ///
  /// In en, this message translates to:
  /// **'Reference for assets eligible as multi-asset margin, using the signed account snapshot and public collateral rates. This does not confirm the active margin mode or represent order funds, withdrawal limits, or total portfolio value.'**
  String get collateralScope;

  /// No description provided for @collateralEligibilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Collateral eligibility is unknown. Read the account again to check.'**
  String get collateralEligibilityUnknown;

  /// No description provided for @collateralEquityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Cross wallet balance or crossed unrealized PnL is missing. Read the account again; missing values are not treated as zero.'**
  String get collateralEquityUnknown;

  /// No description provided for @collateralEventsNeedRead.
  ///
  /// In en, this message translates to:
  /// **'Account events changed this snapshot. Read the account again to verify cross equity.'**
  String get collateralEventsNeedRead;

  /// No description provided for @collateralRatesUnknown.
  ///
  /// In en, this message translates to:
  /// **'Collateral bid/ask rates are unavailable. Refresh public asset prices to retry.'**
  String get collateralRatesUnknown;

  /// No description provided for @collateralStale.
  ///
  /// In en, this message translates to:
  /// **'Contribution uses a stale snapshot. Refresh account balances and public prices before relying on it.'**
  String get collateralStale;

  /// No description provided for @collateralAccountTime.
  ///
  /// In en, this message translates to:
  /// **'Account snapshot (UTC): {time}'**
  String collateralAccountTime(String time);

  /// No description provided for @collateralRateTime.
  ///
  /// In en, this message translates to:
  /// **'Rate timestamp (UTC): {time}'**
  String collateralRateTime(String time);

  /// No description provided for @collateralLiveMarks.
  ///
  /// In en, this message translates to:
  /// **'Crossed PnL recomputed from public mark prices.'**
  String get collateralLiveMarks;

  /// No description provided for @collateralSnapshotPnl.
  ///
  /// In en, this message translates to:
  /// **'Using signed crossed-PnL snapshot; complete live marks or position fields are unavailable.'**
  String get collateralSnapshotPnl;

  /// No description provided for @collateralMarkTime.
  ///
  /// In en, this message translates to:
  /// **'Oldest mark timestamp (UTC): {time}'**
  String collateralMarkTime(String time);

  /// No description provided for @marginAdjustTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust isolated margin'**
  String get marginAdjustTitle;

  /// No description provided for @marginAdjustScope.
  ///
  /// In en, this message translates to:
  /// **'Use the connected wallet to read and confirm one isolated position. Signing and final amounts remain subject to Aster permissions and validation.'**
  String get marginAdjustScope;

  /// No description provided for @marginAdjustRead.
  ///
  /// In en, this message translates to:
  /// **'Read margin and limits'**
  String get marginAdjustRead;

  /// No description provided for @marginAdjustReadHint.
  ///
  /// In en, this message translates to:
  /// **'Reads the account, position and risk tiers with separate signatures. Nothing is submitted until you confirm. Limits expire after 30 seconds.'**
  String get marginAdjustReadHint;

  /// No description provided for @marginAdjustAdd.
  ///
  /// In en, this message translates to:
  /// **'Add margin'**
  String get marginAdjustAdd;

  /// No description provided for @marginAdjustRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove margin'**
  String get marginAdjustRemove;

  /// No description provided for @marginAdjustAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Margin amount'**
  String get marginAdjustAmountLabel;

  /// No description provided for @marginAdjustAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive amount within the current limit, with up to 8 decimal places.'**
  String get marginAdjustAmount;

  /// No description provided for @marginAdjustMaximum.
  ///
  /// In en, this message translates to:
  /// **'Current maximum'**
  String get marginAdjustMaximum;

  /// No description provided for @marginAdjustMax.
  ///
  /// In en, this message translates to:
  /// **'Max (2 decimals)'**
  String get marginAdjustMax;

  /// No description provided for @marginAdjustWallet.
  ///
  /// In en, this message translates to:
  /// **'Current isolated wallet margin'**
  String get marginAdjustWallet;

  /// No description provided for @marginAdjustNextWallet.
  ///
  /// In en, this message translates to:
  /// **'Isolated wallet margin after adjustment'**
  String get marginAdjustNextWallet;

  /// No description provided for @marginAdjustLiquidation.
  ///
  /// In en, this message translates to:
  /// **'Estimated liquidation price after adjustment'**
  String get marginAdjustLiquidation;

  /// No description provided for @marginAdjustPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Reference only, using the signed mark price and risk tiers. Quantity and entry price stay the same. Actual liquidation price is read again after confirmation.'**
  String get marginAdjustPreviewHint;

  /// No description provided for @marginAdjustReview.
  ///
  /// In en, this message translates to:
  /// **'Review adjustment'**
  String get marginAdjustReview;

  /// No description provided for @marginAdjustConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign and submit adjustment'**
  String get marginAdjustConfirm;

  /// No description provided for @marginAdjustConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Re-read limits, then sign and submit once. The result is checked by the original reference and exact terms; balances alone cannot prove success. Further signatures refresh the position, account and risk tiers.'**
  String get marginAdjustConfirmHint;

  /// No description provided for @marginAdjustReference.
  ///
  /// In en, this message translates to:
  /// **'Adjustment reference'**
  String get marginAdjustReference;

  /// No description provided for @marginAdjustHistory.
  ///
  /// In en, this message translates to:
  /// **'Margin adjustment records'**
  String get marginAdjustHistory;

  /// No description provided for @marginAdjustHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No margin adjustment records for this wallet.'**
  String get marginAdjustHistoryEmpty;

  /// No description provided for @marginAdjustCheck.
  ///
  /// In en, this message translates to:
  /// **'Check original reference'**
  String get marginAdjustCheck;

  /// No description provided for @marginAdjustVerified.
  ///
  /// In en, this message translates to:
  /// **'Exact adjustment found in Aster history.'**
  String get marginAdjustVerified;

  /// No description provided for @marginAdjustUnknown.
  ///
  /// In en, this message translates to:
  /// **'Outcome unconfirmed. Keep the original reference and check again; do not resubmit.'**
  String get marginAdjustUnknown;

  /// No description provided for @marginAdjustRejected.
  ///
  /// In en, this message translates to:
  /// **'Aster explicitly rejected this adjustment. No successful adjustment is claimed.'**
  String get marginAdjustRejected;

  /// No description provided for @marginAdjustStorage.
  ///
  /// In en, this message translates to:
  /// **'Margin records are unavailable or could not be saved. Submission is blocked; reload the records.'**
  String get marginAdjustStorage;

  /// No description provided for @marginAdjustReload.
  ///
  /// In en, this message translates to:
  /// **'Reload saved records'**
  String get marginAdjustReload;

  /// No description provided for @marginAdjustExpired.
  ///
  /// In en, this message translates to:
  /// **'Margin information expired or changed. Read the limits again before confirming.'**
  String get marginAdjustExpired;

  /// No description provided for @marginAdjustChanged.
  ///
  /// In en, this message translates to:
  /// **'The position, margin or risk tiers changed. Read again and review the new terms.'**
  String get marginAdjustChanged;

  /// No description provided for @marginAdjustClosed.
  ///
  /// In en, this message translates to:
  /// **'This position is closed or has zero quantity. It cannot be adjusted.'**
  String get marginAdjustClosed;

  /// No description provided for @marginAdjustUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Only a nonzero isolated linear position with known units supports this adjustment.'**
  String get marginAdjustUnsupported;

  /// No description provided for @marginAdjustInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Aster reports insufficient available or isolated margin. Read the limits again.'**
  String get marginAdjustInsufficient;

  /// No description provided for @marginAdjustSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting the confirmed adjustment once…'**
  String get marginAdjustSubmitting;

  /// No description provided for @marginAdjustChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking history, actual position and account…'**
  String get marginAdjustChecking;

  /// No description provided for @marginAdjustStop.
  ///
  /// In en, this message translates to:
  /// **'Stop waiting'**
  String get marginAdjustStop;

  /// No description provided for @marginAdjustStopHint.
  ///
  /// In en, this message translates to:
  /// **'Leaving or stopping does not cancel a sent request. Saved pending records are recovered without resubmission.'**
  String get marginAdjustStopHint;

  /// No description provided for @marginAdjustActualLiquidation.
  ///
  /// In en, this message translates to:
  /// **'Latest actual liquidation price'**
  String get marginAdjustActualLiquidation;

  /// No description provided for @marginAdjustRatio.
  ///
  /// In en, this message translates to:
  /// **'Isolated margin ratio'**
  String get marginAdjustRatio;

  /// No description provided for @marginAdjustEquityRisk.
  ///
  /// In en, this message translates to:
  /// **'Margin equity is zero or negative; liquidation risk is elevated.'**
  String get marginAdjustEquityRisk;

  /// No description provided for @marginAdjustRatioHint.
  ///
  /// In en, this message translates to:
  /// **'Maintenance margin ÷ (isolated wallet margin + unrealized PnL), from the same account snapshot.'**
  String get marginAdjustRatioHint;

  /// No description provided for @marginAdjustOverMaximum.
  ///
  /// In en, this message translates to:
  /// **'Amount exceeds the available limit.'**
  String get marginAdjustOverMaximum;

  /// No description provided for @attachedOrderAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced exit settings'**
  String get attachedOrderAdvanced;

  /// No description provided for @attachedOrderInputMode.
  ///
  /// In en, this message translates to:
  /// **'Input mode'**
  String get attachedOrderInputMode;

  /// No description provided for @attachedOrderPnlMode.
  ///
  /// In en, this message translates to:
  /// **'PnL amount'**
  String get attachedOrderPnlMode;

  /// No description provided for @attachedOrderPriceMode.
  ///
  /// In en, this message translates to:
  /// **'Trigger price'**
  String get attachedOrderPriceMode;

  /// No description provided for @attachedOrderRoiMode.
  ///
  /// In en, this message translates to:
  /// **'Margin ROI (%)'**
  String get attachedOrderRoiMode;

  /// No description provided for @attachedOrderPnlInput.
  ///
  /// In en, this message translates to:
  /// **'PnL amount ({asset})'**
  String attachedOrderPnlInput(String asset);

  /// No description provided for @attachedOrderExecution.
  ///
  /// In en, this message translates to:
  /// **'Exit execution'**
  String get attachedOrderExecution;

  /// No description provided for @attachedOrderManualLimit.
  ///
  /// In en, this message translates to:
  /// **'Manual limit'**
  String get attachedOrderManualLimit;

  /// No description provided for @attachedOrderAutomaticLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit at trigger price'**
  String get attachedOrderAutomaticLimit;

  /// No description provided for @attachedOrderLimitPrice.
  ///
  /// In en, this message translates to:
  /// **'Exit limit price ({asset})'**
  String attachedOrderLimitPrice(String asset);

  /// No description provided for @attachedOrderTriggerPreview.
  ///
  /// In en, this message translates to:
  /// **'Indicative trigger'**
  String get attachedOrderTriggerPreview;

  /// No description provided for @attachedOrderGrossPnl.
  ///
  /// In en, this message translates to:
  /// **'Estimated gross PnL'**
  String get attachedOrderGrossPnl;

  /// No description provided for @attachedOrderGrossRoi.
  ///
  /// In en, this message translates to:
  /// **'Estimated gross ROI'**
  String get attachedOrderGrossRoi;

  /// No description provided for @attachedOrderRoundedPreview.
  ///
  /// In en, this message translates to:
  /// **'Converted trigger prices are rounded to the nearest price tick. Review the resulting price.'**
  String get attachedOrderRoundedPreview;

  /// No description provided for @attachedOrderEstimateScope.
  ///
  /// In en, this message translates to:
  /// **'Estimates use the main-order quantity and indicative entry price, before fees and slippage. A limit exit may remain unfilled after triggering.'**
  String get attachedOrderEstimateScope;

  /// No description provided for @attachedOrderExitIssue.
  ///
  /// In en, this message translates to:
  /// **'{exit}: {reason}'**
  String attachedOrderExitIssue(String exit, String reason);

  /// No description provided for @attachedOrderCheckExits.
  ///
  /// In en, this message translates to:
  /// **'Review the highlighted attached TP/SL fields before continuing.'**
  String get attachedOrderCheckExits;

  /// No description provided for @attachedOrderTargetSign.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive take-profit or negative stop-loss amount / ROI. Zero is not a target.'**
  String get attachedOrderTargetSign;

  /// No description provided for @attachedOrderPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid main-order quantity and price, and read the entry quote and leverage before converting.'**
  String get attachedOrderPreviewUnavailable;

  /// No description provided for @attachedOrderLimitRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive exit limit price.'**
  String get attachedOrderLimitRequired;

  /// No description provided for @attachedOrderExecutionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Review the attached exit execution and limit price.'**
  String get attachedOrderExecutionInvalid;

  /// No description provided for @attachedOrderLegacyLifecycle.
  ///
  /// In en, this message translates to:
  /// **'This saved strategy uses its original full-fill activation and peer-cancellation rules. Its original protected quantity is unchanged.'**
  String get attachedOrderLegacyLifecycle;

  /// No description provided for @attachedOrderDirectionHint.
  ///
  /// In en, this message translates to:
  /// **'Trigger must be {relation} the indicative entry price {price} {asset}.'**
  String attachedOrderDirectionHint(String relation, String price, String asset);

  /// No description provided for @strategyExecutionTitle.
  ///
  /// In en, this message translates to:
  /// **'Strategy execution details'**
  String get strategyExecutionTitle;

  /// No description provided for @strategyExecutionScope.
  ///
  /// In en, this message translates to:
  /// **'Read actual order quantities and filled value separately from strategy terms. Each order has its own snapshot time. These records do not prove current balances or remaining positions.'**
  String get strategyExecutionScope;

  /// No description provided for @strategyExecutionSignHint.
  ///
  /// In en, this message translates to:
  /// **'Sign to recheck the original strategy, then each child order with an exchange order ID. This may require several wallet confirmations. A failure stops further prompts; retry is manual.'**
  String get strategyExecutionSignHint;

  /// No description provided for @strategyExecutionRead.
  ///
  /// In en, this message translates to:
  /// **'Sign to read executions'**
  String get strategyExecutionRead;

  /// No description provided for @strategyExecutionCheckingStrategy.
  ///
  /// In en, this message translates to:
  /// **'Checking the original strategy…'**
  String get strategyExecutionCheckingStrategy;

  /// No description provided for @strategyExecutionCheckingLeg.
  ///
  /// In en, this message translates to:
  /// **'Reading order {sequence}…'**
  String strategyExecutionCheckingLeg(int sequence);

  /// No description provided for @strategyExecutionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop waiting'**
  String get strategyExecutionStop;

  /// No description provided for @strategyExecutionStopped.
  ///
  /// In en, this message translates to:
  /// **'Reading stopped. Any previous snapshot is retained; no orders were canceled.'**
  String get strategyExecutionStopped;

  /// No description provided for @strategyExecutionSkipped.
  ///
  /// In en, this message translates to:
  /// **'Not read after an earlier failure. Read again to check this order.'**
  String get strategyExecutionSkipped;

  /// No description provided for @strategyExecutionStale.
  ///
  /// In en, this message translates to:
  /// **'This snapshot may be out of date. Sign to read again.'**
  String get strategyExecutionStale;

  /// No description provided for @strategyExecutionStrategyTime.
  ///
  /// In en, this message translates to:
  /// **'Strategy checked (UTC)'**
  String get strategyExecutionStrategyTime;

  /// No description provided for @strategyExecutionOrderTime.
  ///
  /// In en, this message translates to:
  /// **'Order checked (UTC)'**
  String get strategyExecutionOrderTime;

  /// No description provided for @strategyExecutionEntry.
  ///
  /// In en, this message translates to:
  /// **'Main order'**
  String get strategyExecutionEntry;

  /// No description provided for @strategyExecutionStrategyLegStatus.
  ///
  /// In en, this message translates to:
  /// **'Status in strategy snapshot'**
  String get strategyExecutionStrategyLegStatus;

  /// No description provided for @strategyExecutionOrderStatus.
  ///
  /// In en, this message translates to:
  /// **'Status in order snapshot'**
  String get strategyExecutionOrderStatus;

  /// No description provided for @strategyExecutionNoOrder.
  ///
  /// In en, this message translates to:
  /// **'The strategy has no ordinary order ID for this leg. Filled quantity and value are unknown.'**
  String get strategyExecutionNoOrder;

  /// No description provided for @strategyExecutionTriggered.
  ///
  /// In en, this message translates to:
  /// **'The order report shows triggering or execution. A trigger alone does not confirm a fill.'**
  String get strategyExecutionTriggered;

  /// No description provided for @strategyExecutionTriggerUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Triggering is not confirmed by this order snapshot.'**
  String get strategyExecutionTriggerUnconfirmed;

  /// No description provided for @strategyExecutionOriginalSize.
  ///
  /// In en, this message translates to:
  /// **'Current order quantity'**
  String get strategyExecutionOriginalSize;

  /// No description provided for @strategyExecutionFilledSize.
  ///
  /// In en, this message translates to:
  /// **'Actual filled quantity'**
  String get strategyExecutionFilledSize;

  /// No description provided for @strategyExecutionFilledValue.
  ///
  /// In en, this message translates to:
  /// **'Actual filled value'**
  String get strategyExecutionFilledValue;

  /// No description provided for @strategyExecutionAveragePrice.
  ///
  /// In en, this message translates to:
  /// **'Reported average fill price'**
  String get strategyExecutionAveragePrice;

  /// No description provided for @strategyExecutionTermsChanged.
  ///
  /// In en, this message translates to:
  /// **'The current quantity or price differs from the original strategy terms. Values above are from this order report; automatic replenishment is not inferred.'**
  String get strategyExecutionTermsChanged;

  /// No description provided for @liveAmountUnit.
  ///
  /// In en, this message translates to:
  /// **'Order size unit'**
  String get liveAmountUnit;

  /// No description provided for @liveAmountInput.
  ///
  /// In en, this message translates to:
  /// **'Order amount ({asset})'**
  String liveAmountInput(String asset);

  /// No description provided for @liveAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter order notional, not margin. The amount is not multiplied by leverage.'**
  String get liveAmountHint;

  /// No description provided for @liveAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive order amount using decimal digits.'**
  String get liveAmountInvalid;

  /// No description provided for @liveAmountBelowStep.
  ///
  /// In en, this message translates to:
  /// **'This amount converts to less than the minimum order quantity or one quantity step.'**
  String get liveAmountBelowStep;

  /// No description provided for @liveAmountReferenceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The required conversion price is unavailable. Refresh the order snapshot or enter a base-asset quantity.'**
  String get liveAmountReferenceUnavailable;

  /// No description provided for @liveAmountLimitReference.
  ///
  /// In en, this message translates to:
  /// **'entered limit price'**
  String get liveAmountLimitReference;

  /// No description provided for @liveAmountAskReference.
  ///
  /// In en, this message translates to:
  /// **'best ask snapshot'**
  String get liveAmountAskReference;

  /// No description provided for @liveAmountBidReference.
  ///
  /// In en, this message translates to:
  /// **'best bid snapshot'**
  String get liveAmountBidReference;

  /// No description provided for @liveAmountTriggerReference.
  ///
  /// In en, this message translates to:
  /// **'trigger price estimate'**
  String get liveAmountTriggerReference;

  /// No description provided for @liveAmountBboReference.
  ///
  /// In en, this message translates to:
  /// **'indicative Mark, not an engine BBO price'**
  String get liveAmountBboReference;

  /// No description provided for @liveAmountConversionPrice.
  ///
  /// In en, this message translates to:
  /// **'Conversion reference: {basis}'**
  String liveAmountConversionPrice(String basis);

  /// No description provided for @liveAmountResolvedQuantity.
  ///
  /// In en, this message translates to:
  /// **'Base quantity to submit'**
  String get liveAmountResolvedQuantity;

  /// No description provided for @liveAmountSnapshotTime.
  ///
  /// In en, this message translates to:
  /// **'Order snapshot (UTC)'**
  String get liveAmountSnapshotTime;

  /// No description provided for @liveAmountEstimateHint.
  ///
  /// In en, this message translates to:
  /// **'Quantity is rounded down to the applicable step and fixed for confirmation. Market, trigger and BBO prices may change; actual spending can exceed this estimate. This amount is not a spending cap.'**
  String get liveAmountEstimateHint;

  /// No description provided for @futuresHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Futures history'**
  String get futuresHistoryTitle;

  /// No description provided for @futuresHistoryScope.
  ///
  /// In en, this message translates to:
  /// **'Read this wallet’s futures orders, individual fills and income ledger separately. BUY/SELL alone does not identify opening or closing. Reading never submits or cancels an order.'**
  String get futuresHistoryScope;

  /// No description provided for @futuresHistoryIncome.
  ///
  /// In en, this message translates to:
  /// **'Income ledger'**
  String get futuresHistoryIncome;

  /// No description provided for @futuresHistorySymbol.
  ///
  /// In en, this message translates to:
  /// **'Futures symbol (optional)'**
  String get futuresHistorySymbol;

  /// No description provided for @futuresHistoryTradeSymbol.
  ///
  /// In en, this message translates to:
  /// **'Futures symbol (required for fills)'**
  String get futuresHistoryTradeSymbol;

  /// No description provided for @futuresHistoryFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Use the exact symbol, including delisted contracts. Orders and income allow all symbols; individual fills require one symbol. Editing clears the displayed results without signing.'**
  String get futuresHistoryFilterHint;

  /// No description provided for @futuresHistoryInvalidSymbol.
  ///
  /// In en, this message translates to:
  /// **'Enter an exact futures symbol. Individual fills require a symbol; spaces and query syntax are not accepted.'**
  String get futuresHistoryInvalidSymbol;

  /// No description provided for @futuresHistoryInvalidType.
  ///
  /// In en, this message translates to:
  /// **'Choose a supported income type, or all types.'**
  String get futuresHistoryInvalidType;

  /// No description provided for @futuresHistoryInvalidWindow.
  ///
  /// In en, this message translates to:
  /// **'Select a valid UTC date range. Each signed request reads less than seven days; longer ranges are read in separate manual batches.'**
  String get futuresHistoryInvalidWindow;

  /// No description provided for @futuresHistoryCapacity.
  ///
  /// In en, this message translates to:
  /// **'This view reached 10,000 records. Earlier results remain; narrow the date range or symbol and read again. No records were silently discarded.'**
  String get futuresHistoryCapacity;

  /// No description provided for @futuresHistoryRetention.
  ///
  /// In en, this message translates to:
  /// **'Aster omits canceled or expired orders with no fills once their creation is more than seven days old. Partly filled canceled orders keep their reported fills. API retention can limit older records.'**
  String get futuresHistoryRetention;

  /// No description provided for @futuresHistoryAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All income types'**
  String get futuresHistoryAllTypes;

  /// No description provided for @futuresHistoryOriginalType.
  ///
  /// In en, this message translates to:
  /// **'Original order type'**
  String get futuresHistoryOriginalType;

  /// No description provided for @futuresHistoryExecuted.
  ///
  /// In en, this message translates to:
  /// **'Reported filled quantity'**
  String get futuresHistoryExecuted;

  /// No description provided for @futuresHistoryPnlHint.
  ///
  /// In en, this message translates to:
  /// **'Reported realized PnL is separate from commission and income-ledger entries. These records are not summed into a net return or portfolio statistic.'**
  String get futuresHistoryPnlHint;

  /// No description provided for @futuresHistoryIncomeAmount.
  ///
  /// In en, this message translates to:
  /// **'Reported income change'**
  String get futuresHistoryIncomeAmount;

  /// No description provided for @futuresHistoryIncomeType.
  ///
  /// In en, this message translates to:
  /// **'{type, select, TRANSFER{Transfer} WITHDRAW{Withdrawal} DEPOSIT{Deposit} WELCOME_BONUS{Welcome bonus} REALIZED_PNL{Realized PnL} FUNDING_FEE{Funding fee} COMMISSION{Commission} INSURANCE_CLEAR{Insurance clearing} MARKET_MERCHANT_RETURN_REWARD{Market merchant return reward} REFERRAL_KICKBACK{Referral kickback} COMMISSION_REBATE{Commission rebate} MARKET_MAKER_REBATE{Market maker rebate} API_REBATE{API rebate} CONTEST_REWARD{Contest reward} CROSS_COLLATERAL_TRANSFER{Cross-collateral transfer} INTERNAL_TRANSFER{Internal transfer} AUTO_EXCHANGE{Automatic exchange} other{Unknown ({type})}}'**
  String futuresHistoryIncomeType(String type);

  /// No description provided for @orderConfirmLimit.
  ///
  /// In en, this message translates to:
  /// **'Confirm limit and Post Only entries'**
  String get orderConfirmLimit;

  /// No description provided for @orderConfirmStopLimit.
  ///
  /// In en, this message translates to:
  /// **'Confirm conditional limit entries'**
  String get orderConfirmStopLimit;

  /// No description provided for @orderConfirmStopMarket.
  ///
  /// In en, this message translates to:
  /// **'Confirm conditional market entries'**
  String get orderConfirmStopMarket;

  /// No description provided for @orderConfirmTrailing.
  ///
  /// In en, this message translates to:
  /// **'Confirm trailing stop entries'**
  String get orderConfirmTrailing;

  /// No description provided for @orderConfirmLimitShared.
  ///
  /// In en, this message translates to:
  /// **'Limit and Post Only share this setting.'**
  String get orderConfirmLimitShared;

  /// No description provided for @orderConfirmDoNotShow.
  ///
  /// In en, this message translates to:
  /// **'Do not show confirmation again for this order type'**
  String get orderConfirmDoNotShow;

  /// No description provided for @orderConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Confirmation'**
  String get orderConfirmTitle;

  /// No description provided for @orderConfirmPrice.
  ///
  /// In en, this message translates to:
  /// **'Order price'**
  String get orderConfirmPrice;

  /// No description provided for @orderConfirmQuantity.
  ///
  /// In en, this message translates to:
  /// **'Order Qty'**
  String get orderConfirmQuantity;

  /// No description provided for @orderConfirmMarketPrice.
  ///
  /// In en, this message translates to:
  /// **'Market Price'**
  String get orderConfirmMarketPrice;

  /// No description provided for @orderConfirmTakeProfit.
  ///
  /// In en, this message translates to:
  /// **'Take Profit'**
  String get orderConfirmTakeProfit;

  /// No description provided for @orderConfirmStopLoss.
  ///
  /// In en, this message translates to:
  /// **'Stop Loss'**
  String get orderConfirmStopLoss;

  /// No description provided for @orderConfirmBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy/Long'**
  String get orderConfirmBuy;

  /// No description provided for @orderConfirmSell.
  ///
  /// In en, this message translates to:
  /// **'Sell/Short'**
  String get orderConfirmSell;

  /// No description provided for @orderConfirmSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Order submitted'**
  String get orderConfirmSubmitted;

  /// No description provided for @orderConfirmExpired.
  ///
  /// In en, this message translates to:
  /// **'Order details are no longer current. Close this dialog and place the order again.'**
  String get orderConfirmExpired;

  /// No description provided for @orderConfirmWalletHint.
  ///
  /// In en, this message translates to:
  /// **'This setting controls the app review. Wallet signatures and checks before submission still apply.'**
  String get orderConfirmWalletHint;

  /// No description provided for @scaledTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total order amount'**
  String get scaledTotalAmount;

  /// No description provided for @scaledAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive total order amount.'**
  String get scaledAmountInvalid;

  /// No description provided for @scaledDistribution.
  ///
  /// In en, this message translates to:
  /// **'Quantity distribution'**
  String get scaledDistribution;

  /// No description provided for @scaledEqual.
  ///
  /// In en, this message translates to:
  /// **'Equal'**
  String get scaledEqual;

  /// No description provided for @scaledIncreasing.
  ///
  /// In en, this message translates to:
  /// **'Increasing'**
  String get scaledIncreasing;

  /// No description provided for @scaledDecreasing.
  ///
  /// In en, this message translates to:
  /// **'Decreasing'**
  String get scaledDecreasing;

  /// No description provided for @scaledRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get scaledRandom;

  /// No description provided for @scaledConstant.
  ///
  /// In en, this message translates to:
  /// **'Distribution constant'**
  String get scaledConstant;

  /// No description provided for @scaledDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get scaledDifference;

  /// No description provided for @scaledRatio.
  ///
  /// In en, this message translates to:
  /// **'Ratio'**
  String get scaledRatio;

  /// No description provided for @scaledDifferenceHint.
  ///
  /// In en, this message translates to:
  /// **'Quantity weights are 1:2:3… from low to high price for Increasing, reversed for Decreasing. Quantity steps may round the pattern.'**
  String get scaledDifferenceHint;

  /// No description provided for @scaledRatioHint.
  ///
  /// In en, this message translates to:
  /// **'Quantity weights are 1:2:4… from low to high price for Increasing, reversed for Decreasing. Every child must meet the minimum size; high counts may require a very large total.'**
  String get scaledRatioHint;

  /// No description provided for @scaledVariance.
  ///
  /// In en, this message translates to:
  /// **'Random variance'**
  String get scaledVariance;

  /// No description provided for @scaledVarianceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a variance from 0% to 10%.'**
  String get scaledVarianceInvalid;

  /// No description provided for @scaledVarianceStep.
  ///
  /// In en, this message translates to:
  /// **'The quantity step cannot represent this random distribution within the selected variance. Increase the total, change the variance or reshuffle.'**
  String get scaledVarianceStep;

  /// No description provided for @scaledRandomRequired.
  ///
  /// In en, this message translates to:
  /// **'Generate a random breakdown before reviewing.'**
  String get scaledRandomRequired;

  /// No description provided for @scaledRandomHint.
  ///
  /// In en, this message translates to:
  /// **'Each quantity stays within the selected percentage of the mean quantity. This breakdown stays fixed until you edit its inputs or reshuffle; changing language never redraws it.'**
  String get scaledRandomHint;

  /// No description provided for @scaledReshuffle.
  ///
  /// In en, this message translates to:
  /// **'Reshuffle quantities'**
  String get scaledReshuffle;

  /// No description provided for @scaledUnallocatedQuote.
  ///
  /// In en, this message translates to:
  /// **'Unallocated order amount'**
  String get scaledUnallocatedQuote;

  /// No description provided for @scaledAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Order amount is the sum of child limit price × quantity, without leverage multiplication. Quote input is rounded down to valid base quantities; the unallocated amount is shown. This excludes fees and is not a margin or final execution-cost limit.'**
  String get scaledAmountHint;

  /// No description provided for @scaledBaseRemainderHint.
  ///
  /// In en, this message translates to:
  /// **'The entered base quantity is conserved exactly. Remaining steps go to the largest fractional remainders, with ties assigned from low to high price.'**
  String get scaledBaseRemainderHint;

  /// No description provided for @scaledPreviousChildren.
  ///
  /// In en, this message translates to:
  /// **'Previous orders'**
  String get scaledPreviousChildren;

  /// No description provided for @scaledNextChildren.
  ///
  /// In en, this message translates to:
  /// **'Next orders'**
  String get scaledNextChildren;

  /// No description provided for @scaledChildType.
  ///
  /// In en, this message translates to:
  /// **'Child order type'**
  String get scaledChildType;

  /// No description provided for @scaledEnteredSize.
  ///
  /// In en, this message translates to:
  /// **'Entered total'**
  String get scaledEnteredSize;

  /// No description provided for @scaledPage.
  ///
  /// In en, this message translates to:
  /// **'Orders {start}–{end} of {total}'**
  String scaledPage(int start, int end, int total);

  /// No description provided for @scaledCountRange.
  ///
  /// In en, this message translates to:
  /// **'2–110'**
  String get scaledCountRange;

  /// No description provided for @assistantNavigation.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get assistantNavigation;

  /// No description provided for @orderTypeTrailing.
  ///
  /// In en, this message translates to:
  /// **'Trailing Stop'**
  String get orderTypeTrailing;

  /// No description provided for @orderTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Type'**
  String get orderTypeTitle;

  /// No description provided for @orderTypePostOnly.
  ///
  /// In en, this message translates to:
  /// **'Post Only'**
  String get orderTypePostOnly;

  /// No description provided for @orderTypeStopLimit.
  ///
  /// In en, this message translates to:
  /// **'Stop Limit'**
  String get orderTypeStopLimit;

  /// No description provided for @orderTypeStopMarket.
  ///
  /// In en, this message translates to:
  /// **'Stop Market'**
  String get orderTypeStopMarket;

  /// No description provided for @orderTypeScaled.
  ///
  /// In en, this message translates to:
  /// **'Scaled Order'**
  String get orderTypeScaled;

  /// No description provided for @orderModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Order type'**
  String get orderModeLabel;

  /// No description provided for @orderModeMore.
  ///
  /// In en, this message translates to:
  /// **'More order types'**
  String get orderModeMore;

  /// No description provided for @orderModeStopLimit.
  ///
  /// In en, this message translates to:
  /// **'TP/SL Limit'**
  String get orderModeStopLimit;

  /// No description provided for @orderModeStopMarket.
  ///
  /// In en, this message translates to:
  /// **'TP/SL Market'**
  String get orderModeStopMarket;

  /// No description provided for @orderModeChase.
  ///
  /// In en, this message translates to:
  /// **'Chase'**
  String get orderModeChase;

  /// No description provided for @orderModeTwap.
  ///
  /// In en, this message translates to:
  /// **'TWAP'**
  String get orderModeTwap;

  /// No description provided for @orderModeChaseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Chase orders are not available yet.'**
  String get orderModeChaseUnavailable;

  /// No description provided for @orderModeTwapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Currently unavailable. TWAP is not included in this release.'**
  String get orderModeTwapUnavailable;

  /// No description provided for @liveCapacityChanged.
  ///
  /// In en, this message translates to:
  /// **'Account settings, positions or reserved margin changed. Refresh the order data before calculating capacity.'**
  String get liveCapacityChanged;

  /// No description provided for @liveCapacityPriceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A reliable price reference for this order is unavailable. Refresh market data or review the pricing mode.'**
  String get liveCapacityPriceUnavailable;

  /// No description provided for @liveCapacityTitle.
  ///
  /// In en, this message translates to:
  /// **'Directional capacity reference'**
  String get liveCapacityTitle;

  /// No description provided for @liveAllocationPercent.
  ///
  /// In en, this message translates to:
  /// **'Order percentage: {percent}%'**
  String liveAllocationPercent(int percent);

  /// No description provided for @liveAllocationManual.
  ///
  /// In en, this message translates to:
  /// **'Manual amount'**
  String get liveAllocationManual;

  /// No description provided for @liveAllocationManualHint.
  ///
  /// In en, this message translates to:
  /// **'Review checks the selected side’s latest capacity with up to six wallet signatures. Your entered amount is preserved and the quantity you click stays fixed.'**
  String get liveAllocationManualHint;

  /// No description provided for @liveAllocationMaximumChanged.
  ///
  /// In en, this message translates to:
  /// **'{direction}: the latest maximum is {maximum} {asset}. Adjust the amount and try again.'**
  String liveAllocationMaximumChanged(String direction, String maximum, String asset);

  /// No description provided for @liveAllocationHint.
  ///
  /// In en, this message translates to:
  /// **'Read capacity before choosing a percentage. Each side uses its own maximum. Review refreshes limits with up to six wallet signatures and freezes the quantity you clicked.'**
  String get liveAllocationHint;

  /// No description provided for @liveAllocationChecking.
  ///
  /// In en, this message translates to:
  /// **'Refreshing limits for the selected direction…'**
  String get liveAllocationChecking;

  /// No description provided for @liveAllocationChanged.
  ///
  /// In en, this message translates to:
  /// **'Order inputs, account data or capacity changed. Review the current values and try again.'**
  String get liveAllocationChanged;

  /// No description provided for @liveAllocationFrozen.
  ///
  /// In en, this message translates to:
  /// **'This direction, order type and quantity are frozen for confirmation. Changed or expired data blocks submission.'**
  String get liveAllocationFrozen;

  /// No description provided for @liveAllocationReviewBuy.
  ///
  /// In en, this message translates to:
  /// **'Review long'**
  String get liveAllocationReviewBuy;

  /// No description provided for @liveAllocationReviewSell.
  ///
  /// In en, this message translates to:
  /// **'Review short'**
  String get liveAllocationReviewSell;

  /// No description provided for @liveCapacityRead.
  ///
  /// In en, this message translates to:
  /// **'Read capacity'**
  String get liveCapacityRead;

  /// No description provided for @liveCapacityReadHint.
  ///
  /// In en, this message translates to:
  /// **'Reading your latest account and order limits requires up to six wallet signatures. No order is placed.'**
  String get liveCapacityReadHint;

  /// No description provided for @liveCapacityMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum quantity reference'**
  String get liveCapacityMaximum;

  /// No description provided for @liveCapacityCost.
  ///
  /// In en, this message translates to:
  /// **'Opening cost reference'**
  String get liveCapacityCost;

  /// No description provided for @liveCapacityAboveMaximum.
  ///
  /// In en, this message translates to:
  /// **'The quantity exceeds this side’s current capacity reference. Reduce the quantity and refresh before placing an order.'**
  String get liveCapacityAboveMaximum;

  /// No description provided for @liveCapacityStale.
  ///
  /// In en, this message translates to:
  /// **'Capacity is out of date. Refresh order data, then read capacity again.'**
  String get liveCapacityStale;

  /// No description provided for @liveCapacityEstimateHint.
  ///
  /// In en, this message translates to:
  /// **'Both sides independently assume a full fill using the same account and current prices. Opening cost includes incremental margin and opening loss. Liquidation estimates use the signed taker fee and risk tiers, holding other prices and collateral rates fixed; actual fills, fees and funding can differ. Missing facts or no positive estimate show —.'**
  String get liveCapacityEstimateHint;

  /// No description provided for @liveCapacityPendingUnknown.
  ///
  /// In en, this message translates to:
  /// **'Capacity is unavailable because the reserved notional of a pending order cannot be verified.'**
  String get liveCapacityPendingUnknown;

  /// No description provided for @liveCapacityRatesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Fresh collateral conversion rates are unavailable. Refresh before calculating capacity.'**
  String get liveCapacityRatesUnavailable;

  /// No description provided for @liveCapacityRefreshAccount.
  ///
  /// In en, this message translates to:
  /// **'Refresh trading account and limits'**
  String get liveCapacityRefreshAccount;

  /// No description provided for @liveCapacityRefreshAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Sign separately to read configuration, balances, positions, orders, risk tiers and the symbol fee, with up to ten wallet signatures; also refresh public prices and collateral rates. No order is submitted.'**
  String get liveCapacityRefreshAccountHint;

  /// No description provided for @liveCapacityLiquidation.
  ///
  /// In en, this message translates to:
  /// **'Estimated liquidation price after fill'**
  String get liveCapacityLiquidation;

  /// No description provided for @apiRequestTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out.'**
  String get apiRequestTimeout;

  /// No description provided for @apiConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the server. Check your network connection.'**
  String get apiConnectionFailed;

  /// No description provided for @apiRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled.'**
  String get apiRequestCancelled;

  /// No description provided for @apiInvalidResponseAt.
  ///
  /// In en, this message translates to:
  /// **'Aster returned invalid data from {endpoint}. Please retry.'**
  String apiInvalidResponseAt(String endpoint);

  /// No description provided for @apiInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The server returned an invalid response.'**
  String get apiInvalidResponse;

  /// No description provided for @authConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect wallet'**
  String get authConnectTitle;

  /// No description provided for @authVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get authVerifyTitle;

  /// No description provided for @authWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Vanta'**
  String get authWelcome;

  /// No description provided for @authWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect your account to manage assets and trade.'**
  String get authWelcomeDescription;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authEmailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get authEmailPlaceholder;

  /// No description provided for @authEmailContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get authEmailContinue;

  /// No description provided for @authGoogleContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authGoogleContinue;

  /// No description provided for @authXContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue with X'**
  String get authXContinue;

  /// No description provided for @authWalletContinue.
  ///
  /// In en, this message translates to:
  /// **'Connect a wallet'**
  String get authWalletContinue;

  /// No description provided for @authAlternative.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authAlternative;

  /// Login notice with independent links to the terms and privacy documents.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to the {termsOfUse} and {privacyPolicy}.'**
  String authLegalNotice(String termsOfUse, String privacyPolicy);

  /// No description provided for @authTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get authTermsOfUse;

  /// No description provided for @authPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyPolicy;

  /// No description provided for @authCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authCheckEmail;

  /// No description provided for @authCodeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code sent to'**
  String get authCodeDelivery;

  /// No description provided for @authCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired. Request a new code.'**
  String get authCodeExpired;

  /// No description provided for @authBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get authBack;

  /// No description provided for @authClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get authClose;

  /// No description provided for @assistantRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait before trying again.'**
  String get assistantRateLimited;

  /// No description provided for @authVerifyContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get authVerifyContinue;

  /// No description provided for @authSpamHint.
  ///
  /// In en, this message translates to:
  /// **'Check your spam folder if the email hasn’t arrived.'**
  String get authSpamHint;

  /// No description provided for @authResendCountdown.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String authResendCountdown(int seconds);

  /// No description provided for @enableTradingTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable trading'**
  String get enableTradingTitle;

  /// No description provided for @enableTradingHeading.
  ///
  /// In en, this message translates to:
  /// **'One more signature'**
  String get enableTradingHeading;

  /// No description provided for @enableTradingWalletHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm the signature in your wallet. Check your wallet app or browser extensions if nothing pops up.'**
  String get enableTradingWalletHint;

  /// No description provided for @enableTradingEmbeddedHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm one more signature with your connected wallet to enable trading.'**
  String get enableTradingEmbeddedHint;

  /// No description provided for @enableTradingWalletConnected.
  ///
  /// In en, this message translates to:
  /// **'Wallet connected'**
  String get enableTradingWalletConnected;

  /// No description provided for @enableTradingUseAnother.
  ///
  /// In en, this message translates to:
  /// **'Use another wallet'**
  String get enableTradingUseAnother;

  /// No description provided for @enableTradingStep.
  ///
  /// In en, this message translates to:
  /// **'2'**
  String get enableTradingStep;

  /// No description provided for @enableTradingSignHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in your wallet to continue.'**
  String get enableTradingSignHint;

  /// No description provided for @enableTradingEmbeddedSignHint.
  ///
  /// In en, this message translates to:
  /// **'Sign to continue.'**
  String get enableTradingEmbeddedSignHint;

  /// No description provided for @enableTradingScope.
  ///
  /// In en, this message translates to:
  /// **'Authorize a device signing key for 30 days of account queries and gas-free Spot and Futures trading without repeated wallet prompts. Withdrawal access is not granted.'**
  String get enableTradingScope;

  /// No description provided for @enableTradingReturnHint.
  ///
  /// In en, this message translates to:
  /// **'If nothing opens, check your wallet app and return here after signing.'**
  String get enableTradingReturnHint;

  /// No description provided for @enableTradingEmbeddedReturnHint.
  ///
  /// In en, this message translates to:
  /// **'Your connected embedded wallet will sign this trading authorization.'**
  String get enableTradingEmbeddedReturnHint;

  /// No description provided for @enableTradingOpenWallet.
  ///
  /// In en, this message translates to:
  /// **'Open wallet to sign'**
  String get enableTradingOpenWallet;

  /// No description provided for @enableTradingSign.
  ///
  /// In en, this message translates to:
  /// **'Sign to enable trading'**
  String get enableTradingSign;

  /// No description provided for @enableTradingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get enableTradingContinue;

  /// No description provided for @enableTradingWalletSetup.
  ///
  /// In en, this message translates to:
  /// **'Wallet setup'**
  String get enableTradingWalletSetup;

  /// No description provided for @tradeNavigation.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get tradeNavigation;

  /// No description provided for @exploreNavigation.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreNavigation;

  /// No description provided for @portfolioTotalValue.
  ///
  /// In en, this message translates to:
  /// **'Total value'**
  String get portfolioTotalValue;

  /// No description provided for @portfolioLoginHint.
  ///
  /// In en, this message translates to:
  /// **'Log in to view your assets and performance.'**
  String get portfolioLoginHint;

  /// No description provided for @portfolioLoginBalances.
  ///
  /// In en, this message translates to:
  /// **'Log in to view your balances'**
  String get portfolioLoginBalances;

  /// No description provided for @portfolioPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get portfolioPerformance;

  /// No description provided for @portfolioFuturesAssets.
  ///
  /// In en, this message translates to:
  /// **'Futures assets'**
  String get portfolioFuturesAssets;

  /// No description provided for @portfolioPnlDetails.
  ///
  /// In en, this message translates to:
  /// **'PnL details'**
  String get portfolioPnlDetails;

  /// No description provided for @portfolioTodayPnl.
  ///
  /// In en, this message translates to:
  /// **'Today’s PnL'**
  String get portfolioTodayPnl;

  /// No description provided for @portfolioPnl7d.
  ///
  /// In en, this message translates to:
  /// **'PnL · 7D'**
  String get portfolioPnl7d;

  /// No description provided for @portfolioVolume7d.
  ///
  /// In en, this message translates to:
  /// **'Volume · 7D'**
  String get portfolioVolume7d;

  /// No description provided for @portfolioTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer between accounts'**
  String get portfolioTransfer;

  /// No description provided for @portfolioMainAccount.
  ///
  /// In en, this message translates to:
  /// **'Main account'**
  String get portfolioMainAccount;

  /// No description provided for @portfolioPreviewAccount.
  ///
  /// In en, this message translates to:
  /// **'Demo · Static preview'**
  String get portfolioPreviewAccount;

  /// No description provided for @portfolioPreviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Static design sample. No real funds or orders.'**
  String get portfolioPreviewNotice;

  /// No description provided for @portfolioPreviewAction.
  ///
  /// In en, this message translates to:
  /// **'This is a static preview. Switch to your account to continue.'**
  String get portfolioPreviewAction;

  /// No description provided for @portfolioAccountSelector.
  ///
  /// In en, this message translates to:
  /// **'Select account'**
  String get portfolioAccountSelector;

  /// No description provided for @portfolioHideBalance.
  ///
  /// In en, this message translates to:
  /// **'Hide balances'**
  String get portfolioHideBalance;

  /// No description provided for @portfolioShowBalance.
  ///
  /// In en, this message translates to:
  /// **'Show balances'**
  String get portfolioShowBalance;

  /// No description provided for @portfolioValueHistory.
  ///
  /// In en, this message translates to:
  /// **'Total value history'**
  String get portfolioValueHistory;

  /// No description provided for @portfolioCollapseHistory.
  ///
  /// In en, this message translates to:
  /// **'Collapse value history'**
  String get portfolioCollapseHistory;

  /// No description provided for @portfolioOpenHistory.
  ///
  /// In en, this message translates to:
  /// **'Expand value history'**
  String get portfolioOpenHistory;

  /// No description provided for @portfolioMissingPnl.
  ///
  /// In en, this message translates to:
  /// **'PnL data unavailable for this account'**
  String get portfolioMissingPnl;

  /// No description provided for @portfolioMissingDay.
  ///
  /// In en, this message translates to:
  /// **'Daily PnL unavailable'**
  String get portfolioMissingDay;

  /// No description provided for @portfolioMissingValue.
  ///
  /// In en, this message translates to:
  /// **'Value history unavailable for this account'**
  String get portfolioMissingValue;

  /// No description provided for @portfolioPnlNote.
  ///
  /// In en, this message translates to:
  /// **'Historical figures may update after settlement. Missing data is shown as unavailable.'**
  String get portfolioPnlNote;

  /// No description provided for @portfolioCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get portfolioCalendar;

  /// No description provided for @portfolioMonthlyPnl.
  ///
  /// In en, this message translates to:
  /// **'Monthly PnL'**
  String get portfolioMonthlyPnl;

  /// No description provided for @portfolioCalendarNote.
  ///
  /// In en, this message translates to:
  /// **'Daily PnL uses UTC · Values in USD'**
  String get portfolioCalendarNote;

  /// No description provided for @portfolioPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get portfolioPreviousMonth;

  /// No description provided for @portfolioNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get portfolioNextMonth;

  /// No description provided for @portfolioHideOtherSymbols.
  ///
  /// In en, this message translates to:
  /// **'Hide other symbols'**
  String get portfolioHideOtherSymbols;

  /// No description provided for @portfolioHideLowBalances.
  ///
  /// In en, this message translates to:
  /// **'Hide low balance assets'**
  String get portfolioHideLowBalances;

  /// No description provided for @portfolioNoPositions.
  ///
  /// In en, this message translates to:
  /// **'No open positions'**
  String get portfolioNoPositions;

  /// No description provided for @portfolioNoAssets.
  ///
  /// In en, this message translates to:
  /// **'No assets to display'**
  String get portfolioNoAssets;

  /// No description provided for @portfolioAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get portfolioAssets;

  /// No description provided for @portfolioLast7Days.
  ///
  /// In en, this message translates to:
  /// **'PnL · Last 7 days'**
  String get portfolioLast7Days;

  /// No description provided for @portfolioPnlPeriod.
  ///
  /// In en, this message translates to:
  /// **'PnL · {period}'**
  String portfolioPnlPeriod(String period);

  /// No description provided for @portfolioVolumePeriod.
  ///
  /// In en, this message translates to:
  /// **'Volume · {period}'**
  String portfolioVolumePeriod(String period);

  /// No description provided for @portfolioHistoryPeriod.
  ///
  /// In en, this message translates to:
  /// **'Total value history · {period}'**
  String portfolioHistoryPeriod(String period);

  /// No description provided for @portfolioDayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{date} · Daily PnL unavailable'**
  String portfolioDayUnavailable(String date);

  /// No description provided for @portfolioPositionsCount.
  ///
  /// In en, this message translates to:
  /// **'Positions({count})'**
  String portfolioPositionsCount(int count);

  /// No description provided for @portfolioAvailable.
  ///
  /// In en, this message translates to:
  /// **'Avbl. {amount}'**
  String portfolioAvailable(String amount);

  /// No description provided for @portfolioLiquidation.
  ///
  /// In en, this message translates to:
  /// **'Liq.'**
  String get portfolioLiquidation;

  /// No description provided for @portfolioSize.
  ///
  /// In en, this message translates to:
  /// **'Size ({unit})'**
  String portfolioSize(String unit);

  /// No description provided for @portfolioPnlUnit.
  ///
  /// In en, this message translates to:
  /// **'PnL ({unit})'**
  String portfolioPnlUnit(String unit);

  /// No description provided for @portfolioPreview7d.
  ///
  /// In en, this message translates to:
  /// **'7D sample only'**
  String get portfolioPreview7d;

  /// No description provided for @portfolioLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get portfolioLogIn;

  /// No description provided for @portfolioCloseAll.
  ///
  /// In en, this message translates to:
  /// **'Close all'**
  String get portfolioCloseAll;

  /// No description provided for @portfolioMark.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get portfolioMark;

  /// No description provided for @portfolioTpsl.
  ///
  /// In en, this message translates to:
  /// **'TP/SL'**
  String get portfolioTpsl;

  /// No description provided for @portfolioAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get portfolioAll;

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTitle;

  /// No description provided for @accountsSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get accountsSwitchTitle;

  /// No description provided for @accountsManage.
  ///
  /// In en, this message translates to:
  /// **'Manage accounts'**
  String get accountsManage;

  /// No description provided for @accountsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Sub-accounts'**
  String get accountsListTitle;

  /// No description provided for @accountsYourChildren.
  ///
  /// In en, this message translates to:
  /// **'Your sub-accounts'**
  String get accountsYourChildren;

  /// No description provided for @accountsSeparateStrategies.
  ///
  /// In en, this message translates to:
  /// **'Keep strategies separate. Each account has its own address and balance.'**
  String get accountsSeparateStrategies;

  /// No description provided for @accountsDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sub-account details'**
  String get accountsDetailsTitle;

  /// No description provided for @accountsStatusUnverified.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get accountsStatusUnverified;

  /// No description provided for @accountsFreezeRequested.
  ///
  /// In en, this message translates to:
  /// **'Freeze request accepted'**
  String get accountsFreezeRequested;

  /// No description provided for @accountsUnfreezeRequested.
  ///
  /// In en, this message translates to:
  /// **'Unfreeze request accepted'**
  String get accountsUnfreezeRequested;

  /// No description provided for @accountsBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get accountsBalance;

  /// No description provided for @accountsStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get accountsStatus;

  /// No description provided for @accountsAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get accountsAddress;

  /// No description provided for @accountsOwnerWallet.
  ///
  /// In en, this message translates to:
  /// **'Owner wallet'**
  String get accountsOwnerWallet;

  /// No description provided for @accountsAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get accountsAssets;

  /// No description provided for @accountsFreeze.
  ///
  /// In en, this message translates to:
  /// **'Freeze account'**
  String get accountsFreeze;

  /// No description provided for @accountsUnfreeze.
  ///
  /// In en, this message translates to:
  /// **'Unfreeze account'**
  String get accountsUnfreeze;

  /// No description provided for @accountsFreezeTitle.
  ///
  /// In en, this message translates to:
  /// **'Freeze {name}?'**
  String accountsFreezeTitle(String name);

  /// No description provided for @accountsFreezeNotice.
  ///
  /// In en, this message translates to:
  /// **'Cross-account transfers to and from this sub-account will be blocked.'**
  String get accountsFreezeNotice;

  /// No description provided for @accountsReviewOrders.
  ///
  /// In en, this message translates to:
  /// **'Review open positions and orders before continuing.'**
  String get accountsReviewOrders;

  /// No description provided for @accountsIndependentKey.
  ///
  /// In en, this message translates to:
  /// **'This sub-account has a separate private key. Manage access carefully.'**
  String get accountsIndependentKey;

  /// No description provided for @accountsFrozenNotice.
  ///
  /// In en, this message translates to:
  /// **'Transfers remain unavailable while a freeze request is pending or accepted. Confirm the current status with Aster.'**
  String get accountsFrozenNotice;

  /// No description provided for @accountsFreezeBoundary.
  ///
  /// In en, this message translates to:
  /// **'This does not confirm that positions, orders or TP/SL have been stopped.'**
  String get accountsFreezeBoundary;

  /// No description provided for @accountsSwitchTo.
  ///
  /// In en, this message translates to:
  /// **'Switch to this account'**
  String get accountsSwitchTo;

  /// No description provided for @accountsSwitchHeading.
  ///
  /// In en, this message translates to:
  /// **'Switch to {name}'**
  String accountsSwitchHeading(String name);

  /// No description provided for @accountsSwitchNotice.
  ///
  /// In en, this message translates to:
  /// **'Your current account remains active until the switch is confirmed.'**
  String get accountsSwitchNotice;

  /// No description provided for @accountsSwitchConnection.
  ///
  /// In en, this message translates to:
  /// **'Confirm the account switch with a signature from your current wallet.'**
  String get accountsSwitchConnection;

  /// No description provided for @accountsSwitchConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm switch'**
  String get accountsSwitchConfirm;

  /// No description provided for @accountsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create sub-account'**
  String get accountsCreate;

  /// No description provided for @accountsNameHeading.
  ///
  /// In en, this message translates to:
  /// **'Name your account'**
  String get accountsNameHeading;

  /// No description provided for @accountsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Use a name that helps you identify this strategy.'**
  String get accountsNameHint;

  /// No description provided for @accountsName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountsName;

  /// No description provided for @accountsOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get accountsOwner;

  /// No description provided for @accountsNewWallet.
  ///
  /// In en, this message translates to:
  /// **'Independent wallet'**
  String get accountsNewWallet;

  /// No description provided for @accountsNewAccount.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get accountsNewAccount;

  /// No description provided for @accountsSlots.
  ///
  /// In en, this message translates to:
  /// **'Sub-account slots'**
  String get accountsSlots;

  /// No description provided for @accountsCreateNotice.
  ///
  /// In en, this message translates to:
  /// **'Your wallet will ask you to sign. You’ll need to save the new account’s private key.'**
  String get accountsCreateNotice;

  /// No description provided for @accountsSignCreate.
  ///
  /// In en, this message translates to:
  /// **'Sign and create'**
  String get accountsSignCreate;

  /// No description provided for @accountsBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Save your private key'**
  String get accountsBackupTitle;

  /// No description provided for @accountsCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created'**
  String get accountsCreated;

  /// No description provided for @accountsBackupNotice.
  ///
  /// In en, this message translates to:
  /// **'Save the private key before continuing.'**
  String get accountsBackupNotice;

  /// No description provided for @accountsPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Private key'**
  String get accountsPrivateKey;

  /// No description provided for @accountsHiddenKey.
  ///
  /// In en, this message translates to:
  /// **'Hidden by default'**
  String get accountsHiddenKey;

  /// No description provided for @accountsRevealKey.
  ///
  /// In en, this message translates to:
  /// **'Show private key'**
  String get accountsRevealKey;

  /// No description provided for @accountsHideKey.
  ///
  /// In en, this message translates to:
  /// **'Hide private key'**
  String get accountsHideKey;

  /// No description provided for @accountsCopyKey.
  ///
  /// In en, this message translates to:
  /// **'Copy private key'**
  String get accountsCopyKey;

  /// No description provided for @accountsKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this key can control the account. Keep it private and store it safely.'**
  String get accountsKeyWarning;

  /// No description provided for @accountsSavedKey.
  ///
  /// In en, this message translates to:
  /// **'I have saved my private key.'**
  String get accountsSavedKey;

  /// No description provided for @accountsContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get accountsContinue;

  /// No description provided for @accountsBackupPending.
  ///
  /// In en, this message translates to:
  /// **'Back up this wallet'**
  String get accountsBackupPending;

  /// No description provided for @accountsTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer between accounts'**
  String get accountsTransferTitle;

  /// No description provided for @accountsFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get accountsFrom;

  /// No description provided for @accountsTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get accountsTo;

  /// No description provided for @accountsAsset.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get accountsAsset;

  /// No description provided for @accountsAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get accountsAmount;

  /// No description provided for @accountsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get accountsAvailable;

  /// No description provided for @accountsMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get accountsMax;

  /// No description provided for @accountsFutures.
  ///
  /// In en, this message translates to:
  /// **'Futures'**
  String get accountsFutures;

  /// No description provided for @accountsReviewTransfer.
  ///
  /// In en, this message translates to:
  /// **'Review transfer'**
  String get accountsReviewTransfer;

  /// No description provided for @accountsTransferReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review transfer'**
  String get accountsTransferReviewTitle;

  /// No description provided for @accountsTransferSubmit.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get accountsTransferSubmit;

  /// No description provided for @accountsTransferSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Transfer submitted'**
  String get accountsTransferSubmitted;

  /// No description provided for @accountsTransferWaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting final status. Account balances update after confirmation.'**
  String get accountsTransferWaiting;

  /// No description provided for @accountsBackPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Back to Portfolio'**
  String get accountsBackPortfolio;

  /// No description provided for @accountsChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Select account'**
  String get accountsChooseAccount;

  /// No description provided for @accountsChooseAsset.
  ///
  /// In en, this message translates to:
  /// **'Select asset'**
  String get accountsChooseAsset;

  /// No description provided for @accountsNoDestination.
  ///
  /// In en, this message translates to:
  /// **'Create a sub-account before transferring between accounts.'**
  String get accountsNoDestination;

  /// No description provided for @accountsUnknownAddress.
  ///
  /// In en, this message translates to:
  /// **'The directory does not provide this account’s wallet address. Manage it through Aster.'**
  String get accountsUnknownAddress;

  /// No description provided for @accountsTransferBalanceNotice.
  ///
  /// In en, this message translates to:
  /// **'Refresh your Futures balance before reviewing the transfer.'**
  String get accountsTransferBalanceNotice;

  /// No description provided for @subaccountSecureStorageFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot access the device’s secure wallet storage. No new creation request will be sent.'**
  String get subaccountSecureStorageFailed;

  /// No description provided for @subaccountSecureStorageFull.
  ///
  /// In en, this message translates to:
  /// **'The device wallet storage is full. Back up your wallets before continuing.'**
  String get subaccountSecureStorageFull;

  /// No description provided for @subaccountLocalKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'The private key is unavailable on this device. Import your backup into an external wallet to use this account.'**
  String get subaccountLocalKeyMissing;

  /// No description provided for @subaccountCreationFailed.
  ///
  /// In en, this message translates to:
  /// **'The sub-account could not be created. Please try again.'**
  String get subaccountCreationFailed;

  /// No description provided for @subaccountCreationNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Aster did not create this sub-account. Please try again.'**
  String get subaccountCreationNotCompleted;

  /// No description provided for @subaccountNativeTransactionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Import this account into an external wallet to send on-chain transactions.'**
  String get subaccountNativeTransactionUnavailable;

  /// No description provided for @accountsTransferInsufficient.
  ///
  /// In en, this message translates to:
  /// **'The amount exceeds the available Futures balance.'**
  String get accountsTransferInsufficient;

  /// No description provided for @accountsLocalWallets.
  ///
  /// In en, this message translates to:
  /// **'Created on this device'**
  String get accountsLocalWallets;

  /// No description provided for @accountsRemoteDirectory.
  ///
  /// In en, this message translates to:
  /// **'Aster account directory'**
  String get accountsRemoteDirectory;

  /// No description provided for @accountsCreatedBadge.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get accountsCreatedBadge;

  /// No description provided for @accountsTotalAssets.
  ///
  /// In en, this message translates to:
  /// **'Total assets'**
  String get accountsTotalAssets;

  /// No description provided for @accountsSlotsUsed.
  ///
  /// In en, this message translates to:
  /// **'{count} of 10 used'**
  String accountsSlotsUsed(int count);

  /// No description provided for @accountsUnfreezeNotice.
  ///
  /// In en, this message translates to:
  /// **'Cross-account transfers can resume after Aster confirms that the account is unfrozen.'**
  String get accountsUnfreezeNotice;

  /// No description provided for @tradeAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get tradeAskAi;

  /// No description provided for @tradeHigh24h.
  ///
  /// In en, this message translates to:
  /// **'24h High'**
  String get tradeHigh24h;

  /// No description provided for @tradeLow24h.
  ///
  /// In en, this message translates to:
  /// **'24h Low'**
  String get tradeLow24h;

  /// No description provided for @tradeFutures.
  ///
  /// In en, this message translates to:
  /// **'Futures'**
  String get tradeFutures;

  /// No description provided for @tradeSymbols.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get tradeSymbols;

  /// No description provided for @accountsSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get accountsSelect;

  /// No description provided for @accountsDifferentSource.
  ///
  /// In en, this message translates to:
  /// **'Choose a different account from the source.'**
  String get accountsDifferentSource;

  /// No description provided for @accountsTransferUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Transfer unavailable'**
  String get accountsTransferUnavailable;

  /// No description provided for @accountsTransferFreezeHeading.
  ///
  /// In en, this message translates to:
  /// **'A selected account has a freeze request'**
  String get accountsTransferFreezeHeading;

  /// No description provided for @accountsBackTransfer.
  ///
  /// In en, this message translates to:
  /// **'Back to transfer'**
  String get accountsBackTransfer;

  /// No description provided for @accountsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get accountsDone;

  /// No description provided for @accountsSwitchRetry.
  ///
  /// In en, this message translates to:
  /// **'Try switching again'**
  String get accountsSwitchRetry;

  /// No description provided for @accountsSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'{message} {account} is still active.'**
  String accountsSwitchFailed(String message, String account);

  /// No description provided for @accountsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountsAccount;

  /// No description provided for @accountsOpenWallet.
  ///
  /// In en, this message translates to:
  /// **'Open wallet'**
  String get accountsOpenWallet;

  /// No description provided for @accountsConfirmCreation.
  ///
  /// In en, this message translates to:
  /// **'Confirm account creation'**
  String get accountsConfirmCreation;

  /// No description provided for @accountsCreateSummary.
  ///
  /// In en, this message translates to:
  /// **'Create {name}'**
  String accountsCreateSummary(String name);

  /// No description provided for @accountsAuthorizeCreation.
  ///
  /// In en, this message translates to:
  /// **'Authorize creation with your main account wallet. Save the new private key after creation.'**
  String get accountsAuthorizeCreation;

  /// No description provided for @accountsConfirmFreeze.
  ///
  /// In en, this message translates to:
  /// **'Confirm freeze in wallet'**
  String get accountsConfirmFreeze;

  /// No description provided for @accountsConfirmUnfreeze.
  ///
  /// In en, this message translates to:
  /// **'Confirm unfreeze in wallet'**
  String get accountsConfirmUnfreeze;

  /// No description provided for @accountsFreezeAction.
  ///
  /// In en, this message translates to:
  /// **'Freeze'**
  String get accountsFreezeAction;

  /// No description provided for @accountsUnfreezeAction.
  ///
  /// In en, this message translates to:
  /// **'Unfreeze'**
  String get accountsUnfreezeAction;

  /// No description provided for @accountsAuthorizeFreeze.
  ///
  /// In en, this message translates to:
  /// **'Authorize this change with the main account wallet. Cross-account transfers will be restricted.'**
  String get accountsAuthorizeFreeze;

  /// No description provided for @accountsAuthorizeUnfreeze.
  ///
  /// In en, this message translates to:
  /// **'Authorize this change with the main account wallet to restore the account status.'**
  String get accountsAuthorizeUnfreeze;

  /// No description provided for @accountsWithdrawMainOnly.
  ///
  /// In en, this message translates to:
  /// **'Main account only'**
  String get accountsWithdrawMainOnly;

  /// No description provided for @authorizationSecureStorageFailed.
  ///
  /// In en, this message translates to:
  /// **'The device signing key could not be read or saved securely. Check device secure storage and try again.'**
  String get authorizationSecureStorageFailed;

  /// No description provided for @authorizationRequired.
  ///
  /// In en, this message translates to:
  /// **'Trading authorization is missing or expired. Enable trading to read this account without repeated wallet prompts.'**
  String get authorizationRequired;

  /// No description provided for @fundingAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get fundingAccountTitle;

  /// No description provided for @fundingDepositTo.
  ///
  /// In en, this message translates to:
  /// **'Deposit to'**
  String get fundingDepositTo;

  /// No description provided for @fundingWithdrawFrom.
  ///
  /// In en, this message translates to:
  /// **'Withdraw from'**
  String get fundingWithdrawFrom;

  /// No description provided for @fundingNetworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get fundingNetworkLabel;

  /// No description provided for @fundingAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fundingAmountLabel;

  /// No description provided for @fundingBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get fundingBalance;

  /// No description provided for @fundingMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get fundingMax;

  /// No description provided for @fundingNetworkBnb.
  ///
  /// In en, this message translates to:
  /// **'BNB Chain'**
  String get fundingNetworkBnb;

  /// No description provided for @fundingNetworkEthereum.
  ///
  /// In en, this message translates to:
  /// **'Ethereum'**
  String get fundingNetworkEthereum;

  /// No description provided for @fundingNetworkArbitrum.
  ///
  /// In en, this message translates to:
  /// **'Arbitrum'**
  String get fundingNetworkArbitrum;

  /// No description provided for @fundingSelectNetwork.
  ///
  /// In en, this message translates to:
  /// **'Select network'**
  String get fundingSelectNetwork;

  /// No description provided for @fundingSelectAsset.
  ///
  /// In en, this message translates to:
  /// **'Select asset'**
  String get fundingSelectAsset;

  /// No description provided for @fundingDepositTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated deposit time for {network} is 1–3 minutes.'**
  String fundingDepositTime(String network);

  /// No description provided for @fundingApproveAsset.
  ///
  /// In en, this message translates to:
  /// **'Approve {asset}'**
  String fundingApproveAsset(String asset);

  /// No description provided for @fundingGasInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient {asset} for network fees. Enter a smaller amount.'**
  String fundingGasInsufficient(String asset);

  /// No description provided for @fundingConfirmDepositTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm deposit in wallet'**
  String get fundingConfirmDepositTitle;

  /// No description provided for @fundingConfirmDepositHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm the transaction in your wallet to continue.'**
  String get fundingConfirmDepositHint;

  /// No description provided for @fundingApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve {asset} in wallet'**
  String fundingApproveTitle(String asset);

  /// No description provided for @fundingApproveSummary.
  ///
  /// In en, this message translates to:
  /// **'Spending permission'**
  String get fundingApproveSummary;

  /// No description provided for @fundingApproveHint.
  ///
  /// In en, this message translates to:
  /// **'Approve {asset} spending in your wallet before making a deposit.'**
  String fundingApproveHint(String asset);

  /// No description provided for @fundingConfirmWithdrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm withdrawal in wallet'**
  String get fundingConfirmWithdrawTitle;

  /// No description provided for @fundingConfirmWithdrawHint.
  ///
  /// In en, this message translates to:
  /// **'Sign the withdrawal request in your wallet to continue.'**
  String get fundingConfirmWithdrawHint;

  /// No description provided for @fundingOpenWallet.
  ///
  /// In en, this message translates to:
  /// **'Open wallet'**
  String get fundingOpenWallet;

  /// No description provided for @fundingTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get fundingTransactions;

  /// No description provided for @fundingFuturesAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} · Futures Account'**
  String fundingFuturesAmount(String amount);

  /// No description provided for @fundingDepositProcessing.
  ///
  /// In en, this message translates to:
  /// **'Deposit processing'**
  String get fundingDepositProcessing;

  /// No description provided for @fundingStepChainPending.
  ///
  /// In en, this message translates to:
  /// **'On-chain transaction'**
  String get fundingStepChainPending;

  /// No description provided for @fundingStepChainConfirmed.
  ///
  /// In en, this message translates to:
  /// **'On-chain transaction confirmed'**
  String get fundingStepChainConfirmed;

  /// No description provided for @fundingStepCrediting.
  ///
  /// In en, this message translates to:
  /// **'Crediting account'**
  String get fundingStepCrediting;

  /// No description provided for @fundingStepCreditingHint.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your account to be credited.'**
  String get fundingStepCreditingHint;

  /// No description provided for @fundingTrackHint.
  ///
  /// In en, this message translates to:
  /// **'You can close this page and continue tracking in Transactions.'**
  String get fundingTrackHint;

  /// No description provided for @fundingViewTransactions.
  ///
  /// In en, this message translates to:
  /// **'View Transactions'**
  String get fundingViewTransactions;

  /// No description provided for @fundingWithdrawable.
  ///
  /// In en, this message translates to:
  /// **'Withdrawable Amount'**
  String get fundingWithdrawable;

  /// No description provided for @fundingTransactionFee.
  ///
  /// In en, this message translates to:
  /// **'Transaction Fee'**
  String get fundingTransactionFee;

  /// No description provided for @fundingFeeWithUsd.
  ///
  /// In en, this message translates to:
  /// **'{amount} ({usd} USD)'**
  String fundingFeeWithUsd(String amount, String usd);

  /// No description provided for @fundingViewHistory.
  ///
  /// In en, this message translates to:
  /// **'View History in Portfolio'**
  String get fundingViewHistory;

  /// No description provided for @fundingWithdrawChainHint.
  ///
  /// In en, this message translates to:
  /// **'Deposited tokens must be withdrawn on the same chain. USDT profits can use any supported chain.'**
  String get fundingWithdrawChainHint;

  /// No description provided for @fundingWithdrawProcessing.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal processing'**
  String get fundingWithdrawProcessing;

  /// No description provided for @fundingWithdrawCompleted.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal completed'**
  String get fundingWithdrawCompleted;

  /// No description provided for @fundingWithdrawFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal failed'**
  String get fundingWithdrawFailedTitle;

  /// No description provided for @fundingStepNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network confirmation'**
  String get fundingStepNetwork;

  /// No description provided for @fundingStepNetworkHint.
  ///
  /// In en, this message translates to:
  /// **'Waiting for network confirmation.'**
  String get fundingStepNetworkHint;

  /// No description provided for @fundingStepWithdrawCompletion.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal completion'**
  String get fundingStepWithdrawCompletion;

  /// No description provided for @fundingStepWithdrawCompletionHint.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the withdrawal to complete.'**
  String get fundingStepWithdrawCompletionHint;

  /// No description provided for @fundingWithdrawalId.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal ID'**
  String get fundingWithdrawalId;

  /// No description provided for @fundingStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get fundingStatus;

  /// No description provided for @fundingStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get fundingStatusFailed;

  /// No description provided for @fundingWithdrawFailedHint.
  ///
  /// In en, this message translates to:
  /// **'This withdrawal was not completed. Check its final status before trying again.'**
  String get fundingWithdrawFailedHint;

  /// No description provided for @fundingRebalanceRequired.
  ///
  /// In en, this message translates to:
  /// **'Rebalance to withdraw'**
  String get fundingRebalanceRequired;

  /// No description provided for @fundingUsdtBalanceValue.
  ///
  /// In en, this message translates to:
  /// **'USDT balance: {amount}'**
  String fundingUsdtBalanceValue(String amount);

  /// No description provided for @fundingRebalance.
  ///
  /// In en, this message translates to:
  /// **'Rebalance'**
  String get fundingRebalance;

  /// No description provided for @fundingRebalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Use other assets to clear the USDT deficit.'**
  String get fundingRebalanceHint;

  /// No description provided for @fundingUsdtBalance.
  ///
  /// In en, this message translates to:
  /// **'USDT balance'**
  String get fundingUsdtBalance;

  /// No description provided for @fundingRebalanceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Rebalance'**
  String get fundingRebalanceConfirm;

  /// No description provided for @fundingRebalancing.
  ///
  /// In en, this message translates to:
  /// **'Rebalancing…'**
  String get fundingRebalancing;

  /// No description provided for @fundingRebalancingHint.
  ///
  /// In en, this message translates to:
  /// **'Updating your balance. Please wait.'**
  String get fundingRebalancingHint;

  /// No description provided for @assetHistoryFutures.
  ///
  /// In en, this message translates to:
  /// **'Futures'**
  String get assetHistoryFutures;

  /// No description provided for @assetHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get assetHistoryTitle;

  /// No description provided for @assetHistoryDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction details'**
  String get assetHistoryDetails;

  /// No description provided for @assetHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records'**
  String get assetHistoryEmpty;

  /// No description provided for @assetHistoryLoaded.
  ///
  /// In en, this message translates to:
  /// **'All records loaded'**
  String get assetHistoryLoaded;

  /// No description provided for @assetHistoryAmountNetwork.
  ///
  /// In en, this message translates to:
  /// **'{amount} on {network}'**
  String assetHistoryAmountNetwork(String amount, String network);

  /// No description provided for @assetHistoryStatus.
  ///
  /// In en, this message translates to:
  /// **'{status, select, processing{Processing} success{Success} failed{Failed} other{Unknown}}'**
  String assetHistoryStatus(String status);

  /// No description provided for @assetHistoryTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get assetHistoryTime;

  /// No description provided for @assetHistoryTransactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get assetHistoryTransactionId;

  /// No description provided for @assetHistoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get assetHistoryUnavailable;

  /// No description provided for @assetHistoryProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get assetHistoryProgress;

  /// No description provided for @assetHistoryConfirmed.
  ///
  /// In en, this message translates to:
  /// **'On-chain transaction confirmed'**
  String get assetHistoryConfirmed;

  /// No description provided for @assetHistoryConfirmationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'On-chain confirmation unavailable'**
  String get assetHistoryConfirmationUnavailable;

  /// No description provided for @assetHistoryDepositCompleted.
  ///
  /// In en, this message translates to:
  /// **'Deposit completed'**
  String get assetHistoryDepositCompleted;

  /// No description provided for @assetHistoryWithdrawCompleted.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal completed'**
  String get assetHistoryWithdrawCompleted;

  /// No description provided for @assetHistoryCrediting.
  ///
  /// In en, this message translates to:
  /// **'Crediting account'**
  String get assetHistoryCrediting;

  /// No description provided for @assetHistoryWithdrawPending.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal pending'**
  String get assetHistoryWithdrawPending;

  /// No description provided for @portfolioFundingPending.
  ///
  /// In en, this message translates to:
  /// **'{amount} · {type, select, deposit{Waiting to be credited} withdraw{Waiting for completion} other{Processing}}'**
  String portfolioFundingPending(String amount, String type);

  /// No description provided for @fundingBalanceInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient {asset} balance. Enter a smaller amount.'**
  String fundingBalanceInsufficient(String asset);

  /// No description provided for @fundingGasTopUp.
  ///
  /// In en, this message translates to:
  /// **'Insufficient {asset} for network fees. Add {asset} to your wallet.'**
  String fundingGasTopUp(String asset);

  /// No description provided for @fundingWithdrawalFeeInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient {asset} for the withdrawal amount and fee. Enter a smaller amount.'**
  String fundingWithdrawalFeeInsufficient(String asset);

  /// No description provided for @tradeOrderPrice.
  ///
  /// In en, this message translates to:
  /// **'Price ({asset})'**
  String tradeOrderPrice(String asset);

  /// No description provided for @tradeOrderSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get tradeOrderSize;

  /// No description provided for @tradeAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get tradeAdvanced;

  /// No description provided for @tradePriceDown.
  ///
  /// In en, this message translates to:
  /// **'Decrease price'**
  String get tradePriceDown;

  /// No description provided for @tradePriceUp.
  ///
  /// In en, this message translates to:
  /// **'Increase price'**
  String get tradePriceUp;

  /// No description provided for @tradeTpSl.
  ///
  /// In en, this message translates to:
  /// **'TP/SL'**
  String get tradeTpSl;

  /// No description provided for @tradeHiddenOrder.
  ///
  /// In en, this message translates to:
  /// **'Hidden Order'**
  String get tradeHiddenOrder;

  /// No description provided for @tradeSelectPriceType.
  ///
  /// In en, this message translates to:
  /// **'Select Price Type'**
  String get tradeSelectPriceType;

  /// No description provided for @tradeSelectUnitType.
  ///
  /// In en, this message translates to:
  /// **'Select Unit Type'**
  String get tradeSelectUnitType;

  /// No description provided for @tradeTriggerByLast.
  ///
  /// In en, this message translates to:
  /// **'Trigger by Last Price'**
  String get tradeTriggerByLast;

  /// No description provided for @tradeTriggerByMark.
  ///
  /// In en, this message translates to:
  /// **'Trigger by Mark Price'**
  String get tradeTriggerByMark;

  /// No description provided for @tradeTakeProfit.
  ///
  /// In en, this message translates to:
  /// **'Take Profit'**
  String get tradeTakeProfit;

  /// No description provided for @tradeStopLoss.
  ///
  /// In en, this message translates to:
  /// **'Stop Loss'**
  String get tradeStopLoss;

  /// No description provided for @tradeTp.
  ///
  /// In en, this message translates to:
  /// **'TP'**
  String get tradeTp;

  /// No description provided for @tradeSl.
  ///
  /// In en, this message translates to:
  /// **'SL'**
  String get tradeSl;

  /// No description provided for @tradeSelectExitMode.
  ///
  /// In en, this message translates to:
  /// **'Select Input Type'**
  String get tradeSelectExitMode;

  /// No description provided for @tradeExitPnl.
  ///
  /// In en, this message translates to:
  /// **'PnL ({asset})'**
  String tradeExitPnl(String asset);

  /// No description provided for @tradeExitPrice.
  ///
  /// In en, this message translates to:
  /// **'Price ({asset})'**
  String tradeExitPrice(String asset);

  /// No description provided for @tradeExitRoi.
  ///
  /// In en, this message translates to:
  /// **'ROI (%)'**
  String get tradeExitRoi;

  /// No description provided for @livePriceDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Market price connection is disconnected. Reconnecting automatically.'**
  String get livePriceDisconnected;

  /// No description provided for @livePriceConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to market prices.'**
  String get livePriceConnecting;

  /// No description provided for @livePriceMarkMissing.
  ///
  /// In en, this message translates to:
  /// **'The mark price has not been received. Retrying automatically.'**
  String get livePriceMarkMissing;

  /// No description provided for @livePriceMarkInvalid.
  ///
  /// In en, this message translates to:
  /// **'The mark price response is invalid. Retrying automatically.'**
  String get livePriceMarkInvalid;

  /// No description provided for @livePriceMarkStale.
  ///
  /// In en, this message translates to:
  /// **'Mark price updates have stopped. Refreshing automatically.'**
  String get livePriceMarkStale;

  /// No description provided for @livePriceLastMissing.
  ///
  /// In en, this message translates to:
  /// **'The latest trade price has not been received. Retrying automatically.'**
  String get livePriceLastMissing;

  /// No description provided for @livePriceLastInvalid.
  ///
  /// In en, this message translates to:
  /// **'The latest trade price response is invalid. Retrying automatically.'**
  String get livePriceLastInvalid;

  /// No description provided for @livePriceLastStale.
  ///
  /// In en, this message translates to:
  /// **'No recent trade price is available. Refreshing automatically.'**
  String get livePriceLastStale;

  /// No description provided for @livePriceBookMissing.
  ///
  /// In en, this message translates to:
  /// **'The best bid and ask have not been received. Retrying automatically.'**
  String get livePriceBookMissing;

  /// No description provided for @livePriceBookInvalid.
  ///
  /// In en, this message translates to:
  /// **'The best bid and ask response is invalid. Retrying automatically.'**
  String get livePriceBookInvalid;

  /// No description provided for @livePriceBookStale.
  ///
  /// In en, this message translates to:
  /// **'Best bid and ask updates have stopped. Refreshing automatically.'**
  String get livePriceBookStale;

  /// No description provided for @livePriceClockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The exchange time could not be verified. Retrying automatically.'**
  String get livePriceClockUnavailable;

  /// No description provided for @livePriceTimestampInvalid.
  ///
  /// In en, this message translates to:
  /// **'The quote timestamp is ahead of exchange time. Refreshing automatically.'**
  String get livePriceTimestampInvalid;

  /// No description provided for @liveOrderMinimumPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Min {amount}'**
  String liveOrderMinimumPlaceholder(String amount);

  /// No description provided for @notificationFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationFilterAll;

  /// No description provided for @notificationFilterTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get notificationFilterTransfers;

  /// No description provided for @notificationFilterOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get notificationFilterOrders;

  /// No description provided for @notificationUnreadOnly.
  ///
  /// In en, this message translates to:
  /// **'Unread only'**
  String get notificationUnreadOnly;

  /// No description provided for @notificationToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationToday;

  /// No description provided for @notificationPerp.
  ///
  /// In en, this message translates to:
  /// **'Perp'**
  String get notificationPerp;

  /// No description provided for @notificationAdlChip.
  ///
  /// In en, this message translates to:
  /// **'ADL'**
  String get notificationAdlChip;

  /// No description provided for @notificationUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String notificationUnreadCount(int count);

  /// No description provided for @notificationOrderSide.
  ///
  /// In en, this message translates to:
  /// **'{side, select, BUY{buy order} SELL{sell order} other{order}}'**
  String notificationOrderSide(String side);

  /// No description provided for @notificationOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'{status, select, NEW{{symbol} {side} created, awaiting fill.} PARTIALLY_FILLED{{symbol} {side} filled {last} this time; {progress} filled in total.} FILLED{{symbol} {side} fully filled at an average price of {average}.} CANCELED{{symbol} {side} canceled; fills before cancellation remain in history.} EXPIRED{{symbol} {side} expired; the unfilled part will no longer execute.} REJECTED{{symbol} {side} was rejected. Check your order records.} other{{symbol} {side} updated. See details.}}'**
  String notificationOrderSummary(
    String status,
    String symbol,
    String side,
    String last,
    String progress,
    String average,
  );

  /// No description provided for @notificationLiquidationSummary.
  ///
  /// In en, this message translates to:
  /// **'{symbol} liquidation order updated. See details for the filled quantity.'**
  String notificationLiquidationSummary(String symbol);

  /// No description provided for @notificationAdlSummary.
  ///
  /// In en, this message translates to:
  /// **'{symbol} ADL order has a new execution. Review your positions and fills.'**
  String notificationAdlSummary(String symbol);

  /// No description provided for @notificationMarginSummary.
  ///
  /// In en, this message translates to:
  /// **'{symbols} position risk is high. Check your margin and positions promptly.'**
  String notificationMarginSummary(String symbols);

  /// No description provided for @notificationTransferSummary.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, deposit_processing{{amount} deposit to the {market} account is processing. Network: {network}.} deposit_success{{amount} deposited to the {market} account. Network: {network}.} deposit_failed{Your {amount} deposit failed. See details.} withdraw_processing{{amount} withdrawal is processing. Check progress in funding records.} withdraw_success{{amount} withdrawn from the {market} account. Network: {network}.} withdraw_failed{Your {amount} withdrawal failed. See details.} other{{amount} transfer updated.}}'**
  String notificationTransferSummary(String kind, String amount, String market, String network);

  /// No description provided for @livePriceDepthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The selected BBO depth has no supported price reference for capacity estimates.'**
  String get livePriceDepthUnavailable;

  /// No description provided for @livePricePrecisionMissing.
  ///
  /// In en, this message translates to:
  /// **'The exchange did not provide price precision for this market order.'**
  String get livePricePrecisionMissing;

  /// No description provided for @livePriceExecutionInvalid.
  ///
  /// In en, this message translates to:
  /// **'The calculated reference execution price is not positive. Check this contract’s price precision.'**
  String get livePriceExecutionInvalid;

  /// No description provided for @notificationTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'{type, select, deposit{{status, select, processing{Deposit Processing} success{Deposit Successful} failed{Deposit Failed} other{Deposit Update}}} withdraw{{status, select, processing{Withdrawal Processing} success{Withdrawal Successful} failed{Withdrawal Failed} other{Withdrawal Update}}} other{Transfer Update}}'**
  String notificationTransferTitle(String type, String status);

  /// No description provided for @modeAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get modeAccountSettings;

  /// No description provided for @modeAssetTitle.
  ///
  /// In en, this message translates to:
  /// **'Asset Mode'**
  String get modeAssetTitle;

  /// No description provided for @modePositionTitle.
  ///
  /// In en, this message translates to:
  /// **'Position Mode'**
  String get modePositionTitle;

  /// No description provided for @modeSingleShort.
  ///
  /// In en, this message translates to:
  /// **'Single-Asset'**
  String get modeSingleShort;

  /// No description provided for @modeMultiShort.
  ///
  /// In en, this message translates to:
  /// **'Multi-Asset'**
  String get modeMultiShort;

  /// No description provided for @modeSingleTitle.
  ///
  /// In en, this message translates to:
  /// **'Single-Asset Mode'**
  String get modeSingleTitle;

  /// No description provided for @modeMultiTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-Asset Mode'**
  String get modeMultiTitle;

  /// No description provided for @modeSingleDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the pair’s settlement currency as margin.\nPnL offsets across Cross positions of the same currency.\nSupports Cross and Isolated margin.'**
  String get modeSingleDescription;

  /// No description provided for @modeMultiDescription.
  ///
  /// In en, this message translates to:
  /// **'Contracts can be traded across margin assets. Profits and losses with different margin assets can offset one another. Supports Cross margin.'**
  String get modeMultiDescription;

  /// No description provided for @modeReadAboutPrefix.
  ///
  /// In en, this message translates to:
  /// **'Read about '**
  String get modeReadAboutPrefix;

  /// No description provided for @modeReadAboutSuffix.
  ///
  /// In en, this message translates to:
  /// **' to better manage risk.'**
  String get modeReadAboutSuffix;

  /// No description provided for @modeOneWayDescription.
  ///
  /// In en, this message translates to:
  /// **'Hold a single net position per market. Orders in the opposite direction reduce or reverse the position.'**
  String get modeOneWayDescription;

  /// No description provided for @modeHedgeDescription.
  ///
  /// In en, this message translates to:
  /// **'Hold long and short positions separately in the same market.'**
  String get modeHedgeDescription;

  /// No description provided for @modePositionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Close all open positions and cancel all open orders before switching position mode.'**
  String get modePositionBlocked;

  /// No description provided for @modeActivateMulti.
  ///
  /// In en, this message translates to:
  /// **'Activate Multi-Asset Mode'**
  String get modeActivateMulti;

  /// No description provided for @modeMultiRequirements.
  ///
  /// In en, this message translates to:
  /// **'Multi-Asset Mode requires all positions to use Cross Margin. Close any open Isolated positions and cancel their open orders before switching.'**
  String get modeMultiRequirements;

  /// No description provided for @modeAffectedMarkets.
  ///
  /// In en, this message translates to:
  /// **'AFFECTED MARKETS'**
  String get modeAffectedMarkets;

  /// No description provided for @modeManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get modeManage;

  /// No description provided for @modeSwitchCross.
  ///
  /// In en, this message translates to:
  /// **'Switch to Cross'**
  String get modeSwitchCross;

  /// No description provided for @modeRequirementsMet.
  ///
  /// In en, this message translates to:
  /// **'Requirements met'**
  String get modeRequirementsMet;

  /// No description provided for @modeOpenPosition.
  ///
  /// In en, this message translates to:
  /// **'Open position'**
  String get modeOpenPosition;

  /// No description provided for @modeOpenOrders.
  ///
  /// In en, this message translates to:
  /// **'Open orders'**
  String get modeOpenOrders;

  /// No description provided for @modeIsolatedCollateral.
  ///
  /// In en, this message translates to:
  /// **'Isolated collateral remaining'**
  String get modeIsolatedCollateral;

  /// No description provided for @modeNoPositionsOrders.
  ///
  /// In en, this message translates to:
  /// **'No open positions or orders'**
  String get modeNoPositionsOrders;

  /// No description provided for @modeNegativeUsdt.
  ///
  /// In en, this message translates to:
  /// **'Your available USDT assets are negative. Please rebalance your assets before switching asset mode.'**
  String get modeNegativeUsdt;

  /// No description provided for @modeRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh settings'**
  String get modeRefresh;

  /// No description provided for @modeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get modeConfirm;

  /// No description provided for @openOrdersCancelAll.
  ///
  /// In en, this message translates to:
  /// **'Cancel all'**
  String get openOrdersCancelAll;

  /// No description provided for @openOrdersAmountUnit.
  ///
  /// In en, this message translates to:
  /// **'Filled / Total amount ({unit})'**
  String openOrdersAmountUnit(String unit);

  /// No description provided for @openOrdersTriggerCondition.
  ///
  /// In en, this message translates to:
  /// **'{basis} {operator} {price}'**
  String openOrdersTriggerCondition(String basis, String operator, String price);

  /// No description provided for @openOrdersYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get openOrdersYes;

  /// No description provided for @openOrdersNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get openOrdersNo;

  /// No description provided for @openOrdersConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get openOrdersConfirm;

  /// No description provided for @openOrdersDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get openOrdersDetailsTitle;

  /// No description provided for @openOrdersViewChart.
  ///
  /// In en, this message translates to:
  /// **'View {symbol} chart'**
  String openOrdersViewChart(String symbol);

  /// No description provided for @openOrdersCancelAllQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel all perpetual orders?'**
  String get openOrdersCancelAllQuestion;

  /// No description provided for @openOrdersCancelSymbolQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel all {symbol} orders?'**
  String openOrdersCancelSymbolQuestion(String symbol);

  /// No description provided for @openOrdersSide.
  ///
  /// In en, this message translates to:
  /// **'Side'**
  String get openOrdersSide;

  /// No description provided for @openOrdersTab.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openOrdersTab;

  /// No description provided for @openOrdersViewExplorer.
  ///
  /// In en, this message translates to:
  /// **'View Explorer'**
  String get openOrdersViewExplorer;

  /// No description provided for @orderResponseIdentityMismatch.
  ///
  /// In en, this message translates to:
  /// **'Aster returned an order reference, symbol or side that does not match this order.'**
  String get orderResponseIdentityMismatch;

  /// No description provided for @orderResponseLinkageMismatch.
  ///
  /// In en, this message translates to:
  /// **'Aster returned TP/SL links that do not match this order.'**
  String get orderResponseLinkageMismatch;

  /// No description provided for @orderResponseTermsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Aster returned a price, quantity or execution setting that does not match this order.'**
  String get orderResponseTermsMismatch;

  /// No description provided for @orderResponseStatusInvalid.
  ///
  /// In en, this message translates to:
  /// **'Aster returned a missing or unrecognized order status.'**
  String get orderResponseStatusInvalid;

  /// No description provided for @orderResponseMalformed.
  ///
  /// In en, this message translates to:
  /// **'Aster returned incomplete or invalid order fields; the order could not be verified.'**
  String get orderResponseMalformed;

  /// No description provided for @orderAcknowledgementInvalid.
  ///
  /// In en, this message translates to:
  /// **'Aster did not return a valid strategy submission result.'**
  String get orderAcknowledgementInvalid;

  /// No description provided for @openOrdersTpSl.
  ///
  /// In en, this message translates to:
  /// **'TP/SL'**
  String get openOrdersTpSl;

  /// No description provided for @openOrdersLinkedOrder.
  ///
  /// In en, this message translates to:
  /// **'Linked order:'**
  String get openOrdersLinkedOrder;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
