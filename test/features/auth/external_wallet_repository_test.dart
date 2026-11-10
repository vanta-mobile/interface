import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/privy_identity_repository.dart';
import 'package:vanta/features/auth/data/wallet_preference_store.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';

import '../../support/wallet_connection.dart';
import '../../support/wallet_transaction.dart';

void main() {
  late _Sdk sdk;
  late MemoryWalletPreferences preferences;
  late TestWalletConnection connection;
  late PrivyIdentityRepository repository;
  PrivyIdentityRepository build() => PrivyIdentityRepository(
    const PrivyConfiguration(appId: 'app', clientId: 'client'),
    create: (_) => sdk,
    preferences: preferences,
    requestTypedData: (_, _) async =>
        throw TestFailure('An EOA must never use the embedded wallet'),
  );
  setUp(() {
    sdk = _Sdk();
    preferences = MemoryWalletPreferences();
    connection = TestWalletConnection();
    repository = build();
  });
  tearDown(() async {
    await repository.dispose();
    await connection.dispose();
    await sdk.events.close();
  });

  test('wallet name is retained on connection and restored for the same address', () async {
    final named = TestWalletConnection(walletName: 'MetaMask');
    addTearDown(named.dispose);
    await repository.initialize();
    final identity = await repository.loginWithWallet(named);
    expect(identity.walletName, 'MetaMask');
    expect(preferences.value?.walletName, 'MetaMask');
    sdk.state = Authenticated(sdk.legacyUser);
    final restored = build();
    addTearDown(restored.dispose);
    expect((await restored.initialize())?.walletName, 'MetaMask');
    expect((await restored.initialize())?.signingAvailable, false);
  });

  test(
    'legacy public EOA preference migrates to an address identity without trusting its user ID',
    () async {
      preferences.value = WalletPreference(
        'other-user',
        WalletKind.external,
        connection.address,
        walletName: 'Other wallet',
      );
      sdk.state = Authenticated(sdk.legacyUser);
      final restored = await repository.initialize();
      expect(restored?.walletName, 'Other wallet');
      expect(restored?.id, 'eip155:${connection.address.toLowerCase()}');
      expect(restored?.signingAvailable, false);
    },
  );

  test(
    'EOA personal message delegates to the connected wallet without an embedded fallback',
    () async {
      await repository.initialize();
      await repository.loginWithWallet(connection);
      final before = connection.personalSigns;
      expect(
        await repository.signPersonalMessage(
          expectedAddress: connection.address,
          message: 'Registration message',
        ),
        TestWalletConnection.signature,
      );
      expect(connection.personalSigns, before + 1);
      expect(connection.personalMessage, 'Registration message');
      expect(sdk.legacyUser.created, 0);
      expect(connection.typedSigns, 0);
    },
  );
  test('EOA invalidation while signing a personal message discards its late signature', () async {
    await repository.initialize();
    await repository.loginWithWallet(connection);
    connection.signGate = Completer();
    final pending = repository.signPersonalMessage(
      expectedAddress: connection.address,
      message: 'Registration message',
    );
    connection.invalidate();
    connection.signGate!.complete();
    await expectLater(pending, throwsA(isA<AuthFailure>()));
    expect(sdk.legacyUser.created, 0);
  });

  test('EOA transactions delegate only to connected wallet without Privy fallback', () async {
    await repository.initialize();
    await repository.loginWithWallet(connection);
    final tx = walletTransaction();
    final result = await repository.sendWalletTransaction(transaction: tx, isCurrent: () => true);
    expect(result.hash, '0x${'a' * 64}');
    expect(connection.transactions.single, same(tx));
    expect(connection.typedSigns, 0);
    expect(sdk.legacyUser.created, 0);
  });
  test('restored EOA cannot send through an existing embedded wallet', () async {
    sdk.state = Authenticated(sdk.legacyUser);
    await repository.initialize();
    await expectLater(
      repository.sendWalletTransaction(transaction: walletTransaction(), isCurrent: () => true),
      throwsA(isA<WalletTransactionNotSent>().having((e) => e.key, 'key', 'authWalletReconnect')),
    );
    expect(connection.transactions, isEmpty);
    expect(sdk.legacyUser.created, 0);
  });
  for (final issue in ['address', 'scope', 'logout', 'dispose']) {
    test('EOA $issue blocks transaction before dispatch', () async {
      await repository.initialize();
      await repository.loginWithWallet(connection);
      if (issue == 'logout') await repository.logout();
      if (issue == 'dispose') {
        await repository.dispose();
      }
      await expectLater(
        repository.sendWalletTransaction(
          transaction: walletTransaction(
            from: issue == 'address' ? '0x${'3' * 40}' : connection.address,
          ),
          isCurrent: () => issue != 'scope',
        ),
        throwsA(isA<WalletTransactionNotSent>()),
      );
      expect(connection.transactions, isEmpty);
      expect(sdk.legacyUser.created, 0);
    });
  }
  test(
    'EOA invalidation during send preserves original hash and blocks duplicate dispatch',
    () async {
      await repository.initialize();
      await repository.loginWithWallet(connection);
      connection.transactionGate = Completer();
      final pending = repository.sendWalletTransaction(
        transaction: walletTransaction(),
        isCurrent: () => true,
      );
      await expectLater(
        repository.sendWalletTransaction(transaction: walletTransaction(), isCurrent: () => true),
        throwsA(
          isA<WalletTransactionNotSent>().having((e) => e.key, 'key', 'walletTransactionBusy'),
        ),
      );
      connection.invalidate();
      connection.transactionGate!.complete();
      expect((await pending).hash, '0x${'a' * 64}');
      expect(connection.transactions.length, 1);
      expect(sdk.legacyUser.created, 0);
    },
  );
  test('unexpected external transport failure after dispatch remains unknown', () async {
    await repository.initialize();
    await repository.loginWithWallet(connection);
    connection.transactionFailure = const AuthFailure('authWalletRejected');
    final result = await repository.sendWalletTransaction(
      transaction: walletTransaction(),
      isCurrent: () => true,
    );
    expect(result.status, WalletTransactionStatus.unknown);
    expect(connection.transactions.length, 1);
  });
  test('proven pre-send external failure stays distinguishable from unknown broadcast', () async {
    await repository.initialize();
    await repository.loginWithWallet(connection);
    connection.transactionFailure = const WalletTransactionNotSent('walletTransactionWrongChain');
    await expectLater(
      repository.sendWalletTransaction(transaction: walletTransaction(), isCurrent: () => true),
      throwsA(isA<WalletTransactionNotSent>()),
    );
  });

  test(
    'EOA connection does not sign in and typed requests use only the connected wallet',
    () async {
      await repository.initialize();
      final identity = await repository.loginWithWallet(connection);
      expect(identity.walletKind, WalletKind.external);
      expect(identity.walletAddress, connection.address);
      expect(identity.signingAvailable, true);
      expect(identity.id, 'eip155:${connection.address.toLowerCase()}');
      expect(connection.personalSigns, 0);
      expect(connection.typedSigns, 0);
      expect((await repository.ensureWallet()).walletKind, WalletKind.external);
      expect(sdk.legacyUser.created, 0);
      final typed = <String, Object?>{
        'primaryType': 'Message',
        'message': {'nonce': '1'},
      };
      expect(
        await repository.signWalletRequest(expectedAddress: connection.address, typedData: typed),
        TestWalletConnection.signature,
      );
      expect(connection.typedSigns, 1);
      expect(connection.typedData, same(typed));
      await repository.logout();
      expect(connection.disconnected, 1);
      expect(sdk.loggedOut, false);
      await expectLater(
        repository.signExternalRequest(expectedAddress: connection.address, typedData: typed),
        throwsA(isA<AuthFailure>()),
      );
    },
  );

  test('EOA connection canonicalizes a lowercase WalletConnect address to EIP-55', () async {
    const checksummed = '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf';
    final lowercaseConnection = TestWalletConnection(address: checksummed.toLowerCase());
    sdk.legacyUser.walletAddress = checksummed;
    await repository.initialize();

    final identity = await repository.loginWithWallet(lowercaseConnection);

    expect(identity.walletAddress, checksummed);
    await lowercaseConnection.dispose();
  });

  test(
    'restart retains the EOA choice even when the Privy user also has an embedded wallet',
    () async {
      await repository.initialize();
      await repository.loginWithWallet(connection);
      sdk.state = Authenticated(sdk.legacyUser);
      final restored = build();
      addTearDown(restored.dispose);
      final identity = await restored.initialize();
      expect(identity?.walletAddress, connection.address);
      expect(identity?.walletKind, WalletKind.external);
      expect(identity?.signingAvailable, false);
      await restored.ensureWallet();
      expect(sdk.legacyUser.created, 0);
      await expectLater(
        restored.signExternalRequest(expectedAddress: connection.address, typedData: {}),
        throwsA(isA<AuthFailure>().having((error) => error.key, 'key', 'authWalletReconnect')),
      );
    },
  );

  test(
    'without saved preference a verified EOA is restored without creating another wallet',
    () async {
      sdk.state = Authenticated(sdk.legacyUser);
      final identity = await repository.initialize();
      expect(identity?.walletKind, WalletKind.external);
      expect(identity?.walletAddress, connection.address);
      await repository.ensureWallet();
      expect(sdk.legacyUser.created, 0);
      preferences.value = WalletPreference('user', WalletKind.embedded, null);
      final embedded = build();
      addTearDown(embedded.dispose);
      expect((await embedded.initialize())?.walletKind, WalletKind.embedded);
    },
  );

  test('an invalid connection never replaces the selected wallet or signs', () async {
    await repository.initialize();
    final original = await repository.loginWithWallet(connection);
    final invalid = TestWalletConnection(address: '0x${'3' * 40}')..current = false;
    addTearDown(invalid.dispose);
    await expectLater(repository.loginWithWallet(invalid), throwsA(isA<AuthFailure>()));
    expect((await repository.initialize())?.id, original.id);
    expect(connection.isCurrent, true);
    expect(invalid.personalSigns, 0);
    expect(sdk.legacyUser.created, 0);
  });

  test('account change invalidates the session and rejects late typed signatures', () async {
    await repository.initialize();
    await repository.loginWithWallet(connection);
    final invalidated = Completer<void>();
    final subscription = repository.changes.listen((identity) {
      if (identity == null && !invalidated.isCompleted) invalidated.complete();
    });
    connection.signGate = Completer<void>();
    final pending = repository.signExternalRequest(
      expectedAddress: connection.address,
      typedData: {},
    );
    connection.invalidate();
    connection.signGate!.complete();
    await expectLater(
      pending,
      throwsA(isA<AuthFailure>().having((error) => error.key, 'key', 'authWalletChanged')),
    );
    await invalidated.future.timeout(const Duration(seconds: 1));
    sdk.state = Authenticated(sdk.legacyUser);
    expect(await repository.initialize(), null);
    expect(sdk.legacyUser.created, 0);
    await subscription.cancel();
  });

  test('a different expected address cannot request a signature', () async {
    await repository.initialize();
    await repository.loginWithWallet(connection);
    await expectLater(
      repository.signExternalRequest(
        expectedAddress: '0x3333333333333333333333333333333333333333',
        typedData: {},
      ),
      throwsA(isA<AuthFailure>()),
    );
    expect(connection.typedSigns, 0);
  });

  test(
    'remembered EOA needs no Privy association and cannot fall back to embedded signing',
    () async {
      preferences.value = const WalletPreference(
        'user',
        WalletKind.external,
        '0x3333333333333333333333333333333333333333',
      );
      sdk.state = Authenticated(sdk.legacyUser);
      final identity = await repository.initialize();
      expect(identity?.walletAddress, preferences.value!.address);
      expect(identity?.signingAvailable, false);
      await expectLater(
        repository.signWalletRequest(
          expectedAddress: identity!.walletAddress!,
          typedData: {'message': 'read'},
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(sdk.legacyUser.created, 0);
    },
  );

  test('EOA connect, restore, sign and logout never initialize Privy', () async {
    final direct = PrivyIdentityRepository(
      const PrivyConfiguration(appId: '', clientId: ''),
      preferences: preferences,
      create: (_) => throw TestFailure('EOA must not initialize Privy'),
    );
    addTearDown(direct.dispose);
    expect(await direct.initialize(), null);
    final identity = await direct.loginWithWallet(connection);
    expect(connection.personalSigns, 0);
    expect(connection.typedSigns, 0);
    expect((await direct.ensureWallet()).id, identity.id);
    await direct.signWalletRequest(
      expectedAddress: connection.address,
      typedData: {'message': 'read'},
    );
    final restored = PrivyIdentityRepository(
      const PrivyConfiguration(appId: 'app', clientId: 'client'),
      preferences: preferences,
      create: (_) => throw TestFailure('Restoration must not initialize Privy'),
    );
    addTearDown(restored.dispose);
    expect((await restored.initialize())?.id, identity.id);
    expect((await restored.initialize())?.signingAvailable, false);
    await direct.logout();
    final signedOut = build();
    addTearDown(signedOut.dispose);
    sdk.state = Authenticated(sdk.legacyUser);
    expect(await signedOut.initialize(), null);
    expect(connection.disconnected, 1);
  });

  test(
    'switch discards a signature from the previous connection and isolates SDK events',
    () async {
      await repository.initialize();
      final subscription = repository.changes.listen((_) => fail('Stale Privy event leaked'));
      addTearDown(subscription.cancel);
      await repository.loginWithWallet(connection);
      connection.signGate = Completer();
      final pending = repository.signWalletRequest(
        expectedAddress: connection.address,
        typedData: {'message': 'read'},
      );
      final other = TestWalletConnection(address: '0x${'3' * 40}');
      addTearDown(other.dispose);
      final switched = await repository.loginWithWallet(other);
      sdk.events.add(Authenticated(sdk.legacyUser));
      sdk.events.add(const Unauthenticated());
      await Future<void>.delayed(Duration.zero);
      connection.signGate!.complete();
      await expectLater(pending, throwsA(isA<AuthFailure>()));
      expect((await repository.initialize())?.id, switched.id);
      expect(other.personalSigns, 0);
      expect(connection.isCurrent, false);
      await repository.signWalletRequest(
        expectedAddress: other.address,
        typedData: {'message': 'read'},
      );
      expect(other.typedSigns, 1);
    },
  );
}

class _Sdk implements Privy {
  AuthState state = const Unauthenticated();
  bool loggedOut = false;
  final legacyUser = _User();
  final events = StreamController<AuthState>.broadcast(sync: true);
  @override
  Stream<AuthState> get authStateStream => events.stream;
  @override
  Future<AuthState> getAuthState() async => state;
  @override
  Future<void> logout() async => loggedOut = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements PrivyUser {
  int created = 0;
  String walletAddress = '0x2222222222222222222222222222222222222222';
  @override
  String get id => 'user';
  @override
  List<LinkedAccounts> get linkedAccounts => [
    LinkedAccounts.fromJson({
      'type': 'wallet',
      'address': walletAddress,
      'chainType': 'Ethereum',
      'chainId': '56',
    }),
  ];
  @override
  List<EmbeddedEthereumWallet> get embeddedEthereumWallets => [
    EmbeddedEthereumWallet(address: '0x1111111111111111111111111111111111111111', hdWalletIndex: 0),
  ];
  @override
  Future<Result<EmbeddedEthereumWallet>> createEthereumWallet({
    bool allowAdditional = false,
  }) async {
    created++;
    return Success(embeddedEthereumWallets.first);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
