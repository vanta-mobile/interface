import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/exact_json.dart';
import 'package:vanta/features/points/data/event_document_mapper.dart';
import 'package:vanta/features/points/data/trading_event_mapper.dart';
import 'package:vanta/features/points/domain/trading_event.dart';

import '../../support/points.dart';
import '../../support/trading_events.dart';

void main() {
  test('retail event preserves exact source fields, rules, tasks and immutable rewards', () {
    final event = tradingEventFixture();
    expect(event.id, 11);
    expect(event.registrationCount, 132);
    expect(event.volume.toString(), '243134683.03089294');
    expect(event.tasks.single.threshold.toString(), '1000.000000000000000001');
    expect(
      event.tasks.single.buttonUrl.toString(),
      'https://app.vanta.exchange/perp/PERP_BTC_USDC',
    );
    expect(event.rules.blocks.map((b) => b.kind), [
      EventBlockKind.heading,
      EventBlockKind.paragraph,
      EventBlockKind.table,
    ]);
    expect(event.rules.blocks.last.rows.last, ['#1', '25,000 USDC']);
    expect(() => event.tasks.clear(), throwsUnsupportedError);
    expect(() => event.rules.blocks.last.rows.first.clear(), throwsUnsupportedError);
  });
  test('raw numeric threshold, volume and int64 identifiers retain every token', () {
    final payload = jsonEncode({'event': eventPayload(id: 9223372036854775807)})
        .replaceFirst('"1000.000000000000000001"', '1000.000000000000000001')
        .replaceFirst('"243134683.03089294"', '243134683.03089294');
    final event = mapTradingEvent(decodeFundingJson(payload), eventId: 9223372036854775807);
    expect(event.tasks.single.threshold.toString(), '1000.000000000000000001');
    expect(event.volume.toString(), '243134683.03089294');
  });
  test('optional absence is unknown; explicit zeros are preserved', () {
    final raw = eventPayload()
      ..remove('registrationCount')
      ..remove('whitelistTotalVolume');
    var event = mapTradingEvent({'event': raw}, eventId: 11);
    expect(event.volume, null);
    expect(event.registrationCount, null);
    raw['registrationCount'] = 0;
    raw['whitelistTotalVolume'] = '0';
    event = mapTradingEvent({'event': raw}, eventId: 11);
    expect(event.volume.toString(), '0');
    expect(event.registrationCount, 0);
  });
  for (final entry in [
    ('eventType', 'UNSUPPORTED'),
    ('eventType', null),
    ('id', 0),
    ('tasks', null),
    (
      'tasks',
      [
        {'metric': 'ownVolume', 'threshold': 'NaN'},
      ],
    ),
    ('registrationCount', -1),
    ('startTime', '2026-02-30T00:00:00Z'),
    ('startTime', '2026-01-01T00:00:00'),
    ('endTime', '2026-10-01T00:00:00Z'),
    ('whitelistTotalVolume', 1.1),
  ]) {
    test('malformed event ${entry.$1}/${entry.$2} never masquerades as eligible', () {
      expect(
        () => mapTradingEvent({'event': eventPayload()..[entry.$1] = entry.$2}, eventId: 11),
        throwsFormatException,
      );
    });
  }
  test('wrong detail/duplicate event scope rejected; empty list explicit', () {
    expect(mapTradingEvents({'items': <Object>[]}), isEmpty);
    expect(
      () => mapTradingEvents({
        'items': [eventPayload(), eventPayload()],
      }),
      throwsFormatException,
    );
    expect(
      () => mapTradingEvent({'event': eventPayload(id: 9)}, eventId: 11),
      throwsFormatException,
    );
    expect(() => mapTradingEvents({}), throwsFormatException);
  });
  test('registration status/time and published leaderboard support are independent', () {
    final event = tradingEventFixture();
    expect(event.canRegister(DateTime.utc(2026, 11, 4)), true);
    expect(event.canRegister(event.end), false);
    expect(tradingEventFixture(status: 'ENDED').canRegister(event.start), false);
    expect(tradingEventFixture(status: 'ENDED').publishesRankings, true);
    expect(tradingEventFixture(status: 'UNKNOWN').publishesRankings, false);
  });
  test('an unsafe task button URL is not silently replaced with a different trading action', () {
    final raw = eventPayload();
    (raw['tasks'] as List).first['buttonUrl'] = 'javascript:alert(1)';
    expect(() => mapTradingEvent({'event': raw}, eventId: 11), throwsFormatException);
  });
  test('rankings bind venue/event, preserve ties/source order and do not infer ranks', () {
    final b = mapEventLeaderboard({
      'eventId': 11,
      'eventType': 'RETAIL',
      'rows': [
        {'rank': 7, 'address': pointsTestAddress, 'volume': '123.000000000000000001'},
        {'rank': 7, 'address': 'A' * 44, 'volume': '0'},
      ],
    }, eventId: 11);
    expect(b.rows.map((r) => r.rank), [7, 7]);
    expect(b.rows.first.volume.toString(), '123.000000000000000001');
    expect(() => b.rows.clear(), throwsUnsupportedError);
    expect(
      () => mapEventLeaderboard({
        'eventId': 12,
        'eventType': 'RETAIL',
        'rows': <Object>[],
      }, eventId: 11),
      throwsFormatException,
    );
  });
  test('top30 caps presentation after all rows have been validated', () {
    final rows = List.generate(
      31,
      (i) => <String, Object>{
        'rank': i + 1,
        'address': '0x${(i + 1).toRadixString(16).padLeft(40, '0')}',
        'volume': '0',
      },
    );
    expect(
      mapEventLeaderboard({
        'eventId': 11,
        'eventType': 'RETAIL',
        'rows': rows,
      }, eventId: 11).rows.length,
      30,
    );
    rows.last['address'] = rows.first['address']!;
    expect(
      () => mapEventLeaderboard({'eventId': 11, 'eventType': 'RETAIL', 'rows': rows}, eventId: 11),
      throwsFormatException,
    );
  });
  test('participant unknown differs from not registered and registered without a score', () {
    expect(
      () => mapEventParticipant({}, eventId: 11, address: pointsTestAddress),
      throwsFormatException,
    );
    var value = mapEventParticipant(
      {
        'registered': false,
        'stats': {'ownVolume': '999'},
      },
      eventId: 11,
      address: pointsTestAddress,
    );
    expect(value.registered, false);
    expect(value.ownVolume, null);
    value = mapEventParticipant({'registered': true}, eventId: 11, address: pointsTestAddress);
    expect(value.registered, true);
    expect(value.ownVolume, null);
  });
  test('participant explicit address and event cannot substitute requested scope', () {
    for (final fields in [
      {'address': '0x2222222222222222222222222222222222222222'},
      {'eventId': 12},
    ]) {
      expect(
        () => mapEventParticipant(
          {'registered': true, ...fields},
          eventId: 11,
          address: pointsTestAddress,
        ),
        throwsFormatException,
      );
    }
    final p = mapEventParticipant(
      {
        'registered': false,
        'registrationBlock': {'reason': 'exclusive', 'conflictingEventName': 'Other campaign'},
      },
      eventId: 11,
      address: pointsTestAddress,
    );
    expect(p.blockReason, 'exclusive');
    expect(p.conflictingEvent, 'Other campaign');
  });
  test(
    'native rule document preserves paragraph boundaries, escaped entities, lists, table and links',
    () {
      final d = mapEventDocument(
        '<h2>Rules &amp; rewards</h2><p>10<strong>,000</strong><br>USDC</p><ul><li><p>First</p><p>second</p></li></ul><a href="/points">More</a>',
      );
      expect(d.blocks.map((b) => b.text), [
        'Rules & rewards',
        '10,000 USDC',
        'First second',
        'More',
      ]);
      expect(d.blocks.last.url.toString(), 'https://app.vanta.exchange/points');
    },
  );
  test('script/style/forms/SVG never render; unsafe links/media do not launch', () {
    final d = mapEventDocument(
      '<script>secret()</script><style>bad</style><iframe src="https://evil.invalid"></iframe><svg><text>bad</text></svg><p>Safe <a href="javascript:alert(1)">text</a></p><img src="https://evil.invalid/track">',
    );
    expect(d.blocks.length, 1);
    expect(d.blocks.single.text, 'Safe text');
  });
  for (final url in [
    'javascript:alert(1)',
    'data:text/html,abc',
    'http://app.vanta.exchange/',
    'https://user:password@example.com/',
    'https://example.com:444/',
    'https://example.com/\nfoo',
  ]) {
    test(
      'untrusted link protocol/credentials rejected: ${url.hashCode}',
      () => expect(eventLink(url), null),
    );
  }
  test('only published raster storage origin is approved for image loading', () {
    const path =
        'https://nltkngcwiuydkpmqrili.supabase.co/storage/v1/object/public/trading-event-content/events/a.png';
    expect(eventLink(path, image: true), Uri.parse(path));
    expect(eventLink('https://nltkngcwiuydkpmqrili.supabase.co/other/a.png', image: true), null);
    expect(eventLink('https://example.com/a.png', image: true), null);
  });
  test('oversized or excessively nested rule documents fail with a safe mapping error', () {
    expect(() => mapEventDocument('x' * 131073), throwsFormatException);
    expect(() => mapEventDocument('${'<div>' * 70}text${'</div>' * 70}'), throwsFormatException);
  });
}
