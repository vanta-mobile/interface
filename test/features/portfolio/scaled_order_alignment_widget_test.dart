import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/scaled_order_provider.dart';
import 'package:vanta/features/portfolio/domain/scaled_order.dart';
import 'package:vanta/features/portfolio/presentation/scaled_order_details.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/scaled_order.dart';
import '../../support/scaled_order_widget.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<(ProviderContainer, TestScaledRepository)> start(
    WidgetTester tester,
    String language, {
    double width = 320,
    double scale = 1.5,
  }) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final repository = TestScaledRepository()..context = liveContext(available: '100000');
    final container = setup(
      tester,
      width: width,
      scale: scale,
      language: Locale(language),
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    return (container, repository);
  }

  Future<void> finish(WidgetTester tester, ProviderContainer container) async {
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  }

  Future<void> quote(WidgetTester tester, {String size = '1000', String count = '3'}) async {
    await field(tester, 'scaled-low', '79000');
    await field(tester, 'scaled-high', '81000');
    await field(tester, 'scaled-quantity', size);
    await field(tester, 'scaled-count', count);
  }

  ScaledOrderPlan preview(WidgetTester tester) =>
      tester.widget<ScaledPlanDetails>(find.byType(ScaledPlanDetails).first).plan;
  for (final language in ['en', 'zh']) {
    testWidgets('blank first visit, independent raw units and progressive defaults $language', (
      tester,
    ) async {
      final (container, repository) = await start(tester, language);
      final l10n = messages(tester);
      for (final key in ['scaled-low', 'scaled-high', 'scaled-quantity', 'scaled-count']) {
        expect(tester.widget<TextField>(find.byKey(Key(key))).controller!.text, '');
      }
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('scaled-unit-quote'))).selected, true);
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('scaled-distribution-equal'))).selected,
        true,
      );
      expect(find.byKey(const Key('scaled-constant-difference')), findsNothing);
      expect(find.byType(ScaledPlanDetails), findsNothing);
      expect(tester.widget<FilledButton>(find.byKey(const Key('scaled-review'))).onPressed, null);
      await quote(tester);
      expect(preview(tester).unallocatedQuote.toString(), '40');
      await tap(tester, 'scaled-unit-base');
      expect(
        tester.widget<TextField>(find.byKey(const Key('scaled-quantity'))).controller!.text,
        '',
      );
      expect(find.byType(ScaledPlanDetails), findsNothing);
      await field(tester, 'scaled-quantity', '0.012');
      await tap(tester, 'scaled-distribution-increasing');
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('scaled-constant-difference'))).selected,
        true,
      );
      expect(preview(tester).orders.map((o) => o.quantity), ['0.002', '0.004', '0.006']);
      await tap(tester, 'scaled-constant-ratio');
      await field(tester, 'scaled-quantity', '0.014');
      expect(preview(tester).orders.map((o) => o.quantity), ['0.002', '0.004', '0.008']);
      await tap(tester, 'scaled-distribution-equal');
      expect(find.text(l10n.scaledConstant), findsNothing);
      await tap(tester, 'scaled-distribution-decreasing');
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('scaled-constant-ratio'))).selected,
        true,
      );
      expect(preview(tester).orders.map((o) => o.quantity), ['0.008', '0.004', '0.002']);
      await tap(tester, 'scaled-unit-quote');
      expect(
        tester.widget<TextField>(find.byKey(const Key('scaled-quantity'))).controller!.text,
        '1000',
      );
      await tap(tester, 'scaled-unit-base');
      expect(
        tester.widget<TextField>(find.byKey(const Key('scaled-quantity'))).controller!.text,
        '0.014',
      );
      expect(repository.reads.length, 1);
      expect(repository.posts, isEmpty);
      await finish(tester, container);
    });
    testWidgets(
      'quote confirmation localizes live, cancel retains input, unknown queries original ID $language',
      (tester) async {
        final (container, repository) = await start(tester, language);
        repository.unknown = true;
        await quote(tester);
        final original = preview(tester);
        await tap(tester, 'scaled-review');
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.byType(Checkbox)), findsNothing);
        final reviewed = tester
            .widget<ScaledPlanDetails>(
              find.descendant(of: dialog, matching: find.byType(ScaledPlanDetails)),
            )
            .plan;
        expect(reviewed.draft, original.draft);
        expect(reviewed.notional.toString(), '960');
        expect(reviewed.unallocatedQuote.toString(), '40');
        container.read(localeProvider.notifier).select(language == 'en' ? 'zh' : 'en');
        await tester.pumpAndSettle();
        final changed = AppLocalizations.of(tester.element(dialog));
        expect(
          find.descendant(of: dialog, matching: find.text(changed.scaledReview)),
          findsOneWidget,
        );
        await tester.tap(find.text(changed.cancel));
        await tester.pumpAndSettle();
        expect(repository.posts, isEmpty);
        expect(repository.reads.length, 1);
        expect(preview(tester).draft, original.draft);
        await tap(tester, 'scaled-review');
        await tap(tester, 'scaled-confirm');
        expect(repository.posts.single.draft.quantity, '0.004');
        expect(repository.posts.single.draft.price, '79000');
        final id = repository.posts.single.clientOrderId;
        repository.unknown = false;
        await tap(tester, 'scaled-recheck');
        expect(repository.posts.length, 1);
        expect(repository.checks.single.clientOrderId, id);
        expect(container.read(scaledOrderProvider).items.skip(1).every((i) => !i.submitted), true);
        expect(
          tester.widget<TextField>(find.byKey(const Key('scaled-quantity'))).controller!.text,
          '1000',
        );
        await finish(tester, container);
      },
    );
    testWidgets(
      '110-child preview and review have all pages, preserve complete frozen plan $language',
      (tester) async {
        final (container, repository) = await start(tester, language);
        await quote(tester, size: '17600', count: '110');
        expect(preview(tester).orders.length, 110);
        expect(find.byKey(const Key('scaled-child-0')), findsOneWidget);
        expect(find.byKey(const Key('scaled-child-10')), findsNothing);
        for (var page = 1; page <= 10; page++) {
          await tap(tester, 'scaled-next-children');
          expect(find.byKey(Key('scaled-child-${page * 10}')), findsOneWidget);
        }
        expect(find.byKey(const Key('scaled-child-109')), findsOneWidget);
        expect(
          tester.widget<OutlinedButton>(find.byKey(const Key('scaled-next-children'))).onPressed,
          null,
        );
        await tap(tester, 'scaled-review');
        final dialog = find.byType(AlertDialog);
        final details = tester.widget<ScaledPlanDetails>(
          find.descendant(of: dialog, matching: find.byType(ScaledPlanDetails)),
        );
        expect(details.plan.orders.length, 110);
        expect(details.clientIds!.toSet().length, 110);
        for (var page = 1; page <= 10; page++) {
          final next = find.descendant(
            of: dialog,
            matching: find.byKey(const Key('scaled-next-children')),
          );
          await tester.ensureVisible(next);
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
        expect(
          find.descendant(of: dialog, matching: find.text(details.clientIds!.last)),
          findsOneWidget,
        );
        tester.view.physicalSize = const Size(844, 320);
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        await tester.ensureVisible(
          find.descendant(
            of: dialog,
            matching: find.text(AppLocalizations.of(tester.element(dialog)).cancel),
          ),
        );
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.text(AppLocalizations.of(tester.element(dialog)).cancel),
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.posts, isEmpty);
        expect(repository.reads.length, 1);
        repository.unknown = true;
        await tap(tester, 'scaled-review');
        await tap(tester, 'scaled-confirm');
        expect(container.read(scaledOrderProvider).items.length, 110);
        expect(repository.posts.length, 1);
        expect(find.byKey(const Key('scaled-result-0')), findsOneWidget);
        expect(find.byKey(const Key('scaled-result-10')), findsNothing);
        for (var page = 1; page <= 10; page++) {
          await tap(tester, 'scaled-results-next-children');
        }
        expect(find.byKey(const Key('scaled-result-109')), findsOneWidget);
        repository.unknown = false;
        await tap(tester, 'scaled-recheck');
        expect(repository.posts.length, 1);
        expect(
          repository.checks.single.clientOrderId,
          container.read(scaledOrderProvider).intent!.clientIds.first,
        );
        await finish(tester, container);
      },
    );
    testWidgets(
      'random preview stays frozen across locale and review, variance errors keep input $language',
      (tester) async {
        final (container, repository) = await start(tester, language, width: 768, scale: 1.3);
        await tap(tester, 'scaled-unit-base');
        await quote(tester, size: '0.03');
        await tap(tester, 'scaled-distribution-random');
        final original = preview(tester);
        final quantities = original.orders.map((o) => o.quantity).toList();
        expect(original.draft.randomSeed, isNotNull);
        expect(find.byKey(const Key('scaled-constant-difference')), findsNothing);
        container.read(localeProvider.notifier).select(language == 'en' ? 'zh' : 'en');
        await tester.pumpAndSettle();
        expect(preview(tester).draft.randomSeed, original.draft.randomSeed);
        expect(preview(tester).orders.map((o) => o.quantity), quantities);
        await tap(tester, 'scaled-review');
        final dialog = find.byType(AlertDialog);
        final captured = tester
            .widget<ScaledPlanDetails>(
              find.descendant(of: dialog, matching: find.byType(ScaledPlanDetails)),
            )
            .plan;
        expect(captured.draft.randomSeed, original.draft.randomSeed);
        expect(captured.orders.map((o) => o.quantity), quantities);
        await tester.tap(find.text(AppLocalizations.of(tester.element(dialog)).cancel));
        await tester.pumpAndSettle();
        await field(tester, 'scaled-variance', '10.000000000000000001');
        expect(find.byType(ScaledPlanDetails), findsNothing);
        expect(find.text(messages(tester).scaledVarianceInvalid), findsOneWidget);
        expect(tester.widget<FilledButton>(find.byKey(const Key('scaled-review'))).onPressed, null);
        await field(tester, 'scaled-variance', '0');
        expect(preview(tester).orders.every((o) => o.quantity == '0.01'), true);
        await tap(tester, 'scaled-reshuffle');
        expect(preview(tester).orders.every((o) => o.quantity == '0.01'), true);
        expect(repository.posts, isEmpty);
        expect(repository.reads.length, 1);
        await finish(tester, container);
      },
    );
  }
  for (final count in ['0', '1', '111', '2.5', '-2', '1e2', '999999999999999999']) {
    testWidgets('invalid child count $count cannot review or submit', (tester) async {
      final (container, repository) = await start(tester, 'en', width: 390, scale: 1);
      await quote(tester, count: count);
      expect(find.text(messages(tester).scaledCountInvalid), findsOneWidget);
      expect(find.byType(ScaledPlanDetails), findsNothing);
      expect(tester.widget<FilledButton>(find.byKey(const Key('scaled-review'))).onPressed, null);
      expect(repository.posts, isEmpty);
      await finish(tester, container);
    });
  }
}
