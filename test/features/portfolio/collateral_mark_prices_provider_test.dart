import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/collateral_mark_prices_provider.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';

import '../../support/mark_prices.dart';

void main() {
  const address = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const units = AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'USDT');
  AsterPosition position({
    String symbol = 'BTCUSDT',
    String qty = '2',
    bool? isolated = false,
    AsterContractUnits? contract = units,
    String? entry = '100',
  }) => AsterPosition(
    symbol: symbol,
    side: 'BOTH',
    quantity: Decimal.parse(qty),
    isolated: isolated,
    units: contract,
    entryPrice: entry == null ? null : Decimal.parse(entry),
  );
  late TestMarkService service;
  late ProviderContainer container;
  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    service = TestMarkService()..now = DateTime.now();
    container = ProviderContainer(overrides: [asterServiceProvider.overrideWithValue(service)]);
  });
  tearDown(() async {
    container.dispose();
    await flush();
    await service.dispose();
  });

  test('loaded snapshot opens only anonymous marks without auth or private reader', () async {
    final scope = collateralMarkScope(address, [position()]);
    final sub = container.listen(collateralMarkPricesProvider(scope), (_, _) {});
    await flush();
    expect(service.channels.single, ['!markPrice@arr@1s']);
    expect(service.snapshots.length, 1);
    expect(container.read(collateralMarkRepositoryProvider(scope))!.symbols, {'BTCUSDT'});
    expect(container.exists(authProvider), false);
    expect(container.exists(identityRepositoryProvider), false);
    expect(container.exists(accountReadProvider), false);
    expect(container.exists(asterAccountRepositoryProvider), false);
    sub.close();
    await flush();
    expect(service.cancelled, 1);
  });

  test(
    'account-wide sorted deduplicated scope shares transport despite ordering/quantity/case',
    () async {
      final scope = collateralMarkScope(address, [
        position(symbol: 'ETHUSDT'),
        position(),
        position(),
      ]);
      final same = collateralMarkScope(address.toUpperCase(), [
        position(qty: '9'),
        position(symbol: 'ETHUSDT'),
      ]);
      expect(scope, same);
      final a = container.listen(collateralMarkPricesProvider(scope), (_, _) {});
      final b = container.listen(collateralMarkPricesProvider(same), (_, _) {});
      await flush();
      expect(service.channels.length, 1);
      expect(container.read(collateralMarkRepositoryProvider(scope))!.symbols, {
        'BTCUSDT',
        'ETHUSDT',
      });
      a.close();
      await flush();
      expect(service.cancelled, 0);
      b.close();
      await flush();
      expect(service.cancelled, 1);
      expect(container.exists(collateralMarkPricesProvider(scope)), false);
      expect(container.exists(collateralMarkRepositoryProvider(scope)), false);
    },
  );

  test(
    'zero/isolated/unknown mode/unknown or nonlinear units/invalid entry do not request marks',
    () async {
      final scope = collateralMarkScope(address, [
        position(qty: '0'),
        position(isolated: true),
        position(isolated: null),
        position(contract: null),
        position(entry: null),
        position(entry: '0'),
        position(
          contract: const AsterContractUnits(base: 'BTC', quote: 'USD', margin: 'BTC'),
        ),
      ]);
      final sub = container.listen(collateralMarkPricesProvider(scope), (_, _) {});
      await flush();
      expect(scope.symbols, isEmpty);
      expect(service.channels, isEmpty);
      expect(service.snapshots, isEmpty);
      expect(container.read(collateralMarkRepositoryProvider(scope)), null);
      expect(container.read(collateralMarkPricesProvider(scope)).value!.quotes, isEmpty);
      sub.close();
    },
  );

  test('missing wallet scope does not open public transport', () async {
    final scope = collateralMarkScope('', [position()]);
    final sub = container.listen(collateralMarkPricesProvider(scope), (_, _) {});
    await flush();
    expect(service.channels, isEmpty);
    expect(service.snapshots, isEmpty);
    sub.close();
  });

  test(
    'background cancels; foreground resumes without initializing private account reads',
    () async {
      final scope = collateralMarkScope(address, [position()]);
      final sub = container.listen(collateralMarkPricesProvider(scope), (_, _) {});
      await flush();
      container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
      await flush();
      expect(service.cancelled, 1);
      container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
      await flush();
      expect(service.channels.length, 2);
      expect(service.snapshots.length, 2);
      expect(container.exists(accountReadProvider), false);
      expect(container.exists(authProvider), false);
      sub.close();
      await flush();
    },
  );

  test('an initially backgrounded card waits until foreground to request marks', () async {
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    final sub = container.listen(
      collateralMarkPricesProvider(collateralMarkScope(address, [position()])),
      (_, _) {},
    );
    await flush();
    expect(service.channels, isEmpty);
    expect(service.snapshots, isEmpty);
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await flush();
    expect(service.channels.length, 1);
    sub.close();
    await flush();
  });

  test(
    'changing wallet isolates old pending marks; disposal ignores late public response',
    () async {
      final oldScope = collateralMarkScope(address, [position()]);
      final old = container.listen(collateralMarkPricesProvider(oldScope), (_, _) {});
      await flush();
      old.close();
      await flush();
      final newScope = collateralMarkScope('0x${'bb' * 20}', [position()]);
      final next = container.listen(collateralMarkPricesProvider(newScope), (_, _) {});
      await flush();
      expect(service.cancelled, 1);
      expect(service.channels.length, 2);
      service.snapshots.first.complete([markPayload(time: service.serverNow)]);
      await flush();
      expect(container.exists(collateralMarkRepositoryProvider(oldScope)), false);
      expect(container.read(collateralMarkPricesProvider(newScope)).value?.quotes, isEmpty);
      next.close();
      await flush();
    },
  );
}
