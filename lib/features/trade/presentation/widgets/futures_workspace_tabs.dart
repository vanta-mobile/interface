import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../application/navigation_provider.dart';
import '../trade_theme.dart';
import 'trade_icon.dart';

class FuturesWorkspaceTabs extends ConsumerWidget {
  const FuturesWorkspaceTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selected = ref.watch(futuresWorkspaceTabProvider);
    return Container(
      key: const Key('trade-workspace-tabs'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TradeColors.switchBackground,
        border: Border.all(color: TradeColors.card),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in FuturesWorkspaceTab.values.reversed)
            Semantics(
              key: ValueKey('trade-workspace-${tab.name}'),
              selected: selected == tab,
              button: true,
              child: IconButton(
                tooltip: tab == FuturesWorkspaceTab.trade ? l.trade : l.quickOrderChartTab,
                onPressed: () => ref.read(futuresWorkspaceTabProvider.notifier).select(tab),
                style: IconButton.styleFrom(
                  backgroundColor: selected == tab ? TradeColors.card : TradeColors.transparent,
                  minimumSize: const Size(32, 30),
                  maximumSize: const Size(32, 30),
                  padding: const EdgeInsets.all(4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: TradeIcon(
                  tab == FuturesWorkspaceTab.trade ? 'trade-view' : 'chart-view',
                  size: 22,
                  color: selected == tab ? TradeColors.text : TradeColors.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
