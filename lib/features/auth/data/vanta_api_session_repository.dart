import 'dart:async';
import 'dart:io';

import '../../../core/data/personal_signature_verifier.dart';
import '../../../core/network/request_scope.dart';
import '../../../core/errors/api_error_details.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../../core/vanta_api/vanta_api_http.dart';
import '../domain/auth_session.dart';
import '../domain/wallet_message_signer.dart';
import 'vanta_api_session_store.dart';
import 'vanta_siwe_message.dart';

/// Vanta API session for one wallet: SIWE sign-in (`/v1/auth/nonce`,
/// `/v1/auth/siwe`), single-flight refresh rotation and bearer reads.
/// A session authorizes only Vanta's own statistics; it is not an Aster or
/// on-chain authorization.
class VantaApiSessionRepository {
  VantaApiSessionRepository({
    required this.http,
    required this.store,
    required this.signer,
    required this.relyingParty,
    DateTime Function()? now,
    String? platform,
  }) : now = now ?? DateTime.now,
       platform = platform ?? (Platform.isIOS ? 'ios' : 'android');
  final VantaApiHttp http;
  final VantaApiSessionStore store;
  final WalletMessageSigner Function() signer;
  final Uri relyingParty;
  final DateTime Function() now;
  final String platform;

  /// Called after the server proves the session can no longer be refreshed.
  void Function(String address)? onSessionLost;

  VantaApiCredentials? _credentials;
  Future<VantaApiCredentials>? _refreshing;
  int _generation = 0;
  bool _closed = false;

  String? get address => _credentials?.address;

  /// Loads a stored session for [address] only. Tokens of another wallet are
  /// never used; they are replaced by that wallet's next sign-in.
  Future<bool> restore(String address) async {
    _check();
    final key = address.toLowerCase();
    if (_credentials?.address == key) return true;
    final generation = _generation;
    VantaApiCredentials? stored;
    try {
      stored = await store.read();
    } catch (_) {
      stored = null;
    }
    if (_closed || generation != _generation) return _credentials?.address == key;
    if (stored?.address != key) return false;
    _credentials = stored;
    return true;
  }

  Future<void> signIn(String address, {int chainId = 1, bool Function()? isCurrent}) async {
    _check();
    final key = address.toLowerCase();
    bool current() => !_closed && (isCurrent?.call() ?? true);
    final challenge = await http.get('/v1/auth/nonce', query: {'address': key});
    if (!current()) throw const VantaApiFailure(vantaApiRequestFailed);
    final nonce = challenge['nonce'], expires = DateTime.tryParse('${challenge['expires_at']}');
    final issuedAt = now().toUtc();
    if (nonce is! String || expires == null || !expires.toUtc().isAfter(issuedAt)) {
      throw const VantaApiFailure(vantaApiDataInvalid);
    }
    final limit = issuedAt.add(const Duration(minutes: 5));
    final VantaSiweMessage message;
    try {
      message = VantaSiweMessage(
        relyingParty: relyingParty,
        address: key,
        nonce: nonce,
        issuedAt: issuedAt,
        expiresAt: expires.toUtc().isBefore(limit) ? expires.toUtc() : limit,
        chainId: chainId,
      );
    } on FormatException {
      throw const VantaApiFailure(vantaApiDataInvalid);
    }
    final signature = await signer()
        .signPersonalMessage(expectedAddress: message.address, message: message.text)
        .timeout(
          message.expiresAt.difference(now().toUtc()),
          onTimeout: () => throw const AuthFailure('authWalletCancelled'),
        );
    if (!current()) throw const VantaApiFailure(vantaApiRequestFailed);
    if (!verifyPersonalSignature(key, message.text, signature)) {
      throw const AuthFailure('authWalletSignature');
    }
    final issued = await http.post(
      '/v1/auth/siwe',
      body: {'message': message.text, 'signature': signature, 'platform': platform},
    );
    final credentials = _issued(issued, key);
    if (!current()) throw const VantaApiFailure(vantaApiRequestFailed);
    _generation++;
    _credentials = credentials;
    _refreshing = null;
    await _save(credentials);
  }

  /// Authorized contract read. `session_expired` refreshes once and retries once.
  Future<Map<String, Object?>> get(
    String path, {
    Map<String, String>? query,
    Object? Function(String)? decode,
  }) async {
    return _authorized((token) => http.get(path, query: query, accessToken: token, decode: decode));
  }

  /// Only idempotent non-financial writes may use this auth-refresh replay.
  /// The original body and idempotency key are retained across the single retry.
  Future<Map<String, Object?>> postIdempotent(
    String path, {
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) => _authorized(
    (token) => http.post(path, body: body, accessToken: token, idempotencyKey: idempotencyKey),
  );

  Future<Map<String, Object?>> _authorized(
    Future<Map<String, Object?>> Function(String token) send,
  ) async {
    _check();
    _checkScope();
    var credentials = await _awaitCredentials(_usable());
    try {
      return await send(credentials.accessToken);
    } on VantaApiFailure catch (failure) {
      if (!failure.sessionExpired) {
        if (failure.requiresSignIn) _lose(credentials);
        rethrow;
      }
    }
    credentials = await _awaitCredentials(_refresh(credentials));
    try {
      return await send(credentials.accessToken);
    } on VantaApiFailure catch (failure) {
      if (failure.requiresSignIn || failure.sessionExpired) _lose(credentials);
      rethrow;
    }
  }

  Future<void> signOut() async {
    final credentials = _credentials;
    _generation++;
    _credentials = null;
    _refreshing = null;
    try {
      await store.clear();
    } catch (_) {
      // A stale record is bound to its address and replaced on next sign-in.
    }
    if (credentials == null || _closed) return;
    try {
      await http.post('/v1/auth/logout', accessToken: credentials.accessToken);
    } catch (_) {
      // Local tokens are already discarded; the server session expires on its own.
    }
  }

  void close() {
    _closed = true;
    _generation++;
    http.close();
  }

  Future<VantaApiCredentials> _usable() async {
    final credentials = _credentials;
    if (credentials == null) throw const VantaApiFailure(vantaApiSignInRequired);
    return credentials.usableAt(now()) ? credentials : _refresh(credentials);
  }

  Future<VantaApiCredentials> _refresh(VantaApiCredentials stale) {
    if (!identical(_credentials, stale)) return _usable();
    return _refreshing ??= () async {
      final generation = _generation;
      try {
        // Rotation belongs to the session. Cancelling one feature must not
        // cancel another caller's refresh or abandon a rotated credential.
        final issued = await RequestScope.runOwned(
          () => !_closed && generation == _generation,
          () => http.post('/v1/auth/refresh', body: {'refresh_token': stale.refreshToken}),
        );
        final next = _issued(issued, stale.address);
        if (_closed || generation != _generation) {
          throw const VantaApiFailure(vantaApiSignInRequired);
        }
        _credentials = next;
        await _save(next);
        return next;
      } on VantaApiFailure catch (failure) {
        // A rotated token cannot be reused; only proven auth failures discard it.
        if (generation == _generation && (failure.requiresSignIn || failure.sessionExpired)) {
          _lose(stale);
        }
        rethrow;
      } finally {
        if (generation == _generation) _refreshing = null;
      }
    }();
  }

  void _checkScope() {
    if (RequestScope.current?.active == false) {
      throw const VantaApiFailure(
        vantaApiRequestFailed,
        details: ApiErrorDetails(cause: ApiErrorCause.cancelled),
      );
    }
  }

  /// A caller can leave a shared session rotation promptly. The session still
  /// receives and saves the rotated token for its remaining consumers.
  Future<VantaApiCredentials> _awaitCredentials(Future<VantaApiCredentials> work) async {
    final scope = RequestScope.current;
    if (scope == null) return work;
    final cancelled = Completer<VantaApiCredentials>();
    void check() {
      if (!scope.active && !cancelled.isCompleted) {
        cancelled.completeError(
          const VantaApiFailure(
            vantaApiRequestFailed,
            details: ApiErrorDetails(cause: ApiErrorCause.cancelled),
          ),
        );
      }
    }

    final timer = Timer.periodic(const Duration(milliseconds: 25), (_) => check());
    try {
      check();
      return await Future.any([work, cancelled.future]);
    } finally {
      timer.cancel();
    }
  }

  VantaApiCredentials _issued(Map<String, Object?> json, String address) {
    try {
      return VantaApiCredentials.fromIssued(json, address: address, receivedAt: now());
    } on FormatException {
      throw const VantaApiFailure(vantaApiDataInvalid);
    }
  }

  Future<void> _save(VantaApiCredentials credentials) async {
    try {
      await store.write(credentials);
    } catch (_) {
      // The in-memory session still works; the next launch signs in again.
    }
  }

  void _lose(VantaApiCredentials credentials) {
    if (!identical(_credentials, credentials)) return;
    _generation++;
    _credentials = null;
    _refreshing = null;
    unawaited(store.clear().catchError((Object _) {}));
    onSessionLost?.call(credentials.address);
  }

  void _check() {
    if (_closed) throw const VantaApiFailure(vantaApiUnavailable);
  }
}
