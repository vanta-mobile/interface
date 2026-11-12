import 'dart:async';

import '../domain/auth_session.dart';
import '../domain/wallet_connection.dart';
import '../domain/wallet_signing_preparation.dart';
import '../domain/wallet_session_verification.dart';
import 'evm_account_address.dart';
import 'wallet_configuration.dart';
import 'wallet_preference_store.dart';

/// A connection-backed local identity, never proof of backend authentication.
/// Public metadata alone cannot sign; attach a validated SDK session first.
class ExternalWalletSession {
  ExternalWalletSession({required this.onInvalidated});
  final void Function() onInvalidated;
  WalletConnection? _connection;
  StreamSubscription<void>? _subscription;
  AuthIdentity? _identity;
  bool _selected = false;
  bool get selected => _selected;
  bool _disposed = false;
  int _revision = 0;

  static String identityId(String address) => 'eip155:${address.toLowerCase()}';
  WalletConnection? get connection => _connection;
  AuthIdentity? get identity {
    if (_disposed) return null;
    final identity = _identity;
    if (identity == null || !identity.signingAvailable || _connection?.isCurrent == true) {
      return identity;
    }
    return null;
  }

  AuthIdentity? restore(WalletPreference preference) {
    _selected = true;
    final address = preference.address;
    if (address == null) return _identity = null; // Explicit logout marker.
    final canonical = canonicalEvmAddress(address);
    if (canonical == null) throw const AuthFailure('authWalletChanged');
    return _identity = AuthIdentity(
      id: identityId(canonical),
      walletAddress: canonical,
      walletKind: WalletKind.external,
      walletName: preference.walletName,
    );
  }

  AuthIdentity connect(WalletConnection connection) {
    final address = canonicalEvmAddress(connection.address);
    if (_disposed ||
        !connection.isCurrent ||
        address == null ||
        !WalletConfiguration.chains.contains(connection.chainId)) {
      throw const AuthFailure('authWalletChanged');
    }
    final previous = _connection;
    final previousSubscription = _subscription;
    _revision++;
    _connection = connection;
    _selected = true;
    _identity = AuthIdentity(
      id: identityId(address),
      walletAddress: address,
      walletKind: WalletKind.external,
      walletName: connection.walletName,
      signingAvailable: true,
    );
    _subscription = connection.invalidations.listen((_) {
      if (_disposed || !identical(_connection, connection)) return;
      _revision++;
      final previous = _identity;
      _identity =
          connection is WalletSessionVerification &&
              (connection as WalletSessionVerification).needsReconnect &&
              previous != null
          ? AuthIdentity(
              id: previous.id,
              walletAddress: previous.walletAddress,
              walletKind: WalletKind.external,
              walletName: previous.walletName,
            )
          : null;
      onInvalidated();
    });
    unawaited(_release(previousSubscription, identical(previous, connection) ? null : previous));
    return _identity!;
  }

  bool owns(WalletConnection connection) =>
      !_disposed && identical(_connection, connection) && connection.isCurrent && identity != null;

  WalletConnection _signer(String expectedAddress) {
    final connection = _connection;
    if (_disposed || connection == null || identity == null || !selected) {
      throw const AuthFailure('authWalletReconnect');
    }
    if (!connection.isCurrent ||
        connection.address.toLowerCase() != expectedAddress.toLowerCase()) {
      throw const AuthFailure('authWalletChanged');
    }
    return connection;
  }

  Future<String> _sign(
    String expectedAddress,
    Future<String> Function(WalletConnection) sign,
  ) async {
    final connection = _signer(expectedAddress), revision = _revision;
    final signature = await sign(connection);
    if (revision != _revision || !owns(connection)) throw const AuthFailure('authWalletChanged');
    if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) {
      throw const AuthFailure('authWalletSignature');
    }
    return signature;
  }

  Future<String> signPersonalMessage({required String expectedAddress, required String message}) {
    if (message.isEmpty || message.length > 16384) throw const AuthFailure('authWalletChanged');
    return _sign(expectedAddress, (connection) => connection.signPersonalMessage(message));
  }

  Future<String> signTypedData({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) => _sign(expectedAddress, (connection) => connection.signTypedData(typedData));

  Future<void> prepareSigning({
    required String expectedAddress,
    required int chainId,
    required bool Function() isCurrent,
  }) async {
    final connection = _signer(expectedAddress), revision = _revision;
    bool current() => revision == _revision && owns(connection) && isCurrent();
    if (!current()) throw const AuthFailure('authWalletChanged');
    if (connection is WalletSigningPreparation) {
      await (connection as WalletSigningPreparation).prepareSigning(
        expectedAddress: expectedAddress,
        chainId: chainId,
        isCurrent: current,
      );
    } else if (connection.chainId != '$chainId') {
      throw const AuthFailure('authWalletSigningNetwork');
    }
    if (!current()) throw const AuthFailure('authWalletChanged');
  }

  Future<void> _release(
    StreamSubscription<void>? subscription,
    WalletConnection? connection,
  ) async {
    try {
      await subscription?.cancel();
      await connection?.release();
    } catch (_) {
      // Cleanup cannot replace the selected identity or a financial outcome.
    }
  }

  Future<void> deselect() {
    _revision++;
    _selected = false;
    _identity = null;
    final connection = _connection, subscription = _subscription;
    _connection = null;
    _subscription = null;
    return _release(subscription, connection);
  }

  Future<void> logout() async {
    final connection = _connection;
    _revision++;
    _selected = true;
    _identity = null;
    _connection = null;
    final subscription = _subscription;
    _subscription = null;
    try {
      await subscription?.cancel();
      await connection?.disconnect();
    } catch (_) {
      // A relay cleanup failure cannot resurrect a signed-out local session.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await deselect();
  }
}
