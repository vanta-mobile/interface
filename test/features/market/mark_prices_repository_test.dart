import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/mark_prices_repository.dart';
import 'package:vanta/features/market/domain/mark_prices.dart';

import '../../support/mark_prices.dart';

void main() {
  test('event age limits freshness even when the delayed REST response just arrived', () async {
    final service = TestMarkService()..now = markClock.add(const Duration(seconds: 9));
    final repository = MarkPricesRepository(service, {'BTCUSDT'}, now: () => service.now);
    final subscription = repository.events.listen((_) {});
    service.controllers.single.add({'connected': true});
    service.snapshots.single.complete([markPayload()]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.fresh, {'BTCUSDT'});
    service.now = service.now.add(const Duration(seconds: 1));
    expect(repository.state.fresh, isEmpty);
    await subscription.cancel();
    await repository.dispose();
    await service.dispose();
  });

  test('repository disposal without a listener releases immediately', () async {
    final service = TestMarkService();
    final repository = MarkPricesRepository(service, {'BTCUSDT'});
    await repository.dispose().timeout(const Duration(seconds: 1));
    expect(service.channels, isEmpty);
    await service.dispose();
  });
  test('starts only requested public stream, merges REST, retains delisted symbols and decimal precision', () async {
    final service = TestMarkService();
    final repository = MarkPricesRepository(service, {
      'BTCUSDT',
      'DELISTEDUSDT',
    }, now: () => service.now);
    final emissions = <MarkPrices>[];
    final subscription = repository.events.listen(emissions.add);
    await Future<void>.delayed(Duration.zero);
    expect(service.channels.single, ['!markPrice@arr@1s']);
    service.controllers.single.add({'connected': true});
    service.snapshots.single.complete([
      markPayload(),
      markPayload(symbol: 'DELISTEDUSDT', price: '0.000000000000000001'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.fresh, {'BTCUSDT', 'DELISTEDUSDT'});
    expect(repository.state.quotes['DELISTEDUSDT']!.price.toString(), '0.000000000000000001');
    final before = emissions.length;
    service.controllers.single.add(markEvent(time: service.serverNow + 1));
    service.controllers.single.add(markEvent(symbol: 'UNWATCHEDUSDT', time: service.serverNow + 1));
    await Future<void>.delayed(Duration.zero);
    expect(emissions.length, before);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(emissions.length, before + 1);
    expect(repository.state.quotes['BTCUSDT']!.price.toString(), '82000.123456789123456789');
    expect(repository.state.quotes.keys, unorderedEquals(['BTCUSDT', 'DELISTEDUSDT']));
    expect(() => repository.state.quotes.clear(), throwsUnsupportedError);
    expect(() => repository.state.fresh.clear(), throwsUnsupportedError);
    await subscription.cancel();
    await repository.dispose();
    await service.dispose();
  });

  test('late REST cannot overwrite stream marks, even with a later response timestamp', () async {
    final service = TestMarkService();
    final repository = MarkPricesRepository(service, {
      'BTCUSDT',
      'ETHUSDT',
    }, now: () => service.now);
    final subscription = repository.events.listen((_) {});
    service.controllers.single.add({'connected': true});
    service.controllers.single.add(markEvent());
    await Future<void>.delayed(Duration.zero);
    service.snapshots.single.complete([
      markPayload(time: service.serverNow + 1),
      markPayload(symbol: 'ETHUSDT'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.quotes['BTCUSDT']!.price.toString(), '82000.123456789123456789');
    expect(repository.state.quotes['ETHUSDT']!.price.toString(), '81000.123456789123456789');
    await subscription.cancel();
    await repository.dispose();
    await service.dispose();
  });

  test('malformed stream during REST bootstrap cannot be revived by its late response', () async {
    final service = TestMarkService();
    final repository = MarkPricesRepository(service, {
      'BTCUSDT',
      'ETHUSDT',
    }, now: () => service.now);
    final subscription = repository.events.listen((_) {});
    service.controllers.single.add({'connected': true});
    service.controllers.single.add(markEvent(price: 'NaN'));
    await Future<void>.delayed(Duration.zero);
    service.snapshots.single.complete([markPayload(), markPayload(symbol: 'ETHUSDT')]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.invalid, {'BTCUSDT'});
    expect(repository.state.quotes.containsKey('BTCUSDT'), false);
    expect(repository.state.fresh, {'ETHUSDT'});
    service.controllers.single.add(markEvent(time: service.serverNow + 1));
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.invalid, isEmpty);
    expect(repository.state.fresh, {'BTCUSDT', 'ETHUSDT'});
    await subscription.cancel();
    await repository.dispose();
    await service.dispose();
  });

  test('events queued while disconnected never verify a reconnected session', () async {
    final service = TestMarkService();
    final repository = MarkPricesRepository(service, {'BTCUSDT'}, now: () => service.now);
    final subscription = repository.events.listen((_) {});
    service.controllers.single.add({'connected': true});
    service.snapshots.single.complete([markPayload()]);
    await Future<void>.delayed(Duration.zero);
    final original = repository.state.quotes['BTCUSDT'];
    service.controllers.single.add({'disconnected': true});
    service.controllers.single.add(markEvent(time: service.serverNow + 1));
    service.controllers.single.add({'connected': true});
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.quotes['BTCUSDT'], same(original));
    expect(repository.state.fresh, isEmpty);
    expect(service.snapshots.length, 2);
    service.snapshots.last.complete([markPayload(time: service.serverNow + 2)]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.fresh, {'BTCUSDT'});
    await subscription.cancel();
    await repository.dispose();
    await service.dispose();
  });

  test('older, duplicate, delayed replay, implausible future and wrong event do not replace current mark', () async {
    final service = TestMarkService();
    final repository = MarkPricesRepository(service, {'BTCUSDT'}, now: () => service.now);
    final subscription = repository.events.listen((_) {});
    service.controllers.single.add({'connected': true});
    service.snapshots.single.complete([]);
    service.controllers.single.add(markEvent());
    await Future<void>.delayed(Duration.zero);
    final original = repository.state.quotes['BTCUSDT'];
    for (final time in [
      service.serverNow - 1,
      service.serverNow,
      service.serverNow - 11000,
      service.serverNow + 11000,
    ]) {
      service.controllers.single.add(markEvent(time: time, price: '1'));
    }
    service.controllers.single.add(
      markEvent(time: service.serverNow + 1, price: '2')..['e'] = '24hrTicker',
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.quotes['BTCUSDT'], same(original));
    await subscription.cancel();
    await repository.dispose();
    await service.dispose();
  });

  test('freshness expires per symbol and repeats do not extend the old event receipt', () async {
    final service = TestMarkService();
    final repository = MarkPricesRepository(service, {
      'BTCUSDT',
      'ETHUSDT',
    }, now: () => service.now);
    final emissions = <MarkPrices>[];
    final subscription = repository.events.listen(emissions.add);
    service.controllers.single.add({'connected': true});
    service.snapshots.single.complete([markPayload(), markPayload(symbol: 'ETHUSDT')]);
    await Future<void>.delayed(Duration.zero);
    final btcFresh = repository.events.firstWhere(
      (value) => value.fresh.length == 1 && value.fresh.contains('BTCUSDT'),
    );
    service.now = service.now.add(const Duration(seconds: 10));
    service.controllers.single.add(markEvent(symbol: 'BTCUSDT', time: service.serverNow));
    service.controllers.single.add(
      markEvent(symbol: 'ETHUSDT', time: markClock.millisecondsSinceEpoch),
    );
    await btcFresh.timeout(const Duration(seconds: 5));
    expect(repository.state.fresh, {'BTCUSDT'});
    expect(emissions.last.fresh, {'BTCUSDT'});
    final expired = repository.events.firstWhere((value) => value.fresh.isEmpty);
    service.now = service.now.add(const Duration(seconds: 10));
    // Wait for the freshness publication, not a wall-clock delay racing the
    // periodic timer under parallel suite load.
    await expired.timeout(const Duration(seconds: 5));
    expect(emissions.last.fresh, isEmpty);
    expect(repository.state.quotes.length, 2);
    await subscription.cancel();
    await repository.dispose();
    await service.dispose();
  });

  test(
    'malformed update preserves value but invalidates only its symbol until a newer valid event',
    () async {
      final service = TestMarkService();
      final repository = MarkPricesRepository(service, {
        'BTCUSDT',
        'ETHUSDT',
      }, now: () => service.now);
      final subscription = repository.events.listen((_) {});
      service.controllers.single.add({'connected': true});
      service.snapshots.single.complete([markPayload(), markPayload(symbol: 'ETHUSDT')]);
      await Future<void>.delayed(Duration.zero);
      final old = repository.state.quotes['BTCUSDT'];
      service.controllers.single.add(markEvent(price: 'NaN', time: service.serverNow + 1));
      await Future<void>.delayed(Duration.zero);
      expect(repository.state.quotes['BTCUSDT'], same(old));
      expect(repository.state.invalid, {'BTCUSDT'});
      expect(repository.state.fresh, {'ETHUSDT'});
      service.controllers.single.add(markEvent(time: service.serverNow + 2));
      await Future<void>.delayed(Duration.zero);
      expect(repository.state.fresh, {'BTCUSDT', 'ETHUSDT'});
      expect(repository.state.invalid, isEmpty);
      await subscription.cancel();
      await repository.dispose();
      await service.dispose();
    },
  );

  test(
    'disconnect and resume require newly verified marks; old REST cannot revive a lost session',
    () async {
      final service = TestMarkService();
      final repository = MarkPricesRepository(service, {'BTCUSDT'}, now: () => service.now);
      final subscription = repository.events.listen((_) {});
      service.controllers.single.add({'connected': true});
      service.controllers.single.add(markEvent());
      await Future<void>.delayed(Duration.zero);
      service.controllers.single.add({'disconnected': true});
      await Future<void>.delayed(Duration.zero);
      expect(repository.state.connection, MarkPriceConnection.offline);
      expect(repository.state.fresh, isEmpty);
      service.snapshots.first.complete([markPayload(time: service.serverNow + 3)]);
      await Future<void>.delayed(Duration.zero);
      expect(repository.state.fresh, isEmpty);
      service.controllers.single.add({'connected': true});
      await Future<void>.delayed(Duration.zero);
      expect(service.snapshots.length, 2);
      expect(repository.state.fresh, isEmpty);
      service.snapshots.last.complete([markPayload(time: service.serverNow + 4)]);
      await Future<void>.delayed(Duration.zero);
      expect(repository.state.fresh, {'BTCUSDT'});
      await repository.setActive(false);
      expect(repository.state.fresh, isEmpty);
      expect(service.cancelled, 1);
      await repository.setActive(true);
      expect(service.controllers.length, 2);
      expect(repository.state.fresh, isEmpty);
      service.controllers.last.add({'connected': true});
      service.controllers.last.add(markEvent(time: service.serverNow + 5));
      await Future<void>.delayed(Duration.zero);
      expect(repository.state.fresh, {'BTCUSDT'});
      await subscription.cancel();
      await repository.dispose();
      await service.dispose();
    },
  );

  test('REST failures and incomplete data preserve stream; explicit reconnect cancels old socket and timers', () async {
    final service = TestMarkService();
    final repository = MarkPricesRepository(service, {
      'BTCUSDT',
      'ETHUSDT',
    }, now: () => service.now);
    final subscription = repository.events.listen((_) {});
    service.controllers.single.add({'connected': true});
    service.controllers.single.add(markEvent());
    service.snapshots.single.completeError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.snapshotFailed, true);
    expect(repository.state.fresh, {'BTCUSDT'});
    await repository.reconnect();
    expect(service.cancelled, 1);
    service.controllers.last.add({'connected': true});
    service.snapshots.last.complete([markPayload(time: service.serverNow + 1)]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.snapshotFailed, true);
    expect(repository.state.fresh, {'BTCUSDT'});
    await subscription.cancel();
    await repository.dispose();
    await service.dispose();
    expect(service.cancelled, 2);
  });
}
