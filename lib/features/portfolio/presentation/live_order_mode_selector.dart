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
    required this.enabled,
    required this.onSelected,
  });
  final LiveOrderEntryMode selected;
  final bool enabled;
  final ValueChanged<LiveOrderEntryMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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

  Future<void> _openCompact(BuildContext context) async {
    final mode = await showModeSettingsSheet<LiveOrderEntryMode>(
      context,
      _CompactOrderModeSheet(selected: selected),
    );
    // The owning screen rechecks current auth and operation state.
    if (mode != null && enabled) onSelected(mode);
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
