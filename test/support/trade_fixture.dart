import 'package:vanta/features/market/application/public_leverage_provider.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/application/open_order_strategies_provider.dart';
import 'package:vanta/features/portfolio/domain/open_order_strategy.dart';

import 'aster_open_orders.dart' show TestOpenOrderStrategyRepository;
import 'trading_agents.dart';
import 'identity_repository.dart';

import 'package:vanta/features/portfolio/application/main_order_pricing_provider.dart';
import 'package:vanta/features/portfolio/application/futures_history_provider.dart';
import 'package:vanta/features/portfolio/domain/futures_history.dart';
import 'package:vanta/features/portfolio/application/asset_metadata_provider.dart';

import 'asset_metadata.dart';
import 'main_order_capacity.dart';

import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity.dart';

import 'package:vanta/features/points/application/points_provider.dart';
import 'package:vanta/features/points/domain/points.dart';

import 'points.dart';

import 'package:vanta/features/portfolio/application/spot_open_orders_provider.dart';
import 'package:vanta/features/portfolio/domain/spot_open_orders.dart';

import 'spot_open_orders.dart';

import 'package:vanta/features/funding/application/internal_transfer_provider.dart';
import 'package:vanta/features/funding/application/internal_transfer_storage_provider.dart';
import 'package:vanta/features/funding/domain/internal_transfer.dart';

import 'internal_transfer.dart';

import 'package:vanta/features/portfolio/application/rebalance_provider.dart';
import 'package:vanta/features/portfolio/application/rebalance_storage_provider.dart';
import 'package:vanta/features/portfolio/domain/asset_rebalance.dart';

import 'rebalance.dart';

import 'package:vanta/features/funding/application/deposit_approval_provider.dart';
import 'package:vanta/features/funding/domain/deposit_approval.dart';

import 'deposit_approval.dart';

import 'package:vanta/features/funding/application/funding_catalog_provider.dart';
import 'package:vanta/features/funding/application/withdraw_info_provider.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/domain/withdraw_info.dart';
import 'package:vanta/features/funding/domain/funding_fee.dart';
import 'package:vanta/features/funding/application/funding_fee_provider.dart';
import 'package:vanta/features/funding/application/deposit_wallet_provider.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:vanta/features/funding/application/deposit_gas_provider.dart';
import 'package:vanta/features/funding/domain/deposit_transaction.dart';

import 'deposit_gas.dart';

import 'funding_info.dart';

import 'package:vanta/features/subaccounts/application/subaccount_list_provider.dart';
import 'package:vanta/features/subaccounts/domain/subaccount_directory.dart';
import 'package:vanta/features/portfolio/application/asset_index_provider.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';

import 'asset_indices.dart';
import 'asset_yields.dart';

import 'package:vanta/features/portfolio/application/asset_yield_provider.dart';

import 'package:vanta/features/portfolio/application/spot_account_change_provider.dart';
import 'package:vanta/features/funding/application/transfer_history_provider.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/notifications/data/notification_units_repository.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';

import 'notifications.dart';

import 'package:vanta/features/portfolio/application/quick_order_provider.dart';
import 'package:vanta/features/portfolio/application/order_confirmation_provider.dart';
import 'package:vanta/features/portfolio/domain/quick_order.dart';
import 'package:vanta/features/portfolio/data/order_confirmation_preferences.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/wallet_configuration.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/market/application/market_sync.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/market/data/market_quote_mapper.dart';
import 'package:vanta/features/market/domain/market_quotes.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/aster_spot_account.dart';
import 'package:vanta/features/portfolio/application/spot_account_provider.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';
import 'package:vanta/features/portfolio/application/order_cancellation_provider.dart';
import 'package:vanta/features/portfolio/application/spot_history_provider.dart';
import 'package:vanta/features/portfolio/domain/spot_history.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/market/domain/market.dart';
import 'package:vanta/main.dart';

import 'locale_preferences.dart';

import 'package:vanta/features/portfolio/application/futures_asset_mode_provider.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';

import 'package:vanta/features/portfolio/application/futures_position_mode_provider.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';

import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';

import 'package:vanta/features/market/domain/mark_prices.dart';
import 'package:vanta/features/portfolio/application/position_mark_prices_provider.dart';

import 'package:vanta/features/portfolio/domain/position_adl.dart';
import 'package:vanta/features/portfolio/application/position_adl_provider.dart';

import 'package:vanta/features/portfolio/domain/position_risk.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/application/position_leverage_provider.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';
import 'package:vanta/features/portfolio/application/position_margin_mode_provider.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';

final fixture = Market(
  symbol: 'BTCUSDT',
  price: Decimal.parse('80000'),
  change: -1.6,
  mark: 80001,
  index: 80000,
  high: 81500,
  low: 79000,
  volume: 1000000000,
  funding: .01,
  nextFunding: DateTime.now().millisecondsSinceEpoch + 3600000,
  candles: List.generate(
    200,
    (i) => Candle(
      time: 1793260000000 + i * 60000,
      open: 80000,
      close: 80000 + i.toDouble(),
      high: 80500,
      low: 79500,
      volume: 100 + i.toDouble(),
      eventTime: 1793270000000,
    ),
  ),
);
final book = OrderBook(
  asks: List.generate(20, (i) => BookLevel(80001 + i.toDouble(), .1 + i)),
  bids: List.generate(20, (i) => BookLevel(80000 - i.toDouble(), .1 + i)),
);

Market fixtureMarket(String symbol, String interval) => Market(
  symbol: symbol,
  interval: interval,
  price: fixture.price,
  change: fixture.change,
  mark: fixture.mark,
  index: fixture.index,
  high: fixture.high,
  low: fixture.low,
  volume: fixture.volume,
  funding: fixture.funding,
  nextFunding: fixture.nextFunding,
  candles: fixture.candles,
);
ProviderContainer setup(
  WidgetTester tester, {
  TradingAgentStore? tradingAgentStore,
  PointsRepository? pointsRepository,
  NotificationRepository? notificationRepository,
  NotificationUnitsRepository? notificationUnitsRepository,
  SpotNotificationUnitsRepository? spotNotificationUnitsRepository,
  AccountChangeRepository? spotAccountChangeRepository,
  TransferHistoryRepository? transferHistoryRepository,
  FundingCatalogRepository? fundingCatalogRepository,
  WithdrawInfoRepository? withdrawInfoRepository,
  FundingFeeRepository? fundingFeeRepository,
  DepositWalletRepository? depositWalletRepository,
  DepositGasRepository? depositGasRepository,
  DepositApprovalJournal? depositApprovalJournal,
  DepositApprovalReceiptRepository? depositApprovalReceiptRepository,
  DateTime Function()? depositGasClock,
  SubaccountListRepository? subaccountListRepository,
  AssetIndexRepository? assetIndexRepository,
  DateTime Function()? assetIndexClock,
  double width = 390,
  double scale = 1,
  MarketPrecision precision = const MarketPrecision(),
  Stream<Market>? marketStream,
  Stream<OrderBook>? bookStream,
  Stream<OrderBook> Function(String symbol)? booksForSymbol,
  Future<List<AsterInstrument>> Function()? instrumentsLoader,
  IdentityRepository? identityRepository,
  LiveOrderRepository? liveOrderRepository,
  MainOrderCapacityRepository? mainOrderCapacityRepository,
  QuickOrderRepository? quickOrderRepository,
  OrderConfirmationPreferences? orderConfirmationPreferences,
  OrderRecoveryJournal? recoveryJournal,
  OrderRecoveryRepository? recoveryRepository,
  DateTime Function()? liveClock,
  Stream<MarketQuotes>? quoteStream,
  Locale? language = const Locale('zh'),
  LocalePreferences? localePreferences,
  WalletConnector? walletConnector,
  AsterAccountRepository? asterAccountRepository,
  AsterSpotAccountRepository? asterSpotRepository,
  AsterOpenOrdersRepository? openOrdersRepository,
  OpenOrderStrategyRepository? openOrderStrategyRepository,
  OrderCancellationRepository? orderCancellationRepository,
  BatchOrderCancellationRepository? batchCancellationRepository,
  PositionAdlRepository? positionAdlRepository,
  PositionRiskRepository? positionRiskRepository,
  PositionLeverageRepository? positionLeverageRepository,
  FuturesAssetModeRepository? futuresAssetModeRepository,
  InternalTransferRepository? internalTransferRepository,
  InternalTransferJournal? internalTransferJournal,
  DateTime Function()? internalTransferClock,
  RebalanceRepository? rebalanceRepository,
  RebalanceJournal? rebalanceJournal,
  DateTime Function()? rebalanceClock,
  DateTime Function()? assetModeClock,
  FuturesPositionModeRepository? futuresPositionModeRepository,
  DateTime Function()? positionModeClock,
  PositionMarginModeRepository? positionMarginModeRepository,
  DateTime Function()? marginModeClock,
  DateTime Function()? leverageClock,
  SpotOpenOrdersRepository? spotOpenOrdersRepository,
  SpotHistoryRepository? spotHistoryRepository,
  FuturesHistoryRepository? futuresHistoryRepository,
  DateTime Function()? futuresHistoryClock,
  Stream<MarkPrices>? markPricesStream,
  AccountChangeRepository? accountChangeRepository,
  DateTime Function()? monitorClock,
  DateTime Function()? historyClock,
}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final inboxRepository =
      notificationRepository ?? LocalNotificationRepository(MemoryNotificationStorage());
  if (notificationRepository == null) addTearDown(inboxRepository.dispose);
  final container = ProviderContainer(
    overrides: [
      publicLeverageProvider.overrideWith((ref) async => const {}),
      tradingAgentStoreProvider.overrideWithValue(
        tradingAgentStore ?? MemoryTradingAgentStorage().store(DateTime.now),
      ),
      pointsRepositoryProvider.overrideWithValue(pointsRepository ?? TestPointsRepository()),
      spotOpenOrdersRepositoryProvider.overrideWithValue(
        spotOpenOrdersRepository ?? TestSpotOpenOrdersRepository(),
      ),
      internalTransferRepositoryProvider.overrideWithValue(
        internalTransferRepository ?? TestInternalTransferRepository(),
      ),
      if (internalTransferJournal != null)
        internalTransferJournalProvider.overrideWithValue(internalTransferJournal),
      if (internalTransferClock != null)
        internalTransferClockProvider.overrideWithValue(internalTransferClock),
      rebalanceRepositoryProvider.overrideWithValue(
        rebalanceRepository ?? TestRebalanceRepository(),
      ),
      if (rebalanceJournal != null) rebalanceJournalProvider.overrideWithValue(rebalanceJournal),
      if (rebalanceClock != null) rebalanceClockProvider.overrideWithValue(rebalanceClock),
      fundingCatalogRepositoryProvider.overrideWithValue(
        fundingCatalogRepository ?? TestFundingCatalogRepository(),
      ),
      if (withdrawInfoRepository != null)
        withdrawInfoRepositoryProvider.overrideWithValue(withdrawInfoRepository),
      if (fundingFeeRepository != null)
        fundingFeeRepositoryProvider.overrideWithValue(fundingFeeRepository),
      if (depositWalletRepository != null)
        depositWalletRepositoryProvider.overrideWithValue(depositWalletRepository),
      depositGasRepositoryProvider.overrideWithValue(
        depositGasRepository ?? TestDepositGasRepository(),
      ),
      if (depositApprovalJournal != null)
        depositApprovalJournalProvider.overrideWithValue(depositApprovalJournal),
      depositApprovalReceiptRepositoryProvider.overrideWithValue(
        depositApprovalReceiptRepository ?? TestApprovalReceiptRepository(),
      ),
      if (depositGasClock != null) depositGasClockProvider.overrideWithValue(depositGasClock),
      if (subaccountListRepository != null)
        subaccountListRepositoryProvider.overrideWithValue(subaccountListRepository),
      assetIndexRepositoryProvider.overrideWithValue(
        assetIndexRepository ?? TestAssetIndexRepository(),
      ),
      assetMetadataRepositoryProvider.overrideWithValue(TestAssetMetadataRepository()),
      assetYieldRepositoryProvider.overrideWithValue(TestAssetYieldRepository()),
      if (assetIndexClock != null) assetIndexClockProvider.overrideWithValue(assetIndexClock),
      notificationRepositoryProvider.overrideWithValue(inboxRepository),
      if (transferHistoryRepository != null)
        transferHistoryRepositoryProvider.overrideWithValue(transferHistoryRepository),
      notificationUnitsRepositoryProvider.overrideWithValue(
        notificationUnitsRepository ?? TestNotificationUnitsRepository(),
      ),
      spotNotificationUnitsRepositoryProvider.overrideWithValue(
        spotNotificationUnitsRepository ?? TestSpotNotificationUnitsRepository(),
      ),
      if (spotAccountChangeRepository != null)
        spotAccountChangeRepositoryProvider.overrideWithValue(spotAccountChangeRepository),
      if (monitorClock != null) accountChangeClockProvider.overrideWithValue(monitorClock),
      if (liveOrderRepository != null)
        liveOrderRepositoryProvider.overrideWithValue(liveOrderRepository),
      mainOrderPricingProvider.overrideWith(fixtureBoundedPricing),
      mainOrderCapacityRepositoryProvider.overrideWithValue(
        mainOrderCapacityRepository ?? FixtureCapacityRepository(),
      ),
      if (quickOrderRepository != null)
        quickOrderRepositoryProvider.overrideWithValue(quickOrderRepository),
      if (orderConfirmationPreferences != null)
        orderConfirmationPreferencesProvider.overrideWithValue(orderConfirmationPreferences),
      if (recoveryJournal != null) orderRecoveryJournalProvider.overrideWithValue(recoveryJournal),
      if (recoveryRepository != null)
        orderRecoveryRepositoryProvider.overrideWithValue(recoveryRepository),
      if (liveClock != null) liveOrderClockProvider.overrideWithValue(liveClock),
      if (futuresAssetModeRepository != null)
        futuresAssetModeRepositoryProvider.overrideWithValue(futuresAssetModeRepository),
      if (assetModeClock != null) futuresAssetModeClockProvider.overrideWithValue(assetModeClock),
      if (futuresPositionModeRepository != null)
        futuresPositionModeRepositoryProvider.overrideWithValue(futuresPositionModeRepository),
      if (positionModeClock != null)
        futuresPositionModeClockProvider.overrideWithValue(positionModeClock),
      if (positionMarginModeRepository != null)
        positionMarginModeRepositoryProvider.overrideWithValue(positionMarginModeRepository),
      if (marginModeClock != null)
        positionMarginModeClockProvider.overrideWithValue(marginModeClock),
      if (positionLeverageRepository != null)
        positionLeverageRepositoryProvider.overrideWithValue(positionLeverageRepository),
      if (leverageClock != null) positionLeverageClockProvider.overrideWithValue(leverageClock),
      if (accountChangeRepository != null)
        accountChangeRepositoryProvider.overrideWithValue(accountChangeRepository),
      positionMarkPricesProvider.overrideWith(
        (ref) => markPricesStream ?? Stream.value(MarkPrices()),
      ),
      if (positionAdlRepository != null)
        positionAdlRepositoryProvider.overrideWithValue(positionAdlRepository),
      if (positionRiskRepository != null)
        positionRiskRepositoryProvider.overrideWithValue(positionRiskRepository),
      if (futuresHistoryClock != null)
        futuresHistoryClockProvider.overrideWithValue(futuresHistoryClock),
      if (futuresHistoryRepository != null)
        futuresHistoryRepositoryProvider.overrideWithValue(futuresHistoryRepository),
      if (historyClock != null) spotHistoryClockProvider.overrideWithValue(historyClock),
      if (spotHistoryRepository != null)
        spotHistoryRepositoryProvider.overrideWithValue(spotHistoryRepository),
      if (batchCancellationRepository != null)
        batchOrderCancellationRepositoryProvider.overrideWithValue(batchCancellationRepository),
      if (orderCancellationRepository != null)
        orderCancellationRepositoryProvider.overrideWithValue(orderCancellationRepository),
      if (openOrdersRepository != null)
        asterOpenOrdersRepositoryProvider.overrideWithValue(openOrdersRepository),
      openOrderStrategyRepositoryProvider.overrideWithValue(
        openOrderStrategyRepository ?? TestOpenOrderStrategyRepository(),
      ),
      if (asterSpotRepository != null)
        asterSpotRepositoryProvider.overrideWithValue(asterSpotRepository),
      if (asterAccountRepository != null)
        asterAccountRepositoryProvider.overrideWithValue(asterAccountRepository),
      initialLocaleProvider.overrideWithValue(language),
      localePreferencesProvider.overrideWithValue(localePreferences ?? MemoryLocalePreferences()),
      if (walletConnector != null) ...[
        walletConnectorProvider.overrideWithValue(walletConnector),
        walletConfigurationProvider.overrideWithValue(const WalletConfiguration(projectId: 'test')),
      ],
      if (identityRepository == null)
        identityRepositoryProvider.overrideWith((ref) {
          final repository = TestIdentityRepository();
          ref.onDispose(repository.dispose);
          return repository;
        }),
      if (identityRepository != null) ...[
        identityRepositoryProvider.overrideWithValue(identityRepository),
        privyConfigurationProvider.overrideWithValue(
          const PrivyConfiguration(appId: 'test-app', clientId: 'test-client'),
        ),
      ],
      marketProvider.overrideWith(
        (ref) =>
            marketStream ??
            Stream.value(fixtureMarket(ref.watch(symbolProvider), ref.watch(intervalProvider))),
      ),
      bookProvider.overrideWith(
        (ref) =>
            booksForSymbol?.call(ref.watch(symbolProvider)) ?? bookStream ?? Stream.value(book),
      ),
      marketSyncProvider.overrideWith((ref) => null),
      syncOverviewProvider.overrideWith(
        (ref) => Stream.value(
          const SyncOverview(loaded: 1, total: 1, connected: true, repairing: 0, failed: 0),
        ),
      ),
      liveMarketQuotesProvider.overrideWith((ref) async* {
        if (quoteStream != null) {
          yield* quoteStream;
        } else {
          final instruments = await ref.watch(instrumentsProvider.future);
          yield MarketQuotes(
            quotes: instruments.map(mapMarketQuote),
            connection: QuoteConnection.live,
          );
        }
      }),
      instrumentsProvider.overrideWith(
        (ref) async => instrumentsLoader != null
            ? instrumentsLoader()
            : List.generate(
                100,
                (i) => AsterInstrument(
                  symbol: i == 0
                      ? 'BTCUSDT'
                      : i == 1
                      ? 'ETHUSDT'
                      : 'COIN${i}USDT',
                  base: i == 0
                      ? 'BTC'
                      : i == 1
                      ? 'ETH'
                      : 'COIN$i',
                  ticker: {
                    'lastPrice': '80000',
                    'priceChangePercent': '-1.6',
                    'lastFundingRate': '0.0001',
                    'quoteVolume': '1234567.89',
                  },
                  precision: precision,
                ),
              ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> launch(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const VantaApp()));
  await tester.pumpAndSettle();
}
