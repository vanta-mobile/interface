import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/futures_history_provider.dart';
import 'package:vanta/features/portfolio/data/futures_history_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_history.dart';

import '../../support/aster_account.dart';
import '../../support/futures_history.dart';
import '../../support/identity_repository.dart';

void main() {
  late TestIdentityRepository identity;
  late TestFuturesHistoryRepository repository;
  late ProviderContainer container;
  late FuturesHistoryController controller;
  late DateTime now;
  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestFuturesHistoryRepository();
    now = futuresHistoryNow;
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        futuresHistoryRepositoryProvider.overrideWithValue(repository),
        futuresHistoryClockProvider.overrideWithValue(() => now),
      ],
    );
    container.read(authProvider);
    controller = container.read(futuresHistoryProvider.notifier);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  FuturesHistoryState state() => container.read(futuresHistoryProvider);
  FuturesHistoryPage page(
    FuturesHistoryQuery q, {
    int count = 1,
    int? time,
    List<Object?>? rows,
    DateTime? received,
  }) {
    final mapped = mapFuturesHistory(
      rows ?? [futuresOrderRow(time: time ?? q.window.end, id: '${q.window.end}')],
      address: accountAddress,
      query: q,
      receivedAt: received ?? futuresHistoryNow,
    );
    return FuturesHistoryPage(
      address: accountAddress,
      query: q,
      receivedAt: mapped.receivedAt,
      records: mapped.records,
      rawCount: count,
    );
  }

  test(
    'opening/configuring never signs; a busy read rejects duplicate and filter changes',
    () async {
      expect(repository.queries, isEmpty);
      controller.setSymbol(' BTCUSDT ');
      expect(state().query.symbol, 'BTCUSDT');
      repository.gate = Completer<void>();
      final pending = controller.refresh();
      await controller.refresh();
      controller.setSymbol('ETHUSDT');
      controller.selectKind(FuturesHistoryKind.trades);
      expect(repository.queries, hasLength(1));
      expect(state().query.kind, FuturesHistoryKind.orders);
      repository.gate!.complete();
      await pending;
      expect(state().account!.records, hasLength(1));
      controller.selectKind(FuturesHistoryKind.income);
      expect(state().account, null);
      expect(state().query.symbol, 'BTCUSDT');
      controller.setIncomeType('FUNDING_FEE');
      expect(state().query.incomeType, 'FUNDING_FEE');
    },
  );
  test('trades require symbol and invalid filters never contact repository', () async {
    controller.selectKind(FuturesHistoryKind.trades);
    await controller.refresh();
    expect(state().failure!.key, 'futuresHistoryInvalidSymbol');
    expect(repository.queries, isEmpty);
    controller.setWindow(HistoryWindow.recent(now, const Duration(days: 30)));
    expect(
      state().query.window.start,
      now.subtract(const Duration(days: 30)).millisecondsSinceEpoch + 1,
    );
    controller.setSymbol('BTC&user=x');
    await controller.refresh();
    expect(repository.queries, isEmpty);
    controller.selectKind(FuturesHistoryKind.income);
    controller.setSymbol('');
    controller.setIncomeType('BAD_TYPE');
    await controller.refresh();
    expect(state().failure!.key, 'futuresHistoryInvalidType');
    expect(repository.queries, isEmpty);
  });
  test('invalid time selection retains previous query, data and input', () async {
    await controller.refresh();
    final old = state();
    controller.setWindow(const HistoryWindow(-1, 1));
    expect(state().query, old.query);
    expect(state().account, same(old.account));
    expect(state().failure!.key, 'futuresHistoryInvalidWindow');
  });
  test('long ranges segment less than 7d with no automatic second prompt', () async {
    repository.respond = (q) => page(q);
    controller.setWindow(HistoryWindow.recent(now, const Duration(days: 30)));
    await controller.refresh();
    expect(repository.queries, hasLength(1));
    expect(repository.queries.single.window.fitsRequest, true);
    expect(state().pending, hasLength(1));
    final first = repository.queries.first.window;
    await controller.loadMore();
    expect(repository.queries.last.window.end, first.start - 1);
    expect(state().account!.records, hasLength(2));
  });
  test(
    'saturated response splits inclusive halves, dedupes and waits for manual continuation',
    () async {
      repository.respond = (q) => page(q, count: repository.queries.length == 1 ? 1000 : 1);
      await controller.refresh();
      final query = state().query;
      final halves = query.window.split().reversed.toList();
      expect(state().pending, halves);
      expect(repository.queries, hasLength(1));
      await controller.loadMore();
      expect(state().pending, [halves.last]);
      await controller.loadMore();
      expect(state().pending, isEmpty);
      expect(state().truncated, false);
      expect(state().account!.records, hasLength(2));
      expect(state().account!.query, query);
    },
  );
  test('1000 rows at same millisecond stay explicitly truncated', () async {
    final end = now.millisecondsSinceEpoch;
    controller.setWindow(HistoryWindow(end, end));
    repository.respond = (q) => page(q, count: 1000);
    await controller.refresh();
    expect(state().truncated, true);
    expect(state().pending, isEmpty);
    expect(state().account!.records, hasLength(1));
    await controller.loadMore();
    expect(repository.queries, hasLength(1));
  });
  test(
    'failed continuation retains earlier rows and unconsumed window for explicit retry',
    () async {
      repository.respond = (q) => page(q, count: 1000);
      await controller.refresh();
      final old = state();
      repository.failure = const AccountReadFailure('authWalletRejected');
      await controller.loadMore();
      expect(state().account, same(old.account));
      expect(state().pending, old.pending);
      expect(state().stale, true);
      repository.failure = null;
      repository.respond = (q) => page(q);
      await controller.loadMore();
      expect(state().failure, null);
    },
  );
  test('failed refresh retains historical results and filter', () async {
    controller.setSymbol('BTCUSDT');
    await controller.refresh();
    final old = state().account;
    repository.failure = const AccountReadFailure('accountNetwork');
    await controller.refresh();
    expect(state().account, same(old));
    expect(state().query.symbol, 'BTCUSDT');
    expect(state().stale, true);
  });
  test('background during first read marks incoming result stale', () async {
    repository.gate = Completer<void>();
    final pending = controller.refresh();
    controller.markStale();
    repository.gate!.complete();
    await pending;
    expect(state().account, isNotNull);
    expect(state().stale, true);
  });
  test('metadata-delayed read uses original snapshot age and rejects backwards clock', () async {
    repository.respond = (q) => page(q, received: now.subtract(const Duration(seconds: 31)));
    await controller.refresh();
    expect(state().stale, true);
    repository.respond = (q) => page(q, received: now.add(const Duration(seconds: 1)));
    final old = state().account;
    await controller.refresh();
    expect(state().account, same(old));
    expect(state().failure!.key, 'accountDataInvalid');
  });
  test('stopping a read discards its response and does not supersede a newer one', () async {
    repository.gate = Completer<void>();
    final gate = repository.gate!;
    final old = controller.refresh();
    final oldCurrent = repository.latestCurrent!;
    controller.stopRead();
    expect(oldCurrent(), false);
    repository.gate = null;
    await controller.refresh();
    final next = state().account;
    gate.complete();
    await old;
    expect(state().account, same(next));
    expect(state().busy, false);
  });
  for (final identityChange in [
    const AuthIdentity(
      id: 'different',
      walletAddress: accountAddress,
      walletKind: WalletKind.external,
      signingAvailable: true,
    ),
    const AuthIdentity(
      id: 'aster-test',
      walletAddress: '0x3333333333333333333333333333333333333333',
      walletKind: WalletKind.external,
      signingAvailable: true,
    ),
    const AuthIdentity(
      id: 'aster-test',
      walletAddress: accountAddress,
      walletKind: WalletKind.external,
      signingAvailable: false,
    ),
    const AuthIdentity(
      id: 'aster-test',
      walletAddress: accountAddress,
      walletKind: WalletKind.embedded,
      signingAvailable: true,
    ),
  ]) {
    test(
      'identity/address/kind/signing changes clear private data and pending reads $identityChange',
      () async {
        await controller.refresh();
        repository.gate = Completer<void>();
        final pending = controller.refresh();
        identity.events.add(identityChange);
        await Future<void>.delayed(Duration.zero);
        expect(state().account, null);
        expect(repository.latestCurrent!(), false);
        repository.gate!.complete();
        await pending;
        expect(state().account, null);
        expect(state().pending, isEmpty);
      },
    );
  }
  test('logout clears private data and symbol without wallet creation', () async {
    controller.setSymbol('BTCUSDT');
    await controller.refresh();
    await container.read(authProvider.notifier).logout();
    expect(state().account, null);
    expect(state().query.symbol, '');
    expect(identity.wallets, 0);
  });
  for (final variant in ['wallet', 'query', 'kind', 'scope', 'raw', 'future']) {
    test('invalid page $variant preserves prior partial state', () async {
      repository.respond = (q) => page(q, count: 1000);
      await controller.refresh();
      final old = state();
      repository.respond = (q) {
        final alternate = futuresQuery(FuturesHistoryKind.income, window: q.window);
        final records = variant == 'kind'
            ? mapFuturesHistory(
                [futuresIncomeRow(time: q.window.end)],
                address: accountAddress,
                query: alternate,
                receivedAt: now,
              ).records
            : page(
                variant == 'scope'
                    ? FuturesHistoryQuery(kind: q.kind, window: q.window, symbol: 'ETHUSDT')
                    : q,
                rows: variant == 'scope'
                    ? [
                        {...futuresOrderRow(time: q.window.end), 'symbol': 'ETHUSDT'},
                      ]
                    : null,
              ).records;
        return FuturesHistoryPage(
          address: variant == 'wallet'
              ? '0x3333333333333333333333333333333333333333'
              : accountAddress,
          query: variant == 'query' ? alternate : q,
          receivedAt: variant == 'future' ? now.add(const Duration(seconds: 1)) : now,
          records: records,
          rawCount: variant == 'raw' ? 0 : 1,
        );
      };
      // Make scope mismatch observable even for the default all-symbol query.
      if (variant == 'scope') {
        controller.setSymbol('BTCUSDT');
        repository.respond = (q) => page(q, count: 1000);
        await controller.refresh();
        final records = mapFuturesHistory(
          [
            {...futuresOrderRow(), 'symbol': 'ETHUSDT'},
          ],
          address: accountAddress,
          query: futuresQuery(FuturesHistoryKind.orders, symbol: 'ETHUSDT'),
          receivedAt: now,
        ).records;
        repository.respond = (q) => FuturesHistoryPage(
          address: accountAddress,
          query: q,
          receivedAt: now,
          records: records,
          rawCount: 1,
        );
      }
      final retained = state();
      await controller.loadMore();
      expect(state().account, same(retained.account));
      expect(state().pending, retained.pending);
      expect(state().failure!.key, 'accountDataInvalid');
      expect(old.account, isNotNull);
    });
  }
  test(
    'capacity guard retains 10000 earlier records and pending query instead of eviction',
    () async {
      repository.respond = (q) => page(
        q,
        count: 1000,
        rows: List.generate(
          1000,
          (i) => futuresOrderRow(id: '${repository.queries.length * 1000 + i}', time: q.window.end),
        ),
      );
      await controller.refresh();
      for (var i = 1; i < 10; i++) {
        await controller.loadMore();
      }
      expect(state().account!.records, hasLength(10000));
      final retained = state();
      await controller.loadMore();
      expect(state().failure!.key, 'futuresHistoryCapacity');
      expect(state().account, same(retained.account));
      expect(state().pending, retained.pending);
    },
  );
  test('disposed provider discards late response', () async {
    repository.gate = Completer<void>();
    final pending = controller.refresh();
    container.dispose();
    repository.gate!.complete();
    await pending;
    expect(repository.latestCurrent!(), false);
  });
}
