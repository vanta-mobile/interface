import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authorization/presentation/enable_trading_screen.dart';
import '../application/auth_provider.dart';
import '../domain/auth_session.dart';
import 'login_panel.dart';
import 'auth_page_header.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({required this.account, super.key});
  final Widget account;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _enableTrading = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.identity == null) {
        if (_enableTrading) setState(() => _enableTrading = false);
      } else if (previous?.identity == null && previous?.phase != AuthPhase.initializing) {
        setState(() => _enableTrading = true);
      }
    });
    final session = ref.watch(authProvider);
    if (_enableTrading && session.identity != null) return const EnableTradingScreen();
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
                    AuthPageHeader(
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
                        child: signedIn ? widget.account : const LoginPanel(),
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
