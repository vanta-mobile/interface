import 'dart:async';

/// Coalesces high-frequency drag values before an expensive commit. The first
/// value commits immediately, later ones at most once per [interval], and
/// [end] always commits the final value so a release is never dropped.
class DragThrottle<T> {
  DragThrottle(this.commit, {this.interval = const Duration(milliseconds: 100)});
  final void Function(T value) commit;
  final Duration interval;
  Timer? _timer;
  T? _pending;
  var _hasPending = false;

  void add(T value) {
    if (_timer != null) {
      _pending = value;
      _hasPending = true;
      return;
    }
    commit(value);
    _timer = Timer(interval, () {
      _timer = null;
      if (!_hasPending) return;
      final value = _pending as T;
      _pending = null;
      _hasPending = false;
      add(value);
    });
  }

  void end(T value) {
    cancel();
    commit(value);
  }

  /// Drops any pending value without committing it.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _hasPending = false;
  }
}
