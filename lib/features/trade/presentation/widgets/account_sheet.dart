import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_provider.dart';
import '../../../auth/domain/auth_session.dart';
import '../../../auth/presentation/identity_panel.dart';
import '../../../auth/presentation/login_screen.dart';

void showAccountSheet(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const LoginScreen(account: AccountSheet())));

/// The step an action takes before the wallet can sign, or null once it can:
/// account setup without an address, otherwise a direct reconnection when the
/// external wallet must be connected again (for example after it no longer
/// recognised this app's session).
VoidCallback? walletConnectionAction(BuildContext context, WidgetRef ref, AuthIdentity? identity) =>
    identity?.walletAddress == null
    ? () => showAccountSheet(context)
    : identity!.needsWalletConnection
    ? () => unawaited(ref.read(authProvider.notifier).connectWallet(context))
    : null;

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});
  @override
  Widget build(BuildContext context) => const IdentityPanel();
}
