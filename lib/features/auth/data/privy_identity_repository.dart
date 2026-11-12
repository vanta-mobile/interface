import 'dart:async';

import 'package:privy_flutter/privy_flutter.dart';

import '../domain/auth_session.dart';
import '../domain/wallet_connection.dart';
import '../domain/wallet_transaction.dart';
import '../domain/wallet_message_signer.dart';
import '../domain/wallet_signing_preparation.dart';
import 'evm_account_address.dart';
import 'external_wallet_session.dart';
import 'wallet_preference_store.dart';
import 'privy_configuration.dart';
import 'privy_auth_failure.dart';

import 'privy_wallet_signer.dart';
import 'privy_transaction_requester.dart';
import 'privy_wallet_transaction_sender.dart';

export 'privy_auth_failure.dart' show failureFromPrivy;

/// External EOA sessions use their connection directly. Privy owns only email /
/// social identities and embedded signing; neither session grants Aster access.
class PrivyIdentityRepository
    implements IdentityRepository, WalletMessageSigner, WalletSigningPreparation {
  PrivyIdentityRepository(
    this.configuration, {
    Privy Function(PrivyConfig)? create,
    WalletPreferenceStore? preferences,
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

  final WalletPreferenceStore _preferences;
  WalletPreference? _preference;
  StreamSubscription<AuthState>? _sdkSubscription;
  late final _events = StreamController<AuthIdentity?>.broadcast(onListen: _observeSdk);
  late final ExternalWalletSession _external = ExternalWalletSession(
    onInvalidated: () {
      _sessionGeneration++;
      final identity = _external.identity;
      if (identity == null) {
        unawaited(_remember(const WalletPreference('', WalletKind.external, null)));
      }
      _events.add(identity);
    },
  );
  bool _disposed = false;
  int _sessionGeneration = 0;
  Future<void> _preferenceWrites = Future.value();

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sessionGeneration++;
    await _sdkSubscription?.cancel();
    await _external.dispose();
    await _events.close();
  }

  @override
  Stream<AuthIdentity?> get changes => _events.stream;

  void _observeSdk() {
    if (_sdk == null || _sdkSubscription != null || _disposed) return;
    _sdkSubscription = _sdk!.authStateStream
        .where((event) => event is Authenticated || event is Unauthenticated)
        .listen(
          (event) {
            // A stale Privy session cannot replace an active EOA or explicit logout.
            if (_external.selected || _disposed) return;
            final next = event is Authenticated ? event.user : null;
            if (next?.id != _user?.id) _sessionGeneration++;
            _user = next;
            try {
              _events.add(next == null ? null : _identity(next));
            } on AuthFailure catch (failure) {
              _events.addError(failure);
            }
          },
          onError: (Object _) {
            if (!_external.selected && !_disposed) {
              _events.addError(const AuthFailure('authUnavailable'));
            }
          },
        );
  }

  Future<void> _remember(WalletPreference preference) async {
    _preference = preference;
    final write = _preferenceWrites.then((_) => _preferences.write(preference));
    _preferenceWrites = write.then<void>((_) {}, onError: (Object _) {});
    try {
      await write;
    } catch (_) {
      // Only public connection metadata is persisted; a live signer is still
      // required after restoration. A failed write never authorizes anything.
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
    if (_disposed) throw const AuthFailure('authSessionUnavailable');
    if (_external.selected) return _external.identity;
    final generation = _sessionGeneration;
    try {
      _preference = await _preferences.read();
    } catch (_) {
      _preference = null;
    }
    if (_disposed || generation != _sessionGeneration) {
      throw const AuthFailure('authSessionUnavailable');
    }
    if (_preference?.kind == WalletKind.external) {
      return _external.restore(_preference!);
    }
    // Missing Privy configuration must not disable the EOA connection path.
    if (!configuration.isConfigured) return null;
    final sdk = _ready;
    final auth = await sdk.getAuthState();
    if (_disposed || generation != _sessionGeneration) {
      throw const AuthFailure('authSessionUnavailable');
    }
    if (auth case Authenticated(:final user)) {
      if (_user?.id != user.id) _sessionGeneration++;
      _user = user;
      final identity = _identity(user);
      if (identity.walletKind == WalletKind.external) {
        // Migrate an old SIWE identity to a public address preference. A stored
        // address cannot restore signing capability or a backend login.
        final preference = WalletPreference(
          ExternalWalletSession.identityId(identity.walletAddress!),
          WalletKind.external,
          identity.walletAddress,
          walletName: identity.walletName,
        );
        final restored = _external.restore(preference);
        await _remember(preference);
        return restored;
      }
      return identity;
    }
    if (_user != null) _sessionGeneration++;
    _user = null;
    if (auth is! Unauthenticated) throw const AuthFailure('authSessionUnavailable');
    return null;
  });

  Privy get _ready {
    if (_disposed) throw const AuthFailure('authSessionUnavailable');
    if (!configuration.isConfigured) throw const AuthFailure('authConfiguration');
    final sdk = _sdk ??= _create(
      PrivyConfig(
        appId: configuration.appId.trim(),
        appClientId: configuration.clientId.trim(),
        logLevel: PrivyLogLevel.none,
      ),
    );
    if (_events.hasListener) _observeSdk();
    return sdk;
  }

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
        unawaited(_external.deselect());
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
        unawaited(_external.deselect());
        _user = value;
        await _remember(WalletPreference(value.id, WalletKind.embedded, null));
        return _identity(value);
      case Failure<PrivyUser>(:final error):
        throw failureFromPrivy(error.message);
    }
  });

  @override
  Future<AuthIdentity> ensureWallet() => _guard(() async {
    if (_external.selected) {
      return _external.identity ?? (throw const AuthFailure('authSessionUnavailable'));
    }
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
    if (!_external.selected) await _sdk?.logout();
    _user = null;
    await _external.logout();
    // Explicit signed-out marker prevents a legacy native SIWE session from
    // reappearing after logout, without needing Privy for an EOA operation.
    await _remember(const WalletPreference('', WalletKind.external, null));
  });

  @override
  Future<AuthIdentity> loginWithWallet(WalletConnection connection) => _guard(() async {
    if (_disposed) throw const AuthFailure('authWalletCancelled');
    final identity = _external.connect(connection);
    _sessionGeneration++;
    await _remember(
      WalletPreference(
        identity.id,
        WalletKind.external,
        identity.walletAddress,
        walletName: identity.walletName,
      ),
    );
    if (_disposed || !_external.owns(connection)) throw const AuthFailure('authWalletChanged');
    return identity;
  });

  @override
  Future<String> signPersonalMessage({required String expectedAddress, required String message}) =>
      _guard(() async {
        if (_external.selected) {
          return _external.signPersonalMessage(expectedAddress: expectedAddress, message: message);
        }
        final user = _user;
        if (_disposed || user == null) throw const AuthFailure('authSessionUnavailable');
        final identity = _identity(user), generation = _sessionGeneration;
        if (!identity.signingAvailable ||
            identity.walletAddress?.toLowerCase() != expectedAddress.toLowerCase() ||
            message.isEmpty ||
            message.length > 16384) {
          throw const AuthFailure('authWalletChanged');
        }
        final signature = await signEmbeddedPersonalMessage(
          user: user,
          expectedAddress: expectedAddress,
          message: message,
          request: _requestTypedData,
        );
        if (_disposed ||
            generation != _sessionGeneration ||
            _user?.id != user.id ||
            _identity(_user!).walletAddress?.toLowerCase() != expectedAddress.toLowerCase()) {
          throw const AuthFailure('authWalletChanged');
        }
        if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) {
          throw const AuthFailure('authWalletSignature');
        }
        return signature;
      });

  @override
  Future<void> prepareSigning({
    required String expectedAddress,
    required int chainId,
    required bool Function() isCurrent,
  }) => _guard(() async {
    if (!isCurrent() || _disposed) throw const AuthFailure('authWalletChanged');
    if (!_external.selected) return; // Embedded signatures need no network switch.
    await _external.prepareSigning(
      expectedAddress: expectedAddress,
      chainId: chainId,
      isCurrent: isCurrent,
    );
  });

  /// Typed requests use the selected wallet. External sessions always delegate
  /// to the connected EOA and never create an embedded fallback signer.
  @override
  Future<String> signWalletRequest({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) => _guard(() async {
    if (typedData.isEmpty) throw const AuthFailure('authWalletChanged');
    if (_external.selected) {
      return signExternalRequest(expectedAddress: expectedAddress, typedData: typedData);
    }
    final user = _user;
    if (_disposed || user == null) {
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
  }) =>
      _guard(() => _external.signTypedData(expectedAddress: expectedAddress, typedData: typedData));

  @override
  Future<WalletTransactionResult> sendWalletTransaction({
    required EvmWalletTransaction transaction,
    required bool Function() isCurrent,
  }) {
    final generation = _sessionGeneration;
    return _transactions.send(
      user: _external.selected ? null : _user,
      resolveIdentity: () =>
          _external.selected ? _external.identity : (_user == null ? null : _identity(_user!)),
      connection: _external.connection,
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
    // Saved EOA metadata is restored before entering the Privy branch. Without
    // a preference, retain the legacy external choice for migration only.
    final external = preference?.kind == WalletKind.embedded ? null : externalWallets.firstOrNull;
    final address = external?.address ?? user.embeddedEthereumWallets.firstOrNull?.address;
    return AuthIdentity(
      id: user.id,
      email: user.linkedAccounts.whereType<EmailAccount>().firstOrNull?.emailAddress,
      walletAddress: address == null ? null : _walletAddress(address),
      walletKind: external == null ? WalletKind.embedded : WalletKind.external,
      signingAvailable: !_disposed && external == null && address != null,
    );
  }

  static String _walletAddress(String address) {
    return canonicalEvmAddress(address) ?? (throw const AuthFailure('authUnavailable'));
  }
}
