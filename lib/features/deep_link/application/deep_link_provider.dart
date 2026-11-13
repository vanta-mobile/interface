import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assistant/application/assistant_provider.dart';
import '../../market/application/market_providers.dart';
import '../../market/application/selection_providers.dart';
import '../../portfolio/application/order_form_prefill_provider.dart';
import '../../portfolio/domain/live_order_size.dart';
import '../../portfolio/domain/order_form_prefill.dart';
import '../../trade/application/navigation_provider.dart';
import '../data/app_link_source.dart';
import '../domain/app_deep_link.dart';

final appLinkSourceProvider = Provider<AppLinkSource>((ref) {
  final source = AppLinkSource();
  ref.onDispose(() => unawaited(source.close()));
  return source;
});

/// Holds the latest link until the home shell can open it, so a launch link
/// survives startup and wallet onboarding.
final deepLinkInboxProvider = NotifierProvider<DeepLinkInbox, AppDeepLink?>(DeepLinkInbox.new);

class DeepLinkInbox extends Notifier<AppDeepLink?> {
  @override
  AppDeepLink? build() {
    ref.watch(appLinkSourceProvider).start((link) => state = link);
    return null;
  }

  /// In-app sources such as tapped push notifications use the same path.
  void deliver(AppDeepLink link) => state = link;

  AppDeepLink? take() {
    final link = state;
    state = null;
    return link;
  }
}

final deepLinkNavigatorProvider = Provider<DeepLinkNavigator>((ref) {
  final navigator = DeepLinkNavigator(ref);
  ref.onDispose(navigator._cancelPrefill);
  return navigator;
});

/// Applies session navigation for a link. Route stacks belong to the host.
class DeepLinkNavigator {
  DeepLinkNavigator(this._ref);

  final Ref _ref;
  int _revision = 0;
  final _prefill = <ProviderSubscription<Object?>>[];

  void open(AppDeepLink link) {
    final revision = ++_revision;
    _cancelPrefill();
    // A newer link replaces any order suggestion the form has not applied yet.
    _ref.read(orderFormPrefillProvider.notifier).clear();
    _ref.read(futuresAccountRequestProvider.notifier).clear();
    final destination = switch (link.target) {
      DeepLinkTarget.futures => AppDestination.futures,
      DeepLinkTarget.portfolio => AppDestination.portfolio,
      DeepLinkTarget.points => AppDestination.points,
      DeepLinkTarget.assistant => AppDestination.assistant,
      DeepLinkTarget.notifications => null,
    };
    if (destination != null) _ref.read(appDestinationProvider.notifier).select(destination);
    if (link.futuresTab case final tab?) {
      _ref
          .read(futuresWorkspaceTabProvider.notifier)
          .select(
            tab == DeepLinkFuturesTab.chart ? FuturesWorkspaceTab.chart : FuturesWorkspaceTab.trade,
          );
    }
    if (link.panel case final panel?) {
      _ref.read(futuresAccountRequestProvider.notifier).show(switch (panel) {
        DeepLinkFuturesPanel.orders => FuturesAccountTab.orders,
        DeepLinkFuturesPanel.positions => FuturesAccountTab.positions,
        DeepLinkFuturesPanel.assets => FuturesAccountTab.assets,
      });
    }
    if (link.symbol case final symbol?) unawaited(_selectSymbol(symbol, link.order, revision));
    if (link.prompt case final prompt?) _prefillAssistant(prompt);
  }

  Future<void> _selectSymbol(String symbol, DeepLinkOrder? order, int revision) async {
    final before = _ref.read(symbolProvider);
    try {
      final instruments = await _ref
          .read(instrumentsProvider.future)
          .timeout(const Duration(seconds: 15));
      // A newer link or the user's own market choice wins over a late catalog.
      if (revision != _revision || _ref.read(symbolProvider) != before) return;
      final instrument = instruments.where((i) => i.symbol == symbol).firstOrNull;
      if (instrument == null) return;
      _ref.read(symbolProvider.notifier).select(symbol);
      if (order != null) {
        _ref
            .read(orderFormPrefillProvider.notifier)
            .propose(_orderPrefill(symbol, order).fit(instrument.precision));
      }
    } catch (_) {
      // An unverifiable symbol keeps the current market.
    }
  }

  OrderFormPrefill _orderPrefill(String symbol, DeepLinkOrder order) => OrderFormPrefill(
    symbol: symbol,
    type: switch (order.type) {
      DeepLinkOrderType.limit => OrderPrefillType.limit,
      DeepLinkOrderType.market => OrderPrefillType.market,
      null => null,
    },
    price: order.price,
    size: order.quantity == null
        ? null
        : LiveOrderSize(
            unit: order.unit == DeepLinkSizeUnit.base ? OrderSizeUnit.base : OrderSizeUnit.quote,
            text: order.quantity!,
          ),
  );

  /// Waits for the signed-in conversation, then fills an empty composer. An
  /// existing draft is the user's input and is never replaced.
  void _prefillAssistant(String prompt) {
    var done = false;
    void finish() {
      done = true;
      _cancelPrefill();
    }

    void onAssistant(AssistantViewState view) {
      if (done || !view.authenticated || !view.historyReady || view.phase != AssistantPhase.idle) {
        return;
      }
      if (view.draft.trim().isEmpty) _ref.read(assistantProvider.notifier).setDraft(prompt);
      finish();
    }

    _prefill.add(
      _ref.listen(appDestinationProvider, (_, next) {
        if (next != AppDestination.assistant) finish();
      }),
    );
    _prefill.add(
      _ref.listen<AssistantViewState>(
        assistantProvider,
        (_, next) => onAssistant(next),
        fireImmediately: true,
      ),
    );
    if (done) _cancelPrefill();
  }

  void _cancelPrefill() {
    for (final subscription in _prefill) {
      subscription.close();
    }
    _prefill.clear();
  }
}
