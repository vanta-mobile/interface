import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/network/refresh_batch.dart';

void main() {
  test('refresh waits for every section including failures and joins repeated gestures', () async {
    final batch = RefreshBatch();
    final first = Completer<void>(), second = Completer<void>();
    var calls = 0, finished = false;
    final pending = batch.run([
      () {
        calls++;
        return first.future;
      },
      () {
        calls++;
        return second.future;
      },
    ]);
    pending.then((_) => finished = true);
    expect(identical(pending, batch.run([() async => calls++])), isTrue);
    first.completeError(StateError('section failure'));
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    second.complete();
    await pending;
    expect(calls, 2);
    expect(finished, isTrue);
    await batch.run([
      () async {
        calls++;
      },
    ]);
    expect(calls, 3);
  });
  test('synchronous failure does not prevent other sections refreshing', () async {
    var refreshed = false;
    await RefreshBatch().run([
      () => throw StateError('failed'),
      () async {
        refreshed = true;
      },
    ]);
    expect(refreshed, isTrue);
  });
}
