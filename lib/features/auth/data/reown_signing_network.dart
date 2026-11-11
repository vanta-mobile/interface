import 'dart:async';

import 'package:reown_appkit/reown_appkit.dart';

import '../domain/auth_session.dart';
import 'reown_wallet_namespaces.dart';

/// Prepare the signing network before obtaining a short-lived authorization
/// nonce. Only explicit 4902 permits adding the known BNB network once.
Future<void> prepareReownSigningNetwork({
  required ReownAppKitModal modal,
  required String address,
  required String fromChain,
  required int chainId,
  required bool Function() isCurrent,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final topic = modal.session?.topic;
  final target = 'eip155:$chainId';
  bool approved() =>
      modal.session
          ?.getAccounts(namespace: 'eip155')
          ?.any((account) => account.toLowerCase() == '$target:$address'.toLowerCase()) ==
      true;
  void current() {
    if (!isCurrent() || topic == null || modal.session?.topic != topic) {
      throw const AuthFailure('authWalletChanged');
    }
  }

  current();
  if (modal.selectedChain?.chainId == target && approved()) return;
  final network = ReownAppKitModalNetworks.getNetworkInfo('eip155', '$chainId');
  if (network == null ||
      modal.session
              ?.getApprovedMethods(namespace: 'eip155')
              ?.contains('wallet_switchEthereumChain') !=
          true) {
    throw const AuthFailure('authWalletSigningNetwork');
  }
  final clock = Stopwatch()..start();
  Future<dynamic> request(String method, List<Object?> params) async {
    current();
    final remaining = timeout - clock.elapsed;
    if (remaining <= Duration.zero) throw TimeoutException('Wallet network approval timed out');
    return modal
        .request(
          topic: topic,
          chainId: approved() && modal.selectedChain?.chainId == target
              ? target
              : 'eip155:$fromChain',
          switchToChainId: target,
          request: SessionRequestParams(method: method, params: params),
        )
        .timeout(remaining);
  }

  Future<dynamic> switchNetwork() => request('wallet_switchEthereumChain', [
    {'chainId': '0x${chainId.toRadixString(16)}'},
  ]);
  try {
    await switchNetwork();
  } catch (error) {
    current();
    final code = switch (error) {
      JsonRpcError(:final code) => code,
      ReownSignError(:final code) => code,
      _ => null,
    };
    if (code != 4902) rethrow;
    final parameters = signingNetworkParameters(chainId);
    if (parameters == null ||
        modal.session
                ?.getApprovedMethods(namespace: 'eip155')
                ?.contains('wallet_addEthereumChain') !=
            true) {
      throw const AuthFailure('authWalletSigningNetwork');
    }
    await request('wallet_addEthereumChain', [parameters]);
    current();
    // Adding a chain is not proof that it is selected or authorized. Some
    // wallets select it during approval; others require an explicit switch.
    if (!approved() || modal.selectedChain?.chainId != target) await switchNetwork();
  }
  current();
  // WalletConnect session approval may arrive after the switch RPC response.
  while (!approved()) {
    current();
    if (clock.elapsed >= timeout) throw const AuthFailure('authWalletSigningNetwork');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  current();
  // The wallet has approved the network. Align AppKit's local routing only.
  final remaining = timeout - clock.elapsed;
  if (remaining <= Duration.zero) throw TimeoutException('Wallet network approval timed out');
  await modal.selectChain(network).timeout(remaining);
  current();
  if (modal.selectedChain?.chainId != target || !approved()) {
    throw const AuthFailure('authWalletSigningNetwork');
  }
}
