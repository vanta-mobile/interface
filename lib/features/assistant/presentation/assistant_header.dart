import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/assistant_provider.dart';
import 'assistant_session_panels.dart';
import 'assistant_status.dart';

class AssistantHeader extends ConsumerWidget {
  const AssistantHeader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (authenticated, phase, active, version) = ref.watch(
      assistantProvider.select((s) => (s.authenticated, s.phase, s.active, s.scopeVersion)),
    );
    final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    final l10n = AppLocalizations.of(context), controller = ref.read(assistantProvider.notifier);
    final idle = active && phase == AssistantPhase.idle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.assistantTitle, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(l10n.assistantIntro),
        const SizedBox(height: 8),
        Text(l10n.assistantScope, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        if (address == null) ...[
          Text(l10n.assistantWalletRequired),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('assistant-connect'),
              onPressed: () => showAccountSheet(context),
              child: Text(tr(context, 'connect')),
            ),
          ),
        ] else ...[
          SelectableText(address, key: const Key('assistant-wallet-address')),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: l10n.assistantCopyAddress,
              onPressed: () => copyAssistantText(context, address),
              icon: const Icon(Icons.copy_outlined),
            ),
          ),
          if (authenticated)
            Text(l10n.assistantReady, style: const TextStyle(color: AppColors.accent))
          else
            Text(l10n.assistantAuthHint),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('assistant-authorize'),
                onPressed: idle ? controller.prepare : null,
                child: Text(l10n.assistantAuthorize),
              ),
              OutlinedButton(
                key: const Key('assistant-restore'),
                onPressed: idle ? controller.restore : null,
                child: Text(l10n.assistantRestore),
              ),
              if (authenticated) ...[
                OutlinedButton(
                  key: const Key('assistant-clear'),
                  onPressed: idle ? () => _confirm(context, ref, version, clear: true) : null,
                  child: Text(l10n.assistantClear),
                ),
                OutlinedButton(
                  key: const Key('assistant-forget'),
                  onPressed: idle ? () => _confirm(context, ref, version, clear: false) : null,
                  child: Text(l10n.assistantForget),
                ),
              ],
            ],
          ),
        ],
        const AssistantChallengePanel(),
        if (authenticated) const AssistantUsagePanel(),
        const SizedBox(height: 12),
        Text(l10n.assistantGuide, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    int version, {
    required bool clear,
  }) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clear ? l10n.assistantClear : l10n.assistantForget),
        content: SingleChildScrollView(
          child: Text(clear ? l10n.assistantClearConfirm : l10n.assistantForgetConfirm),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.assistantCancel),
          ),
          TextButton(
            key: const Key('assistant-dialog-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(clear ? l10n.assistantClear : l10n.assistantForget),
          ),
        ],
      ),
    );
    if (!context.mounted || yes != true) return;
    final controller = ref.read(assistantProvider.notifier);
    if (clear) {
      await controller.clearHistory(version);
    } else {
      await controller.forgetSession(version);
    }
  }
}
