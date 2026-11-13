import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../../../core/network/network_providers.dart';

import 'package:decimal/decimal.dart';
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
  Future<void>? _prefetch;
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

  /// Input stays editable through silent account renewals; only this entry's
  /// explicit read and an order being submitted lock it.
  bool get editable {
    final live = ref.read(liveOrderProvider);
    return !state.loading && !(live.busy && live.intent != null);
  }

  /// Background work this entry should wait for, never lock on: a silent
  /// account read (no order attached) or any held symbol-settings lease, such
  /// as the automatic renewal's capacity stage or a settings read.
  bool get backgroundBusy {
    final live = ref.read(liveOrderProvider);
    return live.busy && live.intent == null ||
        ref.read(symbolSettingsActivityProvider).owner != null;
  }

  /// A tap during background work waits for it instead of being dropped.
  /// Bounded at about 20 seconds; the reads' own deadlines are shorter.
  Future<void> settle() async {
    for (var i = 0; i < 400 && ref.mounted && backgroundBusy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
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

  /// Base quantity sent to the exchange: the typed quote amount converted at
  /// the current ask/bid, or the percentage share of the sizing budget.
  String? quantity(bool buy) {
    if (state.percent == null) {
      final data = context;
      if (data == null) return null;
      return quickOrderQuantityFromAmount(data, buy, state.quantity.trim())?.toString();
    }
    final sizing = state.sizing;
    if (sizing == null || sizing.context != context) return null;
    return sizing.quantity(buy, state.percent!)?.toString();
  }

  String? validation(bool buy) {
    final data = context, amount = quantity(buy);
    if (data == null) return 'liveOrderContextExpired';
    if (amount == null) {
      if (state.percent != null) return 'quickOrderSizingFailure';
      final typed = parseOrderDecimal(state.quantity.trim());
      return typed == null || typed <= Decimal.zero
          ? 'quickOrderInvalidAmount'
          : 'quickOrderQuoteUnavailable';
    }
    if (Decimal.parse(amount) == Decimal.zero) return 'quickOrderAmountTooSmall';
    final invalid = data.validate(
      LiveOrderDraft(buy: buy, market: true, quantity: amount, price: '', quickEntry: true),
    );
    if (invalid != null) return invalid;
    return quickOrderExceedsBalance(data, buy, amount) ? 'quickOrderInsufficientBalance' : null;
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

  /// Explicit read for a tap; a background read already in flight for the
  /// current snapshot is awaited instead of repeated.
  Future<void> load() async {
    // Background sizing for the current snapshot is usually what a tap needs;
    // use it as soon as it lands rather than waiting for unrelated stages.
    var waited = false;
    if (_prefetch case final pending?) {
      await pending;
      waited = true;
      if (!ref.mounted) return;
      if (context case final data? when state.sizing?.context == data) return;
    }
    // Only an own read needs the account quiet (it takes the order lease).
    if (backgroundBusy) {
      await settle();
      waited = true;
    }
    if (!ref.mounted || !editable || ref.read(authProvider).busy) return;
    if (waited) {
      if (context case final data? when state.sizing?.context == data) return;
    }
    final symbol = ref.read(symbolProvider), revision = ++_revision;
    state = QuickOrderState(quantity: state.quantity, percent: state.percent, loading: true);
    bool current() => ref.mounted && revision == _revision && ref.read(symbolProvider) == symbol;
    // The snapshot a renewal just delivered is reused; otherwise read it.
    if (!waited || context == null) {
      await ref.read(liveOrderProvider.notifier).load(symbol);
      if (!current()) return;
    }
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
    try {
      final sizing = await _readSizing(data, current);
      state = QuickOrderState(quantity: state.quantity, percent: state.percent, sizing: sizing);
    } on AccountReadFailure catch (failure) {
      if (current()) {
        state = QuickOrderState(quantity: state.quantity, percent: state.percent, failure: failure);
      }
    }
  }

  /// Background sizing for the visible quick entry: follow each renewed
  /// account snapshot through the active device grant so a percentage applies
  /// at once. Never prompts a wallet and never disables the panel; a failure
  /// stays quiet and the next tap reads again with its normal feedback.
  Future<void> prefetch() {
    if (_prefetch case final pending?) return pending;
    final data = context;
    if (data == null ||
        state.loading ||
        ref.read(authProvider).busy ||
        state.sizing?.context == data ||
        !_silentGrant()) {
      return Future.value();
    }
    final revision = _revision;
    bool current() => ref.mounted && revision == _revision;
    Future<void> read() async {
      try {
        // No activity lease: it would lock other entries while reading. A
        // snapshot or setting change during the read discards its result.
        final sizing = await _readSizing(data, current, lease: false);
        if (current() && !state.loading) {
          state = QuickOrderState(quantity: state.quantity, percent: state.percent, sizing: sizing);
        }
      } on AccountReadFailure {
        // Quiet: an explicit tap reports its own failure.
      }
    }

    final pending = _prefetch = read();
    return pending.whenComplete(() {
      if (identical(_prefetch, pending)) _prefetch = null;
    });
  }

  /// Same conditions as the automatic order renewal: an active, unexpired
  /// device grant for the signed-in wallet signs reads without a prompt.
  bool _silentGrant() {
    final identity = ref.read(authProvider).identity;
    final agent = ref.read(tradingAgentProvider).asData?.value;
    return identity != null &&
        identity.signingAvailable &&
        identity.walletAddress != null &&
        agent?.status == TradingAgentStatus.active &&
        agent!.identityId == identity.id &&
        agent.owner.toLowerCase() == identity.walletAddress!.toLowerCase() &&
        agent.expiresAt.isAfter(ref.read(tradingAgentClockProvider)());
  }

  /// Fee, leverage brackets and open orders for [data]; throws a typed failure.
  Future<QuickOrderSizing> _readSizing(
    LiveOrderContext data,
    bool Function() current, {
    bool lease = true,
  }) async {
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final held = lease ? activity.acquire(SymbolSetting.order) : null;
    if (lease && held == null) throw const AccountReadFailure('liveOrderSettingsBusy');
    final epoch = ref.read(symbolSettingsActivityProvider).epoch;
    bool fresh() =>
        current() &&
        context == data &&
        (lease || ref.read(symbolSettingsActivityProvider).epoch == epoch) &&
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
      return sizing;
    } on AccountReadFailure {
      rethrow;
    } catch (_) {
      throw const AccountReadFailure('accountReadFailed');
    } finally {
      if (held != null) activity.finish(held, unresolved: false);
    }
  }
}
