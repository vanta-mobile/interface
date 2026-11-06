import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';

import '../../support/wallet_connection.dart';
import '../../support/wallet_transaction.dart';

void main() {
  late _Modal modal;
  late ReownWalletConnection connection;
  setUp(() {
    modal = _Modal();
    connection = ReownWalletConnection(modal, modal.address, '56');
  });
  tearDown(() async {
    await connection.release();
    await modal.dispose();
  });

  test('wallet display name comes from the connected peer rather than app metadata', () {
    expect(connection.walletName, 'MetaMask');
    modal.walletName = '  Trust Wallet  ';
    expect(connection.walletName, 'Trust Wallet');
    modal.walletName = '   ';
    expect(connection.walletName, isNull);
  });

  test('transaction RPC preserves exact reviewed fields and original chain', () async {
    final tx = walletTransaction();
    modal.result = '0x${'a' * 64}';
    final result = await connection.sendTransaction(transaction: tx, isCurrent: () => true);
    expect(result.status, WalletTransactionStatus.hashReported);
    expect(result.hash, modal.result);
    expect(modal.chain, 'eip155:56');
    expect(modal.topic, 'topic');
    expect(modal.requested!.method, 'eth_sendTransaction');
    expect(modal.requested!.params, [tx.parameters]);
  });
  for (final issue in [
    'wrongAddress',
    'wrongChain',
    'stale',
    'scope',
    'permission',
    'approvedChain',
  ]) {
    test('send refuses $issue before modal request', () async {
      if (issue == 'stale') connection.release();
      if (issue == 'permission') modal.methods = [];
      if (issue == 'approvedChain') modal.approvedChain = '1';
      final tx = walletTransaction(
        chainId: issue == 'wrongChain' ? 1 : 56,
        from: issue == 'wrongAddress' ? '0x${'3' * 40}' : modal.address,
      );
      await expectLater(
        connection.sendTransaction(transaction: tx, isCurrent: () => issue != 'scope'),
        throwsA(isA<WalletTransactionNotSent>()),
      );
      expect(modal.requested, null);
    });
  }
  test('pending send blocks duplicates and retains hash after wallet account changes', () async {
    modal.result = '0x${'b' * 64}';
    modal.gate = Completer();
    final pending = connection.sendTransaction(
      transaction: walletTransaction(),
      isCurrent: () => true,
    );
    await expectLater(
      connection.sendTransaction(transaction: walletTransaction(), isCurrent: () => true),
      throwsA(isA<WalletTransactionNotSent>().having((e) => e.key, 'key', 'walletTransactionBusy')),
    );
    modal.address = '0x${'3' * 40}';
    modal.changed();
    modal.gate!.complete();
    final result = await pending;
    expect(result.hash, '0x${'b' * 64}');
    expect(connection.isCurrent, false);
  });
  for (final error in [JsonRpcError(code: 4001, message: 'refused'), StateError('4001 rejected')]) {
    test(
      'transaction error ${error.runtimeType} uses structured result, not signature handling',
      () async {
        modal.failure = error;
        final result = await connection.sendTransaction(
          transaction: walletTransaction(),
          isCurrent: () => true,
        );
        expect(
          result.status,
          error is JsonRpcError
              ? WalletTransactionStatus.rejected
              : WalletTransactionStatus.unknown,
        );
        expect(modal.requested!.method, 'eth_sendTransaction');
      },
    );
  }
  test('signature-looking send response is unknown and never retried', () async {
    final result = await connection.sendTransaction(
      transaction: walletTransaction(),
      isCurrent: () => true,
    );
    expect(result.status, WalletTransactionStatus.unknown);
  });

  test(
    'native requests preserve UTF-8 SIWE messages and EIP-712 data on the selected chain',
    () async {
      await connection.signPersonalMessage('Sign in 登录');
      expect(modal.topic, 'topic');
      expect(modal.chain, 'eip155:56');
      expect(modal.requested!.method, 'personal_sign');
      final parameters = modal.requested!.params as List<Object?>;
      final encoded = parameters.first! as String;
      expect(
        utf8.decode([
          for (var i = 2; i < encoded.length; i += 2)
            int.parse(encoded.substring(i, i + 2), radix: 16),
        ]),
        'Sign in 登录',
      );
      expect(parameters.last, connection.address);
      final typed = <String, Object?>{
        'primaryType': 'Message',
        'message': {'nonce': '7'},
      };
      await connection.signTypedData(typed);
      expect(modal.requested!.method, 'eth_signTypedData_v4');
      final typedParameters = modal.requested!.params as List<Object?>;
      expect(typedParameters.first, connection.address);
      expect(jsonDecode(typedParameters.last! as String), typed);
    },
  );

  test(
    'native account changes invalidate once and reject signatures returned after the change',
    () async {
      var invalidations = 0;
      final subscription = connection.invalidations.listen((_) => invalidations++);
      modal.gate = Completer<void>();
      final pending = connection.signTypedData({});
      modal.address = '0x3333333333333333333333333333333333333333';
      modal.changed();
      modal.changed();
      modal.gate!.complete();
      await expectLater(
        pending,
        throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
      );
      expect(invalidations, 1);
      await subscription.cancel();
    },
  );

  test('invalid signatures and wallet rejection become safe failures', () async {
    modal.result = '0x1234';
    await expectLater(
      connection.signPersonalMessage('challenge'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletSignature')),
    );
    modal.failure = StateError('4001 User rejected request');
    await expectLater(
      connection.signPersonalMessage('challenge'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletRejected')),
    );
    await connection.disconnect();
    expect(modal.disconnections, 1);
    expect(modal.observesSession, false);
    expect(connection.isCurrent, false);
  });
}

class _Modal extends ChangeNotifier implements ReownAppKitModal {
  String walletName = 'MetaMask';
  List<String> methods = ['eth_sendTransaction'];
  String approvedChain = '56';
  bool get observesSession => hasListeners;
  @override
  Future<void> dispose() async => super.dispose();
  String address = '0x2222222222222222222222222222222222222222';
  static const metadata = ConnectionMetadata(
    publicKey: 'key',
    metadata: PairingMetadata(
      name: 'test',
      description: 'test',
      url: 'https://example.com',
      icons: [],
    ),
  );
  @override
  ReownAppKitModalSession get session => ReownAppKitModalSession(
    sessionData: SessionData(
      topic: 'topic',
      pairingTopic: 'pairing',
      relay: Relay('irn'),
      expiry: 1,
      acknowledged: true,
      controller: 'key',
      self: metadata,
      peer: ConnectionMetadata(
        publicKey: 'wallet-key',
        metadata: PairingMetadata(
          name: walletName,
          description: 'Connected wallet',
          url: 'https://example.com/wallet',
          icons: [],
        ),
      ),
      namespaces: {
        'eip155': Namespace(
          accounts: ['eip155:$approvedChain:$address'],
          methods: methods,
          events: [],
        ),
      },
    ),
  );
  @override
  bool isConnected = true;
  @override
  ReownAppKitModalNetworkInfo? get selectedChain => const ReownAppKitModalNetworkInfo(
    name: 'BNB Chain',
    chainId: 'eip155:56',
    currency: 'BNB',
    rpcUrl: 'https://example.com',
    explorerUrl: 'https://example.com',
  );
  SessionRequestParams? requested;
  String? topic, chain;
  String result = TestWalletConnection.signature;
  Object? failure;
  Completer<void>? gate;
  int disconnections = 0;
  void changed() => notifyListeners();
  @override
  Future<dynamic> request({
    required String? topic,
    required String chainId,
    String? switchToChainId,
    required SessionRequestParams request,
  }) async {
    this.topic = topic;
    chain = chainId;
    requested = request;
    await gate?.future;
    if (failure case final error?) throw error;
    return result;
  }

  @override
  Future<void> disconnect({bool disconnectAllSessions = true}) async {
    disconnections++;
    isConnected = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
