import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/points/data/event_engagement_journal.dart';
import 'package:vanta/features/points/domain/event_engagement.dart';

import '../../support/points.dart';

void main() {
  late String? saved;
  late bool failWrite;
  late LocalEventEngagementJournal journal;
  LocalEventEngagementJournal create() => LocalEventEngagementJournal(
    readValue: () async => saved,
    writeValue: (v) async {
      if (failWrite) throw const FormatException();
      saved = v;
    },
  );
  PendingEventEngagement entry({
    int id = 17,
    String address = pointsTestAddress,
    EventEngagementAction action = EventEngagementAction.checkIn,
    String day = '2026-11-04',
  }) => PendingEventEngagement(eventId: id, address: address, action: action, day: day);
  setUp(() {
    saved = null;
    failWrite = false;
    journal = create();
  });
  test('reconstructed repository reads only public intent metadata', () async {
    await journal.add(entry());
    final restored = await create().read();
    expect(restored.single.key, entry().key);
    expect(
      (jsonDecode(saved!) as List).single.keys,
      unorderedEquals(['id', 'address', 'action', 'day']),
    );
    expect(saved, isNot(contains('signature')));
  });
  test('same event wallet blocks another action/day until explicit removal', () async {
    await journal.add(entry());
    await expectLater(
      journal.add(entry(action: EventEngagementAction.walletConnect, day: '2026-11-05')),
      throwsFormatException,
    );
    await journal.remove(entry().key);
    await journal.add(entry(action: EventEngagementAction.walletConnect));
    expect((await journal.read()).single.action, EventEngagementAction.walletConnect);
  });
  test('parallel mutations serialize without dropping other wallet records', () async {
    await Future.wait([
      journal.add(entry()),
      journal.add(entry(id: 18)),
      journal.add(entry(address: '0x2222222222222222222222222222222222222222')),
    ]);
    expect((await journal.read()).length, 3);
    await journal.remove(entry().key);
    expect((await journal.read()).length, 2);
  });
  test('failed storage write preserves old entries and queue recovers', () async {
    await journal.add(entry());
    final original = saved;
    failWrite = true;
    await expectLater(journal.remove(entry().key), throwsFormatException);
    expect(saved, original);
    failWrite = false;
    await journal.add(entry(id: 18));
    expect((await journal.read()).length, 2);
  });
  for (final raw in [
    'invalid',
    '{}',
    '[${' ' * 65536}]',
    jsonEncode([
      {'id': 0},
    ]),
    jsonEncode([
      {'id': 17, 'address': pointsTestAddress, 'action': 'checkIn', 'day': '2026-02-30'},
    ]),
  ]) {
    test('corrupt journal ${raw.length}/${raw.hashCode} is retained and fails closed', () async {
      saved = raw;
      await expectLater(journal.read(), throwsA(isA<FormatException>()));
      await expectLater(journal.add(entry()), throwsA(isA<FormatException>()));
      expect(saved, raw);
    });
  }
  test('duplicate persisted keys rejected rather than silently discarded', () async {
    await journal.add(entry());
    final row = (jsonDecode(saved!) as List).single;
    saved = jsonEncode([row, row]);
    await expectLater(journal.read(), throwsFormatException);
  });
  test('100 record cap preserves unresolved entries without eviction', () async {
    for (var i = 1; i <= 100; i++) {
      await journal.add(entry(id: i));
    }
    await expectLater(journal.add(entry(id: 101)), throwsFormatException);
    expect((await journal.read()).length, 100);
  });
  test('awaits durable write acknowledgement before completing add', () async {
    final gate = Completer<void>();
    final j = LocalEventEngagementJournal(
      readValue: () async => null,
      writeValue: (v) async {
        await gate.future;
        saved = v;
      },
    );
    var done = false;
    final future = j.add(entry()).then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(done, false);
    expect(saved, null);
    gate.complete();
    await future;
    expect(done, true);
    expect(saved, isNotNull);
  });
}
