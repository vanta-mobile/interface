import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/core/network/request_scope.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';

import '../../support/reown_modal.dart';
import '../../support/wallet_transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestReownModal modal;
  late ReownWalletConnection connection;
  setUp(() {
    modal = TestReownModal();
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

  test('wallet disconnect and session expiry invalidate exactly once', () async {
    var invalidations = 0;
    final subscription = connection.invalidations.listen((_) => invalidations++);
    modal.expiry = 1;
    modal.changed();
    modal.isConnected = false;
    modal.changed();
    expect(connection.isCurrent, false);
    expect(invalidations, 1);
    await expectLater(connection.signPersonalMessage('test'), throwsA(isA<AuthFailure>()));
    expect(modal.requests, isEmpty);
    await subscription.cancel();
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
  test('stopped send yields to a new request without releasing its lease on late return', () async {
    var current = true;
    modal.result = '0x${'b' * 64}';
    final firstGate = Completer<void>(), secondGate = Completer<void>();
    modal.gate = firstGate;
    final first = connection.sendTransaction(
      transaction: walletTransaction(),
      isCurrent: () => current,
    );
    current = false;
    modal.gate = secondGate;
    final second = connection.sendTransaction(
      transaction: walletTransaction(),
      isCurrent: () => true,
    );
    firstGate.complete();
    expect((await first).hash, modal.result);
    await expectLater(
      connection.sendTransaction(transaction: walletTransaction(), isCurrent: () => true),
      throwsA(isA<WalletTransactionNotSent>()),
    );
    expect(modal.requests, hasLength(2));
    secondGate.complete();
    expect((await second).hash, modal.result);
  });
  test('abandoned signature scope yields while its late signature cannot continue', () async {
    var current = true;
    final firstGate = Completer<void>(), secondGate = Completer<void>();
    modal.gate = firstGate;
    final first = RequestScope.run(() => current, () => connection.signTypedData({}));
    final firstFailure = expectLater(first, throwsA(isA<AuthFailure>()));
    await pumpEventQueue();
    current = false;
    modal.gate = secondGate;
    final second = RequestScope.run(() => true, () => connection.signTypedData({}));
    await pumpEventQueue();
    firstGate.complete();
    await firstFailure;
    await expectLater(connection.signTypedData({}), throwsA(isA<AuthFailure>()));
    expect(modal.requests, hasLength(2));
    secondGate.complete();
    expect(await second, modal.result);
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
