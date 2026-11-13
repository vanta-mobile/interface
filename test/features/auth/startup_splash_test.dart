import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:vanta/features/auth/presentation/startup_splash.dart';

Future<void> main() async {
  // Rive's native test library is installed with `rive_native:setup`.
  TestWidgetsFlutterBinding.ensureInitialized();
  var native = false;
  try {
    native = await rive.RiveNative.init();
  } catch (_) {}
  final skip = native ? null : 'Rive native test library unavailable';

  test(
    'bundled file exposes the handoff artboard, state machine and timelines',
    skip: skip,
    () async {
      final bytes = await io.File(StartupSplash.asset).readAsBytes();
      final file = (await rive.File.decode(bytes, riveFactory: rive.Factory.flutter))!;
      final artboard = file.artboard(StartupSplash.artboard)!;
      expect(artboard.bounds.width, 780);
      expect(artboard.bounds.height, 1688);
      expect(artboard.stateMachine(StartupSplash.stateMachine), isNotNull);
      final intro = artboard.animationNamed(StartupSplash.introAnimation)!;
      final reduced = artboard.animationNamed(StartupSplash.reducedMotionAnimation)!;
      expect(intro.duration, closeTo(3, 1e-6));
      expect(reduced.duration, closeTo(0.2, 1e-6));
      for (final dispose in [intro.dispose, reduced.dispose, artboard.dispose, file.dispose]) {
        dispose();
      }
    },
  );

  Future<void> pumpSplash(WidgetTester tester, VoidCallback onDone, {bool reduced = false}) async {
    if (reduced) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    await tester.pumpWidget(MaterialApp(home: StartupSplash(onIntroCompleted: onDone)));
    // Asset loading and decoding complete outside the fake frame clock.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }

  testWidgets('plays the Rive intro once and continues after splash_complete', skip: skip != null, (
    tester,
  ) async {
    var completed = 0;
    await pumpSplash(tester, () => completed++);
    expect(find.byKey(const Key('startup-splash')), findsOneWidget);
    expect(find.byType(rive.RiveWidget), findsOneWidget);
    for (var i = 0; i < 145; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(completed, 0);
    for (var i = 0; i < 20 && completed == 0; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(completed, 1);
  });

  testWidgets('reduced motion plays only the 200ms fade-in', skip: skip != null, (tester) async {
    var completed = 0;
    await pumpSplash(tester, () => completed++, reduced: true);
    expect(find.byType(rive.RiveWidget), findsNothing);
    expect(find.byType(rive.RiveArtboardWidget), findsOneWidget);
    for (var i = 0; i < 20 && completed == 0; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(completed, 1);
  });

  testWidgets('an unreadable file never holds startup', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _MissingBundle(),
          child: StartupSplash(onIntroCompleted: () => completed++),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(completed, 1);
    expect(find.byKey(const Key('startup-splash')), findsOneWidget);
  });
}

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => Future.error(FlutterError('Missing $key'));
}
