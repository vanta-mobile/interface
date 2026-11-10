import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_switch_authorization.dart';
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
  final repository = PrivyIdentityRepository(ref.watch(privyConfigurationProvider));
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
// Switching uses a fresh SDK connection so a rejected target connection cannot
// disconnect the current signing wallet during connector preparation.
final walletSwitchConnectorFactoryProvider = Provider<WalletConnector Function()>((ref) {
  final config = ref.watch(walletConfigurationProvider);
  return () => ReownWalletConnector(config);
});
final accountSwitchAuthorizationProvider = Provider<AccountSwitchAuthorization>(
  (ref) => AccountSwitchAuthorization(ref.watch(identityRepositoryProvider).signWalletRequest),
);
final authProvider = NotifierProvider<AuthController, AuthSession>(AuthController.new);

class AuthController extends Notifier<AuthSession> {
  StreamSubscription<AuthIdentity?>? _subscription;
  int _generation = 0;
  bool _loggingOut = false;
  bool _refreshing = false;
  bool _restoringWallet = false;
  WalletConnector? _switchConnector;
  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  @override
  AuthSession build() {
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      unawaited(_switchConnector?.dispose());
    });
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

  /// Reconcile an existing native session after returning to the app. Unlike
  /// initial login, this never creates a wallet or toggles busy for the same
  /// identity. SDK changes and explicit commands supersede a late result.
  Future<void> refreshSession() async {
    if (!ref.mounted || state.busy || state.identity == null || _refreshing) return;
    _refreshing = true;
    final generation = _generation;
    final previous = state;
    bool current() => _isCurrent(generation) && identical(state, previous);
    try {
      final identity = await ref.read(identityRepositoryProvider).initialize();
      if (!current()) return;
      if (identity == null) {
        _generation++;
        state = const AuthSession(
          phase: AuthPhase.signedOut,
          failure: AuthFailure('authSessionUnavailable'),
        );
      } else if (identity.id != previous.identity?.id ||
          identity.email != previous.identity?.email ||
          identity.walletAddress != previous.identity?.walletAddress ||
          identity.walletKind != previous.identity?.walletKind ||
          identity.walletName != previous.identity?.walletName ||
          identity.signingAvailable != previous.identity?.signingAvailable) {
        _generation++;
        state = AuthSession(phase: AuthPhase.signedIn, identity: identity);
      }
    } catch (error) {
      if (current()) {
        state = AuthSession(
          phase: previous.phase,
          identity: previous.identity,
          failure: error is AuthFailure ? error : const AuthFailure('authUnavailable'),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> restoreWalletSession(BuildContext context) async {
    if (!ref.mounted || state.busy || _restoringWallet) return;
    final identity = state.identity;
    if (identity?.needsWalletConnection != true || identity?.walletAddress == null) return;
    final connector = ref.read(walletConnectorProvider);
    if (connector is! WalletSessionRestorer) return;
    _restoringWallet = true;
    final generation = _generation;
    final previous = state;
    final pending = AuthSession(phase: previous.phase, identity: identity, busy: true);
    state = pending;
    bool current() => _isCurrent(generation) && identical(state, pending);
    WalletConnection? connection;
    try {
      connection = await (connector as WalletSessionRestorer).restore(
        context,
        expectedAddress: identity!.walletAddress!,
      );
      if (!current()) {
        await connection?.release();
        return;
      }
      final repository = ref.read(identityRepositoryProvider);
      if (connection == null) {
        await repository.logout();
        if (current()) state = const AuthSession(phase: AuthPhase.signedOut);
        return;
      }
      final restored = await repository.loginWithWallet(connection);
      if (!current()) return;
      state = AuthSession(phase: AuthPhase.signedIn, identity: restored);
    } catch (error) {
      await connection?.release();
      if (current()) {
        state = AuthSession(
          phase: previous.phase,
          identity: previous.identity,
          failure: error is AuthFailure ? error : const AuthFailure('authUnavailable'),
        );
      }
    } finally {
      _restoringWallet = false;
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
                identity.walletName != state.identity?.walletName ||
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
    await _login(
      previous,
      () => ref.read(identityRepositoryProvider).verifyCode(previous.email, code),
    );
  }

  Future<void> _login(AuthSession previous, Future<AuthIdentity> Function() operation) async {
    final generation = _generation;
    state = AuthSession(
      phase: previous.phase,
      email: previous.email,
      busy: true,
      resendAt: previous.resendAt,
    );
    try {
      final identity = await operation();
      if (!_isCurrent(generation)) return;
      state = AuthSession(phase: AuthPhase.signedIn, identity: identity);
      await createWallet();
    } on AuthFailure catch (failure) {
      if (_isCurrent(generation)) {
        state = AuthSession(
          phase: previous.phase,
          email: previous.email,
          resendAt: failure.key == 'authCodeExpired' ? null : previous.resendAt,
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

  Future<void> loginWithSocial(SocialLoginProvider provider) async {
    if (state.busy || state.identity != null) return;
    final previous = state;
    final generation = _generation;
    await _login(previous, () async {
      final repository = ref.read(identityRepositoryProvider);
      if (previous.failure?.key == 'authConfiguration' ||
          previous.phase == AuthPhase.initializing) {
        await repository.initialize();
        if (!_isCurrent(generation)) throw const AuthFailure('authSessionUnavailable');
        _observe(repository);
      }
      return repository.loginWithSocial(provider);
    });
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

  /// Connect the target before replacing the active identity. A separate
  /// connector preserves the current wallet when approval is cancelled.
  Future<void> switchToWallet(BuildContext context, String expectedAddress) async {
    if (state.busy || !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(expectedAddress)) return;
    if (state.identity?.walletAddress?.toLowerCase() == expectedAddress.toLowerCase()) return;
    final connector = ref.read(walletSwitchConnectorFactoryProvider)();
    final accepted = await _switchConnection(
      () => connector.connect(context),
      expectedAddress: expectedAddress,
    );
    if (accepted) {
      final previousConnector = _switchConnector;
      _switchConnector = connector;
      try {
        await previousConnector?.dispose();
      } catch (_) {
        // Cleanup cannot invalidate the newly connected identity.
      }
    } else {
      try {
        await connector.dispose();
      } catch (_) {
        // Preserve the connection failure when relay cleanup fails.
      }
    }
  }

  /// Authorize with the current wallet before activating a device signing connection.
  Future<void> switchWithConnection(WalletConnection connection) async {
    if (state.busy) {
      await _releaseSwitchConnection(connection);
      return;
    }
    final accepted = await _switchConnection(
      () async => connection,
      expectedAddress: connection.address,
    );
    if (!accepted) await _releaseSwitchConnection(connection);
  }

  Future<bool> _switchConnection(
    Future<WalletConnection> Function() connect, {
    required String expectedAddress,
  }) async {
    if (state.busy) return false;
    final previous = state, generation = _generation;
    WalletConnection? connection;
    state = AuthSession(
      phase: previous.phase,
      identity: previous.identity,
      busy: true,
      walletStep: WalletLoginStep.connecting,
    );
    try {
      final from = previous.identity?.walletAddress;
      if (from == null || previous.identity?.signingAvailable != true) {
        throw const AuthFailure('authWalletReconnect');
      }
      await ref
          .read(accountSwitchAuthorizationProvider)
          .authorize(
            from: from,
            to: expectedAddress,
            isCurrent: () => _isCurrent(generation) && identical(state.identity, previous.identity),
          );
      if (!_isCurrent(generation)) return false;
      connection = await connect();
      if (!_isCurrent(generation)) {
        await _releaseSwitchConnection(connection);
        return false;
      }
      if (!connection.isCurrent ||
          connection.address.toLowerCase() != expectedAddress.toLowerCase()) {
        throw const AuthFailure('authWalletChanged');
      }
      final identity = await ref.read(identityRepositoryProvider).loginWithWallet(connection);
      if (!_isCurrent(generation)) {
        await _releaseSwitchConnection(connection);
        return false;
      }
      if (identity.walletAddress?.toLowerCase() != expectedAddress.toLowerCase()) {
        throw const AuthFailure('authWalletChanged');
      }
      state = AuthSession(phase: AuthPhase.signedIn, identity: identity);
      return true;
    } catch (error) {
      if (_isCurrent(generation)) {
        state = AuthSession(
          phase: previous.phase,
          identity: previous.identity,
          failure: error is AuthFailure ? error : const AuthFailure('authWalletUnavailable'),
        );
      }
      await _releaseSwitchConnection(connection);
      return false;
    }
  }

  Future<void> _releaseSwitchConnection(WalletConnection? connection) async {
    try {
      await connection?.release();
    } catch (_) {
      // Keep the original failure or identity invalidation authoritative.
    }
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
