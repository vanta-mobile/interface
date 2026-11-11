import 'package:reown_appkit/reown_appkit.dart';

import 'wallet_configuration.dart';

/// Declaring chains alone does not grant permission to switch or add them.
Map<String, RequiredNamespace> reownWalletNamespaces() => {
  'eip155': RequiredNamespace(
    chains: WalletConfiguration.chains.map((chain) => 'eip155:$chain').toList(),
    methods: const [
      'personal_sign',
      'eth_signTypedData_v4',
      'eth_sendTransaction',
      'wallet_switchEthereumChain',
      'wallet_addEthereumChain',
    ],
    events: const ['accountsChanged', 'chainChanged'],
  ),
};

/// Match MetaMask's chainid.network entry for BNB mainnet.
/// https://chainid.network/chains.json (chainId 56)
Map<String, Object?>? signingNetworkParameters(int chainId) => chainId == 56
    ? {
        'chainId': '0x38',
        'chainName': 'BNB Smart Chain Mainnet',
        'nativeCurrency': {'name': 'BNB Chain Native Token', 'symbol': 'BNB', 'decimals': 18},
        'rpcUrls': ['https://bsc-dataseed1.bnbchain.org'],
        'blockExplorerUrls': ['https://bscscan.com'],
      }
    : null;
