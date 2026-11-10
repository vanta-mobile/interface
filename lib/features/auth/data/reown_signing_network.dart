import 'dart:async';

import 'package:reown_appkit/reown_appkit.dart';

import '../domain/auth_session.dart';

/// One network request, followed by approval reconciliation. No add-chain or
/// signature retry is inferred from a failed switch.
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
  await modal
      .request(
        topic: topic,
        chainId: 'eip155:$fromChain',
        switchToChainId: target,
        request: SessionRequestParams(
          method: 'wallet_switchEthereumChain',
          params: [
            {'chainId': '0x${chainId.toRadixString(16)}'},
          ],
        ),
      )
      .timeout(timeout);
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
