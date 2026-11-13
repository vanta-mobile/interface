import 'dart:async';

import 'package:rive/rive.dart' as rive;
import 'package:vanta/features/auth/presentation/startup_splash.dart';

/// Headless tests cannot create the GPU Rive renderer, so the startup intro
/// uses Rive's Flutter-canvas renderer under test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  StartupSplash.riveFactory = () => rive.Factory.flutter;
  await testMain();
}
