import 'package:flutter/widgets.dart';

import '../../../core/errors/api_error_details.dart';
import '../domain/funding_catalog.dart';

/// Form input kept per tab, so switching tabs keeps it. An amount belongs to
/// one network and token; choosing a different one clears it.
class FundingSelection extends ChangeNotifier {
  final amount = TextEditingController();
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
    chainId = null;
    asset = null;
    notifyListeners();
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }
}

/// Supported networks and the asset currently shown by a funding form.
class FundingChoice {
  FundingChoice._(this.chains, this.chainId, this.assets, this.asset);
  factory FundingChoice.of(Iterable<FundingAsset> all, FundingSelection selection) {
    final chains = [
      for (final id in fundingEvmChainIds)
        if (all.any((a) => a.chainId == id)) id,
    ];
    final chain = chains.contains(selection.chainId)
        ? selection.chainId
        : chains.contains(56)
        ? 56
        : chains.firstOrNull;
    // The network's native asset leads, as in the supplied BNB-first frames.
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

/// A failed button action, kept on the form until its input changes.
class FundingActionError {
  const FundingActionError(this.key, [this.details]);
  final String key;
  final ApiErrorDetails? details;
}
