import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/funding/data/deposit_gas_reserve_repository.dart';
import 'package:vanta/features/funding/data/deposit_rpc_service.dart';
import 'package:vanta/features/funding/presentation/add_funds_sheet.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_wallet.dart';
import '../../support/funding_screen.dart';

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(const Key('funding-tab-deposit'))));
FilledButton _button(WidgetTester tester, String key) => tester.widget<FilledButton>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)),
);
final _wei = BigInt.parse('10000000000000000000');

Future<void> _selectUsdt(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('funding-asset-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('funding-option-USDT')).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty wallet asks to add funds; the sheet shows the address until funds arrive', (
    tester,
  ) async {
    final h = FundingHarness();
    var usdt = BigInt.zero;
    h.wallet.resultFor = (q) => depositSnapshot(
      query: q,
      assetUnits: q.asset.isNative ? null : usdt,
      nativeUnits: BigInt.zero,
    );
    await h.open(tester);
    final l = _l(tester);
    expect(find.text(l.fundingEoaWallet), findsOneWidget);
    await _selectUsdt(tester);
    expect(find.text('0 USDT'), findsOneWidget);
    expect(find.byKey(const Key('funding-max')), findsNothing);
    await tester.enterText(find.byKey(const Key('funding-amount')), '0.1');
    await h.settleGas(tester);
    expect(find.text(l.fundingAssetShort('USDT')), findsOneWidget);
    expect(find.byKey(const Key('funding-error')), findsNothing);
    expect(_button(tester, 'funding-deposit-submit').onPressed, isNull);

    await tester.tap(find.byKey(const Key('funding-deposit-alert-action')));
    await tester.pumpAndSettle();
    expect(find.byType(AddFundsSheet), findsOneWidget);
    expect(find.text(l.fundingAddFunds), findsOneWidget);
    expect(find.byKey(const Key('funding-deposit-qr')), findsOneWidget);
    expect(find.text(accountAddress), findsOneWidget);
    expect(find.text(l.fundingTokenAsset), findsOneWidget);
    expect(find.text(l.fundingGasReserveHint('0.003 BNB')), findsOneWidget);
    expect(h.gasReserveReads, contains(56));
    expect(_button(tester, 'funding-add-transferred').onPressed, isNotNull);

    // Funds arrive on the next poll.
    usdt = _wei;
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AddFundsSheet), matching: find.text('10 USDT')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('funding-add-transferred')));
    await h.settleGas(tester);
    expect(find.byType(AddFundsSheet), findsNothing);
    expect(find.text('0.1'), findsOneWidget, reason: 'same network and token keep the amount');
    expect(find.text(l.fundingAssetShort('USDT')), findsNothing);
    expect(find.byKey(const Key('funding-max')), findsOneWidget);
    expect(_button(tester, 'funding-deposit-submit').onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets('Add Gas opens on the gas token and the chosen network carries back to the form', (
    tester,
  ) async {
    final h = FundingHarness();
    await h.open(tester);
    final l = _l(tester);
    await _selectUsdt(tester);
    h.gas.failure = const AccountReadFailure('depositGasBalanceInsufficient');
    await tester.enterText(find.byKey(const Key('funding-amount')), '5');
    await h.settleGas(tester);
    expect(find.text(l.fundingGasShort), findsOneWidget);
    await tester.tap(find.byKey(const Key('funding-deposit-alert-action')));
    await tester.pumpAndSettle();
    expect(find.text(l.fundingGasToken), findsOneWidget);
    expect(find.byKey(const Key('funding-add-balance')), findsNothing);
    expect(find.byKey(const Key('funding-add-gas-hint')), findsNothing, reason: '10 BNB covers it');
    await tester.tap(find.byKey(const Key('funding-add-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AddFundsSheet), findsNothing);

    h.gas.failure = null;
    await tester.tap(find.byKey(const Key('funding-add')));
    await tester.pumpAndSettle();
    expect(find.text(l.fundingTokenAsset), findsOneWidget);
    await tester.tap(find.byKey(const Key('funding-add-gas')));
    await tester.pumpAndSettle();
    expect(find.text(l.fundingGasToken), findsOneWidget);
    await tester.tap(find.byKey(const Key('funding-add-network')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('funding-option-1')).last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AddFundsSheet), matching: find.text('ETH')),
      findsWidgets,
    );
    await tester.tap(find.byKey(const Key('funding-add-transferred')));
    await h.settleGas(tester);
    expect(find.byType(AddFundsSheet), findsNothing);
    expect(find.text(l.fundingNetworkEthereum), findsOneWidget);
    expect(find.text('5'), findsNothing, reason: 'another network clears the amount');
    expect(h.identity.transactions, isEmpty);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets('the refresh icon spins until its balance read settles', (tester) async {
    final h = FundingHarness();
    await h.open(tester);
    await _selectUsdt(tester);
    await tester.tap(find.byKey(const Key('funding-add')));
    await tester.pumpAndSettle();
    Animation<double> turns() => tester
        .widget<RotationTransition>(
          find.descendant(
            of: find.byKey(const Key('funding-add-refresh')),
            matching: find.byType(RotationTransition),
          ),
        )
        .turns;
    expect(turns().status, AnimationStatus.dismissed);
    final reads = h.wallet.calls.length, gate = Completer<void>();
    h.wallet.gate = gate;
    await tester.tap(find.byKey(const Key('funding-add-refresh')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.wallet.calls.length, reads + 1);
    expect(turns().value, greaterThan(0));
    expect((turns() as AnimationController).isAnimating, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect((turns() as AnimationController).isAnimating, isTrue, reason: 'read still pending');
    gate.complete();
    h.wallet.gate = null;
    await tester.pumpAndSettle();
    expect((turns() as AnimationController).isAnimating, isFalse);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  group('gas reserve', () {
    test('rounds wei up to two significant digits', () {
      expect(depositReserveRoundUp(BigInt.from(99)), BigInt.from(99));
      expect(depositReserveRoundUp(BigInt.from(250000000000000)), BigInt.from(250000000000000));
      expect(depositReserveRoundUp(BigInt.from(308641750000)), BigInt.from(310000000000));
    });

    Future<Object> read(Object? price) async {
      final service = DepositRpcService(
        client: MockClient((request) async {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['method'], 'eth_gasPrice');
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': payload['id'], 'result': price}),
            200,
          );
        }),
      );
      addTearDown(service.close);
      try {
        return await RpcDepositGasReserveRepository(service).reserve(56, isCurrent: () => true);
      } on AccountReadFailure catch (error) {
        return error.key;
      }
    }

    test('is the gas budget at the current gas price', () async {
      expect(await read('0x3b9aca00'), Decimal.parse('0.00025'));
    });

    test('a zero or malformed price is invalid', () async {
      expect(await read('0x0'), 'depositRpcInvalid');
      expect(await read('1000'), 'depositRpcInvalid');
    });
  });
}
