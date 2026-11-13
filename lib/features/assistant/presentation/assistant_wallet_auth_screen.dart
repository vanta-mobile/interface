import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/assistant_provider.dart';
import 'assistant_widgets.dart';

enum _AuthStep { connect, sign, canceled, expired, failed }

/// Connect wallet, then sign the server's authentication message. Returns to
/// the conversation once the AI session is verified.
class AssistantWalletAuthScreen extends ConsumerWidget {
  const AssistantWalletAuthScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(assistantProvider.select((s) => s.authenticated), (_, authenticated) {
      if (authenticated && context.mounted) Navigator.of(context).maybePop();
    });
    // An external wallet without a live session must reconnect before signing.
    final connected = ref.watch(
      authProvider.select((s) => s.identity != null && !s.identity!.needsWalletConnection),
    );
    final (failure, details, busy) = ref.watch(
      assistantProvider.select(
        (s) => (
          s.authFailureKey,
          s.authErrorDetails,
          s.phase == AssistantPhase.preparing ||
              s.phase == AssistantPhase.review ||
              s.phase == AssistantPhase.signing ||
              s.phase == AssistantPhase.loadingHistory ||
              s.phase == AssistantPhase.readingUsage,
        ),
      ),
    );
    final l10n = AppLocalizations.of(context);
    final step = !connected
        ? _AuthStep.connect
        : switch (failure) {
            null => _AuthStep.sign,
            'authWalletCancelled' ||
            'authWalletRejected' ||
            'assistantCancelled' => _AuthStep.canceled,
            'assistantChallengeExpired' => _AuthStep.expired,
            _ => _AuthStep.failed,
          };
    final (title, body, action) = switch (step) {
      _AuthStep.connect => (
        l10n.assistantConnectTitle,
        l10n.assistantConnectBody,
        l10n.assistantConnectWallet,
      ),
      _AuthStep.sign => (
        l10n.assistantSignTitle,
        l10n.assistantSignBody,
        l10n.assistantSignWithWallet,
      ),
      _AuthStep.canceled => (
        l10n.assistantSignatureCanceledTitle,
        l10n.assistantSignatureCanceledBody,
        l10n.assistantTryAgain,
      ),
      _AuthStep.expired => (
        l10n.assistantAuthExpiredTitle,
        l10n.assistantAuthExpiredBody,
        l10n.assistantSignAgain,
      ),
      _AuthStep.failed => (
        l10n.assistantAuthFailedTitle,
        apiErrorText(context, failure!, details, fallbackText: _knownCause(context, failure)),
        l10n.assistantRetry,
      ),
    };
    final failed =
        step == _AuthStep.canceled || step == _AuthStep.expired || step == _AuthStep.failed;
    return Scaffold(
      backgroundColor: AssistantColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  AssistantBackButton(
                    label: l10n.assistantBack,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.assistantWalletAuthTitle,
                      style: AssistantTypography.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.assistantEnableTitle, style: AssistantTypography.title),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        _StepLabel(
                          mark: connected ? '✓' : '1',
                          label: l10n.assistantStepConnect,
                          color: connected ? AssistantColors.accent : AssistantColors.text,
                        ),
                        _StepLabel(
                          mark: failed ? '✗' : '2',
                          label: l10n.assistantStepSign,
                          color: failed ? AssistantColors.error : AssistantColors.text,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AssistantInfoCard(
                      key: ValueKey('assistant-auth-${step.name}'),
                      title: title,
                      body: body,
                      gap: 8,
                    ),
                    const SizedBox(height: 16),
                    AssistantPrimaryButton(
                      key: const Key('assistant-auth-action'),
                      label: action,
                      busy: connected && busy,
                      onPressed: connected
                          ? ref.read(assistantProvider.notifier).authenticate
                          : () => showAccountSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A concrete known cause (e.g. the wallet must reconnect) beats generic copy.
String _knownCause(BuildContext context, String key) {
  const generic = {'assistantAuthorization', 'assistantUnavailable', 'assistantInvalidResponse'};
  if (!generic.contains(key)) {
    try {
      return tr(context, key);
    } on ArgumentError {
      // Not a catalogued failure; fall through to the design copy.
    }
  }
  return AppLocalizations.of(context).assistantAuthFailedBody;
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.mark, required this.label, required this.color});
  final String mark, label;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Text('$mark  $label', style: AssistantTypography.caption.copyWith(color: color));
}
