import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/event_registration_provider.dart';
import '../application/trading_event_provider.dart';
import '../domain/event_registration.dart';

class EventRegistrationButton extends ConsumerWidget {
  const EventRegistrationButton({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), action = ref.watch(eventRegistrationProvider(id));
    final participant = ref.watch(eventParticipantProvider(id));
    final locked =
        action.phase == EventRegistrationPhase.unknown ||
        action.phase == EventRegistrationPhase.acknowledged;
    return FilledButton(
      key: const Key('event-register'),
      onPressed: action.busy || participant.loading || locked || !participant.active
          ? null
          : () async {
              final controller = ref.read(eventRegistrationProvider(id).notifier),
                  approval = controller.prepare();
              if (approval == null) return;
              final confirmed = await showEventRegistrationConfirmation(context, approval);
              if (confirmed == true && context.mounted) await controller.confirm(approval);
            },
      child: Text(l10n.eventRegister),
    );
  }
}

Future<bool?> showEventRegistrationConfirmation(
  BuildContext context,
  EventRegistrationApproval approval,
) {
  final l10n = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.eventRegistrationConfirm),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(approval.event.name),
            SelectableText(approval.identity.walletAddress!),
            Text(l10n.eventRegistrationSigningScope),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.eventCancel)),
        FilledButton(
          key: const Key('event-register-confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.eventRegistrationConfirm),
        ),
      ],
    ),
  );
}
