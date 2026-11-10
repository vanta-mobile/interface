import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:privy_flutter/src/modules/email/login_with_email.dart';
import 'package:privy_flutter/src/modules/oauth/login_with_oauth.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/privy_identity_repository.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

import '../../support/wallet_connection.dart';

void main() {
  const configuration = PrivyConfiguration(appId: ' app-id ', clientId: ' client-id ');

  for (final provider in SocialLoginProvider.values) {
    test('$provider maps to Privy OAuth and selects the embedded identity', () async {
      final sdk = _Sdk();
      final preferences = MemoryWalletPreferences();
      final repository = PrivyIdentityRepository(
        configuration,
        create: (_) => sdk,
        preferences: preferences,
      );
      addTearDown(repository.dispose);
      await repository.initialize();
      final identity = await repository.loginWithSocial(provider);
      expect(
        sdk.oAuth.provider,
        provider == SocialLoginProvider.google ? OAuthProvider.google : OAuthProvider.twitter,
      );
      expect(sdk.oAuth.scheme, 'vanta');
      expect(identity.walletKind, WalletKind.embedded);
      expect(preferences.value?.kind, WalletKind.embedded);
      expect(sdk.oAuth.user.created, 0);
    });
  }

  test('OAuth failures retain a safe SDK reason', () async {
    final sdk = _Sdk()..oAuth.failure = const PrivyException('Network unavailable');
    final repository = PrivyIdentityRepository(
      configuration,
      create: (_) => sdk,
      preferences: MemoryWalletPreferences(),
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    await expectLater(
      repository.loginWithSocial(SocialLoginProvider.google),
      throwsA(isA<AuthFailure>().having((e) => e.reason, 'reason', 'Network unavailable')),
    );
    expect(failureFromPrivy('Code expired').key, 'authCodeExpired');
    expect(failureFromPrivy('Invalid code').key, 'authInvalidCode');
  });

  test('personal messages use exact UTF8 hex and the existing embedded wallet', () async {
    final user = _User()..wallets = [_User.wallet];
    final sdk = _Sdk()..state = Authenticated(user);
    final signature = '0x${'1' * 130}';
    var requests = 0;
    final repository = PrivyIdentityRepository(
      configuration,
      create: (_) => sdk,
      preferences: MemoryWalletPreferences(),
      requestTypedData: (wallet, request) async {
        requests++;
        expect(wallet, same(_User.wallet));
        expect(request.method, 'personal_sign');
        expect(request.params, [
          '0x${utf8.encode('Register 你好').map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
          _User.address,
        ]);
        return Success(EthereumRpcResponse(method: request.method, data: signature));
      },
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    expect(
      await repository.signPersonalMessage(expectedAddress: _User.address, message: 'Register 你好'),
      signature,
    );
    expect(requests, 1);
    expect(user.created, 0);
  });
  for (final issue in ['address', 'emptyMessage', 'noWallet', 'logout', 'duplicateWallet']) {
    test('embedded personal message $issue does not sign or create a wallet', () async {
      final user = _User()..wallets = [_User.wallet];
      final sdk = _Sdk()..state = Authenticated(user);
      var requests = 0;
      final repository = PrivyIdentityRepository(
        configuration,
        create: (_) => sdk,
        preferences: MemoryWalletPreferences(),
        requestTypedData: (_, _) async {
          requests++;
          throw StateError('unexpected');
        },
      );
      addTearDown(repository.dispose);
      await repository.initialize();
      if (issue == 'noWallet') user.wallets = [];
      if (issue == 'duplicateWallet') user.wallets = [_User.wallet, _User.wallet];
      if (issue == 'logout') await repository.logout();
      await expectLater(
        repository.signPersonalMessage(
          expectedAddress: issue == 'address' ? '0x${'2' * 40}' : _User.address,
          message: issue == 'emptyMessage' ? '' : 'Registration',
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(requests, 0);
      expect(user.created, 0);
    });
  }
  test('embedded personal signature arriving after logout is rejected', () async {
    final user = _User()..wallets = [_User.wallet];
    final sdk = _Sdk()..state = Authenticated(user);
    final gate = Completer<Result<EthereumRpcResponse>>();
    final repository = PrivyIdentityRepository(
      configuration,
      create: (_) => sdk,
      preferences: MemoryWalletPreferences(),
      requestTypedData: (_, _) => gate.future,
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    final pending = repository.signPersonalMessage(
      expectedAddress: _User.address,
      message: 'Registration',
    );
    await repository.logout();
    gate.complete(Success(EthereumRpcResponse(method: 'personal_sign', data: '0x${'1' * 130}')));
    await expectLater(pending, throwsA(isA<AuthFailure>()));
    expect(user.created, 0);
  });

  test('missing public configuration never initializes a native client', () async {
    var created = false;
    final repository = PrivyIdentityRepository(
      const PrivyConfiguration(appId: '', clientId: ''),
      preferences: MemoryWalletPreferences(),
      create: (_) {
        created = true;
        throw StateError('Unexpected initialization');
      },
    );
    expect(await repository.initialize(), null);
    await expectLater(
      repository.sendCode('test@example.com'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authConfiguration')),
    );
    expect(created, false);
  });

  test(
    'native configuration, verification, wallet creation and logout stay behind the boundary',
    () async {
      final sdk = _Sdk();
      final repository = PrivyIdentityRepository(
        configuration,
        preferences: MemoryWalletPreferences(),
        create: (config) {
          expect(config.appId, 'app-id');
          expect(config.appClientId, 'client-id');
          expect(config.logLevel, PrivyLogLevel.none);
          return sdk;
        },
      );
      expect(await repository.initialize(), null);
      await repository.sendCode('test@example.com');
      expect(sdk.email.requestedEmail, 'test@example.com');
      final identity = await repository.verifyCode('test@example.com', '123456');
      expect(identity.id, 'user');
      expect(identity.email, 'test@example.com');
      expect(identity.walletAddress, null);
      expect(sdk.email.verifiedCode, '123456');
      expect((await repository.ensureWallet()).walletAddress, _User.address);
      await repository.ensureWallet();
      expect(sdk.email.user.created, 1);
      await repository.logout();
      expect(sdk.loggedOut, true);
      await expectLater(repository.ensureWallet(), throwsA(isA<AuthFailure>()));
    },
  );

  test('restored wallet is exposed as an address without creating another wallet', () async {
    final sdk = _Sdk()..state = Authenticated(_User()..wallets = [_User.wallet]);
    final repository = PrivyIdentityRepository(
      configuration,
      preferences: MemoryWalletPreferences(),
      create: (_) => sdk,
    );
    expect((await repository.initialize())?.walletAddress, _User.address);
    expect((await repository.ensureWallet()).walletAddress, _User.address);
  });

  test('malformed native wallet data cannot become an authenticated wallet address', () async {
    final sdk = _Sdk()
      ..state = Authenticated(
        _User()..wallets = [EmbeddedEthereumWallet(address: 'invalid', hdWalletIndex: 0)],
      );
    final repository = PrivyIdentityRepository(
      configuration,
      preferences: MemoryWalletPreferences(),
      create: (_) => sdk,
    );
    await expectLater(repository.initialize(), throwsA(isA<AuthFailure>()));
  });

  test('typed reads use the existing embedded wallet, exact RPC and no wallet creation', () async {
    final user = _User()..wallets = [_User.wallet];
    final sdk = _Sdk()..state = Authenticated(user);
    final typed = <String, Object?>{
      'primaryType': 'Message',
      'message': {'msg': 'nonce=1'},
    };
    final signature = '0x${List.filled(65, '11').join()}';
    var requests = 0;
    final repository = PrivyIdentityRepository(
      configuration,
      preferences: MemoryWalletPreferences(),
      create: (_) => sdk,
      requestTypedData: (wallet, request) async {
        requests++;
        expect(wallet, same(_User.wallet));
        expect(request.method, 'eth_signTypedData_v4');
        expect(request.params.first, _User.address);
        expect(jsonDecode(request.params.last as String), typed);
        return Success(EthereumRpcResponse(method: request.method, data: signature));
      },
    );
    addTearDown(repository.dispose);
    expect((await repository.initialize())?.signingAvailable, true);
    expect(
      await repository.signWalletRequest(expectedAddress: _User.address, typedData: typed),
      signature,
    );
    expect(requests, 1);
    expect(user.created, 0);
    await expectLater(
      repository.signWalletRequest(
        expectedAddress: '0x2222222222222222222222222222222222222222',
        typedData: typed,
      ),
      throwsA(isA<AuthFailure>()),
    );
    expect(requests, 1);
  });

  test('SDK user refresh with the same wallet does not invalidate a pending signature', () async {
    final sdk = _Sdk()..state = Authenticated(_User()..wallets = [_User.wallet]);
    final gate = Completer<Result<EthereumRpcResponse>>();
    final repository = PrivyIdentityRepository(
      configuration,
      preferences: MemoryWalletPreferences(),
      create: (_) => sdk,
      requestTypedData: (_, _) => gate.future,
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    final pending = repository.signWalletRequest(
      expectedAddress: _User.address,
      typedData: {'message': 'read'},
    );
    sdk.state = Authenticated(_User()..wallets = [_User.wallet]);
    await repository.initialize();
    final signature = '0x${List.filled(65, '11').join()}';
    gate.complete(Success(EthereumRpcResponse(method: 'eth_signTypedData_v4', data: signature)));
    expect(await pending, signature);
  });

  test('logout during embedded signing rejects the late signature', () async {
    final sdk = _Sdk()..state = Authenticated(_User()..wallets = [_User.wallet]);
    final gate = Completer<Result<EthereumRpcResponse>>();
    final repository = PrivyIdentityRepository(
      configuration,
      preferences: MemoryWalletPreferences(),
      create: (_) => sdk,
      requestTypedData: (_, _) => gate.future,
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    final pending = repository.signWalletRequest(
      expectedAddress: _User.address,
      typedData: {'message': 'read'},
    );
    final rejected = expectLater(
      pending,
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    await repository.logout();
    gate.complete(
      Success(
        EthereumRpcResponse(
          method: 'eth_signTypedData_v4',
          data: '0x${List.filled(65, '11').join()}',
        ),
      ),
    );
    await rejected;
  });

  test(
    'invalid embedded signatures and missing wallets never create a replacement wallet',
    () async {
      final user = _User()..wallets = [_User.wallet];
      final sdk = _Sdk()..state = Authenticated(user);
      var requests = 0;
      final repository = PrivyIdentityRepository(
        configuration,
        preferences: MemoryWalletPreferences(),
        create: (_) => sdk,
        requestTypedData: (_, _) async {
          requests++;
          return Success(EthereumRpcResponse(method: 'eth_signTypedData_v4', data: 'invalid'));
        },
      );
      addTearDown(repository.dispose);
      await repository.initialize();
      await expectLater(
        repository.signWalletRequest(
          expectedAddress: _User.address,
          typedData: {'message': 'read'},
        ),
        throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletSignature')),
      );
      user.wallets = [];
      await expectLater(
        repository.signWalletRequest(
          expectedAddress: _User.address,
          typedData: {'message': 'read'},
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(requests, 1);
      expect(user.created, 0);
    },
  );

  test('SDK reasons retain useful failures while redacting OTPs, tokens and payloads', () {
    final failure = failureFromPrivy(
      'Network unavailable token=secret otp=123456\nat internal.frame',
    );
    expect(failure.key, 'authNetwork');
    expect(failure.reason, 'Network unavailable [redacted] [redacted]');
    expect(failureFromPrivy('Code 123456 expired').reason, 'Code [redacted] expired');
    expect(failureFromPrivy('Unexpected response {"token":"private"}').reason, null);
    expect(failureFromPrivy('Too many requests').key, 'authRateLimited');
    expect(
      failureFromPrivy('Network private_key=hidden access_token=hidden').reason,
      'Network [redacted] [redacted]',
    );
  });
}

class _Sdk implements Privy {
  AuthState state = const Unauthenticated();
  @override
  final _Email email = _Email();
  @override
  final _OAuth oAuth = _OAuth();
  bool loggedOut = false;
  @override
  Future<AuthState> getAuthState() async => state;
  @override
  Future<void> logout() async {
    loggedOut = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OAuth implements LoginWithOAuth {
  final user = _User();
  OAuthProvider? provider;
  String? scheme;
  PrivyException? failure;

  @override
  Future<Result<PrivyUser>> login({
    required OAuthProvider provider,
    required String appUrlScheme,
  }) async {
    this.provider = provider;
    scheme = appUrlScheme;
    if (failure case final error?) return Failure(error);
    return Success(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Email implements LoginWithEmail {
  final user = _User();
  String? requestedEmail, verifiedCode;
  @override
  Future<Result<void>> sendCode(String email) async {
    requestedEmail = email;
    return const Success(null);
  }

  @override
  Future<Result<PrivyUser>> loginWithCode({required String code, required String email}) async {
    verifiedCode = code;
    return Success(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements PrivyUser {
  static const address = '0x1111111111111111111111111111111111111111';
  static final wallet = EmbeddedEthereumWallet(address: address, hdWalletIndex: 0);
  List<EmbeddedEthereumWallet> wallets = [];
  int created = 0;
  @override
  String get id => 'user';
  @override
  List<LinkedAccounts> get linkedAccounts => [EmailAccount(emailAddress: 'test@example.com')];
  @override
  List<EmbeddedEthereumWallet> get embeddedEthereumWallets => wallets;
  @override
  Future<Result<EmbeddedEthereumWallet>> createEthereumWallet({
    bool allowAdditional = false,
  }) async {
    created++;
    wallets = [wallet];
    return Success(wallet);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
