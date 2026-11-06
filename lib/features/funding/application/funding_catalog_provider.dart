import '../../../core/network/request_scope.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../portfolio/domain/account_snapshot.dart';
import '../data/funding_catalog_repository.dart';
import '../domain/funding_catalog.dart';

final fundingCatalogRepositoryProvider = Provider.autoDispose<FundingCatalogRepository>((ref) {
  final service = FundingCatalogService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return AsterFundingCatalogRepository(service);
});
final fundingCatalogProvider = NotifierProvider.autoDispose
    .family<FundingCatalogController, FundingCatalogState, FundingCatalogQuery>(
      FundingCatalogController.new,
    );

class FundingCatalogController extends Notifier<FundingCatalogState> {
  FundingCatalogController(this.query);
  final FundingCatalogQuery query;
  Timer? _expiry;
  int _generation = 0;
  @override
  FundingCatalogState build() {
    ref.watch(fundingCatalogRepositoryProvider);
    ref.onDispose(() {
      _generation++;
      _expiry?.cancel();
    });
    Future.microtask(() {
      if (ref.mounted) unawaited(refresh());
    });
    return const FundingCatalogState();
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
    state = FundingCatalogState(catalog: state.catalog, loading: true, stale: state.stale);
    try {
      final catalog = await RequestScope.run(
        () => ref.mounted && generation == _generation,
        () => ref.read(fundingCatalogRepositoryProvider).read(query),
      );
      if (!ref.mounted || generation != _generation) return;
      if (catalog.query != query) throw const FormatException();
      state = FundingCatalogState(catalog: catalog);
      _expiry?.cancel();
      _expiry = Timer(const Duration(minutes: 5), () {
        if (ref.mounted) {
          state = FundingCatalogState(
            catalog: state.catalog,
            loading: state.loading,
            stale: true,
            failureKey: state.failureKey,
            errorDetails: state.errorDetails,
          );
        }
      });
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = FundingCatalogState(
        catalog: state.catalog,
        stale: state.catalog != null,
        errorDetails: error is AccountReadFailure ? error.details : null,
        failureKey: error is AccountReadFailure ? error.key : 'fundingCatalogFailed',
      );
    }
  }
}
