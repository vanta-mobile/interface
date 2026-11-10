import '../application/page_refresh_provider.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../points/presentation/points_page.dart';
import '../../assistant/presentation/assistant_page.dart';
import 'explore_page.dart';
import '../application/providers.dart';
import '../application/navigation_provider.dart';
import '../application/trading_lifecycle_provider.dart';
import 'futures_workspace.dart';
import 'widgets/app_bottom_navigation.dart';
import 'destinations.dart';
import 'widgets/market_sheet.dart';
import 'widgets/trading_header.dart';
import 'widgets/trade_page_header.dart';
import 'widgets/primitives.dart';

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
    final portfolio = destination == AppDestination.portfolio;
    final futures = destination == AppDestination.futures;
    return Scaffold(
      backgroundColor: portfolio || futures ? AppColors.authBackground : null,
      appBar: portfolio
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(futures ? 44 : 60),
              child: SafeArea(
                bottom: false,
                child: Container(
                  height: futures ? 44 : 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: futures
                      ? null
                      : const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.line)),
                        ),
                  child: futures
                      ? TradePageHeader(
                          onLanguage: () => showAppSheet<void>(context, _LanguageSheet()),
                        )
                      : TradingHeader(
                          onLanguage: () => showAppSheet<void>(context, _LanguageSheet()),
                        ),
                ),
              ),
            ),
      body: SafeArea(
        top: portfolio,
        bottom: false,
        child: switch (ref.watch(appDestinationProvider)) {
          AppDestination.futures => const FuturesWorkspace(),
          AppDestination.markets => _MarketsPage(
            onTrade: () => ref.read(appDestinationProvider.notifier).select(AppDestination.futures),
          ),
          AppDestination.portfolio => const PortfolioPage(),
          AppDestination.explore => const ExplorePage(),
          AppDestination.assistant => const AssistantPage(),
          AppDestination.points => const PointsPage(),
        },
      ),
      bottomNavigationBar: const AppBottomNavigation(),
    );
  }
}

class _LanguageSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final language in [
        (null, tr(context, 'followSystem')),
        ('zh', tr(context, 'languageChinese')),
        ('en', tr(context, 'languageEnglish')),
      ])
        ListTile(
          key: ValueKey('language-${language.$1 ?? 'system'}'),
          title: Text(language.$2),
          trailing: ref.watch(localeProvider)?.languageCode == language.$1
              ? const Icon(Icons.check, color: AppColors.accent)
              : null,
          onTap: () {
            unawaited(ref.read(localeProvider.notifier).select(language.$1));
            Navigator.pop(context);
          },
        ),
      if (ref.watch(localeSaveErrorProvider)) ...[
        Text(tr(context, 'languageSaveFailed')),
        TextButton(
          onPressed: () =>
              ref.read(localeProvider.notifier).select(ref.read(localeProvider)?.languageCode),
          child: Text(tr(context, 'saveLanguage')),
        ),
      ],
    ],
  );
}

class _MarketsPage extends ConsumerWidget {
  const _MarketsPage({required this.onTrade});
  final VoidCallback onTrade;
  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
    onRefresh: ref.read(pageRefreshProvider).markets,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr(context, 'markets'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        MarketSheet(embedded: true, onSelect: onTrade),
        const SizedBox(height: 24),
        FilledButton(onPressed: onTrade, child: Text(tr(context, 'backToTrade'))),
      ],
    ),
  );
}
