import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppDestination { futures, points, assistant, portfolio }

enum FuturesWorkspaceTab { chart, trade }

/// Session navigation only: no wallet settings, order terms or durable drafts.
/// A new application container opens BTCUSDT (symbolProvider) on the order form.
final appDestinationProvider = NotifierProvider<AppDestinationController, AppDestination>(
  AppDestinationController.new,
);

class AppDestinationController extends Notifier<AppDestination> {
  @override
  AppDestination build() => AppDestination.futures;
  void select(AppDestination value) => state = value;
}

final futuresWorkspaceTabProvider =
    NotifierProvider<FuturesWorkspaceTabController, FuturesWorkspaceTab>(
      FuturesWorkspaceTabController.new,
    );

class FuturesWorkspaceTabController extends Notifier<FuturesWorkspaceTab> {
  @override
  FuturesWorkspaceTab build() => FuturesWorkspaceTab.trade;
  void select(FuturesWorkspaceTab value) => state = value;
}

/// Compact K-line above the order book and form; session-only view state.
final tradeKlineVisibleProvider = NotifierProvider<TradeKlineVisibleController, bool>(
  TradeKlineVisibleController.new,
);

class TradeKlineVisibleController extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}
