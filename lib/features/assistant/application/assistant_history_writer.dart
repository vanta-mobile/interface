import 'dart:async';

import '../data/assistant_vault.dart';
import '../domain/assistant.dart';
import '../domain/assistant_history.dart';
import '../domain/assistant_session.dart';

/// One in-flight write and one replaceable snapshot. Streaming / typing never
/// creates an unbounded queue of native writes. A closing writer flushes only
/// its original, fully scoped session and cannot update a later page's state.
class AssistantHistoryWriter {
  AssistantHistoryWriter(this.vault, this.session, this.onResult);
  final AssistantVault vault;
  final AssistantSession session;
  final void Function(String? key) onResult;
  AssistantHistory? _pending;
  Timer? _timer;
  Completer<void>? _idle;
  int _revision = 0;
  bool _running = false, _closed = false;
  void schedule(AssistantHistory history) {
    if (_closed || history.draft.length > 12000) return;
    _pending = history;
    _timer ??= Timer(const Duration(milliseconds: 400), flush);
  }

  void invalidatePending() {
    _revision++;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    if (!_running) unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    _idle = Completer<void>();
    while (_pending != null) {
      final history = _pending!, revision = _revision;
      _pending = null;
      String? error;
      try {
        await vault.saveHistory(
          session.scope,
          session.userId,
          history,
          isCurrent: () => revision == _revision,
        );
      } on AssistantFailure catch (e) {
        error = e.key;
      } catch (_) {
        error = 'assistantStorage';
      }
      if (!_closed && revision == _revision) onResult(error);
    }
    _running = false;
    _idle!.complete();
  }

  void close() {
    _closed = true;
    flush();
  }

  Future<void> closeAndWait() {
    close();
    return _idle?.future ?? Future.value();
  }
}
