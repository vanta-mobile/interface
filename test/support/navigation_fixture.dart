import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/market/domain/market.dart';
import 'package:vanta/features/trade/presentation/widgets/primitives.dart';

import 'aster_account.dart';
import 'aster_open_orders.dart';
import 'aster_spot_account.dart';
import 'futures_asset_mode.dart';
import 'futures_position_mode.dart';
import 'identity_repository.dart';
import 'live_order.dart';
import 'points.dart';
import 'position_leverage.dart';
import 'position_margin_mode.dart';
import 'position_risk.dart';
import 'quick_order.dart';
import 'trade_fixture.dart';

class NavigationIdentity extends TestIdentityRepository {
  int signatures = 0;
  @override
  Future<String> signWalletRequest({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) async {
    signatures++;
    throw const AuthFailure('authWalletReconnect');
  }
}

class NavigationFixture {
  NavigationFixture(
    WidgetTester tester, {
    String language = 'en',
    bool signedIn = true,
    double width = 390,
    double scale = 1,
    Future<List<AsterInstrument>> Function()? instrumentsLoader,
    Stream<OrderBook> Function(String)? booksForSymbol,
    Stream<Market>? marketStream,
  }) {
    identity.restored = signedIn ? signingIdentity : null;
    addTearDown(identity.dispose);
    container = setup(
      tester,
      language: Locale(language),
      width: width,
      scale: scale,
      identityRepository: identity,
      liveOrderRepository: orders,
      quickOrderRepository: sizing,
      orderConfirmationPreferences: preferences,
      asterAccountRepository: account,
      asterSpotRepository: spot,
      openOrdersRepository: openOrders,
      positionRiskRepository: positions,
      positionLeverageRepository: leverage,
      positionMarginModeRepository: margin,
      futuresPositionModeRepository: positionMode,
      futuresAssetModeRepository: assetMode,
      pointsRepository: points,
      instrumentsLoader: instrumentsLoader,
      booksForSymbol: booksForSymbol,
      marketStream: marketStream,
      liveClock: () => liveOrderClock,
    );
  }
  final identity = NavigationIdentity();
  final orders = TestLiveOrderRepository();
  final sizing = TestQuickOrderRepository();
  final preferences = MemoryOrderConfirmationPreferences();
  final account = TestAsterAccountRepository();
  final spot = TestSpotRepository();
  final openOrders = TestOpenOrdersRepository();
  final positions = TestPositionRiskRepository();
  final leverage = TestPositionLeverageRepository();
  final margin = TestPositionMarginModeRepository();
  final positionMode = TestFuturesPositionModeRepository();
  final assetMode = TestFuturesAssetModeRepository();
  final points = TestPointsRepository();
  late final ProviderContainer container;

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  }

  void expectNoAccountMutation({int contextReads = 0, int sizingReads = 0}) {
    expect(orders.reads, contextReads);
    expect(sizing.reads, sizingReads);
    expect(orders.submits, 0);
    expect(orders.checks, 0);
    expect(account.calls, 0);
    expect(spot.calls, 0);
    expect(openOrders.calls, 0);
    expect(positions.calls, 0);
    for (final counts in [
      [leverage.reads, leverage.changes, leverage.checks],
      [margin.reads, margin.changes, margin.checks],
      [positionMode.reads, positionMode.changes, positionMode.checks],
      [assetMode.reads, assetMode.changes, assetMode.checks],
    ]) {
      expect(counts, [0, 0, 0]);
    }
    expect(identity.signatures, 0);
    expect(identity.wallets, 0);
    expect(identity.externalLogins, 0);
    expect(preferences.writes, 0);
    expect(
      points.calls.where((call) => call.startsWith('wallet:') || call.startsWith('history:')),
      isEmpty,
    );
  }
}

Future<void> tapNavigationControl(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

String quickQuantity(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('quick-order-quantity'))).controller!.text;

String quickValue(WidgetTester tester, String key) =>
    tester.widget<ValueRow>(find.byKey(Key(key))).value;
