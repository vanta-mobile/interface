import '../../subaccounts/presentation/subaccount_list_screen.dart';
import '../../authorization/presentation/trading_authorization_screen.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_provider.dart';
import '../domain/auth_session.dart';

class IdentityPanel extends ConsumerStatefulWidget {
  const IdentityPanel({super.key});
  @override
  ConsumerState<IdentityPanel> createState() => _IdentityPanelState();
}

class _IdentityPanelState extends ConsumerState<IdentityPanel> {
  final email = TextEditingController();
  final code = TextEditingController();
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    email.text = ref.read(authProvider).email;
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(authProvider).phase == AuthPhase.awaitingCode) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    email.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((session) => session.identity?.id), (previous, next) {
      code.clear();
      if (next == null) email.clear();
    });
    final session = ref.watch(authProvider);
    final controller = ref.read(authProvider.notifier);
    final identity = session.identity;
    final awaitingCode = session.phase == AuthPhase.awaitingCode;
    final seconds = session.resendAt == null
        ? 0
        : session.resendAt!.difference(DateTime.now()).inSeconds.clamp(0, 60);
    final configurationReady = ref.watch(privyConfigurationProvider).isConfigured;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr(context, identity == null ? 'loginTitle' : 'account'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (identity == null) ...[
          Text(tr(context, 'loginDescription'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          if (awaitingCode)
            ..._codeFields(session, controller, seconds)
          else
            ..._emailFields(session, controller, configurationReady),
        ] else
          ..._walletFields(identity, session, controller),
        if (session.busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            tr(context, switch (session.walletStep) {
              WalletLoginStep.connecting => 'walletConnectStep',
              WalletLoginStep.signing => 'walletSignStep',
              null => identity == null ? 'loginInProgress' : 'walletInProgress',
            }),
          ),
        ],
        if (session.failure case final failure?) ...[
          const SizedBox(height: 12),
          Text(
            '${tr(context, failure.key)}${failure.reason == null ? '' : '\n${failure.reason}'}',
            key: const Key('auth-error'),
            style: const TextStyle(color: AppColors.negative),
          ),
        ],
      ],
    );
  }

  List<Widget> _codeFields(AuthSession session, AuthController controller, int seconds) => [
    SelectableText(session.email),
    const SizedBox(height: 12),
    TextField(
      key: const Key('login-code'),
      controller: code,
      enabled: !session.busy,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(labelText: tr(context, 'verificationCode')),
      onSubmitted: (_) => controller.verifyCode(code.text),
    ),
    const SizedBox(height: 12),
    FilledButton(
      key: const Key('verify-email-code'),
      onPressed: session.busy ? null : () => controller.verifyCode(code.text),
      child: Text(tr(context, 'verifyAndLogin')),
    ),
    Wrap(
      alignment: WrapAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: session.busy || seconds > 0 ? null : () => controller.sendCode(session.email),
          child: Text(
            seconds > 0
                ? AppLocalizations.of(context).resendCountdown(seconds)
                : tr(context, 'resendCode'),
          ),
        ),
        TextButton(
          onPressed: session.busy
              ? null
              : () {
                  code.clear();
                  controller.changeEmail();
                },
          child: Text(tr(context, 'changeEmail')),
        ),
      ],
    ),
  ];

  List<Widget> _emailFields(
    AuthSession session,
    AuthController controller,
    bool configurationReady,
  ) => [
    TextField(
      key: const Key('login-email'),
      controller: email,
      enabled: !session.busy && configurationReady,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(labelText: tr(context, 'emailAddress')),
      onSubmitted: (_) => controller.sendCode(email.text),
    ),
    const SizedBox(height: 12),
    FilledButton(
      key: const Key('send-email-code'),
      onPressed: session.busy || !configurationReady ? null : () => controller.sendCode(email.text),
      child: Text(tr(context, 'sendCode')),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      key: const Key('connect-external-wallet'),
      onPressed:
          session.busy ||
              !configurationReady ||
              !ref.watch(walletConfigurationProvider).isConfigured
          ? null
          : () => controller.connectWallet(context),
      icon: const Icon(Icons.account_balance_wallet_outlined),
      label: Text(tr(context, 'connectExternalWallet')),
    ),
    Text(tr(context, 'externalWalletLoginHint'), style: Theme.of(context).textTheme.bodySmall),
    if (!ref.watch(walletConfigurationProvider).isConfigured)
      Text(tr(context, 'authWalletConfiguration'), style: Theme.of(context).textTheme.bodySmall),
  ];

  List<Widget> _walletFields(
    AuthIdentity identity,
    AuthSession session,
    AuthController controller,
  ) => [
    Text(
      tr(context, identity.walletKind == WalletKind.external ? 'externalWallet' : 'embeddedWallet'),
      style: Theme.of(context).textTheme.bodySmall,
    ),
    if (identity.email != null) SelectableText(identity.email!),
    const SizedBox(height: 12),
    if (identity.walletAddress case final address?)
      Row(
        children: [
          Expanded(child: SelectableText(address)),
          IconButton(
            tooltip: tr(context, 'copyAddress'),
            onPressed: () => Clipboard.setData(ClipboardData(text: address)),
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      )
    else if (identity.walletKind == WalletKind.embedded)
      OutlinedButton(
        key: const Key('create-wallet'),
        onPressed: session.busy ? null : controller.createWallet,
        child: Text(tr(context, 'createWallet')),
      ),
    if (identity.walletKind == WalletKind.external && !identity.signingAvailable) ...[
      const SizedBox(height: 12),
      Text(tr(context, 'authWalletReconnect')),
      OutlinedButton(
        key: const Key('reconnect-external-wallet'),
        onPressed: session.busy ? null : () => controller.connectWallet(context),
        child: Text(tr(context, 'reconnectExternalWallet')),
      ),
    ],
    const SizedBox(height: 12),
    OutlinedButton(
      key: const Key('trading-authorization-entry'),
      onPressed: session.busy ? null : () => openTradingAuthorization(context),
      child: Text(AppLocalizations.of(context).authorizationTitle),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      key: const Key('subaccount-list-entry'),
      onPressed: session.busy ? null : () => openSubaccountList(context),
      icon: const Icon(Icons.manage_accounts_outlined),
      label: Text(AppLocalizations.of(context).subaccountManagement),
    ),
    const SizedBox(height: 12),
    OutlinedButton(
      key: const Key('logout-identity'),
      onPressed: session.busy ? null : controller.logout,
      child: Text(tr(context, 'logout')),
    ),
  ];
}
