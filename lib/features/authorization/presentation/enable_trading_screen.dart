import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/auth_controls.dart';
import '../../auth/presentation/auth_page_header.dart';
import '../application/trading_authorization_provider.dart';
import '../domain/trading_authorization.dart';
import 'connected_wallet_card.dart';

class EnableTradingScreen extends ConsumerWidget {
  const EnableTradingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    ref.listen(tradingAuthorizationProvider.select((s) => s.result), (previous, next) {
      if (next == TradingAuthorizationResult.acknowledged &&
          previous != next &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.of(context).maybePop();
      }
    });
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
                  AuthPageHeader(
                    title: l.enableTradingTitle,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 24, 24),
                      child: const _EnableTradingContent(),
                    ),
                  ),
                  const _EnableTradingActions(),
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
    final secondary = AuthTypography.body.copyWith(color: AppColors.authSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.enableTradingHeading, style: AuthTypography.heading),
        const SizedBox(height: 12),
        Text(external ? l.enableTradingWalletHint : l.enableTradingEmbeddedHint, style: secondary),
        const SizedBox(height: 12),
        ConnectedWalletCard(
          identity: auth.identity,
          onSwitch: auth.busy || s.busy ? null : ref.read(authProvider.notifier).logout,
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
    final l = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final s = ref.watch(tradingAuthorizationProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (auth.failure case final failure?) ...[
          const SizedBox(height: 12),
          AuthFailureText(failure),
        ],
        if (s.failure case final failure?) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              apiErrorText(context, failure, s.errorDetails),
              key: const Key('enable-trading-error'),
              style: AuthTypography.caption.copyWith(color: AppColors.authError),
            ),
          ),
        ],
        if (s.result == TradingAuthorizationResult.unknown) ...[
          const SizedBox(height: 12),
          Text(l.authorizationUnknown, style: AuthTypography.caption),
          Text(l.authorizationCheckScope, style: AuthTypography.caption),
          if (s.check case final check?) ...[
            Text(
              check.futuresReadAccepted
                  ? l.authorizationReadAccepted
                  : tr(context, check.futuresFailure ?? 'accountReadFailed'),
              style: AuthTypography.caption,
            ),
            Text(switch (check.futuresCanTrade) {
              true => l.authorizationCanTrade,
              false => l.authorizationCannotTrade,
              null => l.authorizationPermissionUnknown,
            }, style: AuthTypography.caption),
            Text(
              check.spotReadAccepted
                  ? l.authorizationSpotPermissionUnknown
                  : tr(context, check.spotFailure ?? 'accountReadFailed'),
              style: AuthTypography.caption,
            ),
          ],
        ],
      ],
    );
  }
}

class _EnableTradingActions extends ConsumerWidget {
  const _EnableTradingActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final s = ref.watch(tradingAuthorizationProvider), identity = auth.identity;
    final controller = ref.read(tradingAuthorizationProvider.notifier);
    final authController = ref.read(authProvider.notifier);
    final unknown = s.result == TradingAuthorizationResult.unknown;
    final acknowledged = s.result == TradingAuthorizationResult.acknowledged;
    final needsWallet = identity?.walletAddress == null;
    final reconnect = identity?.walletKind == WalletKind.external && !identity!.signingAvailable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthActionButton(
            key: const Key('enable-trading-sign'),
            label: acknowledged
                ? l.enableTradingContinue
                : needsWallet
                ? tr(context, 'createWallet')
                : reconnect
                ? tr(context, 'reconnectExternalWallet')
                : unknown
                ? l.authorizationCheck
                : identity?.walletKind == WalletKind.external
                ? l.enableTradingOpenWallet
                : l.enableTradingSign,
            primary: true,
            busy: auth.busy || s.busy,
            onPressed: identity == null
                ? null
                : acknowledged
                ? () => Navigator.of(context).maybePop()
                : needsWallet
                ? authController.createWallet
                : reconnect
                ? () => authController.connectWallet(context)
                : unknown
                ? controller.check
                : controller.enableTrading,
          ),
          const SizedBox(height: 12),
          AuthActionButton(
            key: const Key('enable-trading-cancel'),
            label: tr(context, 'cancel'),
            outlined: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
