import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/application/funding_fee_provider.dart';
import 'package:vanta/features/funding/domain/funding_fee.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/funding/presentation/funding_fee_screen.dart';
import 'package:vanta/features/funding/presentation/funding_info_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/funding_fee.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

class ReadOnlyIdentity extends TestIdentityRepository {
  int signatures = 0;
  @override
  Future<String> signWalletRequest({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) async {
    signatures++;
    throw const AuthFailure('authWalletRejected');
  }
}

Future<void> reveal(WidgetTester tester, Finder target, String scrollKey) async {
  final scroll = find
      .descendant(of: find.byKey(Key(scrollKey)), matching: find.byType(Scrollable))
      .first;
  for (var attempt = 0; attempt < 3; attempt++) {
    await tester.scrollUntilVisible(target, 150, scrollable: scroll);
    await tester.pumpAndSettle();
    if (target.evaluate().isEmpty) continue;
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle();
    if (target.evaluate().isNotEmpty) return;
  }
  fail('Target disappeared after scroll correction: $target');
}

void main() {
  for (final spec in [(320.0, 844.0, 'en'), (320.0, 844.0, 'zh'), (844.0, 390.0, 'en')]) {
    testWidgets('fee units, precise values, stale/failure/retry fit $spec without wallet signing', (
      tester,
    ) async {
      final identity = ReadOnlyIdentity(), repository = TestFundingFeeRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        width: spec.$1,
        scale: 1.5,
        language: Locale(spec.$3),
        identityRepository: identity,
        fundingFeeRepository: repository,
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      await launch(tester, container);
      Navigator.of(tester.element(find.byKey(const Key('account-button')))).push<void>(
        MaterialPageRoute(builder: (_) => const FundingFeeScreen(query: fundingFeeQuery)),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(FundingFeeScreen)));
      expect(repository.calls, [fundingFeeQuery]);
      await reveal(tester, find.text(l10n.fundingFeeAsset), 'funding-fee-scroll');
      expect(find.text('0.123456789012345678901234567890123456789 USDT'), findsOneWidget);
      expect(find.text('0.100000000000000001 USD'), findsOneWidget);
      expect(find.text('1.1235782 USD'), findsOneWidget);
      expect(find.text(l10n.fundingFeeScope), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(container.read(fundingFeeProvider(fundingFeeQuery)).stale, true);
      final refresh = find.byKey(const Key('funding-fee-refresh'));
      repository.failure = const FormatException();
      await reveal(tester, refresh, 'funding-fee-scroll');
      await tester.tap(refresh.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text(l10n.fundingFeeFailed), findsOneWidget);
      expect(find.text('0.100000000000000001 USD'), findsOneWidget);
      expect(find.byKey(const Key('funding-fee-stale')), findsOneWidget);
      repository.failure = null;
      await reveal(tester, refresh, 'funding-fee-scroll');
      await tester.tap(refresh.hitTestable());
      await tester.pumpAndSettle();
      expect(container.read(fundingFeeProvider(fundingFeeQuery)).stale, false);
      expect(find.text(l10n.fundingFeeFailed), findsNothing);
      expect(identity.wallets, 0);
      expect(identity.signatures, 0);
      expect(find.byKey(const Key('login-email')), findsNothing);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
  for (final market in TransferMarket.values) {
    testWidgets('withdraw asset entry opens exact $market/network/asset public fee scope', (
      tester,
    ) async {
      final identity = ReadOnlyIdentity(), repository = TestFundingFeeRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        fundingFeeRepository: repository,
      );
      await launch(tester, container);
      openFundingInfo(tester.element(find.byKey(const Key('account-button'))), market);
      await tester.pumpAndSettle();
      expect(repository.calls, isEmpty);
      expect(find.byType(FundingFeeEntry), findsNothing); // Deposit has no withdrawal fee requests.
      final withdraw = find.byKey(const Key('funding-operation-withdraw'));
      await reveal(tester, withdraw, 'funding-info-scroll');
      await tester.tap(withdraw.hitTestable());
      await tester.pumpAndSettle();
      final entry = find.byKey(const Key('funding-fee-entry-56-USDT'));
      await reveal(tester, entry, 'funding-info-scroll');
      expect(repository.calls, isEmpty); // Do not fetch all displayed asset fees.
      await tester.tap(entry.hitTestable());
      await tester.pumpAndSettle();
      expect(repository.calls, [FundingFeeQuery(market: market, chainId: 56, asset: 'USDT')]);
      expect(find.byType(FundingFeeScreen), findsOneWidget);
      expect(identity.wallets, 0);
      expect(identity.signatures, 0);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
  testWidgets('initial failure shows unknown fee and retry, no fabricated zero quote', (
    tester,
  ) async {
    final repository = TestFundingFeeRepository()..failure = const FormatException();
    final container = setup(tester, fundingFeeRepository: repository);
    await launch(tester, container);
    Navigator.of(
      tester.element(find.byKey(const Key('account-button'))),
    ).push<void>(MaterialPageRoute(builder: (_) => const FundingFeeScreen(query: fundingFeeQuery)));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(FundingFeeScreen)));
    expect(find.text(l10n.fundingFeeFailed), findsOneWidget);
    expect(find.text('0 USDT'), findsNothing);
    expect(find.byKey(const Key('funding-fee-time')), findsNothing);
    repository.failure = null;
    final refresh = find.byKey(const Key('funding-fee-refresh'));
    await reveal(tester, refresh, 'funding-fee-scroll');
    await tester.tap(refresh.hitTestable());
    await tester.pumpAndSettle();
    expect(container.read(fundingFeeProvider(fundingFeeQuery)).quote, isNotNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets('leaving a pending fee read releases its scope and ignores late results', (
    tester,
  ) async {
    final repository = TestFundingFeeRepository()..gates[fundingFeeQuery] = Completer();
    final container = setup(tester, fundingFeeRepository: repository);
    await launch(tester, container);
    Navigator.of(
      tester.element(find.byKey(const Key('account-button'))),
    ).push<void>(MaterialPageRoute(builder: (_) => const FundingFeeScreen(query: fundingFeeQuery)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.calls, [fundingFeeQuery]);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('funding-fee-refresh'))).onPressed,
      null,
    );
    Navigator.of(tester.element(find.byType(FundingFeeScreen))).pop();
    await tester.pumpAndSettle();
    repository.gates[fundingFeeQuery]!.complete(fundingFeeFixture(fundingFeeQuery));
    await tester.pumpAndSettle();
    expect(container.exists(fundingFeeProvider(fundingFeeQuery)), false);
    expect(find.byType(FundingFeeScreen), findsNothing);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
