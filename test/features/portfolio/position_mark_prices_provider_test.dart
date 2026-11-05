import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/application/position_mark_prices_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/mark_prices.dart';
import '../../support/position_risk.dart';
import '../../support/account_updates.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestPositionRiskRepository risk;
  late TestMarkService service;
  setUp(() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    risk = TestPositionRiskRepository();
    service = TestMarkService()..now = DateTime.now();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        positionRiskRepositoryProvider.overrideWithValue(risk),
        asterServiceProvider.overrideWithValue(service),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    await identity.dispose();
    await service.dispose();
  });
  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('opens public transport only after an authenticated nonzero snapshot and ignores chart selection', () async {
    container.read(authProvider);
    final listener = container.listen(positionMarkPricesProvider, (_, _) {});
    await flush();
    expect(service.channels, isEmpty);
    await container.read(positionRiskProvider.notifier).refresh();
    await flush();
    expect(service.channels.single, ['!markPrice@arr@1s']);
    expect(container.read(positionMarkRepositoryProvider)!.symbols, {'BTCUSDT'});
    expect(identity.wallets, 0);
    container.read(symbolProvider.notifier).select('ETHUSDT');
    await flush();
    expect(service.channels.length, 1);
    listener.close();
    await flush();
    expect(service.cancelled, 1);
  });

  test('background stops transport and foreground reopens without another private read', () async {
    container.read(authProvider);
    final listener = container.listen(positionMarkPricesProvider, (_, _) {});
    await flush();
    await container.read(positionRiskProvider.notifier).refresh();
    await flush();
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    await flush();
    expect(service.cancelled, 1);
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await flush();
    expect(service.channels.length, 2);
    expect(risk.calls, 1);
    listener.close();
    await flush();
  });

  test(
    'same-symbol quantity events retain the mark connection; new symbols change its scope',
    () async {
      container.read(authProvider);
      final listener = container.listen(positionMarkPricesProvider, (_, _) {});
      await flush();
      final controller = container.read(positionRiskProvider.notifier);
      await controller.refresh();
      await flush();
      final original = container.read(positionMarkRepositoryProvider);
      controller.applyEvent(accountUpdate());
      await flush();
      expect(container.read(positionMarkRepositoryProvider), same(original));
      expect(service.channels.length, 1);
      controller.applyEvent(
        accountUpdate(
          time: accountEventClock + 1,
          positions: [accountPositionUpdate(symbol: 'NEWUSDT')],
        ),
      );
      await flush();
      expect(container.read(positionMarkRepositoryProvider)!.symbols, {'BTCUSDT', 'NEWUSDT'});
      expect(service.channels.length, 2);
      expect(risk.calls, 1);
      listener.close();
      await flush();
    },
  );

  test(
    'logout clears public marks and drops a pending REST result for the former account',
    () async {
      container.read(authProvider);
      final listener = container.listen(positionMarkPricesProvider, (_, _) {});
      await flush();
      await container.read(positionRiskProvider.notifier).refresh();
      await flush();
      identity.events.add(null);
      await flush();
      expect(service.cancelled, 1);
      service.snapshots.single.complete([markPayload(time: service.serverNow)]);
      await flush();
      expect(container.read(positionMarkRepositoryProvider), null);
      expect(container.read(positionMarkPricesProvider).value?.quotes, isEmpty);
      listener.close();
      await flush();
    },
  );

  test('a zero-quantity isolated debt record never opens a mark feed', () async {
    risk.result = mapPositionRisk(
      [
        positionRiskRow()
          ..['positionAmt'] = '0'
          ..['isolatedWallet'] = '-2',
      ],
      address: accountAddress,
      receivedAt: DateTime.now(),
    );
    container.read(authProvider);
    final listener = container.listen(positionMarkPricesProvider, (_, _) {});
    await flush();
    await container.read(positionRiskProvider.notifier).refresh();
    await flush();
    expect(service.channels, isEmpty);
    expect(service.snapshots, isEmpty);
    listener.close();
    await flush();
  });
}
