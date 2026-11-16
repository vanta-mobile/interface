import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/network/request_scope.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/auth/data/vanta_api_session_repository.dart';
import 'package:vanta/features/auth/data/vanta_api_session_store.dart';
import 'package:vanta/features/portfolio/data/income_archive_repository.dart';
import 'package:vanta/features/portfolio/data/trading_history_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_history.dart';
import 'package:vanta/features/portfolio/domain/trading_history.dart';

import '../../support/trading_history.dart';
import '../../support/vanta_api.dart';

FuturesIncomeRecord income({
  String id = '123',
  String type = 'FUNDING_FEE',
  String? tradeId,
  String amount = '-0.123456789123456789',
}) => FuturesIncomeRecord(
  symbol: 'BTCUSDT',
  time: vantaTestNow.subtract(const Duration(hours: 1)),
  transactionId: id,
  asset: 'USDT',
  type: type,
  income: Decimal.parse(amount),
  tradeId: tradeId,
);

class IncomeSource implements FuturesHistoryRepository {
  List<FuturesHistoryRecord> records = [income()];
  final queries = <FuturesHistoryQuery>[];
  final currentChecks = <bool Function()>[];
  Completer<void>? gate;
  Object? failure;
  bool saturated = false;
  bool alwaysSaturated = false;
  @override
  Future<FuturesHistoryPage> read({
    required String address,
    required FuturesHistoryQuery query,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    queries.add(query);
    currentChecks.add(isCurrent);
    await gate?.future;
    if (failure case final e?) throw e;
    final filtered = records
        .where(
          (r) =>
              r.time.millisecondsSinceEpoch >= query.window.start &&
              r.time.millisecondsSinceEpoch <= query.window.end,
        )
        .toList();
    return FuturesHistoryPage(
      address: address,
      query: query,
      receivedAt: vantaTestNow,
      records: filtered,
      rawCount: alwaysSaturated || saturated && queries.length == 1 ? 1000 : filtered.length,
    );
  }
}

void main() {
  late Backend backend;
  late VantaApiSessionRepository session;
  late IncomeSource source;
  late IncomeReportRepository reports;
  setUp(() async {
    backend = Backend();
    session = vantaTestRepository(
      backend,
      store: MemoryStore()
        ..value = VantaApiCredentials.fromIssued(
          issued('a', 'r'),
          address: vantaTestAddress,
          receivedAt: vantaTestNow,
        ),
      signer: KeySigner(),
      now: () => vantaTestNow,
    );
    addTearDown(session.close);
    await session.restore(vantaTestAddress);
    source = IncomeSource();
    reports = IncomeReportRepository(session, source, () => vantaTestNow);
    backend.routes['POST /v1/report/income'] = (_) =>
        json({'accepted': true, 'report_id': 1, 'landed': true, 'pushed': false});
    backend.routes['GET /v1/history/income'] = (_) => json(historyPage([historyIncome()]));
  });

  test('all income types report exact facts and stable per-owner idempotency', () async {
    source.records = [
      for (final (index, type) in futuresIncomeTypes.indexed)
        income(
          id: '${100 + index}',
          type: type,
          tradeId: type == 'COMMISSION' ? '9007199254740993' : null,
        ),
    ];
    await reports.synchronize(vantaTestAddress);
    final first = backend.requests.toList();
    expect(first, hasLength(futuresIncomeTypes.length));
    final bodies = first.map((r) => jsonDecode(r.body) as Map<String, dynamic>).toList();
    expect(bodies.map((r) => r['incomeType']).toSet(), futuresIncomeTypes.toSet());
    for (final body in bodies) {
      expect(body['amount'], '-0.123456789123456789');
      expect(body['reportedAt'], vantaTestNow.subtract(const Duration(hours: 1)).toIso8601String());
      expect(body['asset'], 'USDT');
    }
    expect(bodies.singleWhere((r) => r['incomeType'] == 'COMMISSION')['tradeId'], 9007199254740993);
    await reports.synchronize(vantaTestAddress);
    for (var i = 0; i < first.length; i++) {
      expect(backend.requests[i + first.length].body, first[i].body);
      expect(
        backend.requests[i + first.length].headers['Idempotency-Key'],
        first[i].headers['Idempotency-Key'],
      );
    }
    expect(first.map((r) => r.headers['Idempotency-Key']).toSet(), hasLength(first.length));
    expect(
      source.queries.every((q) => q.kind == FuturesHistoryKind.income && q.window.fitsRequest),
      isTrue,
    );
  });

  test('expired session refresh replays only the same archival report', () async {
    var calls = 0;
    backend.routes['POST /v1/report/income'] = (_) => calls++ == 0
        ? json({'code': 'session_expired', 'message': 'Expired'}, 401)
        : json({'accepted': true, 'report_id': 1, 'landed': false, 'pushed': false});
    backend.routes['POST /v1/auth/refresh'] = (_) => json(issued('next', 'next-r'));
    await reports.synchronize(vantaTestAddress);
    final writes = backend.requests
        .where((r) => r.url.path == IncomeReportRepository.path)
        .toList();
    expect(writes, hasLength(2));
    expect(writes[0].body, writes[1].body);
    expect(writes[0].headers['Idempotency-Key'], writes[1].headers['Idempotency-Key']);
  });

  test('saturated window splits without losing or re-reporting boundary rows', () async {
    source.saturated = true;
    await reports.synchronize(vantaTestAddress);
    expect(source.queries, hasLength(3));
    final children = source.queries.skip(1).map((q) => q.window).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    expect(children.first.start, source.queries.first.window.start);
    expect(children.first.end + 1, children.last.start);
    expect(children.last.end, source.queries.first.window.end);
    expect(backend.requests, hasLength(1));
  });

  test('reference collisions and conflicting immutable rows stop before any report', () async {
    source.records = [income(type: 'COMMISSION'), income(type: 'REALIZED_PNL')];
    await expectLater(
      reports.synchronize(vantaTestAddress),
      throwsA(
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'incomeArchiveReferenceConflict'),
      ),
    );
    expect(backend.requests, isEmpty);
    source.records = [income(), income(amount: '100')];
    await expectLater(reports.synchronize(vantaTestAddress), throwsA(isA<VantaApiFailure>()));
    expect(backend.requests, isEmpty);
  });

  test('cancel during source read prevents all late reporting', () async {
    var current = true;
    source.gate = Completer<void>();
    final pending = RequestScope.runOwned(
      () => current,
      () => reports.synchronize(vantaTestAddress),
    );
    await Future<void>.delayed(Duration.zero);
    current = false;
    expect(source.currentChecks.single(), isFalse);
    source.gate!.complete();
    await expectLater(pending, throwsA(isA<VantaApiFailure>()));
    expect(backend.requests, isEmpty);
  });

  test('archive refresh awaits reports, pagination never replays reporting', () async {
    source.gate = Completer<void>();
    final repository = IncomeArchiveRepository(
      ApiTradingHistoryRepository(session),
      reports: reports,
    );
    final pending = repository.read(TradingHistoryTab.transactions, address: vantaTestAddress);
    await Future<void>.delayed(Duration.zero);
    expect(backend.requests, isEmpty);
    source.gate!.complete();
    final result = await pending;
    expect(result.records, hasLength(1));
    expect(backend.paths, ['POST /v1/report/income', 'GET /v1/history/income']);
    await repository.read(
      TradingHistoryTab.transactions,
      address: vantaTestAddress,
      cursor: const TradingHistoryCursor('older'),
    );
    expect(source.queries, hasLength(1));
    expect(backend.requests.last.url.queryParameters['cursor'], 'older');
  });

  test('report failure preserves readable archive with typed failure and partial state', () async {
    backend.routes['POST /v1/report/income'] = (_) =>
        json({'code': 'rate_limited', 'message': 'Archive reporting busy'}, 429);
    final repository = IncomeArchiveRepository(
      ApiTradingHistoryRepository(session),
      reports: reports,
    );
    final result = await repository.read(TradingHistoryTab.transactions, address: vantaTestAddress);
    expect(result.records, hasLength(1));
    expect(result.partial, isTrue);
    expect(
      result.refreshFailure,
      isA<VantaApiFailure>().having((e) => e.details?.message, 'cause', 'Archive reporting busy'),
    );
    expect(backend.paths.where((p) => p.startsWith('POST')), hasLength(1));
  });

  test('without a device grant archive-only reads never query Aster', () async {
    final repository = IncomeArchiveRepository(ApiTradingHistoryRepository(session));
    final result = await repository.read(TradingHistoryTab.transactions, address: vantaTestAddress);
    expect(result.records, hasLength(1));
    expect(source.queries, isEmpty);
    expect(backend.paths, ['GET /v1/history/income']);
  });

  test(
    'one-millisecond saturation never claims a complete import or reports partial rows',
    () async {
      source.alwaysSaturated = true;
      await expectLater(
        reports.synchronize(vantaTestAddress),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'historyTruncated')),
      );
      expect(backend.requests, isEmpty);
    },
  );

  test('invalid acknowledgement is rejected without automatic reporting replay', () async {
    for (final result in [
      {'accepted': false, 'report_id': 1, 'landed': true, 'pushed': false},
      {'accepted': true, 'report_id': 1, 'landed': 'true', 'pushed': false},
    ]) {
      backend.requests.clear();
      backend.routes['POST /v1/report/income'] = (_) => json(result);
      await expectLater(reports.synchronize(vantaTestAddress), throwsA(isA<VantaApiFailure>()));
      expect(backend.requests, hasLength(1));
    }
  });

  test('grant loss during a source read aborts report ownership', () async {
    var active = true;
    final reporting = IncomeReportRepository(
      session,
      source,
      () => vantaTestNow,
      isCurrent: () => active,
    );
    source.gate = Completer<void>();
    final pending = reporting.synchronize(vantaTestAddress);
    await Future<void>.delayed(Duration.zero);
    active = false;
    expect(source.currentChecks.single(), isFalse);
    source.gate!.complete();
    await expectLater(pending, throwsA(isA<VantaApiFailure>()));
    expect(backend.requests, isEmpty);
  });
}
