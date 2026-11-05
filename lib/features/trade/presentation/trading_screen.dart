import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/application/position_risk_provider.dart';
import '../../portfolio/application/position_adl_provider.dart';
import '../../portfolio/application/spot_account_provider.dart';
import '../../portfolio/application/spot_history_provider.dart';
import '../../portfolio/application/open_orders_provider.dart';
import '../../portfolio/application/live_order_provider.dart';
import '../../points/presentation/points_page.dart';
import '../../assistant/presentation/assistant_page.dart';
import '../application/providers.dart';
import '../application/navigation_provider.dart';
import 'futures_workspace.dart';
import 'widgets/app_bottom_navigation.dart';
import 'destinations.dart';
import '../../market/application/market_providers.dart';
import 'widgets/market_sheet.dart';
import 'widgets/trading_header.dart';
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
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(accountReadProvider.notifier).markStale();
      ref.read(positionRiskProvider.notifier).markStale();
      ref.read(positionAdlProvider.notifier).markStale();
      ref.read(spotAccountReadProvider.notifier).markStale();
      ref.read(spotHistoryProvider.notifier).markStale();
      ref.read(openOrdersReadProvider.notifier).markStale();
      ref.read(liveOrderProvider.notifier).onLifecycleChanged();
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ref.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    }
    if (state == AppLifecycleState.resumed) {
      if (ref.read(authProvider).identity != null) {
        unawaited(ref.read(authProvider.notifier).bootstrap());
      }
      ref.read(marketSyncProvider)?.reconnect();
      ref.invalidate(bookProvider);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: TradingHeader(onLanguage: () => showAppSheet<void>(context, _LanguageSheet())),
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      bottom: false,
      child: switch (ref.watch(appDestinationProvider)) {
        AppDestination.futures => const FuturesWorkspace(),
        AppDestination.markets => _MarketsPage(
          onTrade: () => ref.read(appDestinationProvider.notifier).select(AppDestination.futures),
        ),
        AppDestination.portfolio => const PortfolioPage(),
        AppDestination.assistant => const AssistantPage(),
        AppDestination.points => const PointsPage(),
      },
    ),
    bottomNavigationBar: const AppBottomNavigation(),
  );
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

class _MarketsPage extends StatelessWidget {
  const _MarketsPage({required this.onTrade});
  final VoidCallback onTrade;
  @override
  Widget build(BuildContext context) => ListView(
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
  );
}
