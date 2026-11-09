import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_provider.dart';
import '../domain/auth_session.dart';
import 'auth_controls.dart';
import 'email_code_form.dart';

class LoginPanel extends ConsumerStatefulWidget {
  const LoginPanel({super.key});
  @override
  ConsumerState<LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends ConsumerState<LoginPanel> {
  final _email = TextEditingController();
  String? _pending;

  @override
  void initState() {
    super.initState();
    _email.text = ref.read(authProvider).email;
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _run(String action, Future<void> Function() operation) async {
    setState(() => _pending = action);
    await operation();
    if (mounted) setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    if (session.phase == AuthPhase.awaitingCode) return const EmailCodeForm();
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(authProvider.notifier);
    final ready = ref.watch(privyConfigurationProvider).isConfigured && !session.busy;
    final reconnect = session.identity?.needsWalletConnection == true;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          const SizedBox(height: 48, child: Text('Vanta', style: AuthTypography.brand)),
          Text(l10n.authWelcome, style: AuthTypography.heading),
          if (!reconnect) _emailField(session, ready, controller, l10n),
          if (session.failure case final failure?) AuthFailureText(failure),
          if (reconnect) ...[
            _walletButton(session, controller, ready, l10n, primary: true),
            AuthActionButton(
              key: const Key('login-use-another-wallet'),
              label: l10n.enableTradingUseAnother,
              busy: session.busy && _pending == 'switch',
              onPressed: session.busy ? null : () => _run('switch', controller.logout),
            ),
          ] else ...[
            AuthActionButton(
              key: const Key('send-email-code'),
              label: l10n.authEmailContinue,
              primary: true,
              busy: session.busy && _pending == 'email',
              onPressed: ready ? () => _run('email', () => controller.sendCode(_email.text)) : null,
            ),
            SizedBox(
              height: 24,
              child: Row(
                spacing: 12,
                children: [
                  const Expanded(child: Divider(color: AppColors.authLine)),
                  Text(l10n.authAlternative, style: AuthTypography.caption),
                  const Expanded(child: Divider(color: AppColors.authLine)),
                ],
              ),
            ),
            _loginMethods(session, controller, ready, l10n),
          ],
          Text(l10n.authLegalNotice, textAlign: TextAlign.center, style: AuthTypography.caption),
        ],
      ),
    );
  }

  Widget _emailField(
    AuthSession session,
    bool ready,
    AuthController controller,
    AppLocalizations l10n,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      Text(l10n.authEmailLabel, style: AuthTypography.caption),
      TextField(
        key: const Key('login-email'),
        controller: _email,
        enabled: !session.busy,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.email],
        style: AuthTypography.body,
        decoration: InputDecoration(
          hintText: l10n.authEmailPlaceholder,
          fillColor: AppColors.authInput,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.authLine),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.authLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.authAccent),
          ),
        ),
        onSubmitted: ready ? (_) => _run('email', () => controller.sendCode(_email.text)) : null,
      ),
    ],
  );

  Widget _loginMethods(
    AuthSession session,
    AuthController controller,
    bool ready,
    AppLocalizations l10n,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      AuthActionButton(
        key: const Key('login-google'),
        label: l10n.authGoogleContinue,
        asset: 'assets/auth/google.webp',
        busy: session.busy && _pending == 'google',
        onPressed: ready
            ? () => _run('google', () => controller.loginWithSocial(SocialLoginProvider.google))
            : null,
      ),
      AuthActionButton(
        key: const Key('login-x'),
        label: l10n.authXContinue,
        asset: 'assets/auth/x.svg',
        busy: session.busy && _pending == 'x',
        onPressed: ready
            ? () => _run('x', () => controller.loginWithSocial(SocialLoginProvider.x))
            : null,
      ),
      _walletButton(session, controller, ready, l10n),
    ],
  );

  Widget _walletButton(
    AuthSession session,
    AuthController controller,
    bool ready,
    AppLocalizations l10n, {
    bool primary = false,
  }) => AuthActionButton(
    key: const Key('connect-external-wallet'),
    label: switch (session.walletStep) {
      WalletLoginStep.connecting => l10n.walletConnectStep,
      WalletLoginStep.signing => l10n.walletSignStep,
      null => l10n.authWalletContinue,
    },
    asset: 'assets/auth/wallet.svg',
    primary: primary,
    busy: session.busy && _pending == 'wallet',
    onPressed: ready && ref.watch(walletConfigurationProvider).isConfigured
        ? () => _run('wallet', () => controller.connectWallet(context))
        : null,
  );
}
