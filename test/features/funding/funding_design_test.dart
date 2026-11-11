import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/application/transfer_history_provider.dart';
import 'package:vanta/features/funding/application/withdraw_info_provider.dart';
import 'package:vanta/features/funding/data/withdraw_info_mapper.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/domain/funding_fee.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/portfolio/application/rebalance_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_wallet.dart';
import '../../support/funding_info.dart';
import '../../support/funding_screen.dart';
import '../../support/rebalance.dart';

const _bnb = '521650000000000000';

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  await tester.tap(find.byKey(Key(key)).last);
  settle ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _amount(WidgetTester tester, FundingHarness h, String value) async {
  await tester.enterText(find.byKey(const Key('funding-amount')), value);
  FocusManager.instance.primaryFocus?.unfocus();
  await h.settleGas(tester);
}

void main() {
  for (final name in [
    'deposit-bnb',
    'deposit-network-open',
    'deposit-asset-open',
    'deposit-wallet',
    'deposit-processing',
    'deposit-usdt-approve',
    'deposit-approve-wallet',
    'deposit-empty',
    'deposit-gas',
    'withdraw-bnb',
    'withdraw-wallet',
    'withdraw-processing',
    'withdraw-failed',
    'withdraw-rebalance',
    'rebalance-confirm',
    'rebalance-processing',
  ]) {
    testWidgets('funding design screenshot $name', (tester) async {
      final inter = FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      await inter.load();
      final h = FundingHarness();
      h.wallet.result = depositSnapshot(
        query: depositQuery(native: true, minimum: '0.01'),
        nativeUnits: BigInt.parse(_bnb),
      );
      if (name.contains('usdt') || name.contains('approve')) {
        h.wallet.result = depositSnapshot(
          query: depositQuery(minimum: '0.01'),
          assetUnits: BigInt.parse('1620000000000000000000'),
          allowance: BigInt.zero,
          nativeUnits: BigInt.parse(_bnb),
        );
      }
      final payload = withdrawInfoPayload();
      payload['balances'] = {
        'BNB': {
          ...withdrawBalanceRow(),
          'currency': 'BNB',
          'chainBalances': {
            '56': {...withdrawChainRow(), 'perpMaxWithdrawAmount': '0.03035568'},
          },
        },
      };
      h.withdrawInfo.result = mapWithdrawInfo(
        payload,
        address: accountAddress,
        receivedAt: DateTime.now().toUtc(),
      );
      // The designed BNB platform fee, so amount + fee fits the withdrawable 0.0303.
      const bnbFee = FundingFeeQuery(market: TransferMarket.perp, chainId: 56, asset: 'BNB');
      h.fees.gates[bnbFee] = Completer()
        ..complete(
          FundingFeeQuote(
            query: bnbFee,
            receivedAt: DateTime.now().toUtc(),
            assetFee: Decimal.parse('0.00014'),
            usdFee: Decimal.parse('0.1'),
          ),
        );
      h.withdrawals.fee = Decimal.parse('0.00014');
      final withdraw = name.startsWith('withdraw') || name.startsWith('rebalance');
      await h.open(
        tester,
        operation: withdraw ? FundingOperation.withdraw : FundingOperation.deposit,
        topInset: 59,
      );
      if (withdraw) {
        await h.container.read(withdrawInfoProvider.notifier).refresh();
        if (name.contains('rebalance')) {
          h.rebalance.context = rebalanceContext(usdt: '-25');
          await h.container.read(rebalanceProvider.notifier).load();
        }
        await tester.pumpAndSettle();
        await _amount(tester, h, '0.02');
      } else if (name == 'deposit-gas') {
        h.gas.failure = const AccountReadFailure('depositGasBalanceInsufficient');
        await _tap(tester, 'funding-max');
        await h.settleGas(tester);
      } else if (name != 'deposit-empty') {
        if (name.contains('usdt') || name.contains('approve')) {
          await _tap(tester, 'funding-asset-selector');
          await _tap(tester, 'funding-option-USDT');
        }
        await _amount(tester, h, name.contains('usdt') || name.contains('approve') ? '10' : '0.1');
      }
      switch (name) {
        case 'deposit-network-open':
          await _tap(tester, 'funding-network');
        case 'deposit-asset-open':
          await _tap(tester, 'funding-asset-selector');
        case 'deposit-wallet' || 'deposit-approve-wallet':
          await _tap(tester, 'funding-deposit-submit');
        case 'deposit-processing':
          await _tap(tester, 'funding-deposit-submit');
          await _tap(tester, 'funding-open-wallet');
        case 'withdraw-wallet':
          await _tap(tester, 'funding-withdraw-submit');
        case 'withdraw-processing' || 'withdraw-failed':
          await _tap(tester, 'funding-withdraw-submit');
          await _tap(tester, 'funding-open-wallet');
          if (name == 'withdraw-failed') {
            h.history
              ..now = DateTime.now().toUtc()
              ..records = [
                TransferRecord(
                  id: 'W-20261103-0841',
                  market: TransferMarket.perp,
                  type: TransferType.withdraw,
                  status: TransferStatus.failed,
                  asset: 'BNB',
                  amount: Decimal.parse('0.02'),
                  recordTime: DateTime.now().toUtc(),
                  chainId: 56,
                ),
              ];
            await h.container.read(transferHistoryProvider.notifier).refresh();
            await tester.pumpAndSettle();
          }
        case 'rebalance-confirm':
          await _tap(tester, 'funding-rebalance');
        case 'rebalance-processing':
          h.rebalance.signGate = Completer<void>();
          await _tap(tester, 'funding-rebalance');
          await _tap(tester, 'funding-rebalance-confirm', settle: false);
      }
      await h.settleIcons(tester);
      await expectLater(
        find.byKey(fundingCaptureKey),
        matchesGoldenFile('goldens/funding-$name.png'),
      );
      expect(tester.takeException(), isNull);
      h.rebalance.signGate?.complete();
      await h.close(tester);
    });
  }
}
