import 'dart:async';

import 'package:privy_flutter/privy_flutter.dart';

import '../domain/auth_session.dart';
import '../domain/wallet_connection.dart';
import '../domain/wallet_transaction.dart';
import '../domain/wallet_message_signer.dart';
import 'evm_account_address.dart';
import 'wallet_configuration.dart';
import 'wallet_preference_store.dart';
import 'privy_configuration.dart';
import 'privy_wallet_signer.dart';
import 'privy_transaction_requester.dart';
import 'privy_wallet_transaction_sender.dart';

/// SDK objects and credentials stay behind this boundary. A Privy identity
/// authenticates a wallet; it does not authorize Aster orders or fund transfers.
class PrivyIdentityRepository implements IdentityRepository, WalletMessageSigner {
  PrivyIdentityRepository(
    this.configuration, {
    Privy Function(PrivyConfig)? create,
    WalletPreferenceStore? preferences,
    this.walletConfiguration = const WalletConfiguration.environment(),
    PrivyTypedDataRequester? requestTypedData,
    PrivyTypedDataRequester? requestTransaction,
  }) : _create = create ?? ((config) => Privy.init(config: config)),
       _requestTypedData =
           requestTypedData ?? ((wallet, request) => wallet.provider.request(request)),
       _transactions = PrivyWalletTransactionSender(requestTransaction ?? requestPrivyTransaction),
       _preferences = preferences ?? LocalWalletPreferenceStore();

  final PrivyConfiguration configuration;
  final Privy Function(PrivyConfig) _create;
  final PrivyTypedDataRequester _requestTypedData;
  final PrivyWalletTransactionSender _transactions;
  Privy? _sdk;
  PrivyUser? _user;

  final WalletConfiguration walletConfiguration;
  final WalletPreferenceStore _preferences;
  WalletPreference? _preference;
  WalletConnection? _connection;
  StreamSubscription<void>? _walletSubscription;
  final _walletEvents = StreamController<AuthIdentity?>.broadcast();
  bool _externalInvalidated = false;
  bool _disposed = false;
  int _sessionGeneration = 0;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sessionGeneration++;
    await _walletSubscription?.cancel();
    await _connection?.release();
    _connection = null;
    await _walletEvents.close();
  }

  @override
  Stream<AuthIdentity?> get changes => Stream.multi((output) {
    final sdk = _ready.authStateStream
        .where((event) => event is Authenticated || event is Unauthenticated)
        .listen((event) {
          final next = event is Authenticated ? event.user : null;
          if (next?.id != _user?.id) _sessionGeneration++;
          _user = event is Authenticated ? event.user : null;
          if (_externalInvalidated) {
            output.add(null);
          } else {
            try {
              output.add(_user == null ? null : _identity(_user!));
            } on AuthFailure catch (failure) {
              output.addError(failure);
            }
          }
        }, onError: (Object _) => output.addError(const AuthFailure('authUnavailable')));
    final wallet = _walletEvents.stream.listen(output.add);
    output.onCancel = () async {
      await sdk.cancel();
      await wallet.cancel();
    };
  });

  Future<void> _remember(WalletPreference preference) async {
    _preference = preference;
    try {
      await _preferences.write(preference);
    } catch (_) {
      // Persistence contains only an address preference. Native auth remains
      // authoritative; restoration falls back to a verified external wallet.
    }
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthFailure {
      rethrow;
    } on PrivyException catch (error) {
      throw failureFromPrivy(error.message);
    } catch (_) {
      throw const AuthFailure('authUnavailable');
    }
  }

  @override
  Future<AuthIdentity?> initialize() => _guard(() async {
    if (!configuration.isConfigured) throw const AuthFailure('authConfiguration');
    final sdk = _sdk ??= _create(
      PrivyConfig(
        appId: configuration.appId.trim(),
        appClientId: configuration.clientId.trim(),
        logLevel: PrivyLogLevel.none,
      ),
    );
    final auth = await sdk.getAuthState();
    if (auth case Authenticated(:final user)) {
      if (_externalInvalidated) return null;
      if (_user?.id != user.id) _sessionGeneration++;
      _user = user;
      try {
        _preference = await _preferences.read();
      } catch (_) {
        _preference = null;
      }
      return _identity(user);
    }
    if (_user != null) _sessionGeneration++;
    _user = null;
    if (auth is! Unauthenticated) throw const AuthFailure('authSessionUnavailable');
    return null;
  });

  Privy get _ready => _sdk ?? (throw const AuthFailure('authUnavailable'));

  @override
  Future<void> sendCode(String email) => _guard(() async {
    switch (await _ready.email.sendCode(email)) {
      case Success<void>():
        return;
      case Failure<void>(:final error):
        throw failureFromPrivy(error.message);
    }
  });

  @override
  Future<AuthIdentity> verifyCode(String email, String code) => _guard(() async {
    switch (await _ready.email.loginWithCode(email: email, code: code)) {
      case Success<PrivyUser>(:final value):
        _sessionGeneration++;
        _externalInvalidated = false;
        _user = value;
        await _remember(WalletPreference(value.id, WalletKind.embedded, null));
        return _identity(value);
      case Failure<PrivyUser>(:final error):
        throw failureFromPrivy(error.message);
    }
  });

  @override
  Future<AuthIdentity> loginWithSocial(SocialLoginProvider provider) => _guard(() async {
    switch (await _ready.oAuth.login(
      provider: provider == SocialLoginProvider.google
          ? OAuthProvider.google
          : OAuthProvider.twitter,
      appUrlScheme: 'vanta',
    )) {
      case Success<PrivyUser>(:final value):
        if (_disposed) throw const AuthFailure('authSessionUnavailable');
        _sessionGeneration++;
        _externalInvalidated = false;
        _user = value;
        await _remember(WalletPreference(value.id, WalletKind.embedded, null));
        return _identity(value);
      case Failure<PrivyUser>(:final error):
        throw failureFromPrivy(error.message);
    }
  });

  @override
  Future<AuthIdentity> ensureWallet() => _guard(() async {
    final user = _user;
    if (user == null) throw const AuthFailure('authSessionUnavailable');
    if (_identity(user).walletKind == WalletKind.external) return _identity(user);
    if (user.embeddedEthereumWallets.isEmpty) {
      switch (await user.createEthereumWallet()) {
        case Success<EmbeddedEthereumWallet>(:final value):
          return AuthIdentity(
            id: user.id,
            email: _identity(user).email,
            walletAddress: _walletAddress(value.address),
            signingAvailable: true,
          );
        case Failure<EmbeddedEthereumWallet>(:final error):
          throw failureFromPrivy(error.message);
      }
    }
    return _identity(user);
  });

  @override
  Future<void> logout() => _guard(() async {
    _sessionGeneration++;
    await _ready.logout();
    _user = null;
    _externalInvalidated = false;
    final connection = _connection;
    _connection = null;
    await _walletSubscription?.cancel();
    _walletSubscription = null;
    try {
      await connection?.disconnect();
    } catch (_) {
      // Privy logout succeeded. A relay cleanup failure cannot resurrect it.
    }
  });

  @override
  Future<AuthIdentity> loginWithWallet(WalletConnection connection) => _guard(() async {
    if (_disposed) throw const AuthFailure('authWalletCancelled');
    final origin = walletConfiguration.relyingParty;
    if (origin == null) throw const AuthFailure('authWalletConfiguration');
    final walletAddress = _walletAddress(connection.address);
    if (!connection.isCurrent || !WalletConfiguration.chains.contains(connection.chainId)) {
      throw const AuthFailure('authWalletChanged');
    }
    final params = SiweMessageParams(
      appDomain: origin.host,
      appUri: origin.toString(),
      chainId: connection.chainId,
      walletAddress: walletAddress,
    );
    final message = switch (await _ready.siwe.generateMessage(params)) {
      Success<String>(:final value) => value,
      Failure<String>(:final error) => throw failureFromPrivy(error.message),
    };
    if (!connection.isCurrent) throw const AuthFailure('authWalletChanged');
    final signature = await connection.signPersonalMessage(message);
    if (!connection.isCurrent) throw const AuthFailure('authWalletChanged');
    final user = switch (await _ready.siwe.login(
      message: message,
      signature: signature,
      params: params,
      metadata: const WalletLoginMetadata(connectorType: 'walletconnect'),
    )) {
      Success<PrivyUser>(:final value) => value,
      Failure<PrivyUser>(:final error) => throw failureFromPrivy(error.message),
    };
    final verified = user.linkedAccounts.whereType<ExternalWalletAccount>().any(
      (wallet) =>
          wallet.chainType.name == 'ethereum' &&
          wallet.address.toLowerCase() == connection.address.toLowerCase(),
    );
    if (!verified || !connection.isCurrent || _disposed) {
      await _ready.logout();
      throw const AuthFailure('authWalletChanged');
    }
    await _walletSubscription?.cancel();
    if (!identical(_connection, connection)) await _connection?.release();
    _connection = connection;
    _sessionGeneration++;
    _externalInvalidated = false;
    _user = user;
    _walletSubscription = connection.invalidations.listen((_) {
      if (_disposed || !identical(_connection, connection)) return;
      _externalInvalidated = true;
      _sessionGeneration++;
      _user = null;
      _walletEvents.add(null);
    });
    await _remember(
      WalletPreference(
        user.id,
        WalletKind.external,
        connection.address,
        walletName: connection.walletName,
      ),
    );
    if (!connection.isCurrent || _externalInvalidated) throw const AuthFailure('authWalletChanged');
    return _identity(user);
  });

  @override
  Future<String> signPersonalMessage({required String expectedAddress, required String message}) =>
      _guard(() async {
        final user = _user;
        if (_disposed || user == null || _externalInvalidated) {
          throw const AuthFailure('authSessionUnavailable');
        }
        final identity = _identity(user), generation = _sessionGeneration;
        if (!identity.signingAvailable ||
            identity.walletAddress?.toLowerCase() != expectedAddress.toLowerCase() ||
            message.isEmpty ||
            message.length > 16384) {
          throw const AuthFailure('authWalletChanged');
        }
        final connection = _connection;
        String signature;
        if (identity.walletKind == WalletKind.external) {
          if (connection == null || !connection.isCurrent) {
            throw const AuthFailure('authWalletReconnect');
          }
          signature = await connection.signPersonalMessage(message);
        } else {
          signature = await signEmbeddedPersonalMessage(
            user: user,
            expectedAddress: expectedAddress,
            message: message,
            request: _requestTypedData,
          );
        }
        if (_disposed ||
            generation != _sessionGeneration ||
            _user?.id != user.id ||
            _externalInvalidated ||
            _identity(_user!).walletAddress?.toLowerCase() != expectedAddress.toLowerCase() ||
            (identity.walletKind == WalletKind.external &&
                (!identical(connection, _connection) || !connection!.isCurrent))) {
          throw const AuthFailure('authWalletChanged');
        }
        if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) {
          throw const AuthFailure('authWalletSignature');
        }
        return signature;
      });

  /// Typed requests use the selected wallet. External sessions always delegate
  /// to the connected EOA and never create an embedded fallback signer.
  @override
  Future<String> signWalletRequest({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) => _guard(() async {
    final user = _user;
    if (_disposed || user == null || _externalInvalidated) {
      throw const AuthFailure('authSessionUnavailable');
    }
    final identity = _identity(user);
    final generation = _sessionGeneration;
    if (typedData.isEmpty ||
        identity.walletAddress?.toLowerCase() != expectedAddress.toLowerCase()) {
      throw const AuthFailure('authWalletChanged');
    }
    if (identity.walletKind == WalletKind.external) {
      return signExternalRequest(expectedAddress: expectedAddress, typedData: typedData);
    }
    final signature = await signEmbeddedRequest(
      user: user,
      expectedAddress: expectedAddress,
      typedData: typedData,
      request: _requestTypedData,
    );
    if (_disposed ||
        generation != _sessionGeneration ||
        _user?.id != user.id ||
        _identity(_user!).walletAddress?.toLowerCase() != expectedAddress.toLowerCase()) {
      throw const AuthFailure('authWalletChanged');
    }
    return signature;
  });

  @override
  Future<String> signExternalRequest({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) => _guard(() async {
    final user = _user;
    final connection = _connection;
    if (_disposed || user == null || connection == null || _externalInvalidated) {
      throw const AuthFailure('authWalletReconnect');
    }
    final identity = _identity(user);
    final generation = _sessionGeneration;
    if (identity.walletKind != WalletKind.external ||
        identity.walletAddress?.toLowerCase() != expectedAddress.toLowerCase() ||
        !connection.isCurrent) {
      throw const AuthFailure('authWalletChanged');
    }
    final signature = await connection.signTypedData(typedData);
    if (_disposed ||
        generation != _sessionGeneration ||
        _user?.id != user.id ||
        !identical(connection, _connection) ||
        !connection.isCurrent ||
        _externalInvalidated) {
      throw const AuthFailure('authWalletChanged');
    }
    return signature;
  });

  @override
  Future<WalletTransactionResult> sendWalletTransaction({
    required EvmWalletTransaction transaction,
    required bool Function() isCurrent,
  }) {
    final generation = _sessionGeneration;
    return _transactions.send(
      user: _externalInvalidated ? null : _user,
      resolveIdentity: _identity,
      connection: _connection,
      transaction: transaction,
      isCurrent: () => !_disposed && generation == _sessionGeneration && isCurrent(),
    );
  }

  AuthIdentity _identity(PrivyUser user) {
    if (user.id.trim().isEmpty) throw const AuthFailure('authSessionUnavailable');
    final preference = _preference?.userId == user.id ? _preference : null;
    final externalWallets = user.linkedAccounts.whereType<ExternalWalletAccount>().where(
      (wallet) => wallet.chainType.name == 'ethereum',
    );
    final selectedExternal = externalWallets
        .where((wallet) => wallet.address.toLowerCase() == preference?.address?.toLowerCase())
        .firstOrNull;
    // A remembered EOA must never silently become an embedded signer when its
    // linked account is missing or changed on the server.
    if (preference?.kind == WalletKind.external && selectedExternal == null) {
      throw const AuthFailure('authWalletChanged');
    }
    final external = preference?.kind == WalletKind.embedded
        ? null
        : selectedExternal ?? externalWallets.firstOrNull;
    final address = external?.address ?? user.embeddedEthereumWallets.firstOrNull?.address;
    final connection =
        _connection?.isCurrent == true &&
            _connection?.address.toLowerCase() == external?.address.toLowerCase()
        ? _connection
        : null;
    return AuthIdentity(
      id: user.id,
      email: user.linkedAccounts.whereType<EmailAccount>().firstOrNull?.emailAddress,
      walletAddress: address == null ? null : _walletAddress(address),
      walletKind: external == null ? WalletKind.embedded : WalletKind.external,
      walletName: external == null
          ? null
          : connection?.walletName ??
                (selectedExternal == external ? preference?.walletName : null),
      signingAvailable:
          !_disposed &&
          !_externalInvalidated &&
          (external == null ? address != null : connection != null),
    );
  }

  static String _walletAddress(String address) {
    return canonicalEvmAddress(address) ?? (throw const AuthFailure('authUnavailable'));
  }
}

AuthFailure failureFromPrivy(String message) {
  final lower = message.toLowerCase();
  final key = lower.contains('network') || lower.contains('timeout') || lower.contains('connection')
      ? 'authNetwork'
      : lower.contains('rate') || lower.contains('too many')
      ? 'authRateLimited'
      : lower.contains('expired') && (lower.contains('code') || lower.contains('otp'))
      ? 'authCodeExpired'
      : lower.contains('code') || lower.contains('otp') || lower.contains('expired')
      ? 'authInvalidCode'
      : lower.contains('client') || lower.contains('app id') || lower.contains('configuration')
      ? 'authConfiguration'
      : 'authUnavailable';
  // Retain a concise SDK reason, without code values, credentials or payloads.
  var reason = message.split('\n').first.trim();
  reason = reason.replaceAll(
    RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'),
    '[redacted]',
  );
  reason = reason.replaceAll(
    RegExp(
      r'(?:[a-z_]*token|[a-z_]*secret|private[_ -]?key|password|signature|authorization|code|otp)\s*[:=]\s*[^\s,;]+',
      caseSensitive: false,
    ),
    '[redacted]',
  );
  reason = reason.replaceAll(RegExp(r'\b\d{6}\b|0x[a-fA-F0-9]{64,}'), '[redacted]');
  reason = reason.replaceAll(RegExp(r'\bBearer\s+[^\s,;]+', caseSensitive: false), '[redacted]');
  reason = reason.replaceAll(RegExp(r'\b[a-fA-F0-9]{64}\b'), '[redacted]');
  if (reason.contains('{') || reason.contains('Exception(') || reason.length > 200) reason = '';
  return AuthFailure(key, reason: reason.isEmpty ? null : reason);
}
