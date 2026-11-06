import '../../../core/network/request_scope.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../portfolio/domain/account_snapshot.dart';
import '../data/funding_fee_repository.dart';
import '../domain/funding_fee.dart';

final fundingFeeRepositoryProvider = Provider.autoDispose<FundingFeeRepository>((ref) {
  final service = FundingFeeService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return AsterFundingFeeRepository(service);
});

final fundingFeeProvider = NotifierProvider.autoDispose
    .family<FundingFeeController, FundingFeeState, FundingFeeQuery>(FundingFeeController.new);

class FundingFeeController extends Notifier<FundingFeeState> {
  FundingFeeController(this.query);
  final FundingFeeQuery query;
  Timer? _expiry;
  int _generation = 0;
  @override
  FundingFeeState build() {
    ref.watch(fundingFeeRepositoryProvider);
    ref.onDispose(() {
      _generation++;
      _expiry?.cancel();
    });
    Future.microtask(() {
      if (ref.mounted) unawaited(refresh());
    });
    return const FundingFeeState();
  }

  Future<void>? _refreshTask;
  Future<void> refresh() {
    if (state.loading && _refreshTask != null) return _refreshTask!;
    final task = _refresh();
    _refreshTask = task;
    return task.whenComplete(() {
      if (identical(_refreshTask, task)) _refreshTask = null;
    });
  }

  Future<void> _refresh() async {
    if (!ref.mounted || state.loading) return;
    final generation = ++_generation;
    state = FundingFeeState(quote: state.quote, loading: true, stale: state.stale);
    try {
      final quote = await RequestScope.run(
        () => ref.mounted && generation == _generation,
        () => ref.read(fundingFeeRepositoryProvider).read(query),
      );
      if (!ref.mounted || generation != _generation) return;
      if (quote.query != query) throw const FormatException();
      state = FundingFeeState(quote: quote);
      _expiry?.cancel();
      _expiry = Timer(const Duration(seconds: 30), () {
        if (ref.mounted) {
          state = FundingFeeState(
            quote: state.quote,
            loading: state.loading,
            stale: true,
            failureKey: state.failureKey,
            errorDetails: state.errorDetails,
          );
        }
      });
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = FundingFeeState(
        quote: state.quote,
        stale: state.quote != null,
        errorDetails: error is AccountReadFailure ? error.details : null,
        failureKey: error is AccountReadFailure ? error.key : 'fundingFeeFailed',
      );
    }
  }
}
