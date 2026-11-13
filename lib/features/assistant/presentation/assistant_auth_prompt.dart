import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/assistant_provider.dart';
import 'assistant_wallet_auth_screen.dart';
import 'assistant_widgets.dart';

/// Shown until this wallet has a valid AI session, including after expiry.
class AssistantAuthPrompt extends ConsumerWidget {
  const AssistantAuthPrompt({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = ref.watch(assistantProvider.select((s) => s.sessionExpired));
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: const Key('assistant-auth-prompt'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.assistantCopilotTitle, style: AssistantTypography.title),
          const SizedBox(height: 16),
          Text(l10n.assistantAuthIntro, style: AssistantTypography.secondary),
          const SizedBox(height: 16),
          AssistantInfoCard(title: l10n.assistantAuthCardTitle, body: l10n.assistantAuthCardBody),
          const SizedBox(height: 16),
          if (expired) ...[
            Text(
              l10n.assistantSessionExpired,
              key: const Key('assistant-session-expired'),
              style: AssistantTypography.caption.copyWith(color: AssistantColors.error),
            ),
            const SizedBox(height: 4),
          ],
          AssistantPrimaryButton(
            key: const Key('assistant-authenticate'),
            label: l10n.assistantAuthenticate,
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const AssistantWalletAuthScreen())),
          ),
        ],
      ),
    );
  }
}
