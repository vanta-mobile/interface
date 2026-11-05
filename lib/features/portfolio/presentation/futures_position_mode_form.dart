import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/futures_position_mode.dart';
import 'futures_position_mode_status.dart';

class FuturesPositionModeForm extends StatelessWidget {
  const FuturesPositionModeForm({
    super.key,
    required this.settings,
    required this.stale,
    required this.busy,
    required this.target,
    required this.onChanged,
    required this.onReview,
  });
  final FuturesPositionModeContext settings;
  final bool stale, busy;
  final FuturesPositionMode? target;
  final ValueChanged<FuturesPositionMode?> onChanged;
  final VoidCallback? onReview;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        ValueRow(l10n.positionModeCurrentSetting, positionModeLabel(l10n, settings.current)),
        Text('${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(settings.receivedAt.toUtc())} UTC'),
        if (stale)
          Text(l10n.positionModeContextExpired, style: const TextStyle(color: AppColors.warning)),
        if (settings.hasPosition)
          Text(l10n.positionModeHasPosition, style: const TextStyle(color: AppColors.warning)),
        if (settings.openOrderCount > 0)
          Text(l10n.positionModeOpenOrders, style: const TextStyle(color: AppColors.warning)),
        const SizedBox(height: 12),
        DropdownButtonFormField<FuturesPositionMode>(
          key: const Key('position-mode-target'),
          initialValue: target,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.positionModeTarget),
          items: [
            for (final mode in FuturesPositionMode.values)
              DropdownMenuItem(value: mode, child: Text(positionModeLabel(l10n, mode))),
          ],
          onChanged: busy ? null : onChanged,
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('position-mode-review'),
          onPressed: onReview,
          child: Text(l10n.positionModeReviewChange),
        ),
      ],
    );
  }
}
