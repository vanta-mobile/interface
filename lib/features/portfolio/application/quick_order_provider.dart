import '../../authorization/application/trading_agent_provider.dart';
import '../../../core/network/network_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../market/application/selection_providers.dart';
import '../data/aster_account_service.dart';
import '../data/signed_quick_order_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import '../domain/quick_order.dart';
import 'account_read_provider.dart';
import 'live_order_provider.dart';
import 'symbol_settings_activity.dart';

final quickOrderRepositoryProvider = Provider<QuickOrderRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedQuickOrderRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});

final quickOrderProvider = NotifierProvider<QuickOrderController, QuickOrderState>(
  QuickOrderController.new,
);

class QuickOrderController extends Notifier<QuickOrderState> {
  int _revision = 0;
  @override
  QuickOrderState build() {
    void reset() {
      _revision++;
      state = const QuickOrderState();
    }

    ref.listen(symbolProvider, (a, b) {
      if (a != b) reset();
    });
    ref.listen(
      authProvider.select(
        (a) => (a.identity?.id, a.identity?.walletAddress, a.identity?.signingAvailable),
      ),
      (a, b) {
        if (a != b) reset();
      },
    );
    ref.listen(liveOrderProvider.select((s) => s.result), (before, result) {
      final intent = ref.read(liveOrderProvider).intent;
      if (result?.orderId != null &&
          result?.failure == null &&
          result?.status != 'REJECTED' &&
          intent?.draft.quickEntry == true &&
          intent?.context.symbol == ref.read(symbolProvider)) {
        state = const QuickOrderState();
      }
    });
    ref.onDispose(() => _revision++);
    return const QuickOrderState();
  }

  bool get editable {
    final live = ref.read(liveOrderProvider);
    return !state.loading && !live.busy;
  }

  void setQuantity(String value) {
    if (editable) {
      state = QuickOrderState(quantity: value, sizing: state.sizing, failure: state.failure);
    }
  }

  void selectPercent(int value) {
    if (editable && [25, 50, 75, 100].contains(value)) {
      state = QuickOrderState(percent: value, sizing: state.sizing, failure: state.failure);
    }
  }

  LiveOrderContext? get context {
    final live = ref.read(liveOrderProvider), data = live.context;
    if (data == null || data.symbol != ref.read(symbolProvider) || live.stale) return null;
    final age = ref.read(liveOrderClockProvider)().difference(data.receivedAt);
    return age.isNegative || age >= const Duration(seconds: 30) ? null : data;
  }

  String? quantity(bool buy) {
    if (state.percent == null) return state.quantity.trim();
    final sizing = state.sizing;
    if (sizing == null || sizing.context != context) return null;
    return sizing.quantity(buy, state.percent!)?.toString();
  }

  String? validation(bool buy) {
    final data = context, amount = quantity(buy);
    if (data == null) return 'liveOrderContextExpired';
    if (amount == null) return 'quickOrderSizingFailure';
    return data.validate(
      LiveOrderDraft(buy: buy, market: true, quantity: amount, price: '', quickEntry: true),
    );
  }

  LiveOrderIntent? prepare(bool buy) {
    if (!editable || context == null) return null;
    final amount = quantity(buy);
    if (amount == null) return null;
    return ref
        .read(liveOrderProvider.notifier)
        .prepare(
          ref.read(symbolProvider),
          LiveOrderDraft(buy: buy, market: true, quantity: amount, price: '', quickEntry: true),
        );
  }

  Future<void> submit(LiveOrderIntent intent) async {
    if (!intent.draft.quickEntry ||
        !editable ||
        intent.context != context ||
        quantity(intent.draft.buy) != intent.draft.quantity) {
      return;
    }
    await ref.read(liveOrderProvider.notifier).submit(intent);
  }

  Future<void> load() async {
    if (!editable || ref.read(authProvider).busy) return;
    final symbol = ref.read(symbolProvider), revision = ++_revision;
    state = QuickOrderState(quantity: state.quantity, percent: state.percent, loading: true);
    bool current() => ref.mounted && revision == _revision && ref.read(symbolProvider) == symbol;
    await ref.read(liveOrderProvider.notifier).load(symbol);
    if (!current()) return;
    final data = context;
    if (data == null) {
      state = QuickOrderState(
        quantity: state.quantity,
        percent: state.percent,
        failure:
            ref.read(liveOrderProvider).failure ?? const AccountReadFailure('liveOrderReadFunds'),
      );
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.order);
    if (lease == null) {
      state = QuickOrderState(
        quantity: state.quantity,
        percent: state.percent,
        failure: const AccountReadFailure('liveOrderSettingsBusy'),
      );
      return;
    }
    bool fresh() =>
        current() &&
        context == data &&
        !ref.read(authProvider).busy &&
        ref.read(liveOrderClockProvider)().difference(data.receivedAt) >= Duration.zero &&
        ref.read(liveOrderClockProvider)().difference(data.receivedAt) <
            const Duration(seconds: 30);
    try {
      final sizing = await ref
          .read(quickOrderRepositoryProvider)
          .readSizing(
            context: data,
            isCurrent: fresh,
            onStep: (_) {
              if (!fresh()) throw const AccountReadFailure('liveOrderContextExpired');
            },
          );
      if (!fresh()) throw const AccountReadFailure('liveOrderContextExpired');
      if (sizing.context != data) throw const AccountReadFailure('accountDataInvalid');
      state = QuickOrderState(quantity: state.quantity, percent: state.percent, sizing: sizing);
    } catch (error) {
      if (current()) {
        state = QuickOrderState(
          quantity: state.quantity,
          percent: state.percent,
          failure: error is AccountReadFailure
              ? error
              : const AccountReadFailure('accountReadFailed'),
        );
      }
    } finally {
      activity.finish(lease, unresolved: false);
    }
  }
}
