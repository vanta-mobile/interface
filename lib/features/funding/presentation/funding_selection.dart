import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error_details.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../domain/funding_catalog.dart';

/// Form input kept per tab, so switching tabs keeps it. An amount belongs to
/// one network and token; choosing a different one clears it.
class FundingSelection extends ChangeNotifier {
  final amount = TextEditingController();

  /// Withdrawal destination; an EVM address is the same on every network.
  final receiver = TextEditingController();
  int? chainId;
  String? asset;

  /// [shownChain]/[shownAsset] are what the form displayed, which may be a
  /// default the user never picked explicitly.
  void select({int? chainId, String? asset, int? shownChain, String? shownAsset}) {
    if (chainId != null && chainId != shownChain || asset != null && asset != shownAsset) {
      amount.clear();
    }
    if (chainId != null) this.chainId = chainId;
    if (asset != null) this.asset = asset;
    notifyListeners();
  }

  void clear() {
    amount.clear();
    receiver.clear();
    chainId = null;
    asset = null;
    notifyListeners();
  }

  @override
  void dispose() {
    amount.dispose();
    receiver.dispose();
    super.dispose();
  }
}

/// Supported networks and the asset currently shown by a funding form.
class FundingChoice {
  FundingChoice._(this.chains, this.chainId, this.assets, this.asset);

  /// [defaultChain] is shown until the user picks a network; an unsupported
  /// one leaves the network unselected.
  factory FundingChoice.of(
    Iterable<FundingAsset> all,
    FundingSelection selection, {
    int? defaultChain,
  }) {
    final chains = [
      for (final id in fundingEvmChainIds)
        if (all.any((a) => a.chainId == id)) id,
    ];
    // A choice that is no longer supported is dropped.
    final chain = chains.contains(selection.chainId)
        ? selection.chainId
        : chains.contains(defaultChain)
        ? defaultChain
        : null;
    // The network's native asset leads, as in the supplied frames.
    final onChain = all.where((a) => a.chainId == chain);
    final assets = [...onChain.where((a) => a.isNative), ...onChain.where((a) => !a.isNative)];
    final asset = assets.where((a) => a.asset == selection.asset).firstOrNull ?? assets.firstOrNull;
    return FundingChoice._(chains, chain, assets, asset);
  }
  final List<int> chains;
  final int? chainId;
  final List<FundingAsset> assets;
  final FundingAsset? asset;
}

/// The network a funding form starts on: the external wallet's current
/// network, or BNB Chain for the embedded wallet.
int? fundingDefaultChain(WidgetRef ref) {
  final kind = ref.watch(authProvider.select((s) => s.identity?.walletKind));
  return switch (kind) {
    WalletKind.embedded => 56,
    WalletKind.external => ref.watch(walletChainProvider),
    null => null,
  };
}

/// A failed button action, kept on the form until its input changes.
class FundingActionError {
  const FundingActionError(this.key, [this.details]);
  final String key;
  final ApiErrorDetails? details;
}
