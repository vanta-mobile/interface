import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/spot_history_provider.dart';
import 'package:vanta/features/portfolio/data/spot_history_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/spot_history.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/spot_history.dart';

void main() {
  late TestIdentityRepository identity;
  late TestSpotHistoryRepository repository;
  late ProviderContainer container;
  late SpotHistoryController controller;
  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestSpotHistoryRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        spotHistoryRepositoryProvider.overrideWithValue(repository),
        spotHistoryClockProvider.overrideWithValue(() => historyNow),
      ],
    );
    container.read(authProvider);
    controller = container.read(spotHistoryProvider.notifier);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  SpotHistoryState getState() => container.read(spotHistoryProvider);
  SpotHistoryPage page(SpotHistoryQuery q, {int rawCount = 1, List<Object?>? rows}) {
    final mapped = mapSpotHistory(
      rows ?? [spotOrderRow(id: '${q.window.end}', time: q.window.end)],
      address: accountAddress,
      query: q,
      receivedAt: historyNow,
    );
    return SpotHistoryPage(
      address: accountAddress,
      query: q,
      receivedAt: historyNow,
      records: mapped.records,
      rawCount: rawCount,
    );
  }

  test('opening history and changing filters never reads; loading prevents duplicates and scope changes', () async {
    expect(repository.queries, isEmpty);
    controller.setScope(' BNBUSDT ');
    expect(getState().query.scope, 'BNBUSDT');
    repository.gate = Completer<void>();
    final pending = controller.refresh();
    await controller.refresh();
    controller.setScope('BTCUSDT');
    controller.selectKind(SpotHistoryKind.trades);
    expect(repository.queries.length, 1);
    expect(getState().query.kind, SpotHistoryKind.orders);
    expect(getState().query.scope, 'BNBUSDT');
    repository.gate!.complete();
    await pending;
    expect(getState().account!.records.length, 1);
    expect(getState().pending, isEmpty);
    controller.selectKind(SpotHistoryKind.transactions);
    expect(getState().account, null);
    expect(getState().query.scope, isEmpty);
    expect(repository.queries.length, 1);
  });

  test(
    'saturated response is incomplete until explicit reads cover both inclusive halves',
    () async {
      repository.respond = (q) => page(q, rawCount: repository.queries.length == 1 ? 1000 : 1);
      await controller.refresh();
      final originalQuery = getState().query;
      final firstTime = getState().account!.receivedAt;
      expect(getState().pending.length, 2);
      expect(repository.queries.length, 1);
      final halves = originalQuery.window.split().reversed.toList();
      expect(getState().pending, halves);
      await controller.loadMore();
      expect(repository.queries[1].window, halves[0]);
      expect(getState().pending, [halves[1]]);
      await controller.loadMore();
      expect(repository.queries[2].window, halves[1]);
      expect(getState().query, same(originalQuery));
      expect(getState().pending, isEmpty);
      expect(getState().truncated, false);
      expect(getState().account!.records.length, 2);
      expect(getState().account!.receivedAt, firstTime);
      await controller.loadMore();
      expect(repository.queries.length, 3);
    },
  );

  test('failed continuation keeps data and exact pending range; retry never auto-pages', () async {
    repository.respond = (q) => page(q, rawCount: 1000);
    await controller.refresh();
    final old = getState();
    repository.failure = const AccountReadFailure('authWalletRejected');
    await controller.loadMore();
    expect(getState().account, same(old.account));
    expect(getState().pending, old.pending);
    expect(getState().stale, true);
    expect(getState().failure!.key, 'authWalletRejected');
    repository.failure = null;
    repository.respond = (q) => page(q);
    await controller.loadMore();
    expect(repository.queries[2], repository.queries[1]);
    expect(repository.queries.length, 3);
    expect(getState().pending.length, 1);
  });

  test(
    'one-millisecond overflow remains explicitly truncated with no infinite pagination',
    () async {
      controller.setWindow(const HistoryWindow(42, 42));
      repository.respond = (q) => page(q, rawCount: 1000);
      await controller.refresh();
      expect(getState().truncated, true);
      expect(getState().pending, isEmpty);
      await controller.loadMore();
      expect(repository.queries.length, 1);
      expect(getState().account!.records.length, 1);
    },
  );

  test('long trade history reads seven-day segments only on request with a fixed end', () async {
    controller.selectKind(SpotHistoryKind.trades);
    final range = HistoryWindow.recent(historyNow, const Duration(days: 20));
    controller.setWindow(range);
    repository.respond = (q) => mapSpotHistory(
      [spotTradeRow(id: '${q.window.end}', time: q.window.end)],
      address: accountAddress,
      query: q,
      receivedAt: historyNow,
    );
    await controller.refresh();
    expect(repository.queries.length, 1);
    expect(getState().pending, isNotEmpty);
    await controller.loadMore();
    await controller.loadMore();
    final windows = repository.queries.map((q) => q.window).toList();
    expect(windows.every((w) => w.fitsRequest), true);
    expect(windows.first.end, range.end);
    expect(windows.last.start, range.start);
    expect(windows[1].end + 1, windows[0].start);
    expect(windows[2].end + 1, windows[1].start);
    expect(getState().pending, isEmpty);
    expect(getState().account!.records.length, 3);
    controller.selectKind(SpotHistoryKind.orders);
    expect(getState().query.window.fitsRequest, true);
  });

  test('stopping a pending read releases controls and drops late records', () async {
    repository.gate = Completer<void>();
    final pending = controller.refresh();
    controller.stopRead();
    expect(getState().busy, false);
    expect(getState().failure!.key, 'historyReadStopped');
    repository.gate!.complete();
    await pending;
    expect(getState().account, null);
    expect(repository.queries.length, 1);
    repository.gate = null;
    await controller.refresh();
    expect(getState().account, isNotNull);
    expect(repository.queries.length, 2);
  });

  test('older overlapping versions cannot resurrect a cancelled order', () async {
    controller.setWindow(const HistoryWindow(0, 99));
    repository.respond = (q) => switch (repository.queries.length) {
      1 => page(
        q,
        rawCount: 1000,
        rows: [spotOrderRow(id: 1, time: 75, updated: 95, status: 'CANCELED')],
      ),
      2 => page(q, rows: [spotOrderRow(id: 1, time: 75, updated: 80, status: 'NEW')]),
      _ => page(q, rows: [spotOrderRow(id: 2, time: 25)]),
    };
    await controller.refresh();
    await controller.loadMore();
    await controller.loadMore();
    final records = getState().account!.records.cast<SpotOrderRecord>();
    expect(records.length, 2);
    expect(records.firstWhere((r) => r.orderId == '1').status, 'CANCELED');
  });

  test(
    'failed refresh preserves previous records and scope; a successful refresh replaces coverage',
    () async {
      await controller.refresh();
      final old = getState().account;
      repository.failure = const AccountReadFailure('accountNetwork');
      await controller.refresh();
      expect(getState().account, same(old));
      expect(getState().failure!.key, 'accountNetwork');
      repository.failure = null;
      repository.records = [];
      await controller.refresh();
      expect(getState().account!.records, isEmpty);
      expect(getState().failure, null);
      expect(getState().stale, false);
    },
  );

  test('logout and restore of same wallet discard in-flight records and previous scopes', () async {
    controller.setScope('BNBUSDT');
    repository.gate = Completer<void>();
    final pending = controller.refresh();
    identity.events.add(null);
    await container.read(authProvider.notifier).bootstrap();
    repository.gate!.complete();
    await pending;
    expect(getState().account, null);
    expect(getState().query.scope, isEmpty);
    expect(getState().busy, false);
    expect(repository.queries.length, 1);
  });

  test('wrong wallet, query, record kind or scope cannot replace a valid partial result', () async {
    repository.respond = (q) => page(q, rawCount: 1000);
    await controller.refresh();
    final old = getState();
    for (final variant in [0, 1, 2, 3]) {
      repository.respond = (q) {
        final alternate = SpotHistoryQuery(
          kind: SpotHistoryKind.transactions,
          window: q.window,
          scope: 'ASTER',
        );
        final tx = mapSpotHistory(
          [spotTransactionRow(time: q.window.end)],
          address: accountAddress,
          query: alternate,
          receivedAt: historyNow,
        ).records;
        return SpotHistoryPage(
          address: variant == 0 ? '0x3333333333333333333333333333333333333333' : accountAddress,
          query: variant == 1 ? alternate : q,
          receivedAt: historyNow,
          records: variant == 2
              ? tx
              : variant == 3
              ? page(q).records.map(
                  (r) => SpotOrderRecord(
                    symbol: 'WRONG',
                    time: DateTime.utc(2050),
                    orderId: '2',
                    side: 'BUY',
                    type: 'LIMIT',
                    status: 'NEW',
                    updatedAt: DateTime.utc(2050),
                    quantity: (r as SpotOrderRecord).quantity,
                    executed: r.executed,
                    price: r.price,
                    quoteFilled: r.quoteFilled,
                  ),
                )
              : page(q).records,
          rawCount: 1,
        );
      };
      await controller.loadMore();
      expect(getState().account, same(old.account));
      expect(getState().pending, old.pending);
      expect(getState().failure!.key, 'accountDataInvalid');
    }
  });

  test(
    'invalid scope or oversized window never signs and leaves valid time selection intact',
    () async {
      final window = getState().query.window;
      controller.setWindow(HistoryWindow.recent(historyNow, const Duration(days: 8)));
      expect(getState().query.window, window);
      expect(getState().failure!.key, 'historyInvalidWindow');
      controller.setScope('BNB USDT');
      await controller.refresh();
      expect(getState().failure!.key, 'historyInvalidScope');
      expect(repository.queries, isEmpty);
    },
  );

  test('background revision during read keeps successful result visibly stale', () async {
    repository.gate = Completer<void>();
    final pending = controller.refresh();
    controller.markStale();
    repository.gate!.complete();
    await pending;
    expect(getState().account, isNotNull);
    expect(getState().stale, true);
  });

  test('dispose discards a late result safely', () async {
    repository.gate = Completer<void>();
    final pending = controller.refresh();
    container.dispose();
    repository.gate!.complete();
    await pending;
    expect(repository.queries.length, 1);
  });
}
