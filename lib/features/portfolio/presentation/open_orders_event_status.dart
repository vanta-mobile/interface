import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/open_orders_provider.dart';
import 'account_change_panel.dart';

class OpenOrdersEventStatus extends ConsumerWidget {
  const OpenOrdersEventStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final time = ref.watch(openOrdersReadProvider.select((s) => s.account?.lastEventAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('open-order-monitor'),
          onPressed: () =>
              showAppSheet<void>(context, const AccountChangePanel(initiallyExpanded: true)),
          icon: const Icon(Icons.sensors),
          label: Text(l10n.accountChangeTitle),
        ),
        if (time != null) ...[
          Text(
            l10n.openOrdersEventTime(DateFormat('yyyy-MM-dd HH:mm:ss').format(time.toUtc())),
            key: const Key('open-orders-event-time'),
          ),
          Text(l10n.openOrdersEventScope, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
