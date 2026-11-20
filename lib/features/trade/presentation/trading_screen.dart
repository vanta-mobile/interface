import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../points/presentation/points_page.dart';
import '../../portfolio/presentation/history_destination_page.dart';
import '../../assistant/presentation/assistant_page.dart';
import '../application/navigation_provider.dart';
import '../application/trading_lifecycle_provider.dart';
import 'futures_workspace.dart';
import 'widgets/app_bottom_navigation.dart';
import 'destinations.dart';
import 'widgets/market_header.dart';
import 'widgets/trade_page_header.dart';

class TradingScreen extends ConsumerStatefulWidget {
  const TradingScreen({super.key});
  @override
  ConsumerState<TradingScreen> createState() => _TradingScreenState();
}

class _TradingScreenState extends ConsumerState<TradingScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(tradingLifecycleProvider).onChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(tradingLifecycleProvider);
    final destination = ref.watch(appDestinationProvider);
    final futures = destination == AppDestination.futures;
    return Scaffold(
      backgroundColor: AppColors.authBackground,
      // Every other destination draws its own design header.
      appBar: futures
          ? PreferredSize(
              preferredSize: Size.fromHeight(
                44.0 + MediaQuery.textScalerOf(context).scale(40.0).clamp(48.0, double.infinity),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 44, child: TradePageHeader()),
                      const MarketHeaderRow(),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: SafeArea(
        top: !futures,
        bottom: false,
        child: switch (destination) {
          // Tapping outside the inputs dismisses the keyboard; controls that
          // handle the tap themselves win the gesture arena.
          AppDestination.futures => GestureDetector(
            key: const Key('futures-dismiss-keyboard'),
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: const FuturesWorkspace(),
          ),
          AppDestination.portfolio => const PortfolioPage(),
          AppDestination.assistant => const AssistantPage(),
          AppDestination.points => const PointsPage(),
          AppDestination.history => const HistoryDestinationPage(),
        },
      ),
      bottomNavigationBar: const AppBottomNavigation(),
    );
  }
}
