import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/presentation/status_view.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

Widget host(Widget child, {double width = 361}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

Finder get retry => find.byKey(const Key('status-retry'));
Finder get spinner => find.byKey(const Key('status-action-loading'));

void main() {
  testWidgets('failure shows the design copy, illustration and fixed-width retry', (tester) async {
    await tester.pumpWidget(host(StatusFailureView(onRetry: () async {})));

    expect(find.text('Unable to Load'), findsOneWidget);
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/feedback/load-failed.webp');
    expect(tester.getSize(find.byType(Image)), const Size(80, 80));
    expect(tester.getSize(retry), const Size(120, 40));
  });

  testWidgets('retry spins and blocks repeats until its request settles', (tester) async {
    var calls = 0;
    final request = Completer<void>();
    await tester.pumpWidget(
      host(
        StatusFailureView(
          message: 'Order book disconnected.',
          onRetry: () {
            calls++;
            return request.future;
          },
        ),
      ),
    );
    expect(find.text('Order book disconnected.'), findsOneWidget);

    await tester.tap(retry);
    await tester.pump();
    expect(spinner, findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(retry);
    await tester.pump();
    expect(calls, 1);

    request.completeError(StateError('still offline'));
    await tester.pump();
    expect(spinner, findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('external retrying state keeps the button disabled', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(StatusFailureView(retrying: true, onRetry: () async => calls++)));
    expect(spinner, findsOneWidget);
    await tester.tap(retry);
    expect(calls, 0);
  });

  testWidgets('narrow columns wrap copy and hug the retry label', (tester) async {
    await tester.pumpWidget(host(StatusFailureView(onRetry: () async {}), width: 147));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(retry).width, lessThan(120));
    expect(tester.getSize(retry).height, 40);
    expect(tester.getSize(find.text('Something went wrong. Please try again.')).width, 147);
  });

  testWidgets('empty state uses generic copy and an optional action', (tester) async {
    await tester.pumpWidget(host(const StatusEmptyView()));
    expect(find.text('No Data Yet'), findsOneWidget);
    expect(find.text("There's nothing to display here right now."), findsOneWidget);
    expect(find.byKey(const Key('status-action')), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/feedback/empty.webp');

    var deposits = 0;
    await tester.pumpWidget(
      host(
        StatusEmptyView(
          title: 'No Assets Yet',
          message: 'Deposit funds to get started with trading.',
          actionLabel: 'Deposit',
          onAction: () => deposits++,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('status-action')));
    await tester.pump();
    expect(deposits, 1);
    expect(spinner, findsNothing);
  });

  testWidgets('skeleton boxes use the design radius and fit their slot', (tester) async {
    await tester.pumpWidget(
      host(
        const Row(
          children: [
            SkeletonBox.circle(20),
            SizedBox(width: 30, child: SkeletonBox(width: 82, height: 10)),
          ],
        ),
      ),
    );
    final boxes = find.byType(SkeletonBox);
    expect(tester.getSize(boxes.first), const Size(20, 20));
    expect(tester.getSize(boxes.last), const Size(30, 10));
    expect(tester.takeException(), isNull);
  });
}
