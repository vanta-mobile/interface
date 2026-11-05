import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/wallet_configuration.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/market/application/market_sync.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/market/data/market_quote_mapper.dart';
import 'package:vanta/features/market/domain/market_quotes.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/main.dart';

import '../support/locale_preferences.dart';
import '../support/notifications.dart' show MemoryNotificationStorage;
import '../support/trade_fixture.dart' show fixtureMarket, book;

/// Uses the real trading UI with fixed public data and an unconfigured wallet.
/// No production entry point, native persistence, signer, or transport is used.
final class PerformanceFixture {
  PerformanceFixture() {
    container = ProviderContainer(
      overrides: [
        asterServiceProvider.overrideWith((ref) {
          transportAccesses++;
          throw StateError('Performance must not access live market transport');
        }),
        initialLocaleProvider.overrideWithValue(const Locale('zh')),
        localePreferencesProvider.overrideWithValue(MemoryLocalePreferences()),
        privyConfigurationProvider.overrideWithValue(
          const PrivyConfiguration(appId: '', clientId: ''),
        ),
        walletConfigurationProvider.overrideWithValue(const WalletConfiguration(projectId: '')),
        notificationRepositoryProvider.overrideWithValue(notifications),
        marketProvider.overrideWith(
          (ref) =>
              Stream.value(fixtureMarket(ref.watch(symbolProvider), ref.watch(intervalProvider))),
        ),
        bookProvider.overrideWith((ref) => Stream.value(book)),
        marketSyncProvider.overrideWith((ref) => null),
        syncOverviewProvider.overrideWith(
          (ref) => Stream.value(
            const SyncOverview(loaded: 1, total: 1, connected: true, repairing: 0, failed: 0),
          ),
        ),
        instrumentsProvider.overrideWith(
          (ref) async => List.generate(
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
              ticker: const {
                'lastPrice': '80000',
                'priceChangePercent': '-1.6',
                'lastFundingRate': '0.0001',
                'quoteVolume': '1234567.89',
              },
            ),
          ),
        ),
        liveMarketQuotesProvider.overrideWith((ref) async* {
          final instruments = await ref.watch(instrumentsProvider.future);
          yield MarketQuotes(
            quotes: instruments.map(mapMarketQuote),
            connection: QuoteConnection.live,
          );
        }),
      ],
    );
  }

  int transportAccesses = 0;
  final notifications = LocalNotificationRepository(MemoryNotificationStorage());
  late final ProviderContainer container;
  Widget get app => UncontrolledProviderScope(container: container, child: const VantaApp());

  Future<void> dispose() async {
    container.dispose();
    await notifications.dispose();
  }
}
