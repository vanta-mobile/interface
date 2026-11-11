import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/features/auth/data/reown_signing_network.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/data/reown_wallet_namespaces.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';

import '../../support/reown_modal.dart';
import '../../support/wallet_transaction.dart';

void main() {
  late TestReownModal modal;
  late ReownWalletConnection connection;
  setUp(() {
    modal = TestReownModal()
      ..selectedChainId = '42161'
      ..approvedChain = '42161';
    connection = ReownWalletConnection(modal, modal.address, '42161');
  });
  tearDown(() async {
    await connection.release();
    await modal.dispose();
  });
  Future<void> prepare({bool Function()? current}) => connection.prepareSigning(
    expectedAddress: connection.address,
    chainId: 56,
    isCurrent: current ?? () => true,
  );
  void approve() {
    modal.approvedAccounts = ['eip155:42161:${modal.address}', 'eip155:56:${modal.address}'];
    modal.selectedChainId = '56';
    modal.changed();
  }

  test(
    'Arbitrum connection approves BNB before routing the unchanged signature on chain 56',
    () async {
      var invalidations = 0;
      final subscription = connection.invalidations.listen((_) => invalidations++);
      modal.onRequest = (request) async {
        if (request.method == 'wallet_switchEthereumChain') {
          expect(modal.chain, 'eip155:42161');
          expect(request.params, [
            {'chainId': '0x38'},
          ]);
          approve();
          return null;
        }
        return modal.result;
      };
      await prepare();
      expect(connection.chainId, '56');
      expect(connection.isCurrent, true);
      expect(invalidations, 0);
      final data = <String, Object?>{
        'domain': {'chainId': 56},
        'message': {'msg': 'original'},
      };
      await connection.signTypedData(data);
      expect(modal.chain, 'eip155:56');
      expect(jsonDecode((modal.requested!.params as List).last as String), data);
      expect(modal.requests.map((r) => r.method), [
        'wallet_switchEthereumChain',
        'eth_signTypedData_v4',
      ]);
      await subscription.cancel();
    },
  );

  test('already selected and approved BNB does not open another switch prompt', () async {
    await connection.release();
    modal.selectedChainId = '56';
    modal.approvedChain = '56';
    connection = ReownWalletConnection(modal, modal.address, '56');
    await prepare();
    expect(modal.requests, isEmpty);
  });

  test('user rejection preserves the original connection and does not sign or retry', () async {
    modal.failure = JsonRpcError(code: 4001, message: 'User rejected network switch');
    await expectLater(
      prepare(),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletRejected')),
    );
    expect(connection.chainId, '42161');
    expect(connection.isCurrent, true);
    expect(modal.requests.map((r) => r.method), ['wallet_switchEthereumChain']);
  });

  test('missing network-switch permission never sends a wallet request', () async {
    modal.methods = ['eth_signTypedData_v4'];
    await expectLater(
      prepare(),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletSigningNetwork')),
    );
    expect(modal.requests, isEmpty);
  });

  for (final autoSelect in [true, false]) {
    test('MetaMask 4902 adds BNB once and confirms selection: autoSelect=$autoSelect', () async {
      var switches = 0;
      modal.onRequest = (request) async {
        if (request.method == 'wallet_switchEthereumChain') {
          if (++switches == 1) throw JsonRpcError(code: 4902, message: 'Invalid chainId');
          approve();
        } else if (request.method == 'wallet_addEthereumChain') {
          expect(modal.chain, 'eip155:42161');
          expect(request.params, [
            {
              'chainId': '0x38',
              'chainName': 'BNB Smart Chain Mainnet',
              'nativeCurrency': {'name': 'BNB Chain Native Token', 'symbol': 'BNB', 'decimals': 18},
              'rpcUrls': ['https://bsc-dataseed1.bnbchain.org'],
              'blockExplorerUrls': ['https://bscscan.com'],
            },
          ]);
          if (autoSelect) approve();
        }
        return null;
      };
      await prepare();
      expect(connection.isCurrent, true);
      expect(connection.chainId, '56');
      expect(modal.requests.map((r) => r.method), [
        'wallet_switchEthereumChain',
        'wallet_addEthereumChain',
        if (!autoSelect) 'wallet_switchEthereumChain',
      ]);
    });
  }

  test('old sessions without add-chain permission stop with the reconnect instruction', () async {
    modal.methods.remove('wallet_addEthereumChain');
    modal.failure = JsonRpcError(code: 4902, message: 'Invalid chainId');
    await expectLater(
      prepare(),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletSigningNetwork')),
    );
    expect(modal.requests.map((r) => r.method), ['wallet_switchEthereumChain']);
    expect(connection.isCurrent, true);
  });

  for (final code in [4001, -32602, -32000]) {
    test('switch failure $code never adds a network or repeats the request', () async {
      modal.failure = JsonRpcError(code: code, message: 'Invalid chainId');
      await expectLater(prepare(), throwsA(isA<AuthFailure>()));
      expect(modal.requests.map((r) => r.method), ['wallet_switchEthereumChain']);
    });
  }

  for (final issue in ['rejected', 'scope', 'timeout', 'secondSwitch']) {
    test('add-network $issue prevents signing and has no further fallback', () async {
      var switches = 0;
      var current = true;
      final gate = Completer<void>();
      modal.onRequest = (request) async {
        if (request.method == 'wallet_switchEthereumChain') {
          switches++;
          throw JsonRpcError(code: 4902, message: 'Invalid chainId');
        }
        if (issue == 'rejected') throw JsonRpcError(code: 4001, message: 'User rejected network');
        if (issue == 'scope') current = false;
        if (issue == 'timeout') await gate.future;
        return null;
      };
      await expectLater(
        prepareReownSigningNetwork(
          modal: modal,
          address: modal.address,
          fromChain: '42161',
          chainId: 56,
          isCurrent: () => current,
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(issue == 'timeout' ? isA<TimeoutException>() : anything),
      );
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(modal.requests.map((r) => r.method), [
        'wallet_switchEthereumChain',
        'wallet_addEthereumChain',
        if (issue == 'secondSwitch') 'wallet_switchEthereumChain',
      ]);
      expect(switches, issue == 'secondSwitch' ? 2 : 1);
    });
  }

  test('network requests use only the supported mainnets and explicit permissions', () {
    final namespaces = reownWalletNamespaces();
    expect(namespaces.keys, ['eip155']);
    expect(namespaces['eip155']!.chains, ['eip155:1', 'eip155:56', 'eip155:42161', 'eip155:8453']);
    expect(
      namespaces['eip155']!.methods,
      containsAll([
        'eth_signTypedData_v4',
        'wallet_switchEthereumChain',
        'wallet_addEthereumChain',
      ]),
    );
    expect(signingNetworkParameters(1666), null);
  });

  for (final issue in ['account', 'network', 'scope', 'dispose']) {
    test('$issue change during network approval prevents a subsequent signature', () async {
      final gate = Completer<void>();
      var current = true;
      modal.onRequest = (_) async {
        await gate.future;
        if (issue == 'account') modal.address = '0x${'3' * 40}';
        if (issue == 'network') modal.selectedChainId = '1';
        if (issue == 'scope') current = false;
        modal.changed();
        return null;
      };
      final pending = prepare(current: () => current);
      final check = expectLater(
        pending,
        throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
      );
      if (issue == 'dispose') await connection.release();
      gate.complete();
      await check;
      expect(modal.requests.map((r) => r.method), ['wallet_switchEthereumChain']);
    });
  }

  test('switch in progress blocks concurrent signatures, transfers and preparation', () async {
    final gate = Completer<void>();
    modal.onRequest = (_) async {
      await gate.future;
      approve();
      return null;
    };
    final pending = prepare();
    await expectLater(
      connection.signTypedData({}),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletBusy')),
    );
    await expectLater(
      prepare(),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletBusy')),
    );
    await expectLater(
      connection.sendTransaction(transaction: walletTransaction(), isCurrent: () => true),
      throwsA(isA<WalletTransactionNotSent>()),
    );
    gate.complete();
    await pending;
    expect(modal.requests.length, 1);
  });

  test('unrelated network change still invalidates the connection', () {
    modal.selectedChainId = '1';
    modal.changed();
    expect(connection.isCurrent, false);
  });

  test('switch timeout sends no second request and never signs', () async {
    final gate = Completer<void>();
    modal.onRequest = (_) async {
      await gate.future;
      return null;
    };
    await expectLater(
      prepareReownSigningNetwork(
        modal: modal,
        address: modal.address,
        fromChain: '42161',
        chainId: 56,
        isCurrent: () => true,
        timeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<TimeoutException>()),
    );
    gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(modal.requests.length, 1);
    expect(modal.selectedChainId, '42161');
  });

  test('switch success without session approval is never treated as signing permission', () async {
    modal.onRequest = (_) async => null;
    await expectLater(
      prepareReownSigningNetwork(
        modal: modal,
        address: modal.address,
        fromChain: '42161',
        chainId: 56,
        isCurrent: () => true,
        timeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletSigningNetwork')),
    );
    expect(modal.requests.length, 1);
    expect(modal.selectedChainId, '42161');
  });
}
