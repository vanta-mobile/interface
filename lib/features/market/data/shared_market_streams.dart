import 'dart:async';

/// Reference-counted public subscriptions; never used for private user streams.
class SharedMarketStreams {
  SharedMarketStreams(this.open);
  final Stream<Map<String, Object?>> Function(List<String>) open;
  final _entries = <String, _SharedSubscription>{};
  bool _disposed = false;

  Stream<Map<String, Object?>> stream(List<String> channels) {
    final normalized = channels.toSet().toList();
    final key = (normalized.toList()..sort()).join(',');
    return Stream.multi((consumer) {
      if (_disposed) {
        consumer.close();
        return;
      }
      final entry = _entries.putIfAbsent(key, _SharedSubscription.new);
      entry.consumers.add(consumer);
      if (entry.connection case final connection?) consumer.add(connection);
      entry.subscription ??= open(normalized).listen(
        (event) {
          final immutable = Map<String, Object?>.unmodifiable(event);
          if (event.containsKey('connected') || event.containsKey('disconnected')) {
            entry.connection = immutable;
          }
          for (final listener in entry.consumers.toList()) {
            listener.add(immutable);
          }
        },
        onError: (Object error, StackTrace stack) {
          entry.connection = const {'disconnected': true};
          for (final listener in entry.consumers.toList()) {
            listener.addError(error, stack);
          }
        },
        onDone: () {
          if (identical(_entries[key], entry)) _entries.remove(key);
          for (final listener in entry.consumers.toList()) {
            listener.close();
          }
          entry.consumers.clear();
        },
      );
      consumer.onCancel = () async {
        entry.consumers.remove(consumer);
        if (entry.consumers.isEmpty) {
          if (identical(_entries[key], entry)) _entries.remove(key);
          await entry.subscription?.cancel();
        }
      };
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    final entries = _entries.values.toList();
    _entries.clear();
    for (final entry in entries) {
      for (final consumer in entry.consumers.toList()) {
        consumer.close();
      }
      entry.consumers.clear();
    }
    await Future.wait(entries.map((entry) async => entry.subscription?.cancel()));
  }
}

class _SharedSubscription {
  final consumers = <MultiStreamController<Map<String, Object?>>>{};
  StreamSubscription<Map<String, Object?>>? subscription;
  Map<String, Object?>? connection;
}
