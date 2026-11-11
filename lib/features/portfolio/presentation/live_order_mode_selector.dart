import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/live_order_entry_mode.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';
import 'mode_settings_sheet.dart';
import 'order_choice_sheet.dart';

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

const _availableModes = [
  LiveOrderEntryMode.market,
  LiveOrderEntryMode.limit,
  LiveOrderEntryMode.stopLimit,
  LiveOrderEntryMode.stopMarket,
  LiveOrderEntryMode.trailing,
  LiveOrderEntryMode.postOnly,
  LiveOrderEntryMode.scaled,
];

String _compactLabel(AppLocalizations l, LiveOrderEntryMode mode) => switch (mode) {
  LiveOrderEntryMode.postOnly => l.orderTypePostOnly,
  LiveOrderEntryMode.stopLimit => l.orderTypeStopLimit,
  LiveOrderEntryMode.stopMarket => l.orderTypeStopMarket,
  LiveOrderEntryMode.scaled => l.orderTypeScaled,
  LiveOrderEntryMode.trailing => l.orderTypeTrailing,
  _ => orderEntryModeLabel(l, mode),
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
      return Semantics(
        button: true,
        enabled: enabled,
        label: l.orderTypeTitle,
        child: InkWell(
          key: const Key('trade-order-type'),
          onTap: enabled ? () => _openCompact(context) : null,
          child: InputDecorator(
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Row(
              children: [
                Expanded(child: Text(_compactLabel(l, selected), style: TradeTypography.body)),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
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

  Future<void> _openCompact(BuildContext context) async {
    final mode = await showModeSettingsSheet<LiveOrderEntryMode>(
      context,
      _CompactOrderModeSheet(selected: selected),
    );
    // The owning screen rechecks current auth and operation state.
    if (mode != null && enabled) onSelected(mode);
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
                for (final mode in _availableModes)
                  if (mode != LiveOrderEntryMode.limit && mode != LiveOrderEntryMode.market)
                    ListTile(
                      key: Key('order-mode-option-${mode.name}'),
                      title: Text(orderEntryModeLabel(l, mode)),
                      selected: mode == selected,
                      trailing: mode == selected ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, mode),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactOrderModeSheet extends StatelessWidget {
  const _CompactOrderModeSheet({required this.selected});
  final LiveOrderEntryMode selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OrderChoiceSheet(
      key: const Key('order-type-sheet'),
      title: l.orderTypeTitle,
      children: [
        for (final mode in _availableModes)
          TradeOptionRow(
            key: Key('order-mode-option-${mode.name}'),
            option: (value: mode, label: _compactLabel(l, mode), description: null),
            selected: selected == mode,
            emphasizeSelected: false,
            onTap: () => Navigator.pop(context, mode),
          ),
      ],
    );
  }
}
