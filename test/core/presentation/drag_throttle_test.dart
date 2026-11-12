import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/presentation/drag_throttle.dart';

void main() {
  test('commits the first value, the latest per interval and the final value', () {
    fakeAsync((async) {
      final commits = <int>[];
      final throttle = DragThrottle<int>(commits.add);
      throttle
        ..add(1)
        ..add(2)
        ..add(3);
      expect(commits, [1]);
      async.elapse(const Duration(milliseconds: 100));
      expect(commits, [1, 3]);
      throttle.add(4);
      async.elapse(const Duration(milliseconds: 50));
      throttle.end(5);
      async.elapse(const Duration(milliseconds: 200));
      expect(commits, [1, 3, 5]);
    });
  });
  test('cancel drops a pending value', () {
    fakeAsync((async) {
      final commits = <int>[];
      DragThrottle<int>(commits.add)
        ..add(1)
        ..add(2)
        ..cancel();
      async.elapse(const Duration(milliseconds: 200));
      expect(commits, [1]);
    });
  });
}
