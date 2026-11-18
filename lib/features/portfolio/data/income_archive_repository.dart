import 'dart:convert';

import 'package:web3dart/web3dart.dart' as evm;

import '../../../core/errors/api_error_details.dart';
import '../../../core/network/request_scope.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../auth/data/vanta_api_session_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/futures_history.dart';
import '../domain/futures_history_merge.dart';
import '../domain/trading_history.dart';

/// Copies exchange ledger facts into an idempotent archive. These reports do
/// not execute transfers, orders or other financial writes.
class IncomeReportRepository {
  const IncomeReportRepository(this.session, this.source, this.now, {this.isCurrent});
  final VantaApiSessionRepository session;
  final FuturesHistoryRepository source;
  final DateTime Function() now;
  final bool Function()? isCurrent;
  static const path = '/v1/report/income';

  Future<void> synchronize(String address) async {
    final scope = RequestScope.current;
    bool current() =>
        (scope?.active ?? true) &&
        (isCurrent?.call() ?? true) &&
        session.address == address.toLowerCase();
    void check() {
      if (!current()) throw const VantaApiFailure(vantaApiSignInRequired);
    }

    check();
    final pending = [HistoryWindow.recent(now(), const Duration(days: 7))];
    var rows = <FuturesHistoryRecord>[];
    // Read/validate the whole available window before reporting any of it.
    for (var requests = 0; pending.isNotEmpty; requests++) {
      check();
      if (requests == 128) throw const AccountReadFailure('historyTruncated');
      final window = pending.removeLast();
      final page = await source.read(
        address: address,
        query: FuturesHistoryQuery(kind: FuturesHistoryKind.income, window: window),
        isCurrent: current,
        onStep: (_) {},
      );
      check();
      if (page.address.toLowerCase() != address.toLowerCase() ||
          page.query.kind != FuturesHistoryKind.income ||
          page.query.window != window ||
          page.records.any((r) => r is! FuturesIncomeRecord)) {
        throw const VantaApiFailure(vantaApiDataInvalid);
      }
      try {
        rows = mergeFuturesHistory(rows, page.records);
      } on FormatException {
        throw const VantaApiFailure(vantaApiDataInvalid);
      }
      if (page.rawCount == FuturesHistoryPage.limit) {
        final split = window.split();
        if (split.isEmpty) throw const AccountReadFailure('historyTruncated');
        pending.addAll(split);
      }
    }
    final reports = <Map<String, Object?>>[];
    for (final row in rows.cast<FuturesIncomeRecord>()) {
      // tranId is unique only within an incomeType; the archive deduplicates
      // by (incomeType, tranId), so colliding types are reported separately.
      final tradeId = row.tradeId == null ? null : int.tryParse(row.tradeId!);
      if (row.tradeId != null && (tradeId == null || tradeId < 0)) {
        throw const VantaApiFailure(vantaApiDataInvalid);
      }
      reports.add({
        'incomeType': row.type,
        'tranId': row.transactionId,
        'tradeId': ?tradeId,
        'symbol': row.symbol,
        'asset': row.asset,
        'amount': row.income.toString(),
        'reportedAt': row.time.toUtc().toIso8601String(),
      });
    }
    for (final body in reports) {
      check();
      // Stable across refreshes, process restarts and an auth-refresh replay.
      // Include the owner: idempotency never crosses wallet identities.
      final digest = evm.bytesToHex(
        evm.keccak256(utf8.encode(jsonEncode([address.toLowerCase(), body]))),
      );
      final result = await RequestScope.run(
        current,
        () => session.postIdempotent(path, body: body, idempotencyKey: 'income:$digest'),
      );
      check();
      if (result['accepted'] != true ||
          result['report_id'] is! int ||
          result['landed'] is! bool ||
          result['pushed'] is! bool) {
        throw const VantaApiFailure(
          vantaApiDataInvalid,
          details: ApiErrorDetails(cause: ApiErrorCause.invalidResponse, endpoint: path),
        );
      }
    }
  }
}

/// First-page refresh awaits reporting before reading the merged archive.
/// Pagination only reads the archive. Without a device grant it stays readable.
class IncomeArchiveRepository implements TradingHistoryRepository {
  const IncomeArchiveRepository(this.archive, {this.reports, this.canReport});
  final TradingHistoryRepository archive;
  final IncomeReportRepository? reports;
  final bool Function()? canReport;

  @override
  Future<TradingHistoryPage> read(
    TradingHistoryTab tab, {
    required String address,
    TradingHistoryCursor? cursor,
  }) async {
    Object? failure;
    if (tab == TradingHistoryTab.transactions && cursor == null && (canReport?.call() ?? true)) {
      try {
        await reports?.synchronize(address);
      } catch (error) {
        if (RequestScope.current?.active == false) rethrow;
        failure = error;
      }
    }
    final page = await archive.read(tab, address: address, cursor: cursor);
    return TradingHistoryPage(
      address: page.address,
      records: page.records,
      next: page.next,
      partial: page.partial || failure != null,
      refreshFailure: failure ?? page.refreshFailure,
    );
  }
}
