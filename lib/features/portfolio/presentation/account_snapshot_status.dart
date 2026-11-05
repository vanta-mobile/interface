import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/account_snapshot.dart';

class AccountSnapshotStatus extends StatelessWidget {
  const AccountSnapshotStatus({
    super.key,
    required this.state,
    this.timeKey = const Key('account-snapshot-time'),
    this.staleKey = const Key('account-snapshot-stale'),
  });
  final AccountSnapshotState<WalletAccountSnapshot> state;
  final Key timeKey, staleKey;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.account case final account?) ...[
          const SizedBox(height: 12),
          Text(
            l10n.accountSnapshotTime(
              DateFormat.yMd(Localizations.localeOf(context).toLanguageTag())
                  .add_Hms()
                  .format(account.receivedAt.toLocal()),
            ),
            key: timeKey,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (state.stale) ...[
          const SizedBox(height: 8),
          Text(
            l10n.accountSnapshotStale,
            key: staleKey,
            style: const TextStyle(color: AppColors.warning),
          ),
        ],
      ],
    );
  }
}
