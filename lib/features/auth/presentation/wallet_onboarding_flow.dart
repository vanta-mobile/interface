import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authorization/presentation/enable_trading_screen.dart';
import '../application/auth_provider.dart';
import '../application/wallet_onboarding_provider.dart';
import '../domain/auth_session.dart';
import 'startup_splash.dart';

/// Used by both cold startup and a newly connected/login wallet.
class WalletOnboardingFlow extends ConsumerStatefulWidget {
  const WalletOnboardingFlow({required this.onCompleted, required this.onCancel, super.key});
  final VoidCallback onCompleted, onCancel;

  @override
  ConsumerState<WalletOnboardingFlow> createState() => _WalletOnboardingFlowState();
}

class _WalletOnboardingFlowState extends ConsumerState<WalletOnboardingFlow> {
  bool _inspected = false;
  String? _identityKey;
  WalletOnboardingController? _controller;

  @override
  void dispose() {
    if (_identityKey case final key?) _controller?.stopAutomatic(key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final status = ref.watch(walletOnboardingStatusProvider);
    final progress = ref.watch(walletOnboardingProvider);
    final identity = auth.identity;
    final key = onboardingIdentityKey(identity);
    final embedded = identity?.walletKind == WalletKind.embedded;
    if (_identityKey != key) _inspected = false;
    _identityKey = key;
    _controller = ref.read(walletOnboardingProvider.notifier);
    if (status.complete && !progress.busy || identity == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) widget.onCompleted();
      });
      return const StartupSplash();
    }
    if (embedded && key != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ref.read(walletOnboardingProvider.notifier).startAutomatic(key);
      });
    }
    if (!status.checking) _inspected = true;
    if (auth.busy ||
        status.checking && !_inspected ||
        embedded && (progress.automaticKey != key || progress.busy)) {
      return const StartupSplash();
    }
    return EnableTradingScreen(closeWhenComplete: false, onCancel: widget.onCancel);
  }
}
