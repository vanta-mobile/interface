import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:privy_flutter/src/modules/login_with_siwe/login_with_siwe.dart';
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
  });

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
      expect(sdk.siwe.user.created, 0);
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
    expect(sdk.siwe.user.created, 0);
  });

  test('EOA transactions delegate only to connected wallet without Privy fallback', () async {
    await repository.initialize();
    await repository.loginWithWallet(connection);
    final tx = walletTransaction();
    final result = await repository.sendWalletTransaction(transaction: tx, isCurrent: () => true);
    expect(result.hash, '0x${'a' * 64}');
    expect(connection.transactions.single, same(tx));
    expect(connection.typedSigns, 0);
    expect(sdk.siwe.user.created, 0);
  });
  test('restored EOA cannot send through an existing embedded wallet', () async {
    sdk.state = Authenticated(sdk.siwe.user);
    await repository.initialize();
    await expectLater(
      repository.sendWalletTransaction(transaction: walletTransaction(), isCurrent: () => true),
      throwsA(isA<WalletTransactionNotSent>().having((e) => e.key, 'key', 'authWalletReconnect')),
    );
    expect(connection.transactions, isEmpty);
    expect(sdk.siwe.user.created, 0);
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
      expect(sdk.siwe.user.created, 0);
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
      expect(sdk.siwe.user.created, 0);
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
    'EOA SIWE and typed requests use the connected wallet and never create an embedded wallet',
    () async {
      await repository.initialize();
      final identity = await repository.loginWithWallet(connection);
      expect(identity.walletKind, WalletKind.external);
      expect(identity.walletAddress, connection.address);
      expect(identity.signingAvailable, true);
      expect(sdk.siwe.params?.walletAddress, connection.address);
      expect(sdk.siwe.params?.chainId, '56');
      expect(connection.personalMessage, 'Privy server challenge');
      expect(sdk.siwe.signature, TestWalletConnection.signature);
      expect((await repository.ensureWallet()).walletKind, WalletKind.external);
      expect(sdk.siwe.user.created, 0);
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
      expect(sdk.loggedOut, true);
      await expectLater(
        repository.signExternalRequest(expectedAddress: connection.address, typedData: typed),
        throwsA(isA<AuthFailure>()),
      );
    },
  );

  test('EOA SIWE canonicalizes a lowercase WalletConnect address to EIP-55', () async {
    const checksummed = '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf';
    final lowercaseConnection = TestWalletConnection(address: checksummed.toLowerCase());
    sdk.siwe.user.walletAddress = checksummed;
    await repository.initialize();

    final identity = await repository.loginWithWallet(lowercaseConnection);

    expect(sdk.siwe.params?.walletAddress, checksummed);
    expect(identity.walletAddress, checksummed);
    await lowercaseConnection.dispose();
  });

  test(
    'restart retains the EOA choice even when the Privy user also has an embedded wallet',
    () async {
      await repository.initialize();
      await repository.loginWithWallet(connection);
      sdk.state = Authenticated(sdk.siwe.user);
      final restored = build();
      final identity = await restored.initialize();
      expect(identity?.walletAddress, connection.address);
      expect(identity?.walletKind, WalletKind.external);
      expect(identity?.signingAvailable, false);
      await restored.ensureWallet();
      expect(sdk.siwe.user.created, 0);
      await expectLater(
        restored.signExternalRequest(expectedAddress: connection.address, typedData: {}),
        throwsA(isA<AuthFailure>().having((error) => error.key, 'key', 'authWalletReconnect')),
      );
    },
  );

  test(
    'without saved preference a verified EOA is restored without creating another wallet',
    () async {
      sdk.state = Authenticated(sdk.siwe.user);
      final identity = await repository.initialize();
      expect(identity?.walletKind, WalletKind.external);
      expect(identity?.walletAddress, connection.address);
      await repository.ensureWallet();
      expect(sdk.siwe.user.created, 0);
      preferences.value = WalletPreference('user', WalletKind.embedded, null);
      expect((await build().initialize())?.walletKind, WalletKind.embedded);
    },
  );

  test('rejected login never authenticates or creates a wallet', () async {
    await repository.initialize();
    connection.failure = const AuthFailure('authWalletRejected');
    await expectLater(
      repository.loginWithWallet(connection),
      throwsA(isA<AuthFailure>().having((error) => error.key, 'key', 'authWalletRejected')),
    );
    expect(sdk.siwe.logins, 0);
    expect(sdk.siwe.user.created, 0);
    expect(preferences.value, null);
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
    sdk.state = Authenticated(sdk.siwe.user);
    expect(await repository.initialize(), null);
    expect(sdk.siwe.user.created, 0);
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

  test('a missing remembered EOA cannot fall back to an embedded wallet', () async {
    preferences.value = const WalletPreference(
      'user',
      WalletKind.external,
      '0x3333333333333333333333333333333333333333',
    );
    sdk.state = Authenticated(sdk.siwe.user);
    await expectLater(
      repository.initialize(),
      throwsA(isA<AuthFailure>().having((failure) => failure.key, 'key', 'authWalletChanged')),
    );
    await expectLater(repository.ensureWallet(), throwsA(isA<AuthFailure>()));
    expect(sdk.siwe.user.created, 0);
  });
}

class _Sdk implements Privy {
  AuthState state = const Unauthenticated();
  bool loggedOut = false;
  @override
  final _Siwe siwe = _Siwe();
  @override
  Stream<AuthState> get authStateStream => const Stream.empty();
  @override
  Future<AuthState> getAuthState() async => state;
  @override
  Future<void> logout() async => loggedOut = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Siwe implements LoginWithSiwe {
  final user = _User();
  SiweMessageParams? params;
  String? signature;
  int logins = 0;
  @override
  Future<Result<String>> generateMessage(SiweMessageParams params) async {
    this.params = params;
    return const Success('Privy server challenge');
  }

  @override
  Future<Result<PrivyUser>> login({
    required String message,
    required String signature,
    required SiweMessageParams params,
    WalletLoginMetadata? metadata,
  }) async {
    this.signature = signature;
    logins++;
    return Success(user);
  }

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
