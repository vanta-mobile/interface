import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';
import 'package:vanta/features/assistant/domain/assistant_session.dart';

import 'assistant_protocol_test.dart' show failure;
import 'assistant_session_fixture.dart';

void main() {
  late AssistantAuthHarness h;
  late AssistantSession session;
  setUp(() {
    h = AssistantAuthHarness();
    session = AssistantSession(
      scope: h.scope,
      credentials: AssistantCredentials.fromResponse(assistantCredentialResponse()),
      verifiedAt: h.time,
    );
  });
  tearDown(() => h.close());
  Future<AssistantQuota> read() =>
      h.repository.usage(session, cancellation: AssistantCancellation(), isCurrent: () => true);

  test('explicit UTC user-scoped usage reads do not fabricate remaining allowance', () async {
    expect(h.requests, isEmpty);
    final result = await read();
    expect(result.used, 2);
    expect(result.day, '2026-11-04');
    expect(result.limit, isNull);
    expect(result.remaining, isNull);
    expect(result.resetAt, isNull);
    final request = h.requests.last;
    expect(request.url.path, '/rest/v1/ai_daily_usage');
    expect(request.url.queryParameters, {
      'select': 'user_id,usage_date,request_count',
      'user_id': 'eq.$assistantTestUser',
      'usage_date': 'eq.2026-11-04',
      'limit': '2',
    });
    expect(request.headers['accept-profile'], 'vanta');
    expect(request.headers['authorization'], 'Bearer ${session.credentials.accessToken}');
    expect(h.signer.messages, isEmpty);
  });
  test('authoritative empty row means zero used but still unknown limit', () async {
    h.respond = (_) async => AssistantAuthHarness.response([]);
    final result = await read();
    expect(result.used, 0);
    expect(result.remaining, isNull);
  });
  final invalid = <Object?>[
    {},
    null,
    [null],
    [
      {'user_id': assistantOtherUser, 'usage_date': '2026-11-04', 'request_count': 2},
    ],
    [
      {'user_id': assistantTestUser, 'usage_date': '2026-11-03', 'request_count': 2},
    ],
    [
      {'user_id': assistantTestUser, 'usage_date': '2026-11-04', 'request_count': -1},
    ],
    [
      {'user_id': assistantTestUser, 'usage_date': '2026-11-04', 'request_count': 1.5},
    ],
    [
      {'user_id': assistantTestUser, 'usage_date': '2026-11-04', 'request_count': '2'},
    ],
    [
      {'user_id': assistantTestUser, 'usage_date': '2026-11-04', 'request_count': 1000000001},
    ],
    [<String, Object?>{}, <String, Object?>{}],
  ];
  for (final (index, value) in invalid.indexed) {
    test('rejects unknown or wrong usage row $index', () async {
      h.respond = (_) async => AssistantAuthHarness.response(value);
      await expectLater(read(), throwsA(failure('assistantInvalidResponse')));
    });
  }
  test('expired credentials require explicit restore and never issue usage request', () async {
    h.time = session.credentials.expiresAt;
    await expectLater(read(), throwsA(failure('assistantAuthorization')));
    expect(h.requests, isEmpty);
  });
  test('scope change during public config fetch prevents following personal request', () async {
    // The cached runtime is fetched before any authenticated request. The HTTP
    // guard must run again after that await, not only on entry to the repository.
    var checks = 0;
    await expectLater(
      h.repository.usage(
        session,
        cancellation: AssistantCancellation(),
        isCurrent: () => ++checks < 3,
      ),
      throwsA(failure('assistantSessionChanged')),
    );
    expect(h.requests.map((r) => r.url.path), ['/config.js']);
  });
  test('late usage after scope change cannot update another wallet', () async {
    var current = true;
    h.respond = (_) async {
      current = false;
      return null;
    };
    await expectLater(
      h.repository.usage(session, cancellation: AssistantCancellation(), isCurrent: () => current),
      throwsA(failure('assistantSessionChanged')),
    );
  });
}
