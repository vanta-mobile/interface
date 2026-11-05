import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/order_confirmation_preferences.dart';
import '../domain/order_confirmation.dart';

final orderConfirmationPreferencesProvider = Provider<OrderConfirmationPreferences>(
  (_) => LocalOrderConfirmationPreferences(),
);

class OrderConfirmationState {
  const OrderConfirmationState({this.required = true, this.loading = false, this.failure = false});
  final bool required, loading, failure;
  bool get canSkip => !required && !loading && !failure;
}

final orderConfirmationProvider =
    NotifierProvider.family<
      OrderConfirmationController,
      OrderConfirmationState,
      OrderConfirmationKind
    >(OrderConfirmationController.new);
// Both quick entry and the main ordinary market form use this exact instance.
final marketOrderConfirmationProvider = orderConfirmationProvider(OrderConfirmationKind.market);

class OrderConfirmationController extends Notifier<OrderConfirmationState> {
  OrderConfirmationController(this.kind);
  final OrderConfirmationKind kind;
  int _revision = 0;
  bool _saved = true;
  Future<void> _writes = Future.value();
  @override
  OrderConfirmationState build() {
    ref.onDispose(() => _revision++);
    final revision = _revision;
    unawaited(Future<void>.microtask(() => _load(revision)));
    return const OrderConfirmationState(loading: true);
  }

  Future<void> _load(int revision) async {
    if (!ref.mounted || revision != _revision) return;
    try {
      final value = await ref.read(orderConfirmationPreferencesProvider).read(kind);
      if (ref.mounted && revision == _revision) {
        _saved = value;
        state = OrderConfirmationState(required: value);
      }
    } catch (_) {
      if (ref.mounted && revision == _revision) state = const OrderConfirmationState(failure: true);
    }
  }

  Future<void> select(bool required) async {
    final revision = ++_revision;
    final store = ref.read(orderConfirmationPreferencesProvider);
    state = OrderConfirmationState(required: _saved, loading: true);
    try {
      _writes = _writes.catchError((Object _) {}).then((_) async {
        await store.write(kind, required);
        _saved = required;
      });
      await _writes;
      if (ref.mounted && revision == _revision) state = OrderConfirmationState(required: required);
    } catch (_) {
      if (ref.mounted && revision == _revision) {
        state = OrderConfirmationState(required: _saved, failure: true);
      }
    }
  }
}
