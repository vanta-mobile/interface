import 'dart:async';

/// Carries an operation's existing identity/revision guard through repositories.
/// Transport checks it while queued and in flight, not only after completion.
class RequestScope {
  RequestScope._(this.isCurrent, this.parent);
  final bool Function() isCurrent;
  final RequestScope? parent;
  static final Object _key = Object();
  static RequestScope? get current => Zone.current[_key] as RequestScope?;
  bool get active => isCurrent() && (parent?.active ?? true);

  static Future<T> run<T>(bool Function() isCurrent, Future<T> Function() operation) {
    final scope = RequestScope._(isCurrent, current);
    return runZoned(operation, zoneValues: {_key: scope});
  }
}
