import '../application/page_refresh_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/aster_account_panel.dart';
import '../../portfolio/presentation/spot_account_panel.dart';
import '../application/providers.dart';
import 'widgets/account_sheet.dart';
import 'widgets/positions_panel.dart';
import 'widgets/primitives.dart';

class PortfolioPage extends ConsumerStatefulWidget {
  const PortfolioPage({super.key});
  @override
  ConsumerState<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends ConsumerState<PortfolioPage> {
  bool demo = false, spot = false;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => ref.read(pageRefreshProvider).portfolio(spot: spot, demo: demo),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      key: const Key('portfolio-page'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr(context, 'overview'), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        TabChoices(
          items: [AppLocalizations.of(context).asterAccountTab, tr(context, 'demo')],
          selected: demo ? 1 : 0,
          onSelect: (index) => setState(() => demo = index == 1),
        ),
        const SizedBox(height: 20),
        if (demo)
          const _DemoPortfolio()
        else
          _LivePortfolio(spot: spot, onSelect: (value) => setState(() => spot = value)),
      ],
    ),
  );
}

class _LivePortfolio extends StatelessWidget {
  const _LivePortfolio({required this.spot, required this.onSelect});
  final bool spot;
  final ValueChanged<bool> onSelect;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabChoices(
          items: [l10n.accountPerpetualTab, l10n.accountSpotTab],
          selected: spot ? 1 : 0,
          onSelect: (index) => onSelect(index == 1),
        ),
        const SizedBox(height: 20),
        if (spot) const SpotAccountPanel() else const AsterAccountPanel(),
      ],
    );
  }
}

class _DemoPortfolio extends ConsumerWidget {
  const _DemoPortfolio();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'demo'),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        Panel(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MutedText(tr(context, 'equity')),
              const SizedBox(height: 12),
              Text(
                account.connected ? account.balance.toStringAsFixed(2) : '—',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
              ),
              const MutedText('USDT'),
              const SizedBox(height: 24),
              ValueRow(
                tr(context, 'available'),
                '${account.connected ? account.available.toStringAsFixed(2) : '—'} USDT',
              ),
              ValueRow(tr(context, 'usedMargin'), '${account.reserved.toStringAsFixed(2)} USDT'),
              const SizedBox(height: 16),
              if (!account.connected)
                FilledButton(
                  key: const Key('portfolio-connect-demo'),
                  onPressed: () => showDemoAccountSheet(context),
                  child: Text(tr(context, 'connect')),
                )
              else
                Text(
                  tr(context, 'demoActive'),
                  style: const TextStyle(color: AppColors.warning, fontSize: 11),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const PositionsPanel(),
      ],
    );
  }
}
