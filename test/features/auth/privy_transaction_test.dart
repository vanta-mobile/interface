import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:privy_flutter/src/logging/logger_service.dart';
import 'package:privy_flutter/src/logging/privy_logger.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/privy_identity_repository.dart';
import 'package:vanta/features/auth/data/privy_transaction_requester.dart';
import 'package:vanta/features/auth/data/privy_wallet_signer.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';

import '../../support/wallet_connection.dart';
import '../../support/wallet_transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('privy_flutter');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _User user;
  late _Sdk sdk;
  late PrivyIdentityRepository repository;
  late List<MethodCall> calls;
  late Future<Object?> Function(MethodCall) response;
  PrivyIdentityRepository build({PrivyTypedDataRequester? requester}) => PrivyIdentityRepository(
    const PrivyConfiguration(appId: 'app', clientId: 'client'),
    create: (_) => sdk,
    preferences: MemoryWalletPreferences(),
    requestTransaction: requester,
  );
  Future<WalletTransactionResult> send({bool current = true}) => repository.sendWalletTransaction(
    transaction: walletTransaction(from: _User.address),
    isCurrent: () => current,
  );
  setUp(() {
    // The SDK initializes this logger in real Privy.init; our fake SDK skips it.
    LoggerService.initializeLogger(_SilentLogger());
    user = _User();
    sdk = _Sdk(user);
    calls = [];
    response = (_) async => {'method': 'eth_sendTransaction', 'data': '0x${'a' * 64}'};
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return response(call);
    });
    repository = build();
  });
  tearDown(() async {
    await repository.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });
  test('native personal_sign carries exact hex text and the existing wallet address', () async {
    response = (_) async => {'method': 'personal_sign', 'data': '0x${'1' * 130}'};
    await repository.initialize();
    await repository.signPersonalMessage(expectedAddress: _User.address, message: 'Registration');
    expect(calls.single.method, 'ethSendRpcRequest');
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(args['method'], 'personal_sign');
    expect(args['walletAddress'], _User.address);
    expect(args['params'], [
      '0x${utf8.encode('Registration').map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
      _User.address,
    ]);
    expect(user.created, 0);
  });
  test('native channel sends one JSON transaction for the existing embedded wallet', () async {
    await repository.initialize();
    final tx = walletTransaction(from: _User.address);
    final result = await send();
    expect(result.status, WalletTransactionStatus.hashReported);
    expect(result.hash, '0x${'a' * 64}');
    expect(calls.length, 1);
    expect(calls.single.method, 'ethSendRpcRequest');
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(arguments['method'], 'eth_sendTransaction');
    expect(arguments['walletAddress'], _User.address);
    expect(jsonDecode((arguments['params'] as List).single as String), tx.parameters);
    expect(user.created, 0);
  });
  for (final issue in [
    'notInitialized',
    'scope',
    'address',
    'missingWallet',
    'duplicateWallet',
    'logout',
    'disposed',
  ]) {
    test('embedded $issue cannot dispatch or create a wallet', () async {
      if (issue != 'notInitialized') await repository.initialize();
      if (issue == 'missingWallet') user.wallets = [];
      if (issue == 'duplicateWallet') user.wallets = [_User.wallet, _User.wallet];
      if (issue == 'logout') await repository.logout();
      if (issue == 'disposed') {
        await repository.dispose();
      }
      await expectLater(
        repository.sendWalletTransaction(
          transaction: walletTransaction(
            from: issue == 'address' ? '0x${'3' * 40}' : _User.address,
          ),
          isCurrent: () => issue != 'scope',
        ),
        throwsA(isA<WalletTransactionNotSent>()),
      );
      expect(calls, isEmpty);
      expect(user.created, 0);
    });
  }
  for (final error in [
    PlatformException(code: '4001', message: 'structured refusal'),
    PlatformException(code: 'RPC_REQUEST_FAILED', message: '4001 rejected'),
    PlatformException(code: 'NETWORK', message: 'private rpc failure'),
  ]) {
    test('native structured ${error.code} retained through pinned Privy adapter', () async {
      await repository.initialize();
      response = (_) async => throw error;
      final result = await send();
      expect(
        result.status,
        error.code == '4001' ? WalletTransactionStatus.rejected : WalletTransactionStatus.unknown,
      );
      expect(result.hash, null);
      expect(calls.length, 1);
    });
  }
  for (final malformed in [
    null,
    <String, Object?>{},
    {'method': 'personal_sign', 'data': '0x${'a' * 64}'},
    {'method': 'eth_sendTransaction', 'data': 'bad'},
    {'method': 'eth_sendTransaction', 'data': '0x${'0' * 64}'},
    {'method': 'eth_sendTransaction', 'data': 1},
  ]) {
    test('malformed native response $malformed cannot authorize a retry', () async {
      await repository.initialize();
      response = (_) async => malformed;
      expect((await send()).status, WalletTransactionStatus.unknown);
      expect(calls.length, 1);
    });
  }
  for (final change in ['logout', 'dispose', 'user', 'caller']) {
    test('hash returned after $change stays attached to original request', () async {
      await repository.initialize();
      var current = true;
      final gate = Completer<Object?>();
      response = (_) => gate.future;
      final pending = repository.sendWalletTransaction(
        transaction: walletTransaction(from: _User.address),
        isCurrent: () => current,
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls.length, 1);
      if (change == 'logout') await repository.logout();
      if (change == 'dispose') await repository.dispose();
      if (change == 'user') {
        sdk.user = _User(id: 'other');
        await repository.initialize();
      }
      if (change == 'caller') current = false;
      gate.complete({'method': 'eth_sendTransaction', 'data': '0x${'b' * 64}'});
      expect((await pending).hash, '0x${'b' * 64}');
    });
  }
  test('concurrent embedded sends rejected before the second native call', () async {
    await repository.initialize();
    final gate = Completer<Object?>();
    response = (_) => gate.future;
    final pending = send();
    await expectLater(
      send(),
      throwsA(isA<WalletTransactionNotSent>().having((e) => e.key, 'key', 'walletTransactionBusy')),
    );
    gate.complete({'method': 'eth_sendTransaction', 'data': '0x${'a' * 64}'});
    await pending;
    expect(calls.length, 1);
  });
  test('same-user SDK refresh preserves pending transaction result', () async {
    await repository.initialize();
    final gate = Completer<Object?>();
    response = (_) => gate.future;
    final pending = send();
    sdk.user = _User();
    await repository.initialize();
    gate.complete({'method': 'eth_sendTransaction', 'data': '0x${'c' * 64}'});
    expect((await pending).hash, '0x${'c' * 64}');
  });
  test('wrapped SDK failure containing 4001 is uncertain, never a proven refusal', () async {
    await repository.dispose();
    repository = build(requester: (_, _) async => const Failure(PrivyException('4001 rejected')));
    await repository.initialize();
    expect((await send()).status, WalletTransactionStatus.unknown);
    expect(calls, isEmpty);
  });
  test('wrong SDK response method does not reuse a signature as a transaction hash', () async {
    await repository.dispose();
    repository = build(
      requester: (_, _) async =>
          Success(EthereumRpcResponse(method: 'personal_sign', data: '0x${'a' * 64}')),
    );
    await repository.initialize();
    expect((await send()).status, WalletTransactionStatus.unknown);
  });
  test('transaction-only native adapter rejects signing methods before channel', () async {
    await expectLater(
      requestPrivyTransaction(
        _User.wallet,
        EthereumRpcRequest.personalSign('sensitive', _User.address),
      ),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });
}

class _SilentLogger implements PrivyLogger {
  @override
  void debug(String message) {}
  @override
  void info(String message) {}
  @override
  void warning(String message) {}
  @override
  void error(String message) {}
  @override
  void internal(String message) {}
}

class _Sdk implements Privy {
  _Sdk(this.user);
  @override
  _User user;
  @override
  Future<AuthState> getAuthState() async => Authenticated(user);
  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements PrivyUser {
  _User({this.id = 'user'});
  static const address = '0x1111111111111111111111111111111111111111';
  static final wallet = EmbeddedEthereumWallet(address: address, hdWalletIndex: 0);
  List<EmbeddedEthereumWallet> wallets = [wallet];
  int created = 0;
  @override
  final String id;
  @override
  List<LinkedAccounts> get linkedAccounts => [EmailAccount(emailAddress: 'test@example.com')];
  @override
  List<EmbeddedEthereumWallet> get embeddedEthereumWallets => wallets;
  @override
  Future<Result<EmbeddedEthereumWallet>> createEthereumWallet({
    bool allowAdditional = false,
  }) async {
    created++;
    return Success(wallet);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
