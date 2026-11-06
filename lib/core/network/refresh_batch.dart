import 'dart:async';

/// Join repeated gestures and settle every section, even if another fails.
/// Section controllers retain their own data/errors and authorization policy.
class RefreshBatch {
  Future<void>? _pending;
  Future<void> run(Iterable<Future<void> Function()> operations) {
    if (_pending case final pending?) return pending;
    final done = Completer<void>();
    _pending = done.future;
    Future.wait(
      operations.map((operation) async {
        try {
          await operation();
        } catch (_) {
          /* Section owns its error state. */
        }
      }),
    ).then((_) {
      _pending = null;
      done.complete();
    });
    return done.future;
  }
}
