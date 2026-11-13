import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Taps on system notifications: the one that launched the app and those that
/// bring it back from the background. Only the `data` map is passed on.
class PushOpenSource {
  PushOpenSource({required this.opened, required this.initial});

  factory PushOpenSource.firebase() => PushOpenSource(
    opened: FirebaseMessaging.onMessageOpenedApp.map((message) => message.data),
    initial: () async => (await FirebaseMessaging.instance.getInitialMessage())?.data,
  );

  final Stream<Map<String, Object?>> opened;
  final Future<Map<String, Object?>?> Function() initial;
  StreamSubscription<Map<String, Object?>>? _subscription;
  bool _closed = false;

  void start(void Function(Map<String, Object?>) onOpen) {
    if (_closed || _subscription != null) return;
    _subscription = opened.listen((data) {
      if (!_closed) onOpen(data);
    }, onError: (Object _) {});
    unawaited(() async {
      try {
        final data = await initial();
        if (data != null && !_closed) onOpen(data);
      } catch (_) {
        // Without a launch notification the app opens its default page.
      }
    }());
  }

  Future<void> close() async {
    _closed = true;
    await _subscription?.cancel();
  }
}
