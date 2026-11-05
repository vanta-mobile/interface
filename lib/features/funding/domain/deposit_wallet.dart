import 'package:decimal/decimal.dart';

import '../../portfolio/domain/account_snapshot.dart';
import 'funding_catalog.dart';
import 'transfer_history.dart';

class DepositWalletQuery {
  const DepositWalletQuery({
    required this.market,
    required this.asset,
    this.verifiedMinimumDeposit,
  });

  /// User-entered minimum verified on Aster when the public catalog omits it.
  final Decimal? verifiedMinimumDeposit;
  bool sameAsset(DepositWalletQuery other) =>
      market == other.market &&
      asset.asset == other.asset.asset &&
      asset.chainId == other.asset.chainId &&
      asset.tokenAddress.toLowerCase() == other.asset.tokenAddress.toLowerCase() &&
      asset.decimals == other.asset.decimals &&
      asset.isNative == other.asset.isNative &&
      asset.routeType == other.asset.routeType &&
      asset.minimumDeposit == other.asset.minimumDeposit;
  final TransferMarket market;
  final FundingAsset asset;
  Object get _key => (
    market,
    asset.asset,
    asset.chainId,
    asset.tokenAddress.toLowerCase(),
    asset.decimals,
    asset.isNative,
    asset.routeType,
    asset.minimumDeposit,
    verifiedMinimumDeposit,
  );
  @override
  bool operator ==(Object other) => other is DepositWalletQuery && other._key == _key;
  @override
  int get hashCode => _key.hashCode;
}

/// Documented vaults are allowance spenders here, never a manual pay address.
const depositVaults = {
  1: '0x604DD02d620633Ae427888d41bfd15e38483736E',
  56: '0x128463A60784c4D3f46c23Af3f65Ed859Ba87974',
  42161: '0x9E36CB86a159d479cEd94Fa05036f235Ac40E1d5',
};

Decimal depositQuantity(BigInt units, int decimals) => Decimal.parse('${units}e-$decimals');

class DepositWalletSnapshot implements WalletAccountSnapshot {
  const DepositWalletSnapshot({
    required this.address,
    required this.receivedAt,
    required this.query,
    required this.assetUnits,
    required this.nativeUnits,
    required this.allowanceUnits,
    required this.blockNumber,
    required this.blockHash,
    required this.blockTime,
  });
  @override
  final String address;
  @override
  final DateTime receivedAt;
  final DepositWalletQuery query;
  final BigInt assetUnits, nativeUnits, blockNumber;
  final BigInt? allowanceUnits;
  final String blockHash;
  final DateTime blockTime;
  Decimal get assetBalance => depositQuantity(assetUnits, query.asset.decimals);
  Decimal get nativeBalance => depositQuantity(nativeUnits, 18);
  Decimal? get allowance =>
      allowanceUnits == null ? null : depositQuantity(allowanceUnits!, query.asset.decimals);
}

abstract interface class DepositWalletRepository {
  Future<DepositWalletSnapshot> read({
    required String address,
    required DepositWalletQuery query,
    required bool Function() isCurrent,
  });
}

class DepositAmountCheck {
  const DepositAmountCheck({this.units, this.errorKey, this.allowanceSufficient});
  final BigInt? units;
  final String? errorKey;
  final bool? allowanceSufficient;
}

DepositAmountCheck checkDepositAmount({
  required String input,
  required DepositWalletQuery query,
  required DepositWalletSnapshot? snapshot,
  required bool stale,
}) {
  final text = input.trim(), asset = query.asset;
  DepositAmountCheck fail(String key) => DepositAmountCheck(errorKey: key);
  if (text.isEmpty) return const DepositAmountCheck();
  if (asset.decimals < 0 || asset.decimals > 255) return fail('depositAmountPrecision');
  if (text.length > 160 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) {
    return fail('depositAmountInvalid');
  }
  if (text.split('.').last.length > asset.decimals && text.contains('.')) {
    return fail('depositAmountPrecision');
  }
  final amount = Decimal.parse(text);
  if (amount <= Decimal.zero) return fail('depositAmountInvalid');
  final units = (amount * Decimal.parse('1e${asset.decimals}')).toBigInt();
  if (units >= BigInt.one << 256) return fail('depositAmountInvalid');
  final minimum = asset.minimumDeposit ?? query.verifiedMinimumDeposit;
  if (minimum == null || minimum < Decimal.zero) return fail('depositMinimumUnknown');
  if (amount < minimum) return fail('depositBelowMinimum');
  if (snapshot == null || !snapshot.query.sameAsset(query)) return fail('depositReadRequired');
  if (stale) return fail('depositReadStale');
  if (units > snapshot.assetUnits) return fail('depositBalanceInsufficient');
  return DepositAmountCheck(
    units: units,
    allowanceSufficient: asset.isNative
        ? null
        : snapshot.allowanceUnits != null && snapshot.allowanceUnits! >= units,
  );
}
