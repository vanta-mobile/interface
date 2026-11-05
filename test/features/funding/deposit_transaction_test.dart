import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/domain/deposit_transaction.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_wallet.dart';

void main() {
  const vaults = {
    1: '0x604DD02d620633Ae427888d41bfd15e38483736E',
    56: '0x128463A60784c4D3f46c23Af3f65Ed859Ba87974',
    42161: '0x9E36CB86a159d479cEd94Fa05036f235Ac40E1d5',
  };
  final units = BigInt.parse('1230000000000000001');
  for (final chain in vaults.keys) {
    for (final market in TransferMarket.values) {
      for (final native in [false, true]) {
        test('exact depositFor ABI vector chain=$chain market=$market native=$native', () {
          final query = depositQuery(native: native, chain: chain, market: market);
          final tx = nextDepositTransaction(depositSnapshot(query: query), units);
          expect(tx.kind, DepositTransactionKind.deposit);
          expect(tx.from, accountAddress);
          expect(tx.to, vaults[chain]);
          expect(tx.value, native ? units : BigInt.zero);
          expect(tx.amountUnits, units);
          const token = '0000000000000000000000005555555555555555555555555555555555555555';
          const placeholder = '000000000000000000000000fdae1ba7c826abdc4c99903c8056f82a1a04a615';
          expect(
            tx.data,
            '0xcf4a0c5e${native ? placeholder : token}'
            '${accountAddress.substring(2).padLeft(64, '0')}'
            '0000000000000000000000000000000000000000000000001111d67bb1bb0001'
            '${market == TransferMarket.spot ? '0' * 61 + '3e8' : '0' * 64}',
          );
          expect(tx.call, {
            'from': accountAddress,
            'to': vaults[chain],
            'data': tx.data,
            'value': native ? '0x1111d67bb1bb0001' : '0x0',
          });
          expect(() => tx.call['value'] = '0x0', throwsUnsupportedError);
        });
      }
    }
  }
  for (final chain in vaults.keys) {
    test('zero allowance approves exact amount on $chain, nonzero resets first', () {
      final query = depositQuery(chain: chain);
      for (final allowance in [BigInt.zero, BigInt.one]) {
        final tx = nextDepositTransaction(
          depositSnapshot(query: query, allowance: allowance),
          units,
        );
        expect(
          tx.kind,
          allowance == BigInt.zero
              ? DepositTransactionKind.approve
              : DepositTransactionKind.resetApproval,
        );
        expect(tx.to, query.asset.tokenAddress);
        expect(tx.value, BigInt.zero);
        expect(
          tx.data,
          '0x095ea7b3${vaults[chain]!.substring(2).toLowerCase().padLeft(64, '0')}'
          '${allowance == BigInt.zero ? '0' * 47 + '01111d67bb1bb0001' : '0' * 64}',
        );
        expect(tx.data.contains('f' * 64), false);
      }
      final tx = nextDepositTransaction(depositSnapshot(query: query, allowance: units), units);
      expect(tx.kind, DepositTransactionKind.deposit);
    });
  }
  test('uint256 maximum and smallest-unit amounts retain exact precision', () {
    final max = (BigInt.one << 256) - BigInt.one;
    final query = depositQuery(decimals: 6);
    final wallet = depositSnapshot(query: query, assetUnits: max, allowance: max);
    final tx = nextDepositTransaction(wallet, max);
    expect(tx.data.substring(138, 202), 'f' * 64);
    expect(nextDepositTransaction(wallet, BigInt.one).amountUnits, BigInt.one);
  });
  for (final query in [
    depositQuery(chain: 999),
    depositQuery(route: 'special'),
    depositQuery(decimals: -1),
    depositQuery(decimals: 256),
    depositQuery(native: true, decimals: 6),
    depositQuery(tokenAddress: '0x${'0' * 40}'),
    depositQuery(tokenAddress: 'invalid'),
    depositQuery(native: true, tokenAddress: '0x${'5' * 40}'),
    depositQuery(tokenAddress: '0xfdae1ba7c826abdc4c99903c8056f82a1a04a615'),
  ]) {
    test(
      'reject unsupported/malformed metadata ${query.asset.chainId}/${query.asset.routeType}/${query.asset.decimals}/${query.asset.tokenAddress}/${query.asset.isNative}',
      () {
        expect(
          () => nextDepositTransaction(depositSnapshot(query: query), units),
          throwsA(isA<AccountReadFailure>()),
        );
      },
    );
  }
  test('invalid amount, owner, allowance and insufficient balance never encode', () {
    final query = depositQuery();
    final wallet = depositSnapshot(query: query);
    for (final units in [
      BigInt.zero,
      -BigInt.one,
      BigInt.one << 256,
      wallet.assetUnits + BigInt.one,
    ]) {
      expect(() => nextDepositTransaction(wallet, units), throwsA(isA<AccountReadFailure>()));
    }
    for (final address in ['invalid', '0x${'0' * 40}']) {
      expect(
        () => nextDepositTransaction(depositSnapshot(query: query, address: address), units),
        throwsA(isA<AccountReadFailure>()),
      );
    }
    for (final allowance in [-BigInt.one, BigInt.one << 256]) {
      expect(
        () => nextDepositTransaction(depositSnapshot(query: query, allowance: allowance), units),
        throwsA(isA<AccountReadFailure>()),
      );
    }
  });
}
