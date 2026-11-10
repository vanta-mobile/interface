import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/live_order_entry_mode.dart';
import '../../trade/presentation/trade_theme.dart';

String orderEntryModeLabel(AppLocalizations l, LiveOrderEntryMode mode) => switch (mode) {
  LiveOrderEntryMode.limit => l.limit,
  LiveOrderEntryMode.postOnly => l.liveOrderPolicyPostOnly,
  LiveOrderEntryMode.market => l.market,
  LiveOrderEntryMode.stopLimit => l.orderModeStopLimit,
  LiveOrderEntryMode.stopMarket => l.orderModeStopMarket,
  LiveOrderEntryMode.trailing => l.openOrdersTrailingStop,
  LiveOrderEntryMode.chase => l.orderModeChase,
  LiveOrderEntryMode.scaled => l.scaledTitle,
  LiveOrderEntryMode.twap => l.orderModeTwap,
};

class LiveOrderModeSelector extends StatelessWidget {
  const LiveOrderModeSelector({
    super.key,
    required this.selected,
    required this.remembered,
    required this.enabled,
    required this.onSelected,
    this.compact = false,
  });
  final LiveOrderEntryMode selected, remembered;
  final bool enabled;
  final ValueChanged<LiveOrderEntryMode> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (compact) {
      return PopupMenuButton<LiveOrderEntryMode>(
        key: const Key('trade-order-type'),
        enabled: enabled,
        tooltip: l.orderModeLabel,
        initialValue: selected,
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (final mode in LiveOrderEntryMode.values)
            PopupMenuItem(
              key: Key('order-mode-option-${mode.name}'),
              value: mode,
              enabled: mode != LiveOrderEntryMode.chase && mode != LiveOrderEntryMode.twap,
              child: Text(orderEntryModeLabel(l, mode)),
            ),
        ],
        child: InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: Row(
            children: [
              Expanded(child: Text(orderEntryModeLabel(l, selected), style: TradeTypography.body)),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.orderModeLabel),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in [LiveOrderEntryMode.limit, LiveOrderEntryMode.market])
              ChoiceChip(
                key: Key('order-mode-${mode.name}'),
                label: Text(orderEntryModeLabel(l, mode)),
                selected: selected == mode,
                onSelected: enabled ? (_) => onSelected(mode) : null,
              ),
            ChoiceChip(
              key: const Key('order-mode-more'),
              label: Text(orderEntryModeLabel(l, remembered)),
              avatar: const Icon(Icons.expand_more),
              selected:
                  selected != LiveOrderEntryMode.limit && selected != LiveOrderEntryMode.market,
              onSelected: enabled ? (_) => _open(context) : null,
              tooltip: l.orderModeMore,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final mode = await showModalBottomSheet<LiveOrderEntryMode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _OrderModeMenu(selected: selected),
    );
    // ListView may recycle this selector while the sheet is open. The owning
    // screen rechecks mounted/auth/operation state before applying the intent.
    if (mode != null && enabled) onSelected(mode);
  }
}

class _OrderModeMenu extends StatelessWidget {
  const _OrderModeMenu({required this.selected});
  final LiveOrderEntryMode selected;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FractionallySizedBox(
      heightFactor: .8,
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(l.orderModeMore)),
          Expanded(
            child: ListView(
              key: const Key('order-mode-menu'),
              children: [
                for (final mode in LiveOrderEntryMode.values)
                  if (mode != LiveOrderEntryMode.limit && mode != LiveOrderEntryMode.market)
                    ListTile(
                      key: Key('order-mode-option-${mode.name}'),
                      title: Text(orderEntryModeLabel(l, mode)),
                      subtitle: switch (mode) {
                        LiveOrderEntryMode.chase => Text(l.orderModeChaseUnavailable),
                        LiveOrderEntryMode.twap => Text(l.orderModeTwapUnavailable),
                        _ => null,
                      },
                      selected: mode == selected,
                      enabled: mode != LiveOrderEntryMode.chase && mode != LiveOrderEntryMode.twap,
                      trailing: mode == selected ? const Icon(Icons.check) : null,
                      onTap: mode == LiveOrderEntryMode.chase || mode == LiveOrderEntryMode.twap
                          ? null
                          : () => Navigator.pop(context, mode),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
