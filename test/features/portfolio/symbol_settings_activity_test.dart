import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/position_leverage_provider.dart';
import 'package:vanta/features/portfolio/application/position_margin_mode_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';

import '../../support/aster_account.dart';
import '../../support/futures_asset_mode.dart';

import 'package:vanta/features/portfolio/application/futures_asset_mode_provider.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';

import '../../support/futures_position_mode.dart';

import 'package:vanta/features/portfolio/application/futures_position_mode_provider.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';

import '../../support/identity_repository.dart';
import '../../support/position_leverage.dart';
import '../../support/position_margin_mode.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestPositionLeverageRepository leverage;
  late TestPositionMarginModeRepository margin;
  late TestFuturesPositionModeRepository position;
  late TestFuturesAssetModeRepository asset;
  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    leverage = TestPositionLeverageRepository();
    margin = TestPositionMarginModeRepository();
    position = TestFuturesPositionModeRepository();
    asset = TestFuturesAssetModeRepository();
    container = ProviderContainer(
      overrides: [
        futuresAssetModeRepositoryProvider.overrideWithValue(asset),
        futuresAssetModeClockProvider.overrideWithValue(() => assetModeClock),
        futuresPositionModeRepositoryProvider.overrideWithValue(position),
        futuresPositionModeClockProvider.overrideWithValue(() => positionModeClock),
        identityRepositoryProvider.overrideWithValue(identity),
        positionLeverageRepositoryProvider.overrideWithValue(leverage),
        positionLeverageClockProvider.overrideWithValue(() => leverageClock),
        positionMarginModeRepositoryProvider.overrideWithValue(margin),
        positionMarginModeClockProvider.overrideWithValue(() => marginModeClock),
      ],
    );
    container.read(authProvider);
    container.read(futuresAssetModeProvider);
    container.read(futuresPositionModeProvider);
    container.read(positionLeverageProvider);
    container.read(positionMarginModeProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });

  test('an account switch drops old leases and starts a new epoch', () async {
    final controller = container.read(symbolSettingsActivityProvider.notifier);
    final old = controller.acquire(SymbolSetting.order);
    final epoch = container.read(symbolSettingsActivityProvider).epoch;
    identity.events.add(null);
    container.read(pendingWalletOrdersProvider);
    expect(container.read(symbolSettingsActivityProvider).busy, false);
    expect(container.read(symbolSettingsActivityProvider).epoch, epoch + 1);
    identity.restored = signingIdentity;
    await container.read(authProvider.notifier).bootstrap();
    final next = controller.acquire(SymbolSetting.leverage);
    controller.finish(old); // an old lease cannot release the new one
    expect(container.read(symbolSettingsActivityProvider).isRunning(SymbolSetting.leverage), true);
    controller.finish(next);
    expect(container.read(symbolSettingsActivityProvider).busy, false);
  });

  test('independent settings reads run concurrently', () async {
    leverage.readGate = Completer<void>();
    final pending = container.read(positionLeverageProvider.notifier).load('BTCUSDT');
    await container.read(positionMarginModeProvider.notifier).load('BTCUSDT');
    await container.read(futuresPositionModeProvider.notifier).load();
    expect(margin.reads, 1);
    expect(position.reads, 1);
    expect(container.read(symbolSettingsActivityProvider).isRunning(SymbolSetting.leverage), true);
    leverage.readGate!.complete();
    await pending;
    expect(leverage.reads, 1);
    expect(container.read(symbolSettingsActivityProvider).busy, false);
  });

  test('an unverified write is queried automatically, once, and never resubmitted', () async {
    final controller = container.read(positionLeverageProvider.notifier);
    await controller.load('BTCUSDT');
    leverage.result = const LeverageResult(failure: AccountReadFailure('accountNetwork'));
    leverage.checkResult = LeverageResult(observed: 20, checkedAt: leverageClock);
    await controller.change(controller.prepare('BTCUSDT', '20')!);
    expect(leverage.changes, 1);
    expect(leverage.checks, 1);
    expect(container.read(positionLeverageProvider).result?.observed, 20);
    expect(container.read(positionLeverageProvider).failure, isNull);
    // Other settings were never blocked.
    await container.read(positionMarginModeProvider.notifier).load('BTCUSDT');
    expect(margin.reads, 1);
  });

  test('a failed verification is reported as the concrete error, without blocking', () async {
    final controller = container.read(positionMarginModeProvider.notifier);
    await controller.load('BTCUSDT');
    margin.result = const MarginModeResult(failure: AccountReadFailure('accountNetwork'));
    await controller.change(controller.prepare('BTCUSDT', PositionMarginMode.isolated)!);
    expect(margin.changes, 1);
    expect(margin.checks, 1);
    expect(container.read(positionMarginModeProvider).failure?.key, 'accountNetwork');
    expect(container.read(positionMarginModeProvider).result, isNull);
    await container.read(positionLeverageProvider.notifier).load('BTCUSDT');
    expect(leverage.reads, 1);
  });

  test('submitting either setting invalidates the other cached confirmation', () async {
    final a = container.read(positionLeverageProvider.notifier),
        b = container.read(positionMarginModeProvider.notifier);
    await a.load('BTCUSDT');
    final old = a.prepare('BTCUSDT', '20')!;
    await b.load('BTCUSDT');
    await b.change(b.prepare('BTCUSDT', PositionMarginMode.isolated)!);
    expect(container.read(positionLeverageProvider).stale, true);
    await a.change(old);
    expect(leverage.changes, 0);
    await a.load('BTCUSDT');
    await b.load('BTCUSDT');
    final oldMode = b.prepare('BTCUSDT', PositionMarginMode.isolated)!;
    await a.change(a.prepare('BTCUSDT', '20')!);
    expect(container.read(positionMarginModeProvider).stale, true);
    await b.change(oldMode);
    expect(margin.changes, 1);
  });
  test('read failures release the shared operation while preserving their safe error', () async {
    margin.readFailure = const AccountReadFailure('accountNetwork');
    await container.read(positionMarginModeProvider.notifier).load('BTCUSDT');
    expect(container.read(positionMarginModeProvider).failure?.key, 'accountNetwork');
    await container.read(positionLeverageProvider.notifier).load('BTCUSDT');
    expect(leverage.reads, 1);
  });
  test(
    'account-mode read runs beside symbol operations; symbol submit invalidates confirmation',
    () async {
      final controller = container.read(futuresPositionModeProvider.notifier);
      final leverageController = container.read(positionLeverageProvider.notifier);
      await controller.load();
      final old = controller.prepare(FuturesPositionMode.hedge)!;
      leverage.readGate = Completer<void>();
      final pending = leverageController.load('BTCUSDT');
      await controller.load();
      expect(position.reads, 2);
      leverage.readGate!.complete();
      await pending;
      await leverageController.change(leverageController.prepare('BTCUSDT', '20')!);
      expect(container.read(futuresPositionModeProvider).stale, true);
      await controller.change(old);
      expect(position.changes, 0);
    },
  );
  test('account mode submission invalidates both old symbol confirmations', () async {
    final a = container.read(positionLeverageProvider.notifier);
    final b = container.read(positionMarginModeProvider.notifier);
    final c = container.read(futuresPositionModeProvider.notifier);
    await a.load('ETHUSDT');
    await b.load('BTCUSDT');
    final oldLeverage = a.prepare('ETHUSDT', '20')!;
    final oldMargin = b.prepare('BTCUSDT', PositionMarginMode.isolated)!;
    await c.load();
    await c.change(c.prepare(FuturesPositionMode.hedge)!);
    await a.change(oldLeverage);
    await b.change(oldMargin);
    expect(container.read(positionLeverageProvider).stale, true);
    expect(container.read(positionMarginModeProvider).stale, true);
    expect(leverage.changes, 0);
    expect(margin.changes, 0);
  });
  test('asset-mode submit invalidates all three prior setting confirmations', () async {
    final a = container.read(positionLeverageProvider.notifier);
    final b = container.read(positionMarginModeProvider.notifier);
    final c = container.read(futuresPositionModeProvider.notifier);
    final d = container.read(futuresAssetModeProvider.notifier);
    await a.load('BTCUSDT');
    await b.load('ETHUSDT');
    await c.load();
    await d.load();
    final leverageIntent = a.prepare('BTCUSDT', '20')!;
    final marginIntent = b.prepare('ETHUSDT', PositionMarginMode.isolated)!;
    final positionIntent = c.prepare(FuturesPositionMode.hedge)!;
    await d.change(d.prepare(FuturesAssetMode.multi)!);
    await a.change(leverageIntent);
    await b.change(marginIntent);
    await c.change(positionIntent);
    expect(leverage.changes, 0);
    expect(margin.changes, 0);
    expect(position.changes, 0);
    expect(container.read(positionLeverageProvider).stale, true);
    expect(container.read(positionMarginModeProvider).stale, true);
    expect(container.read(futuresPositionModeProvider).stale, true);
  });
  test('symbol margin-mode submission invalidates an old asset-mode confirmation', () async {
    final a = container.read(futuresAssetModeProvider.notifier);
    final b = container.read(positionMarginModeProvider.notifier);
    await a.load();
    final old = a.prepare(FuturesAssetMode.multi)!;
    await b.load('BTCUSDT');
    await b.change(b.prepare('BTCUSDT', PositionMarginMode.isolated)!);
    expect(container.read(futuresAssetModeProvider).stale, true);
    await a.change(old);
    expect(asset.changes, 0);
  });
}
