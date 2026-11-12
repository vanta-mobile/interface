import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'startup_splash.dart';
import '../application/auth_provider.dart';
import '../domain/auth_session.dart';
import 'wallet_onboarding_flow.dart';
import 'wallet_session_host.dart';

class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({required this.home, super.key});
  final Widget home;

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  bool _finished = false, _restoring = false;
  String? _restoredKey;

  void _finish() => setState(() => _finished = true);

  @override
  Widget build(BuildContext context) {
    if (_finished) return WalletSessionHost(child: widget.home);
    final auth = ref.watch(authProvider), identity = auth.identity;
    if (auth.phase == AuthPhase.initializing || auth.busy || _restoring) {
      return const StartupSplash();
    }
    if (identity == null) {
      // Keep the public home available to signed-out users, as before.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finish();
      });
      return const StartupSplash();
    }
    final key = '${identity.id}:${identity.walletAddress}';
    if (identity.needsWalletConnection && _restoredKey != key) {
      _restoredKey = key;
      _restoring = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref.read(authProvider.notifier).restoreWalletSession(context).whenComplete(() {
            if (mounted) setState(() => _restoring = false);
          }),
        );
      });
      return const StartupSplash();
    }
    return WalletOnboardingFlow(onCompleted: _finish, onCancel: _finish);
  }
}
