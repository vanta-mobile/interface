import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/errors/api_error_details.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../auth/application/wallet_onboarding_provider.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/auth_controls.dart';
import '../../auth/presentation/auth_page_header.dart';
import '../application/trading_authorization_provider.dart';
import 'connected_wallet_card.dart';

class EnableTradingScreen extends ConsumerWidget {
  const EnableTradingScreen({this.closeWhenComplete = true, this.onCancel, super.key});

  final bool closeWhenComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    if (closeWhenComplete) {
      ref.listen(walletOnboardingStatusProvider.select((s) => s.complete), (_, complete) {
        if (complete && (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).maybePop();
        }
      });
    }
    void cancel() => (onCancel ?? () => Navigator.of(context).maybePop())();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.transparent,
        systemNavigationBarColor: AppColors.authBackground,
      ),
      child: Scaffold(
        key: const Key('enable-trading-page'),
        backgroundColor: AppColors.authBackground,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthPageHeader(title: l.enableTradingTitle, onBack: cancel, onClose: cancel),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 24, 24),
                      child: const _EnableTradingContent(),
                    ),
                  ),
                  _EnableTradingActions(onCancel: cancel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnableTradingContent extends ConsumerWidget {
  const _EnableTradingContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final s = ref.watch(tradingAuthorizationProvider);
    final external = auth.identity?.walletKind == WalletKind.external;
    final status = ref.watch(walletOnboardingStatusProvider);
    final progress = ref.watch(walletOnboardingProvider);
    final secondary = AuthTypography.body.copyWith(color: AppColors.authSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          status.tradingReady ? l.walletVerificationTitle : l.enableTradingTitle,
          style: AuthTypography.heading,
        ),
        const SizedBox(height: 12),
        Text(l.walletOnboardingHint, style: secondary),
        const SizedBox(height: 12),
        ConnectedWalletCard(
          identity: auth.identity,
          tradingReady: status.tradingReady,
          verified: status.verified,
          onSwitch: auth.busy || s.busy || progress.busy
              ? null
              : ref.read(authProvider.notifier).logout,
        ),
        const SizedBox(height: 12),
        Text(l.enableTradingScope, style: secondary),
        const SizedBox(height: 24),
        Row(
          children: [
            SvgPicture.asset(
              'assets/auth/info-circle.svg',
              width: 16,
              height: 16,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                external ? l.enableTradingReturnHint : l.enableTradingEmbeddedReturnHint,
                style: AuthTypography.caption,
              ),
            ),
          ],
        ),
        const _EnableTradingFeedback(),
      ],
    );
  }
}

class _EnableTradingFeedback extends ConsumerWidget {
  const _EnableTradingFeedback();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final authorization = ref.watch(tradingAuthorizationProvider);
    final status = ref.watch(walletOnboardingStatusProvider);
    final session = ref.watch(vantaApiSessionProvider);
    final verificationFailure =
        session.failure ??
        (session.status == VantaApiSessionStatus.unavailable
            ? const VantaApiFailure(vantaApiUnavailable)
            : null);
    String? message;
    if (auth.failure case final failure?) {
      message = authFailureText(context, failure);
    } else if (authorization.failure case final failure?) {
      // Dispatch uncertainty is a recovery guard, not an extra page state.
      // The existing error slot shows the actual API/transport cause instead.
      final key = {'authorizationUnknown', 'builderApprovalUnknown'}.contains(failure)
          ? 'accountReadFailed'
          : failure;
      message = apiErrorText(context, key, authorization.errorDetails);
    } else if (status.agentFailure case final failure?) {
      message = apiErrorText(context, 'accountReadFailed', errorDetailsOf(failure));
    } else if (verificationFailure case final failure?) {
      message = failure is AuthFailure
          ? authFailureText(context, failure)
          : apiErrorText(
              context,
              failure is VantaApiFailure ? failure.key : vantaApiRequestFailed,
              errorDetailsOf(failure),
            );
    }
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          key: Key(
            verificationFailure != null &&
                    authorization.failure == null &&
                    auth.failure == null &&
                    status.agentFailure == null
                ? 'wallet-verification-error'
                : 'enable-trading-error',
          ),
          style: AuthTypography.caption.copyWith(color: AppColors.authError),
        ),
      ),
    );
  }
}

class _EnableTradingActions extends ConsumerWidget {
  const _EnableTradingActions({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final s = ref.watch(tradingAuthorizationProvider), identity = auth.identity;
    final status = ref.watch(walletOnboardingStatusProvider);
    final progress = ref.watch(walletOnboardingProvider);
    final session = ref.watch(vantaApiSessionProvider);
    final authController = ref.read(authProvider.notifier);
    final needsWallet = identity?.walletAddress == null;
    final reconnect = identity?.needsWalletConnection == true;
    final busy = auth.busy || s.busy || progress.busy || status.checking || session.pending;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthActionButton(
            key: const Key('enable-trading-sign'),
            label: needsWallet
                ? tr(context, 'createWallet')
                : reconnect
                ? tr(context, 'reconnectExternalWallet')
                : status.tradingReady
                ? l.walletVerificationTitle
                : identity?.walletKind == WalletKind.external
                ? l.enableTradingOpenWallet
                : l.enableTradingSign,
            primary: true,
            busy: busy,
            onPressed: identity == null
                ? null
                : needsWallet
                ? authController.createWallet
                : reconnect
                ? () => authController.connectWallet(context)
                : () => ref
                      .read(walletOnboardingProvider.notifier)
                      .continueSigning(completeAll: identity.walletKind == WalletKind.embedded),
          ),
          const SizedBox(height: 12),
          AuthActionButton(
            key: const Key('enable-trading-cancel'),
            label: tr(context, 'cancel'),
            outlined: true,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
