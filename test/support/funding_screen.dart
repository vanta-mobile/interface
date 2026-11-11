import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/funding/application/deposit_approval_provider.dart';
import 'package:vanta/features/funding/application/deposit_gas_provider.dart';
import 'package:vanta/features/funding/application/deposit_submission_provider.dart';
import 'package:vanta/features/funding/application/deposit_wallet_provider.dart';
import 'package:vanta/features/funding/application/funding_catalog_provider.dart';
import 'package:vanta/features/funding/application/funding_fee_provider.dart';
import 'package:vanta/features/funding/application/funding_flow_provider.dart';
import 'package:vanta/features/funding/application/transfer_history_provider.dart';
import 'package:vanta/features/funding/application/withdraw_info_provider.dart';
import 'package:vanta/features/funding/application/withdrawal_provider.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/domain/funding_fee.dart';
import 'package:vanta/features/funding/domain/withdrawal.dart';
import 'package:vanta/features/funding/presentation/funding_screen.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/portfolio/application/rebalance_provider.dart';
import 'package:vanta/features/portfolio/application/asset_metadata_provider.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import 'aster_account.dart';
import 'deposit_approval.dart';
import 'deposit_gas.dart';
import 'deposit_submission.dart';
import 'deposit_wallet.dart';
import 'funding_fee.dart';
import 'funding_info.dart';
import 'funding_icons.dart';
import 'notifications.dart';
import 'rebalance.dart';
import 'trading_agents.dart';
import 'transfers.dart';

class FundingIdentity extends ApprovalIdentityRepository {
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

class TestWithdrawalRepository implements WithdrawalRepository {
  final prepared = <(DepositWalletQuery, String)>[];
  int submits = 0;
  Completer<void>? gate;
  Object? failure;
  Decimal fee = fundingFeeFixture(fundingFeeQuery).assetFee;
  @override
  Future<WithdrawalReview> prepare({
    required AuthIdentity identity,
    required DepositWalletQuery query,
    required String amount,
    required bool Function() isCurrent,
  }) async {
    prepared.add((query, amount));
    final quote = fundingFeeFixture(fundingFeeQuery);
    return WithdrawalReview(
      identity: identity,
      query: query,
      amount: Decimal.parse(amount),
      fee: feeQuoteWith(quote, fee),
      info: withdrawInfoFixture(),
      preparedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<WalletOperationRecord> submit(
    WithdrawalReview review, {
    required bool Function() isCurrent,
  }) async {
    submits++;
    await gate?.future;
    if (failure case final error?) throw error;
    return WalletOperationRecord(
      kind: WalletOperationKind.withdrawal,
      address: accountAddress,
      nonce: 1,
      preparedAt: review.preparedAt,
      acknowledged: true,
      reference: 'W-20261103-0841',
      terms: {
        'chain': '${review.query.asset.chainId}',
        'market': review.query.market.name,
        'asset': review.query.asset.asset,
        'amount': review.amount.toString(),
        'fee': review.fee.assetFee.toString(),
        'receiver': accountAddress,
      },
    );
  }
}

/// Copies a fixture quote with another platform fee.
FundingFeeQuote feeQuoteWith(FundingFeeQuote quote, Decimal fee) => FundingFeeQuote(
  query: quote.query,
  receivedAt: quote.receivedAt,
  assetFee: fee,
  usdFee: quote.usdFee,
  assetPriceUsd: quote.assetPriceUsd,
);

const fundingCaptureKey = Key('funding-design-render');

/// Funding screen with every repository replaced; nothing reaches a network.
class FundingHarness {
  FundingHarness() {
    catalog.rows = [
      fundingAssetRow()..['minDeposit'] = '0.01',
      fundingAssetRow(asset: 'BNB', native: true)..['minDeposit'] = '0.01',
      fundingAssetRow(asset: 'ETH', chain: 1, native: true)..['minDeposit'] = '0.01',
    ];
    identity.restored = signingIdentity;
  }
  final identity = FundingIdentity();
  final catalog = TestFundingCatalogRepository();
  final icons = FundingIconFixture();
  final wallet = TestDepositWalletRepository();
  final gas = TestDepositGasRepository();
  final approvalReceipts = TestApprovalReceiptRepository();
  final depositReceipts = TestDepositReceiptRepository();
  final fees = TestFundingFeeRepository();
  final withdrawInfo = TestWithdrawInfoRepository();
  final withdrawals = TestWithdrawalRepository();
  final rebalance = TestRebalanceRepository();
  final history = TestTransferHistoryRepository()..records = [];
  final inbox = LocalNotificationRepository(MemoryNotificationStorage());
  late final ProviderContainer container;

  Future<void> open(
    WidgetTester tester, {
    FundingOperation operation = FundingOperation.deposit,
    Size size = const Size(393, 852),
    Locale locale = const Locale('en'),
    double textScale = 1,
    double topInset = 0,
    bool deviceGrant = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: topInset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        tradingAgentStoreProvider.overrideWithValue(
          MemoryTradingAgentStorage().store(DateTime.now),
        ),
        fundingCatalogRepositoryProvider.overrideWithValue(catalog),
        assetMetadataServiceProvider.overrideWith((ref) {
          final service = icons.service();
          ref.onDispose(service.close);
          return service;
        }),
        depositWalletRepositoryProvider.overrideWithValue(wallet),
        depositGasRepositoryProvider.overrideWithValue(gas),
        depositApprovalReceiptRepositoryProvider.overrideWithValue(approvalReceipts),
        depositSubmissionReceiptRepositoryProvider.overrideWithValue(depositReceipts),
        fundingFeeRepositoryProvider.overrideWithValue(fees),
        withdrawInfoRepositoryProvider.overrideWithValue(withdrawInfo),
        withdrawalRepositoryProvider.overrideWithValue(withdrawals),
        rebalanceRepositoryProvider.overrideWithValue(rebalance),
        transferHistoryRepositoryProvider.overrideWithValue(history),
        notificationRepositoryProvider.overrideWithValue(inbox),
        if (deviceGrant) fundingSilentReadsProvider.overrideWith((_) => true),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(identity.dispose);
    addTearDown(inbox.dispose);
    container.read(authProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: fundingCaptureKey,
          child: MaterialApp(
            theme: vantaTheme(),
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const Key('open-funding'),
                    onPressed: () => openFunding(context, operation),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Raster asset icons decode asynchronously; load USDT before rendering.
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/portfolio/usdt.webp'),
        tester.element(find.byKey(const Key('open-funding'))),
      ),
    );
    await tester.tap(find.byKey(const Key('open-funding')));
    await tester.pumpAndSettle();
    await settleIcons(tester);
  }

  /// Wait for native image codecs, which run outside the widget fake clock.
  Future<void> settleIcons(WidgetTester tester) async {
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      await Future.wait([for (final image in images) precacheImage(image.image, context)]);
    });
    await tester.pump();
  }

  /// Disposes the providers so their snapshot expiry timers end with the test.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  /// Lets the debounced public gas estimate run.
  Future<void> settleGas(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }
}
