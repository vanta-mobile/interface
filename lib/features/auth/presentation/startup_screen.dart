import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'startup_splash.dart';
import '../application/auth_provider.dart';
import '../application/geo_restriction_provider.dart';
import '../application/wallet_onboarding_provider.dart';
import '../domain/auth_session.dart';
import 'geo_restriction_dialog.dart';
import 'wallet_onboarding_flow.dart';
import 'wallet_session_host.dart';

class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({required this.home, super.key});
  final Widget home;

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  bool _finished = false, _restoring = false, _introPlayed = false;
  bool _startupResolved = false;
  String? _restoredKey;
  bool _checkOnEntry = false, _entryCheckScheduled = false, _entryPromptOpen = false;
  bool _geoChecked = false;

  void _finish() => setState(() => _finished = true);

  void _checkEntry() {
    if (!_entryPromptOpen && (ModalRoute.of(context)?.isCurrent ?? false)) {
      setState(() => _checkOnEntry = true);
    }
  }

  Widget _home() {
    if (_checkOnEntry) {
      final auth = ref.watch(authProvider);
      final status = ref.watch(walletOnboardingStatusProvider);
      final progress = ref.watch(walletOnboardingProvider);
      if (!auth.busy && !status.checking && !progress.busy && !_entryCheckScheduled) {
        _entryCheckScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _resumeOnboarding());
      }
    }
    return WalletSessionHost(
      onRestored: _checkEntry,
      initiallyAttemptedIdentity: _restoredKey,
      child: widget.home,
    );
  }

  void _resumeOnboarding() {
    _entryCheckScheduled = false;
    if (!mounted) return;
    final auth = ref.read(authProvider), identity = auth.identity;
    final status = ref.read(walletOnboardingStatusProvider);
    if (auth.busy || status.checking || ref.read(walletOnboardingProvider).busy) return;
    setState(() => _checkOnEntry = false);
    if (_entryPromptOpen ||
        !(ModalRoute.of(context)?.isCurrent ?? false) ||
        identity?.walletAddress == null ||
        identity?.signingAvailable != true ||
        status.complete) {
      return;
    }
    // Push over the existing home so backgrounding never discards order input.
    _entryPromptOpen = true;
    final navigator = Navigator.of(context);
    late final MaterialPageRoute<void> route;
    void close() {
      if (route.isCurrent) navigator.pop();
    }

    route = MaterialPageRoute<void>(
      builder: (_) =>
          WalletOnboardingFlow(automaticEmbedded: false, onCompleted: close, onCancel: close),
    );
    unawaited(navigator.push(route).whenComplete(() => _entryPromptOpen = false));
  }

  @override
  Widget build(BuildContext context) {
    // Startup restoration runs during the intro; its destination waits for it.
    final destination = _destination();
    if (_introPlayed) {
      if (!_geoChecked) {
        final geo = ref.watch(geoRestrictionProvider);
        geo.whenData((restriction) {
          if (restriction.blocked && !_geoChecked) {
            _geoChecked = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                unawaited(showGeoRestrictionDialog(context, restriction.restrictedAreas));
            });
          } else if (!restriction.blocked) {
            _geoChecked = true;
          }
        });
      }
      return destination;
    }
    return StartupSplash(onIntroCompleted: () => setState(() => _introPlayed = true));
  }

  Widget _destination() {
    if (_finished) return _home();
    if (_startupResolved) {
      return WalletOnboardingFlow(
        automaticEmbedded: false,
        onCompleted: _finish,
        onCancel: _finish,
      );
    }
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
    _startupResolved = true;
    return WalletOnboardingFlow(automaticEmbedded: false, onCompleted: _finish, onCancel: _finish);
  }
}
