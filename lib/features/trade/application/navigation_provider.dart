import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppDestination { futures, markets, portfolio, assistant, points }

enum FuturesWorkspaceTab { chart, trade }

/// Session navigation only: no wallet settings, order terms or durable drafts.
/// A new application container opens BTCUSDT (symbolProvider) on the chart.
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
  FuturesWorkspaceTab build() => FuturesWorkspaceTab.chart;
  void select(FuturesWorkspaceTab value) => state = value;
}
