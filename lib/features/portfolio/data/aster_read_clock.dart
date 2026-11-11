/// Operation-local server clock for a sequence of safe reads. Each request
/// still receives its own monotonically unique nonce and signature. Never
/// share this calibration between operations or use it for financial writes.
class AsterReadClock {
  AsterReadClock(this.fetch, {this.maximumAge = const Duration(seconds: 10)});
  final Future<int> Function() fetch;
  final Duration maximumAge;
  Stopwatch? _elapsed;
  int? _serverTime;

  Future<int> serverTime() async {
    final elapsed = _elapsed, server = _serverTime;
    if (elapsed != null && server != null && elapsed.elapsed < maximumAge) {
      return server + elapsed.elapsedMilliseconds;
    }
    final time = await fetch();
    _serverTime = time;
    _elapsed = Stopwatch()..start();
    return time;
  }
}
