import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/vanta_api/vanta_api_configuration.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../../core/vanta_api/vanta_api_http.dart';
import '../data/vanta_api_session_repository.dart';
import '../data/vanta_api_session_store.dart';
import '../domain/auth_session.dart';
import '../domain/wallet_message_signer.dart';
import 'auth_provider.dart';

final vantaApiConfigurationProvider = Provider<VantaApiConfiguration>(
  (_) => const VantaApiConfiguration.environment(),
);
final vantaApiSessionStoreProvider = Provider<VantaApiSessionStore>(
  (_) => NativeVantaApiSessionStore(),
);
final vantaApiClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Null when `VANTA_API_ORIGIN` or the SIWE relying party is not configured.
final vantaApiSessionRepositoryProvider = Provider<VantaApiSessionRepository?>((ref) {
  final base = ref.watch(vantaApiConfigurationProvider).baseUri;
  final relyingParty = ref.watch(walletConfigurationProvider).relyingParty;
  if (base == null || relyingParty == null) return null;
  final repository = VantaApiSessionRepository(
    http: VantaApiHttp(baseUri: base, client: ref.watch(backendHttpPoolProvider).lease()),
    store: ref.watch(vantaApiSessionStoreProvider),
    relyingParty: relyingParty,
    now: ref.watch(vantaApiClockProvider),
    signer: () {
      final identity = ref.read(identityRepositoryProvider);
      if (identity is! WalletMessageSigner) throw const AuthFailure('authWalletReconnect');
      return identity as WalletMessageSigner;
    },
  );
  ref.onDispose(repository.close);
  return repository;
});

enum VantaApiSessionStatus { unavailable, signedOut, restoring, signing, ready }

class VantaApiSessionState {
  const VantaApiSessionState(this.status, {this.address, this.failure});
  final VantaApiSessionStatus status;

  /// Lowercase wallet the session belongs to; data from another wallet is stale.
  final String? address;

  /// Last sign-in failure (cancelled or rejected signature, network, server code).
  final Object? failure;
  bool get ready => status == VantaApiSessionStatus.ready;
  bool get pending =>
      status == VantaApiSessionStatus.restoring || status == VantaApiSessionStatus.signing;
}

final vantaApiSessionProvider = NotifierProvider<VantaApiSessionController, VantaApiSessionState>(
  VantaApiSessionController.new,
);

/// Restores a stored session for the active wallet without opening the wallet.
/// [ensure] requests SIWE from an explicit external-wallet action or the
/// user-authorized silent embedded-wallet onboarding flow.
class VantaApiSessionController extends Notifier<VantaApiSessionState> {
  int _generation = 0;
  Future<void>? _pending;
  Future<void>? _signingOut;
  bool _pendingExplicit = false;

  @override
  VantaApiSessionState build() {
    final repository = ref.watch(vantaApiSessionRepositoryProvider);
    if (repository == null) return const VantaApiSessionState(VantaApiSessionStatus.unavailable);
    repository.onSessionLost = (address) {
      if (!ref.mounted || state.address != address) return;
      _generation++;
      state = VantaApiSessionState(VantaApiSessionStatus.signedOut, address: address);
    };
    ref.listen(authProvider.select(_signingKey), (previous, next) {
      final generation = ++_generation;
      _pending = null;
      if (previous?.$1 != null && previous!.$1 != next.$1) {
        // Logout removes this session's push devices on the server before
        // restoring/signing another wallet. Never race the store clear with restore.
        state = VantaApiSessionState(VantaApiSessionStatus.signedOut, address: next.$1);
        final logout = repository.signOut();
        _signingOut = logout;
        unawaited(
          logout.whenComplete(() {
            if (identical(_signingOut, logout)) _signingOut = null;
            if (ref.mounted && generation == _generation) unawaited(_sync());
          }),
        );
      } else {
        unawaited(_sync());
      }
    });
    ref.onDispose(() => _generation++);
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(_sync());
    });
    return const VantaApiSessionState(VantaApiSessionStatus.restoring);
  }

  static (String?, bool, String?) _signingKey(AuthSession session) {
    final identity = session.identity;
    final address = identity?.walletAddress?.toLowerCase();
    return (address, identity?.signingAvailable == true && !session.busy, identity?.id);
  }

  /// Explicit sign-in: completes once the signature attempt has settled.
  Future<void> ensure() {
    if (state.ready || state.status == VantaApiSessionStatus.unavailable) return Future.value();
    return _sync(explicit: true);
  }

  Future<void> _sync({bool explicit = false}) {
    if (_signingOut case final logout?) {
      final generation = _generation;
      return logout.then((_) async {
        if (ref.mounted && generation == _generation) await _sync(explicit: explicit);
      });
    }
    if (_pending case final pending?) {
      if (!explicit || _pendingExplicit) return pending;
      final generation = _generation;
      return pending.then((_) async {
        if (!ref.mounted || generation != _generation) return;
        await ensure();
      });
    }
    _pendingExplicit = explicit;
    final task = _run(explicit);
    _pending = task;
    return task.whenComplete(() {
      if (identical(_pending, task)) _pending = null;
    });
  }

  Future<void> _run(bool explicit) async {
    final repository = ref.read(vantaApiSessionRepositoryProvider);
    if (repository == null) return;
    final (address, canSign, _) = _signingKey(ref.read(authProvider));
    final generation = _generation;
    bool current() => ref.mounted && generation == _generation;
    if (address == null) {
      state = const VantaApiSessionState(VantaApiSessionStatus.signedOut);
      return;
    }
    if (state.address == address && state.ready) return;
    final previousFailure = state.address == address ? state.failure : null;
    state = VantaApiSessionState(VantaApiSessionStatus.restoring, address: address);
    try {
      if (await repository.restore(address)) {
        if (current()) state = VantaApiSessionState(VantaApiSessionStatus.ready, address: address);
        return;
      }
    } catch (error) {
      if (current()) {
        state = VantaApiSessionState(
          VantaApiSessionStatus.signedOut,
          address: address,
          failure: error is AuthFailure || error is VantaApiFailure
              ? error
              : const VantaApiFailure(vantaApiRequestFailed),
        );
      }
      return;
    }
    if (!current()) return;
    if (!canSign || !explicit) {
      state = VantaApiSessionState(
        VantaApiSessionStatus.signedOut,
        address: address,
        failure: previousFailure,
      );
      return;
    }
    state = VantaApiSessionState(VantaApiSessionStatus.signing, address: address);
    try {
      await repository.signIn(address, isCurrent: current);
      if (current()) state = VantaApiSessionState(VantaApiSessionStatus.ready, address: address);
    } catch (error) {
      if (!current()) return;
      state = VantaApiSessionState(
        VantaApiSessionStatus.signedOut,
        address: address,
        failure: error is VantaApiFailure || error is AuthFailure
            ? error
            : const VantaApiFailure(vantaApiRequestFailed),
      );
    }
  }
}
