import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

class LiveOrderEntireControls extends StatelessWidget {
  const LiveOrderEntireControls({
    super.key,
    required this.selected,
    required this.market,
    required this.enabled,
    required this.onChanged,
  });
  final bool selected, market, enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('live-order-entire-close'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.liveEntireClose),
          value: selected,
          onChanged: enabled && market ? onChanged : null,
        ),
        Text(selected ? l10n.liveEntireHint : l10n.liveEntireMarketOnly),
      ],
    );
  }
}
