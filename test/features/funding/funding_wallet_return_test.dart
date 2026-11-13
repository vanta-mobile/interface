import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/data/wallet_configuration.dart';
import 'package:vanta/features/auth/data/wallet_redirect_handler.dart';
import 'package:vanta/features/auth/domain/wallet_connection.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';
import 'package:vanta/features/funding/application/deposit_submission_provider.dart';
import 'package:vanta/features/funding/presentation/funding_status_screens.dart';
import 'package:vanta/features/funding/presentation/funding_wallet_screens.dart';

import '../../support/funding_screen.dart';
import '../../support/deposit_gas.dart';
import '../../support/deposit_wallet.dart';
import '../../support/reown_modal.dart';

Future<void> _depositReview(WidgetTester tester, FundingHarness h) async {
  await h.open(tester);
  await tester.enterText(find.byKey(const Key('funding-amount')), '0.1');
  await h.settleGas(tester);
  await tester.tap(find.byKey(const Key('funding-deposit-submit')));
  await tester.pumpAndSettle();
  expect(find.byType(DepositConfirmScreen), findsOneWidget);
}

void main() {
  for (final beforeResume in [true, false]) {
    testWidgets(
      'deposit hash returned ${beforeResume ? 'before' : 'after'} app resume opens processing',
      (tester) async {
        final h = FundingHarness();
        await _depositReview(tester, h);
        final gate = Completer<void>();
        h.identity.transactionGate = gate;
        await tester.tap(find.byKey(const Key('funding-open-wallet')));
        await tester.pump();
        expect(h.identity.transactions, hasLength(1));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        if (beforeResume) gate.complete();
        await tester.pump(const Duration(seconds: 1));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        if (!beforeResume) gate.complete();
        await tester.pumpAndSettle();
        expect(h.container.read(pendingDepositSubmissionsProvider).single.hash, isNotNull);
        expect(find.byType(DepositConfirmScreen), findsNothing);
        expect(find.byType(DepositProcessingScreen), findsOneWidget);
        expect(h.identity.transactions, hasLength(1));
        expect(tester.takeException(), isNull);
        await h.close(tester);
      },
    );
  }

  for (final asset in ['BNB', 'USDT']) {
    testWidgets('$asset native wallet response resolves spinner and opens processing once', (
      tester,
    ) async {
      final native = _NativeWallet();
      final h = FundingHarness(identity: native.identity);
      await h.open(tester);
      await native.restore(tester);
      if (asset == 'USDT') {
        await _selectApprovedUsdt(tester, h);
      }
      await _reviewOpenPage(tester, h);
      await tester.tap(find.byKey(const Key('funding-open-wallet')));
      await tester.pump();
      expect(native.modal.requests, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      _background(tester);
      // A bare return/lifecycle change proves nothing about the transaction.
      native.links.add(Uri.parse('vantaapp://wallet'));
      _resume(tester);
      await tester.pump();
      expect(find.byType(DepositConfirmScreen), findsOneWidget);
      expect(h.container.read(pendingDepositSubmissionsProvider).single.hash, isNull);
      native.links.add(native.response);
      await tester.pumpAndSettle();
      final record = h.container.read(pendingDepositSubmissionsProvider).single;
      expect(record.hash, native.modal.hash);
      expect(record.query.asset.asset, asset);
      expect(find.byType(DepositConfirmScreen), findsNothing);
      expect(find.byType(DepositProcessingScreen), findsOneWidget);
      native.links.add(native.response);
      await tester.pumpAndSettle();
      expect(native.modal.envelopes, [native.response.toString()]);
      expect(native.modal.requests, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.runAsync(native.close);
      await h.close(tester);
    });
  }

  testWidgets('late wallet response after leaving confirmation retains hash without navigation', (
    tester,
  ) async {
    final native = _NativeWallet();
    final h = FundingHarness(identity: native.identity);
    await _depositReview(tester, h);
    await native.restore(tester);
    await tester.tap(find.byKey(const Key('funding-open-wallet')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('funding-wallet-cancel')));
    await tester.pumpAndSettle();
    native.links.add(native.response);
    await tester.pumpAndSettle();
    expect(h.container.read(pendingDepositSubmissionsProvider).single.hash, native.modal.hash);
    expect(find.byType(DepositProcessingScreen), findsNothing);
    expect(find.byType(DepositConfirmScreen), findsNothing);
    expect(find.byKey(const Key('funding-amount')), findsOneWidget);
    expect(native.modal.requests, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.runAsync(native.close);
    await h.close(tester);
  });

  testWidgets('wallet response without a valid hash does not open processing or retry send', (
    tester,
  ) async {
    final native = _NativeWallet();
    native.modal.walletResult = null;
    final h = FundingHarness(identity: native.identity);
    await _depositReview(tester, h);
    await native.restore(tester);
    await tester.tap(find.byKey(const Key('funding-open-wallet')));
    await tester.pump();
    native.links.add(native.response);
    await tester.pumpAndSettle();
    expect(h.container.read(pendingDepositSubmissionsProvider).single.hash, isNull);
    expect(find.byType(DepositProcessingScreen), findsNothing);
    expect(find.byType(DepositConfirmScreen), findsNothing);
    expect(find.byKey(const Key('funding-error')), findsOneWidget);
    expect(native.modal.requests, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.runAsync(native.close);
    await h.close(tester);
  });
}

Future<void> _reviewOpenPage(WidgetTester tester, FundingHarness h) async {
  await tester.enterText(find.byKey(const Key('funding-amount')), '0.1');
  await h.settleGas(tester);
  await tester.tap(find.byKey(const Key('funding-deposit-submit')));
  await tester.pumpAndSettle();
  expect(find.byType(DepositConfirmScreen), findsOneWidget);
}

Future<void> _selectApprovedUsdt(WidgetTester tester, FundingHarness h) async {
  final query = depositQuery(minimum: '0.01');
  final wallet = depositSnapshot(query: query, allowance: BigInt.parse('9' * 30));
  h.wallet.result = wallet;
  h.gas.result = gasQuote(query: query, wallet: wallet, amount: '0.1');
  await tester.tap(find.byKey(const Key('funding-asset-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('funding-option-USDT')).last);
  await tester.pumpAndSettle();
}

void _background(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _resume(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

class _NativeIdentity extends FundingIdentity {
  late WalletConnection connection;
  @override
  Future<WalletTransactionResult> sendWalletTransaction({
    required EvmWalletTransaction transaction,
    required bool Function() isCurrent,
  }) => connection.sendTransaction(transaction: transaction, isCurrent: isCurrent);
}

/// The SDK fake resolves a request only when the native envelope is dispatched.
/// No transaction/hash response is injected into the controller or UI directly.
class _ReturnModal extends TestReownModal {
  final envelopes = <String>[];
  final pending = Completer<Object?>();
  final hash = '0x${'c' * 64}';
  Object? walletResult;
  _ReturnModal() {
    walletResult = hash;
    onRequest = (_) => pending.future;
  }
  @override
  ReownAppKitModalStatus status = ReownAppKitModalStatus.idle;
  @override
  Future<void> init() async => status = ReownAppKitModalStatus.initialized;
  @override
  Future<bool> dispatchEnvelope(String url) async {
    envelopes.add(url);
    pending.complete(walletResult);
    return true;
  }
}

class _NativeWallet {
  final identity = _NativeIdentity();
  final modal = _ReturnModal();
  final links = StreamController<Uri>(sync: true);
  final response = Uri.parse('vantaapp://wallet?topic=topic&wc_ev=encrypted-response');
  late final connector = ReownWalletConnector(
    const WalletConfiguration(projectId: 'test'),
    createModal: (_) => modal,
    redirects: WalletRedirectHandler(links: links.stream, initialLink: () async => null),
  );

  Future<void> restore(WidgetTester tester) async {
    identity.connection = (await connector.restore(
      tester.element(find.byType(Scaffold).last),
      expectedAddress: modal.address,
    ))!;
  }

  Future<void> close() async {
    await identity.connection.release();
    await connector.dispose();
    await links.close();
  }
}
