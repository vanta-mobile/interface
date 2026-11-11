import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/presentation/app_toast.dart';
import 'package:vanta/core/theme.dart';

Widget buildTestApp(void Function(BuildContext) onPressed, {String label = 'Show'}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: FilledButton(onPressed: () => onPressed(context), child: Text(label)),
      ),
    ),
  ),
);

String svgAsset(WidgetTester tester) {
  final picture = tester.widget<SvgPicture>(
    find
        .descendant(of: find.byKey(const Key('app-toast')), matching: find.byType(SvgPicture))
        .first,
  );
  return (picture.bytesLoader as SvgAssetLoader).assetName;
}

void main() {
  tearDown(AppToast.dismiss);

  testWidgets('success toast matches the design and dismisses automatically', (tester) async {
    await tester.pumpWidget(buildTestApp((context) => AppToast.showSuccess(context, 'Saved')));
    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.text('Saved'), findsOneWidget);
    expect(svgAsset(tester), 'assets/feedback/success.svg');
    expect(find.byKey(const Key('app-toast-close')), findsNothing);
    final toast = tester.getRect(find.byKey(const Key('app-toast')));
    expect(toast.width, 313);
    expect(toast.height, 46);
    expect(tester.widget<Text>(find.text('Saved')).style, ToastTypography.message);

    await tester.pump(AppToast.autoDismissDuration - const Duration(milliseconds: 1));
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('failure toast stays until manually closed by default', (tester) async {
    await tester.pumpWidget(
      buildTestApp((context) => AppToast.showFailure(context, 'Request failed')),
    );
    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(svgAsset(tester), 'assets/feedback/fail.svg');
    expect(find.byKey(const Key('app-toast-close')), findsOneWidget);
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Request failed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-toast-close')));
    await tester.pump();
    expect(find.text('Request failed'), findsNothing);
  });

  testWidgets('success feedback cannot replace an unread error', (tester) async {
    late BuildContext toastContext;
    await tester.pumpWidget(
      buildTestApp((context) {
        toastContext = context;
        AppToast.showFailure(context, 'Margin is insufficient.');
      }),
    );
    await tester.tap(find.text('Show'));
    await tester.pump();
    AppToast.showSuccess(toastContext, 'Refreshed');
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Margin is insufficient.'), findsOneWidget);
    expect(find.text('Refreshed'), findsNothing);
    await tester.tap(find.byKey(const Key('app-toast-close')));
    await tester.pump();
    AppToast.showSuccess(toastContext, 'Refreshed');
    await tester.pump();
    expect(find.text('Refreshed'), findsOneWidget);
    await tester.pump(AppToast.autoDismissDuration);
    await tester.pump();
    expect(find.text('Refreshed'), findsNothing);
  });

  testWidgets('replaced success timer cannot close an error', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      buildTestApp((context) {
        if (count++ == 0) {
          AppToast.showSuccess(context, 'Saved');
        } else {
          AppToast.showFailure(context, 'Request failed');
        }
      }),
    );
    await tester.tap(find.text('Show'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Show'));
    // Cross the old deadline before the next frame removes its overlay state.
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Request failed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-toast-close')));
    await tester.pump();
  });

  testWidgets('persistent failure stays until manually closed', (tester) async {
    await tester.pumpWidget(
      buildTestApp((context) => AppToast.showFailure(context, 'Outcome unknown', persistent: true)),
    );
    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));

    expect(find.text('Outcome unknown'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('app-toast-close'))), const Size(40, 40));
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.text('Outcome unknown'), findsNothing);
  });

  testWidgets('a new toast replaces the current one and restarts its timer', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      buildTestApp((context) => AppToast.showSuccess(context, 'Saved ${++count}')),
    );
    await tester.tap(find.text('Show'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.text('Saved 1'), findsNothing);
    expect(find.text('Saved 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Saved 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Saved 2'), findsNothing);
  });

  testWidgets('narrow windows keep side margins and wrap long messages', (tester) async {
    tester.view.physicalSize = const Size(280, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const long = 'A long failure message from the API that needs to wrap onto more lines';
    await tester.pumpWidget(buildTestApp((context) => AppToast.showFailure(context, long)));
    await tester.tap(find.text('Show'));
    await tester.pump();

    final toast = tester.getRect(find.byKey(const Key('app-toast')));
    expect(toast.left, 16);
    expect(toast.right, 264);
    expect(toast.height, greaterThan(44));
    expect(tester.takeException(), isNull);
  });
}
