import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/request_scope.dart';
import '../data/open_interest_repository.dart';
import 'market_providers.dart';

final openInterestRepositoryProvider = Provider<OpenInterestRepository>(
  (ref) => OpenInterestRepository(ref.watch(asterServiceProvider)),
);

/// Base-asset open interest of one symbol. Only rows on screen listen, so the
/// list never requests every market; a row scrolled away keeps its value briefly.
final openInterestProvider = FutureProvider.autoDispose.family<Decimal, String>(
  retry: (_, _) => null,
  (ref, symbol) async {
    var current = true;
    final link = ref.keepAlive();
    Timer? release;
    final renew = Timer(const Duration(seconds: 30), ref.invalidateSelf);
    ref.onCancel(() => release = Timer(const Duration(seconds: 30), link.close));
    ref.onResume(() => release?.cancel());
    ref.onDispose(() {
      current = false;
      renew.cancel();
      release?.cancel();
    });
    final value = await RequestScope.run(
      () => current,
      () => ref.read(openInterestRepositoryProvider).read(symbol),
    );
    if (current) ref.read(openInterestCacheProvider.notifier).put(symbol, value);
    return value;
  },
);

/// Last loaded values, used only to order the list by open interest.
final openInterestCacheProvider = NotifierProvider<OpenInterestCache, Map<String, Decimal>>(
  OpenInterestCache.new,
);

class OpenInterestCache extends Notifier<Map<String, Decimal>> {
  @override
  Map<String, Decimal> build() => const {};
  void put(String symbol, Decimal value) {
    if (state[symbol] != value) state = Map.unmodifiable({...state, symbol: value});
  }
}

/// Re-reads the open interest currently on screen and waits for it to settle.
Future<void> refreshOpenInterest(WidgetRef ref) async {
  ref.invalidate(openInterestProvider);
  // Listened rows rebuild, and start their reads, by the end of the frame.
  await WidgetsBinding.instance.endOfFrame;
  await ref.read(openInterestRepositoryProvider).settled();
}
