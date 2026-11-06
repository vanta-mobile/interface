import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_provider.dart';
import '../domain/auth_session.dart';
import 'login_panel.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({required this.account, super.key});
  final Widget account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    final awaitingCode = session.phase == AuthPhase.awaitingCode;
    final signedIn = session.identity != null;
    final l10n = AppLocalizations.of(context);
    void back() {
      if (awaitingCode && !session.busy) {
        ref.read(authProvider.notifier).changeEmail();
      } else {
        Navigator.of(context).pop();
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.transparent,
        systemNavigationBarColor: AppColors.authBackground,
      ),
      child: PopScope(
        canPop: !awaitingCode || session.busy,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) back();
        },
        child: Scaffold(
          backgroundColor: AppColors.authBackground,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LoginHeader(
                      title: signedIn
                          ? l10n.account
                          : awaitingCode
                          ? l10n.authVerifyTitle
                          : l10n.authConnectTitle,
                      onBack: back,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(left: 16, right: 24, top: 12, bottom: 24),
                        child: signedIn ? account : const LoginPanel(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 3),
      child: Row(
        children: [
          IconButton(
            key: const Key('auth-back'),
            tooltip: l10n.authBack,
            onPressed: onBack,
            icon: SvgPicture.asset(
              'assets/auth/back.svg',
              width: 18,
              height: 14,
              excludeFromSemantics: true,
            ),
          ),
          Expanded(child: Text(title, style: AuthTypography.heading)),
          IconButton(
            key: const Key('auth-close'),
            tooltip: l10n.authClose,
            onPressed: () => Navigator.of(context).pop(),
            icon: SvgPicture.asset(
              'assets/auth/close.svg',
              width: 24,
              height: 24,
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    );
  }
}
