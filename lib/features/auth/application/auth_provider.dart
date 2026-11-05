import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/privy_configuration.dart';
import '../data/privy_identity_repository.dart';
import '../domain/auth_session.dart';
import '../domain/wallet_connection.dart';
import '../data/reown_wallet_connector.dart';
import '../data/wallet_configuration.dart';

final privyConfigurationProvider = Provider<PrivyConfiguration>(
  (_) => const PrivyConfiguration.environment(),
);
final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  final repository = PrivyIdentityRepository(
    ref.watch(privyConfigurationProvider),
    walletConfiguration: ref.watch(walletConfigurationProvider),
  );
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});
final walletConfigurationProvider = Provider<WalletConfiguration>(
  (_) => const WalletConfiguration.environment(),
);
final walletConnectorProvider = Provider<WalletConnector>((ref) {
  final connector = ReownWalletConnector(ref.watch(walletConfigurationProvider));
  ref.onDispose(() => unawaited(connector.dispose()));
  return connector;
});
final authProvider = NotifierProvider<AuthController, AuthSession>(AuthController.new);

class AuthController extends Notifier<AuthSession> {
  StreamSubscription<AuthIdentity?>? _subscription;
  int _generation = 0;
  bool _loggingOut = false;
  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  @override
  AuthSession build() {
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    scheduleMicrotask(bootstrap);
    return const AuthSession();
  }

  Future<void> bootstrap() async {
    if (!ref.mounted || state.busy) return;
    final generation = _generation;
    final previous = state;
    state = AuthSession(phase: previous.phase, identity: previous.identity, busy: true);
    try {
      final repository = ref.read(identityRepositoryProvider);
      final identity = await repository.initialize();
      if (!_isCurrent(generation)) return;
      _observe(repository);
      state = AuthSession(
        phase: identity == null ? AuthPhase.signedOut : AuthPhase.signedIn,
        identity: identity,
      );
      if (identity != null &&
          identity.walletKind == WalletKind.embedded &&
          identity.walletAddress == null) {
        await createWallet();
      }
    } on AuthFailure catch (failure) {
      if (_isCurrent(generation)) {
        state = AuthSession(
          phase: previous.identity == null ? AuthPhase.signedOut : AuthPhase.signedIn,
          identity: previous.identity,
          failure: failure,
        );
      }
    } catch (_) {
      if (_isCurrent(generation)) {
        state = AuthSession(
          phase: previous.identity == null ? AuthPhase.signedOut : AuthPhase.signedIn,
          identity: previous.identity,
          failure: const AuthFailure('authUnavailable'),
        );
      }
    }
  }

  void _observe(IdentityRepository repository) {
    _subscription ??= repository.changes.listen(
      (identity) {
        if (!ref.mounted || state.identity == null) return;
        if (identity == null) {
          _generation++;
          state = AuthSession(
            phase: AuthPhase.signedOut,
            failure: _loggingOut ? null : const AuthFailure('authSessionUnavailable'),
          );
        } else if (!state.busy &&
            (identity.id != state.identity?.id ||
                identity.walletAddress != state.identity?.walletAddress ||
                identity.walletKind != state.identity?.walletKind ||
                identity.signingAvailable != state.identity?.signingAvailable)) {
          _generation++;
          state = AuthSession(phase: AuthPhase.signedIn, identity: identity);
        }
      },
      onError: (Object _) {
        // Initialization / explicit commands surface SDK failures. A failed
        // observer alone does not prove that the user has logged out.
      },
    );
  }

  Future<void> sendCode(String input) async {
    if (state.busy || state.identity != null) return;
    final generation = _generation;
    final email = input.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      state = AuthSession(
        phase: AuthPhase.signedOut,
        email: email,
        failure: const AuthFailure('authInvalidEmail'),
      );
      return;
    }
    if (state.email == email && state.resendAt?.isAfter(DateTime.now()) == true) {
      state = AuthSession(phase: AuthPhase.awaitingCode, email: email, resendAt: state.resendAt);
      return;
    }
    final previous = state;
    state = AuthSession(
      phase: previous.phase,
      email: email,
      busy: true,
      resendAt: previous.resendAt,
    );
    try {
      // A configuration error can be retried after initializing the SDK.
      if (previous.failure?.key == 'authConfiguration' ||
          previous.phase == AuthPhase.initializing) {
        await ref.read(identityRepositoryProvider).initialize();
        _observe(ref.read(identityRepositoryProvider));
      }
      await ref.read(identityRepositoryProvider).sendCode(email);
      if (!_isCurrent(generation)) return;
      state = AuthSession(
        phase: AuthPhase.awaitingCode,
        email: email,
        resendAt: DateTime.now().add(const Duration(seconds: 60)),
      );
    } on AuthFailure catch (failure) {
      if (_isCurrent(generation)) {
        state = AuthSession(
          phase: previous.phase,
          email: email,
          resendAt: previous.resendAt,
          failure: failure,
        );
      }
    } catch (_) {
      if (_isCurrent(generation)) {
        state = AuthSession(
          phase: previous.phase,
          email: email,
          failure: const AuthFailure('authUnavailable'),
        );
      }
    }
  }

  Future<void> verifyCode(String input) async {
    if (state.busy || state.phase != AuthPhase.awaitingCode) return;
    final generation = _generation;
    final code = input.trim();
    final previous = state;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      state = AuthSession(
        phase: previous.phase,
        email: previous.email,
        resendAt: previous.resendAt,
        failure: const AuthFailure('authInvalidCode'),
      );
      return;
    }
    state = AuthSession(
      phase: previous.phase,
      email: previous.email,
      busy: true,
      resendAt: previous.resendAt,
    );
    try {
      final identity = await ref.read(identityRepositoryProvider).verifyCode(previous.email, code);
      if (!_isCurrent(generation)) return;
      state = AuthSession(phase: AuthPhase.signedIn, identity: identity);
      await createWallet();
    } on AuthFailure catch (failure) {
      if (_isCurrent(generation)) {
        state = AuthSession(
          phase: previous.phase,
          email: previous.email,
          resendAt: previous.resendAt,
          failure: failure,
        );
      }
    } catch (_) {
      if (_isCurrent(generation)) {
        state = AuthSession(
          phase: previous.phase,
          email: previous.email,
          resendAt: previous.resendAt,
          failure: const AuthFailure('authUnavailable'),
        );
      }
    }
  }

  void changeEmail() {
    if (state.busy || state.identity != null) return;
    state = AuthSession(phase: AuthPhase.signedOut, email: state.email, resendAt: state.resendAt);
  }

  Future<void> createWallet() async {
    final identity = state.identity;
    if (state.busy ||
        identity == null ||
        identity.walletAddress != null ||
        identity.walletKind == WalletKind.external) {
      return;
    }
    final generation = _generation;
    state = AuthSession(phase: AuthPhase.signedIn, identity: identity, busy: true);
    try {
      final withWallet = await ref.read(identityRepositoryProvider).ensureWallet();
      if (_isCurrent(generation)) {
        state = AuthSession(phase: AuthPhase.signedIn, identity: withWallet);
      }
    } on AuthFailure catch (failure) {
      if (_isCurrent(generation)) {
        state = AuthSession(phase: AuthPhase.signedIn, identity: identity, failure: failure);
      }
    } catch (_) {
      if (_isCurrent(generation)) {
        state = AuthSession(
          phase: AuthPhase.signedIn,
          identity: identity,
          failure: const AuthFailure('authUnavailable'),
        );
      }
    }
  }

  Future<void> connectWallet(BuildContext context, {String? expectedAddress}) async {
    if (state.busy ||
        (state.identity != null && state.identity?.walletKind != WalletKind.external)) {
      return;
    }
    final generation = _generation;
    final previous = state;
    WalletConnection? connection;
    state = AuthSession(
      phase: previous.phase,
      identity: previous.identity,
      email: previous.email,
      busy: true,
      walletStep: WalletLoginStep.connecting,
    );
    try {
      final repository = ref.read(identityRepositoryProvider);
      // Initialize without auto-creating any wallet. EOA login owns its signer.
      await repository.initialize();
      if (!_isCurrent(generation)) return;
      _observe(repository);
      if (!_isCurrent(generation) || !context.mounted) return;
      connection = await ref.read(walletConnectorProvider).connect(context);
      if (!_isCurrent(generation) || !context.mounted) {
        await connection.disconnect();
        return;
      }
      final expected = expectedAddress ?? previous.identity?.walletAddress;
      if (expected != null && expected.toLowerCase() != connection.address.toLowerCase()) {
        throw const AuthFailure('authWalletChanged');
      }
      state = AuthSession(
        phase: previous.phase,
        identity: previous.identity,
        busy: true,
        walletStep: WalletLoginStep.signing,
      );
      final identity = await repository.loginWithWallet(connection);
      if (!_isCurrent(generation)) {
        await connection.disconnect();
        return;
      }
      state = AuthSession(phase: AuthPhase.signedIn, identity: identity);
    } catch (error) {
      if (_isCurrent(generation)) {
        state = AuthSession(
          phase: previous.phase,
          identity: previous.identity,
          email: previous.email,
          resendAt: previous.resendAt,
          failure: error is AuthFailure ? error : const AuthFailure('authWalletUnavailable'),
        );
      }
      try {
        await connection?.disconnect();
      } catch (_) {
        // The original safe failure remains visible if relay cleanup fails.
      }
    } finally {
      if (_isCurrent(generation) && state.busy) {
        state = AuthSession(
          phase: previous.phase,
          identity: previous.identity,
          email: previous.email,
          failure: const AuthFailure('authWalletCancelled'),
        );
      }
    }
  }

  /// Explicit account switch signs out first. New identity is accepted only
  /// after SIWE for the selected address; no local active-account override.
  Future<void> switchToWallet(BuildContext context, String expectedAddress) async {
    if (state.busy || !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(expectedAddress)) return;
    if (state.identity?.walletAddress?.toLowerCase() == expectedAddress.toLowerCase()) return;
    if (state.identity != null) await logout();
    if (!ref.mounted || !context.mounted || state.identity != null || state.busy) return;
    await connectWallet(context, expectedAddress: expectedAddress);
  }

  Future<void> logout() async {
    if (state.busy || state.identity == null) return;
    final generation = _generation;
    final previous = state;
    _loggingOut = true;
    state = AuthSession(phase: previous.phase, identity: previous.identity, busy: true);
    try {
      await ref.read(identityRepositoryProvider).logout();
      if (_isCurrent(generation)) state = const AuthSession(phase: AuthPhase.signedOut);
    } on AuthFailure catch (failure) {
      if (_isCurrent(generation)) {
        state = AuthSession(phase: previous.phase, identity: previous.identity, failure: failure);
      }
    } catch (_) {
      if (_isCurrent(generation)) {
        state = AuthSession(
          phase: previous.phase,
          identity: previous.identity,
          failure: const AuthFailure('authUnavailable'),
        );
      }
    } finally {
      _loggingOut = false;
    }
  }
}
