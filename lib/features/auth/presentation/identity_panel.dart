import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../subaccounts/presentation/subaccount_list_screen.dart';
import '../../authorization/presentation/trading_authorization_screen.dart';
import '../application/auth_provider.dart';
import '../domain/auth_session.dart';
import 'auth_controls.dart';
import 'login_panel.dart';

class IdentityPanel extends ConsumerWidget {
  const IdentityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    final identity = session.identity;
    if (identity == null || identity.needsWalletConnection) return const LoginPanel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr(context, 'account'), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ..._walletFields(context, identity, session, ref.read(authProvider.notifier)),
        if (session.failure case final failure?) ...[
          const SizedBox(height: 12),
          AuthFailureText(failure),
        ],
      ],
    );
  }

  List<Widget> _walletFields(
    BuildContext context,
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
