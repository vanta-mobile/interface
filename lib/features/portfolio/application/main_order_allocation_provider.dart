import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../market/application/selection_providers.dart';
import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import '../domain/live_order_size.dart';
import '../domain/main_order_allocation.dart';
import '../domain/main_order_capacity_preview.dart';
import '../domain/main_order_review_input.dart';
import 'live_order_provider.dart';
import 'main_order_capacity_provider.dart';
import 'main_order_pricing_provider.dart';
import 'main_order_pricing_wait.dart';
import 'main_order_refresh_provider.dart';
import 'symbol_settings_activity.dart';
import 'order_review_activity_provider.dart';

final mainOrderAllocationProvider =
    NotifierProvider<MainOrderAllocationController, MainOrderAllocationState>(
      MainOrderAllocationController.new,
    );

class MainOrderAllocationController extends Notifier<MainOrderAllocationState> {
  int _revision = 0;
  MainOrderPricingWait? _pricingWait;
  bool Function()? _formCurrent;
  Object? _identityKey;
  String? _activeClientId;

  Object _identity() {
    final auth = ref.read(authProvider);
    return (
      auth.identity?.id,
      auth.identity?.walletAddress?.toLowerCase(),
      auth.identity?.walletKind,
      auth.identity?.signingAvailable,
      auth.busy,
    );
  }

  @override
  MainOrderAllocationState build() {
    void reset({bool scope = false}) {
      _pricingWait?.cancel();
      _pricingWait = null;
      _revision++;
      _formCurrent = null;
      state = MainOrderAllocationState(percent: scope ? 0 : state.percent);
    }

    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
          s.busy,
        ),
      ),
      (a, b) {
        if (a != b) {
          _activeClientId = null;
          reset(scope: true);
        }
      },
    );
    ref.listen(symbolProvider, (a, b) {
      if (a != b) {
        _activeClientId = null;
        reset(scope: true);
      }
    });
    ref.listen(liveOrderProvider, (before, after) {
      final result = after.result;
      if (_activeClientId != null &&
          after.intent?.clientOrderId == _activeClientId &&
          result != null &&
          !result.needsRecheck &&
          result.failure == null &&
          result.status != 'REJECTED') {
        _activeClientId = null;
        reset(scope: state.percent != null);
      } else if (before?.context != after.context || after.stale && before?.stale != true) {
        // An open live review owns raw choices, not an expiring account
        // snapshot. Keep those choices while background reads renew its facts.
        if (state.review?.input != null && ref.read(orderReviewActivityProvider) > 0) return;
        reset();
      }
    });
    // Keep the shared public source observed throughout a review/signature.
    ref.listen(mainOrderPricingProvider, (_, _) {});
    ref.onDispose(() {
      _revision++;
      _pricingWait?.cancel();
    });
    return const MainOrderAllocationState();
  }

  bool get editable {
    final live = ref.read(liveOrderProvider);
    return !ref.read(mainOrderRefreshProvider).loading && !state.preparing && !live.busy;
  }

  /// A ratio is only a choice; a silent background refresh must not block or
  /// interrupt adjusting it. A clicked review still re-reads everything.
  bool get adjustable {
    final refresh = ref.read(mainOrderRefreshProvider), live = ref.read(liveOrderProvider);
    final silent = refresh.background && live.intent == null;
    return (!refresh.loading || silent) && !state.preparing && (!live.busy || silent);
  }

  /// [pending] accepts a ratio before current capacity and prices are known;
  /// the click's fresh read resolves it, as for any stale facts.
  void selectPercent(int percent, {bool pending = false}) {
    if (!(pending ? adjustable : editable) ||
        percent < 0 ||
        percent > 100 ||
        !pending && percent > 0 && ref.read(mainOrderCapacityProvider.notifier).current == null) {
      return;
    }
    if (percent > 0 && !pending) {
      try {
        ref
            .read(mainOrderPricingProvider)
            .revalue(ref.read(mainOrderCapacityProvider.notifier).current!);
      } on AccountReadFailure {
        return;
      }
    }
    _revision++;
    _formCurrent = null;
    state = MainOrderAllocationState(percent: percent);
  }

  void manual() {
    // Editing local text during a silent read does not authorize a review.
    final live = ref.read(liveOrderProvider);
    final background = ref.read(mainOrderRefreshProvider).background;
    if (!editable && !(background && !state.preparing && live.intent == null)) {
      return;
    }
    _revision++;
    _formCurrent = null;
    state = const MainOrderAllocationState(percent: null);
  }

  void stop() {
    if (!state.preparing) return;
    _pricingWait?.cancel();
    _pricingWait = null;
    _revision++;
    _formCurrent = null;
    state = MainOrderAllocationState(percent: state.percent);
    ref.read(mainOrderCapacityProvider.notifier).stop();
  }

  Future<MainOrderAllocationReview?> prepare(
    LiveOrderDraft draft, {
    required bool Function() isFormCurrent,
    MainOrderReviewInput? input,
  }) async {
    final live = ref.read(liveOrderProvider), context = live.context;
    if (!editable ||
        ref.read(authProvider).busy ||
        context == null ||
        live.stale ||
        draft.reducing ||
        context.symbol != ref.read(symbolProvider) ||
        !isFormCurrent()) {
      return null;
    }
    String? invalid;
    AccountReadFailure? pricingFailure;
    // Raw form input is resolved and fully validated against the fresh read
    // below; a stale price or capacity must not reject the click up front.
    if (input == null) {
      try {
        invalid = ref.read(mainOrderPricingProvider).priceContext(context).validate(draft);
      } on AccountReadFailure catch (failure) {
        invalid = failure.key;
        pricingFailure = failure;
      }
    }
    if (invalid != null) {
      state = MainOrderAllocationState(
        percent: state.percent,
        failure: pricingFailure ?? AccountReadFailure(invalid),
      );
      return null;
    }
    final percent = state.percent;
    final revision = ++_revision;
    final identity = _identity();
    bool scoped() => ref.mounted && revision == _revision;
    bool current() =>
        scoped() &&
        _identity() == identity &&
        isFormCurrent() &&
        ref.read(liveOrderProvider).context == context;
    state = MainOrderAllocationState(percent: percent, preparing: true);
    try {
      // Legacy fixed-quantity callers retain their captured amount. The main
      // form carries raw choices so its confirmation can show current results.
      await ref.read(mainOrderCapacityProvider.notifier).load(context.symbol);
      if (!current()) throw const AccountReadFailure('liveAllocationChanged');
      final snapshot = ref.read(mainOrderCapacityProvider.notifier).current;
      if (snapshot == null || snapshot.context != context) {
        throw ref.read(mainOrderCapacityProvider).failure ??
            const AccountReadFailure('liveCapacityStale');
      }
      final waiting = MainOrderPricingWait(ref, snapshot, current);
      _pricingWait = waiting;
      waiting.start();
      final valuation = await waiting.future;
      if (identical(_pricingWait, waiting)) _pricingWait = null;
      if (!current()) throw const AccountReadFailure('liveAllocationChanged');
      if (input != null) draft = input.resolve(snapshot, valuation).draft;
      final preview = MainOrderCapacityPreview(
        snapshot: snapshot,
        valuation: valuation,
        draft: draft,
        unit: OrderSizeUnit.base,
        input: draft.quantity,
      );
      final side = draft.buy ? preview.buy : preview.sell;
      if (side.failure case final failure?) {
        if (failure.key == 'liveCapacityAboveMaximum' && side.capacity != null) {
          throw MainOrderCapacityExceeded(capacity: side.capacity!, context: valuation.context);
        }
        throw failure;
      }
      if (side.capacity == null ||
          side.quantity == null ||
          valuation.context.validate(draft) != null) {
        throw const AccountReadFailure('liveAllocationChanged');
      }
      final intent = ref
          .read(liveOrderProvider.notifier)
          .prepare(context.symbol, draft, pricingContext: valuation.context);
      if (intent == null) throw const AccountReadFailure('liveAllocationChanged');
      final review = MainOrderAllocationReview(
        intent: intent,
        capacity: snapshot,
        side: side,
        revision: revision,
        valuation: valuation,
        input: input,
      );
      _formCurrent = isFormCurrent;
      _identityKey = identity;
      state = MainOrderAllocationState(percent: percent, review: review);
      return review;
    } catch (error) {
      if (scoped()) {
        state = MainOrderAllocationState(
          percent: percent,
          failure: error is AccountReadFailure
              ? error
              : const AccountReadFailure('accountReadFailed'),
        );
      }
      return null;
    }
  }

  bool _sameReview(MainOrderAllocationReview review) =>
      state.review?.revision == review.revision &&
      state.review?.intent.clientOrderId == review.intent.clientOrderId;

  /// Recalculate the dialog's current terms without reading or submitting.
  /// The returned immutable revision is frozen only when Confirm is pressed.
  MainOrderAllocationReview reprice(MainOrderAllocationReview review) {
    if (!_sameReview(review) || _identityKey != _identity()) {
      throw const AccountReadFailure('authWalletChanged');
    }
    if (_formCurrent?.call() != true) {
      throw const AccountReadFailure('liveAllocationChanged');
    }
    final capacity = ref.read(mainOrderCapacityProvider.notifier).current;
    if (capacity == null) {
      throw ref.read(mainOrderCapacityProvider).failure ??
          ref.read(liveOrderProvider).failure ??
          const AccountReadFailure('liveCapacityStale');
    }
    final valuation = ref.read(mainOrderPricingProvider).revalue(capacity);
    final input =
        review.input ??
        MainOrderReviewInput(
          draft: review.intent.draft,
          size: LiveOrderSize(unit: OrderSizeUnit.base, text: review.intent.draft.quantity),
        );
    final resolved = input.resolve(capacity, valuation);
    final intent = ref
        .read(liveOrderProvider.notifier)
        .prepare(
          capacity.context.symbol,
          resolved.draft,
          pricingContext: valuation.context,
          clientOrderId: review.intent.clientOrderId,
        );
    if (intent == null) throw const AccountReadFailure('liveOrderContextExpired');
    return MainOrderAllocationReview(
      intent: intent,
      capacity: capacity,
      side: resolved.side,
      revision: review.revision,
      valuation: valuation,
      input: review.input,
    );
  }

  bool matches(MainOrderAllocationReview review, {bool submitting = false}) {
    if (!ref.mounted ||
        ref.read(mainOrderRefreshProvider).loading ||
        state.preparing ||
        !_sameReview(review) ||
        review.revision != _revision ||
        _identityKey != _identity() ||
        _formCurrent?.call() != true) {
      return false;
    }
    final live = ref.read(liveOrderProvider), capacity = ref.read(mainOrderCapacityProvider);
    final operation = ref.read(symbolSettingsActivityProvider);
    final context = review.intent.context;
    final age = ref.read(liveOrderClockProvider)().difference(context.receivedAt);
    final matches =
        live.context == context &&
        context.symbol == ref.read(symbolProvider) &&
        !live.stale &&
        (!live.busy || submitting) &&
        capacity.snapshot == review.capacity &&
        !capacity.stale &&
        !capacity.loading &&
        !operation.recoveryBlocked &&
        !operation.unresolved &&
        (submitting && live.busy
            ? operation.owner == SymbolSetting.order && operation.busy
            : operation.owner == null && !operation.busy) &&
        !age.isNegative &&
        age < const Duration(seconds: 30);
    if (!matches) return false;
    try {
      final valuation = ref.read(mainOrderPricingProvider).revalue(review.capacity);
      final draft = review.intent.draft;
      final preview = MainOrderCapacityPreview(
        snapshot: review.capacity,
        valuation: valuation,
        draft: draft,
        unit: OrderSizeUnit.base,
        input: draft.quantity,
      );
      final side = draft.buy ? preview.buy : preview.sell;
      return side.failure == null &&
          side.quantity != null &&
          side.capacity != null &&
          valuation.context.validate(draft) == null;
    } on AccountReadFailure {
      return false;
    }
  }

  Future<void> submit(MainOrderAllocationReview review) async {
    if (!matches(review)) {
      if (ref.mounted && _sameReview(review)) {
        state = MainOrderAllocationState(
          percent: state.percent,
          failure: const AccountReadFailure('liveAllocationChanged'),
        );
      }
      return;
    }
    _activeClientId = review.intent.clientOrderId;
    await ref
        .read(liveOrderProvider.notifier)
        .submit(review.intent, submitGuard: () => matches(review, submitting: true));
  }
}
