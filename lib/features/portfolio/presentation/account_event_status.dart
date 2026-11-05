import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';

class AccountEventStatus extends StatelessWidget {
  const AccountEventStatus({super.key, required this.time});
  final DateTime? time;
  @override
  Widget build(BuildContext context) {
    if (time == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.accountEventTime(_format(time!)), key: const Key('account-event-time')),
          Text(l10n.accountEventScope, style: const TextStyle(color: AppColors.warning)),
        ],
      ),
    );
  }
}

class AccountEventRowTime extends StatelessWidget {
  const AccountEventRowTime({super.key, required this.time});
  final DateTime? time;
  @override
  Widget build(BuildContext context) => time == null
      ? const SizedBox.shrink()
      : ValueRow(AppLocalizations.of(context).accountEventRowTime, _format(time!));
}

String _format(DateTime time) => DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(time.toUtc());
