import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/position_margin_mode.dart';
import 'position_margin_mode_status.dart';

class PositionMarginModeForm extends StatelessWidget {
  const PositionMarginModeForm({
    super.key,
    required this.settings,
    required this.stale,
    required this.busy,
    required this.target,
    required this.onChanged,
    required this.onReview,
  });
  final PositionMarginModeContext settings;
  final bool stale, busy;
  final PositionMarginMode? target;
  final ValueChanged<PositionMarginMode?> onChanged;
  final VoidCallback? onReview;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        ValueRow(l10n.marginModeCurrentSetting, marginModeLabel(l10n, settings.current)),
        Text('${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(settings.receivedAt.toUtc())} UTC'),
        if (stale)
          Text(l10n.marginModeContextExpired, style: const TextStyle(color: AppColors.warning)),
        if (settings.hasPosition)
          Text(l10n.marginModeHasPosition, style: const TextStyle(color: AppColors.warning)),
        if (settings.openOrderCount > 0)
          Text(l10n.marginModeOpenOrders, style: const TextStyle(color: AppColors.warning)),
        const SizedBox(height: 12),
        DropdownButtonFormField<PositionMarginMode>(
          key: const Key('margin-mode-target'),
          initialValue: target,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.marginModeTarget),
          items: [
            for (final mode in PositionMarginMode.values)
              DropdownMenuItem(value: mode, child: Text(marginModeLabel(l10n, mode))),
          ],
          onChanged: busy ? null : onChanged,
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('margin-mode-review'),
          onPressed: onReview,
          child: Text(l10n.marginModeReviewChange),
        ),
      ],
    );
  }
}
