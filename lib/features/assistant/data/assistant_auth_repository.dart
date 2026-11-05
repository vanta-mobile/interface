import 'dart:async';

import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_message_signer.dart';
import '../domain/assistant.dart';
import '../domain/assistant_session.dart';
import 'assistant_auth_service.dart';
import 'assistant_personal_signature.dart';
import 'assistant_vault.dart';

class AssistantAuthRepository {
  AssistantAuthRepository({
    required this.service,
    required this.vault,
    required this.signer,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AssistantAuthService service;
  final AssistantVault vault;
  final WalletMessageSigner Function() signer;
  final DateTime Function() now;
  AssistantCancellation? _active;
  AssistantChallenge? _prepared;
  bool _busy = false, _closed = false;

  void cancel() {
    _prepared = null;
    _active?.cancel();
  }

  void close() {
    _closed = true;
    cancel();
  }

  Future<T> _operation<T>(
    AssistantCancellation cancellation,
    bool Function() isCurrent,
    Future<T> Function(void Function() guard) run,
  ) async {
    if (_busy) throw const AssistantFailure('assistantBusy');
    void guard() {
      cancellation.check();
      if (_closed || !isCurrent()) throw const AssistantFailure('assistantSessionChanged');
    }

    guard();
    _busy = true;
    _active = cancellation;
    try {
      return await run(guard);
    } on AuthFailure {
      rethrow;
    } on AssistantFailure {
      rethrow;
    } catch (_) {
      throw const AssistantFailure('assistantAuthorization');
    } finally {
      _busy = false;
      _active = null;
      cancellation.cancel();
    }
  }

  Future<AssistantChallenge> prepare(
    AuthIdentity identity, {
    required AssistantCancellation cancellation,
    required bool Function() isCurrent,
  }) => _operation(cancellation, isCurrent, (guard) async {
    _prepared = null;
    if (!identity.signingAvailable) throw const AuthFailure('authWalletReconnect');
    final scope = AssistantWalletScope.fromIdentity(identity);
    final challenge = await service.challenge(scope, now(), cancellation, guard: guard);
    guard();
    if (!challenge.freshAt(now())) throw const AssistantFailure('assistantChallengeExpired');
    return _prepared = challenge;
  });

  Future<AssistantSession> confirm(
    AssistantChallenge challenge, {
    required AssistantCancellation cancellation,
    required bool Function() isCurrent,
    Future<void> Function()? awaitForeground,
  }) => _operation(cancellation, isCurrent, (guard) async {
    if (!identical(_prepared, challenge)) throw const AssistantFailure('assistantChallengeExpired');
    // A challenge is single-use locally, including rejection or a lost verify response.
    _prepared = null;
    void fresh() {
      guard();
      if (!challenge.freshAt(now())) throw const AssistantFailure('assistantChallengeExpired');
    }

    fresh();
    final signature =
        await Future.any([
          signer().signPersonalMessage(
            expectedAddress: challenge.scope.address,
            message: challenge.message,
          ),
          cancellation.whenCancelled.then<String>(
            (_) => throw const AssistantFailure('assistantCancelled'),
          ),
        ]).timeout(
          challenge.receivedAt.add(const Duration(minutes: 5)).difference(now().toUtc()),
          onTimeout: () => throw const AssistantFailure('assistantChallengeExpired'),
        );
    fresh();
    if (!verifyAssistantPersonalSignature(challenge.scope.address, challenge.message, signature)) {
      throw const AuthFailure('authWalletSignature');
    }
    // An external wallet can deliver its signature before the application has
    // resumed. Keep only the signature in memory; do not submit auth in the
    // background. Leaving the page/account or expiration still cancels this wait.
    if (awaitForeground != null) {
      await Future.any([
        awaitForeground(),
        cancellation.whenCancelled.then<void>(
          (_) => throw const AssistantFailure('assistantCancelled'),
        ),
      ]).timeout(
        challenge.receivedAt.add(const Duration(minutes: 5)).difference(now().toUtc()),
        onTimeout: () => throw const AssistantFailure('assistantChallengeExpired'),
      );
    }
    fresh();
    final credentials = await service.verify(challenge, signature, cancellation, guard: guard);
    guard();
    if (credentials.needsRefresh(now())) throw const AssistantFailure('assistantAuthorization');
    await service.verifyBinding(challenge.scope, credentials, now(), cancellation, guard: guard);
    guard();
    if (credentials.needsRefresh(now())) throw const AssistantFailure('assistantAuthorization');
    await vault.saveCredentials(
      challenge.scope,
      credentials,
      isCurrent: () => !_closed && !cancellation.isCancelled && isCurrent(),
    );
    guard();
    return AssistantSession(
      scope: challenge.scope,
      credentials: credentials,
      verifiedAt: now().toUtc(),
    );
  });

  /// Only explicit restore/send/usage intents call this. No background refresh.
  Future<AssistantSession?> restore(
    AssistantWalletScope scope, {
    required AssistantCancellation cancellation,
    required bool Function() isCurrent,
  }) => _operation(cancellation, isCurrent, (guard) async {
    _prepared = null;
    var credentials = await vault.credentials(scope);
    guard();
    if (credentials == null) return null;
    if (credentials.needsRefresh(now())) {
      credentials = await service.refresh(credentials, cancellation, guard: guard);
      guard();
      if (credentials.needsRefresh(now())) throw const AssistantFailure('assistantAuthorization');
      // Persist rotation before further network reads. If user/binding reads fail,
      // a later explicit restore can use the rotated credential but must verify it.
      await vault.saveCredentials(
        scope,
        credentials,
        isCurrent: () => !_closed && !cancellation.isCancelled && isCurrent(),
      );
      guard();
    }
    await service.verifyBinding(scope, credentials, now(), cancellation, guard: guard);
    guard();
    if (credentials.needsRefresh(now())) throw const AssistantFailure('assistantAuthorization');
    return AssistantSession(scope: scope, credentials: credentials, verifiedAt: now().toUtc());
  });

  Future<AssistantQuota> usage(
    AssistantSession session, {
    required AssistantCancellation cancellation,
    required bool Function() isCurrent,
  }) => _operation(cancellation, isCurrent, (guard) async {
    if (session.credentials.needsRefresh(now())) {
      throw const AssistantFailure('assistantAuthorization');
    }
    final result = await service.usage(session, now(), cancellation, guard: guard);
    guard();
    return result;
  });
}
