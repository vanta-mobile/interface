import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/strategy_execution_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/strategy_execution.dart';
import 'package:vanta/features/portfolio/presentation/strategy_execution_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/strategy_execution.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late StrategyExecutionFixture fixture;
  late TestStrategyExecutionRepository repository;
  late ValueNotifier<Locale> locale;
  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(StrategyExecutionScreen)));
  Future<void> open(
    WidgetTester tester, {
    String language = 'zh',
    Size size = const Size(390, 844),
    double scale = 1,
    bool route = false,
  }) async {
    fixture = StrategyExecutionFixture();
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestStrategyExecutionRepository(fixture);
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        strategyExecutionRepositoryProvider.overrideWithValue(repository),
        liveOrderClockProvider.overrideWithValue(() => liveOrderClock),
      ],
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(identity.dispose);
    addTearDown(container.dispose);
    locale = ValueNotifier(Locale(language));
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, child) => MaterialApp(
            locale: value,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: route
                ? Builder(
                    builder: (context) => Scaffold(
                      body: FilledButton(
                        key: const Key('open-details'),
                        onPressed: () => openStrategyExecution(
                          context,
                          fixture.query.order,
                          fixture.query.strategyId,
                        ),
                        child: const Text('Open'),
                      ),
                    ),
                  )
                : StrategyExecutionScreen(query: fixture.query),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (route) {
      await tester.tap(find.byKey(const Key('open-details')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> visible(WidgetTester tester, Finder target) async {
    final scroll = find
        .descendant(
          of: find.byKey(const Key('strategy-execution-page')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(target, 150, scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pump();
  }

  Future<void> tapRead(WidgetTester tester) async {
    final button = find.byKey(const Key('strategy-execution-read'));
    await visible(tester, button);
    await tester.tap(button);
    await tester.pump();
  }

  StrategyExecutionState state() => container.read(strategyExecutionProvider(fixture.query));
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }

  for (final language in ['zh', 'en']) {
    for (final size in [const Size(320, 844), const Size(844, 390), const Size(768, 1024)]) {
      testWidgets(
        'explicit per-leg details exact partial fill and separate statuses $language $size',
        (tester) async {
          await open(tester, language: language, size: size, scale: 1.5);
          final messages = l10n(tester);
          expect(repository.calls, 0);
          expect(identity.wallets, 0);
          for (final value in [accountAddress, 'BTCUSDT', fixture.intent.clientOrderId, '9876']) {
            expect(
              find.byWidgetPredicate((w) => w is SelectableText && w.data == value),
              findsOneWidget,
            );
          }
          await tapRead(tester);
          await tester.pumpAndSettle();
          final entry = find.byKey(const Key('strategy-execution-leg-1'));
          await visible(
            tester,
            find.descendant(of: entry, matching: find.text(messages.strategyExecutionFilledValue)),
          );
          expect(
            find.descendant(of: entry, matching: find.text('PARTIALLY_FILLED')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: entry, matching: find.text(messages.historyCanceled)),
            findsOneWidget,
          );
          expect(find.descendant(of: entry, matching: find.text('0.0004 BTC')), findsOneWidget);
          expect(
            find.descendant(of: entry, matching: find.text('32.000000000000000001 USDT')),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate((w) => w is SelectableText && w.data == '100'),
            findsOneWidget,
          );
          await visible(tester, find.text(messages.strategyExecutionTermsChanged));
          expect(find.text(messages.strategyExecutionTriggered), findsOneWidget);
          expect(find.text(messages.strategyExecutionTermsChanged), findsOneWidget);
          await visible(tester, find.text(messages.strategyExecutionNoOrder));
          expect(find.text(messages.strategyExecutionNoOrder), findsOneWidget);
          expect(repository.calls, 1);
          expect(identity.wallets, 0);
          expect(tester.takeException(), null);
          await close(tester);
        },
      );
    }
  }
  testWidgets('stop and retry retains evidence, releases ownership and ignores late read', (
    tester,
  ) async {
    await open(tester);
    await tapRead(tester);
    await tester.pumpAndSettle();
    final previous = state().snapshot;
    final gate = Completer<void>();
    repository.gate = gate;
    await tapRead(tester);
    final stop = find.byKey(const Key('strategy-execution-stop'));
    await visible(tester, stop);
    await tester.tap(stop);
    await tester.pump();
    expect(state().snapshot, same(previous));
    expect(state().failure!.key, 'strategyExecutionStopped');
    expect(container.read(symbolSettingsActivityProvider).owner, null);
    gate.complete();
    await tester.pumpAndSettle();
    expect(state().snapshot, same(previous));
    repository.gate = null;
    await tapRead(tester);
    await tester.pumpAndSettle();
    expect(repository.calls, 3);
    expect(state().failure, null);
    await close(tester);
  });
  testWidgets('snapshot expires at30seconds, lifecycle marks stale, neither prompts a signature', (
    tester,
  ) async {
    await open(tester);
    await tapRead(tester);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 29));
    expect(state().stale, false);
    await tester.pump(const Duration(seconds: 1));
    expect(state().stale, true);
    expect(repository.calls, 1);
    await tapRead(tester);
    await tester.pumpAndSettle();
    expect(state().stale, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(state().stale, true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.calls, 2);
    await close(tester);
  });
  testWidgets('logout clears all private executions and disables signing', (tester) async {
    await open(tester);
    await tapRead(tester);
    await tester.pumpAndSettle();
    await container.read(authProvider.notifier).logout();
    await tester.pumpAndSettle();
    expect(state().snapshot, null);
    await visible(tester, find.byKey(const Key('strategy-execution-read')));
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('strategy-execution-read'))).onPressed,
      null,
    );
    expect(find.text(l10n(tester).authWalletChanged), findsOneWidget);
    expect(repository.calls, 1);
    await close(tester);
  });
  testWidgets('per-leg failure and skipped leg are explicit without inferred cancellation', (
    tester,
  ) async {
    await open(tester);
    repository.result = (q) {
      final snapshot = fixture.snapshot(request: q);
      return StrategyExecutionSnapshot(
        query: q,
        strategy: snapshot.strategy,
        strategyCheckedAt: snapshot.strategyCheckedAt,
        receivedAt: snapshot.receivedAt,
        units: snapshot.units,
        legs: [
          snapshot.legs[0],
          StrategyExecutionLeg(
            strategyLeg: snapshot.legs[1].strategyLeg,
            failure: const AccountReadFailure('authWalletRejected'),
          ),
          StrategyExecutionLeg(
            strategyLeg: snapshot.legs[2].strategyLeg,
            failure: const AccountReadFailure('strategyExecutionSkipped'),
          ),
        ],
      );
    };
    await tapRead(tester);
    await tester.pumpAndSettle();
    await visible(tester, find.text(l10n(tester).authWalletRejected));
    expect(find.text(l10n(tester).authWalletRejected), findsOneWidget);
    await visible(tester, find.text(l10n(tester).strategyExecutionSkipped));
    expect(find.text(l10n(tester).strategyExecutionSkipped), findsOneWidget);
    expect(state().snapshot!.legs.last.strategyLeg.status, 'PENDING_NEW');
    expect(repository.calls, 1);
    await close(tester);
  });
  testWidgets('locale rebuild retains the pinned route query and existing snapshot', (
    tester,
  ) async {
    await open(tester, route: true);
    final query = tester
        .widget<StrategyExecutionScreen>(find.byType(StrategyExecutionScreen))
        .query;
    await tapRead(tester);
    await tester.pumpAndSettle();
    final snapshot = container.read(strategyExecutionProvider(query)).snapshot;
    expect(snapshot, isNotNull);
    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    final updated = tester.widget<StrategyExecutionScreen>(find.byType(StrategyExecutionScreen));
    expect(identical(updated.query, query), true);
    expect(container.read(strategyExecutionProvider(query)).snapshot, same(snapshot));
    expect(find.text('Strategy execution details'), findsOneWidget);
    expect(repository.calls, 1);
    await close(tester);
  });
  testWidgets('missing public units and optional values stay unknown in details', (tester) async {
    await open(tester);
    repository.result = (q) {
      final snapshot = fixture.snapshot(request: q);
      return StrategyExecutionSnapshot(
        query: q,
        strategy: snapshot.strategy,
        strategyCheckedAt: snapshot.strategyCheckedAt,
        receivedAt: snapshot.receivedAt,
        legs: snapshot.legs,
      );
    };
    await tapRead(tester);
    await tester.pumpAndSettle();
    final expected = '32.000000000000000001 ${l10n(tester).accountUnitUnavailable}';
    await visible(tester, find.text(expected));
    expect(find.text(expected), findsOneWidget);
    expect(find.text('32.000000000000000001 USDT'), findsNothing);
    await close(tester);
  });
}
