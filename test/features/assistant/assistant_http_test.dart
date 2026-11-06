import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/assistant/data/assistant_chat_repository.dart';
import 'package:vanta/features/assistant/data/assistant_configuration.dart';
import 'package:vanta/features/assistant/data/assistant_http.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';

import 'assistant_protocol_test.dart' show runtimeConfiguration, frame, failure, message;

const user = '00000000-1111-2222-3333-444444444444';
const requestId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const token = 'test-access-token';

http.Response jsonResponse(Object? value, [int status = 200]) =>
    http.Response(jsonEncode(value), status, headers: {'content-type': 'application/json'});
http.Response sseResponse(String value) =>
    http.Response(value, 200, headers: {'content-type': 'text/event-stream; charset=utf-8'});
http.Response configResponse() =>
    http.Response(runtimeConfiguration(), 200, headers: {'content-type': 'application/javascript'});

void main() {
  group('HTTP boundary', () {
    test('no network until explicit request; runtime cached only in service memory', () async {
      final requests = <http.Request>[];
      final service = AssistantHttp(
        client: MockClient((request) async {
          requests.add(request);
          return request.url == AssistantConfiguration.runtimeUri
              ? configResponse()
              : jsonResponse({'ok': true});
        }),
      );
      addTearDown(service.close);
      expect(requests, isEmpty);
      final cancellation = AssistantCancellation();
      for (var i = 0; i < 2; i++) {
        expect(
          await service.json('GET', '/rest/v1/example', cancellation: cancellation, token: token),
          {'ok': true},
        );
      }
      expect(requests, hasLength(3));
      expect(requests.first.headers.keys, isNot(contains('authorization')));
      for (final request in requests) {
        expect(request.followRedirects, isFalse);
      }
      expect(requests.last.url.origin, AssistantConfiguration.trustedOrigin.origin);
      expect(requests.last.headers['authorization'], 'Bearer $token');
      cancellation.cancel();
    });

    test('nonce requests use public key, not Privy credential', () async {
      final requests = <http.Request>[];
      final service = AssistantHttp(
        client: MockClient((request) async {
          requests.add(request);
          return request.url == AssistantConfiguration.runtimeUri
              ? configResponse()
              : jsonResponse({});
        }),
      );
      addTearDown(service.close);
      final cancellation = AssistantCancellation();
      await service.json(
        'POST',
        '/functions/v1/auth-nonce',
        cancellation: cancellation,
        body: {'address': 'example'},
      );
      final request = requests.last;
      expect(request.headers['authorization'], 'Bearer ${request.headers['apikey']}');
      expect(jsonDecode(request.body), {'address': 'example'});
      cancellation.cancel();
    });

    for (final status in [301, 302, 401, 403, 429, 500, 503]) {
      test('classifies $status without exposing server payload', () async {
        final service = AssistantHttp(
          client: MockClient(
            (request) async => request.url == AssistantConfiguration.runtimeUri
                ? configResponse()
                : jsonResponse({'error': 'private raw secret stack trace'}, status),
          ),
        );
        addTearDown(service.close);
        final cancellation = AssistantCancellation();
        try {
          await service.json('GET', '/rest/v1/example', cancellation: cancellation, token: token);
          fail('non-success was accepted');
        } on AssistantFailure catch (error) {
          expect(error.status, status);
          expect(
            error.key,
            status == 429
                ? 'assistantRateLimited'
                : [401, 403].contains(status)
                ? 'assistantAuthorization'
                : 'assistantUnavailable',
          );
          expect(error.toString(), isNot(contains('secret')));
        } finally {
          cancellation.cancel();
        }
      });
    }

    test('maps quota fields with UTC date and no fabricated default allowance', () async {
      final service = AssistantHttp(
        now: () => DateTime.parse('2026-11-04T00:01:00Z'),
        client: MockClient(
          (request) async => request.url == AssistantConfiguration.runtimeUri
              ? configResponse()
              : jsonResponse({
                  'code': 'daily_quota_exceeded',
                  'limit': 8,
                  'used': 8,
                  'remaining': 0,
                  'reset_at': '2026-11-05T00:00:00Z',
                }, 400),
        ),
      );
      addTearDown(service.close);
      final cancellation = AssistantCancellation();
      try {
        await service.json('GET', '/rest/v1/example', cancellation: cancellation);
        fail('quota error was accepted');
      } on AssistantFailure catch (error) {
        expect(error.key, 'assistantQuotaExceeded');
        expect(error.quota!.day, '2026-11-04');
        expect(error.quota!.remaining, 0);
        expect(error.quota!.limit, 8);
        expect(error.quota!.resetAt, DateTime.utc(2026, 11, 5));
        expect(error.canComplete, isFalse);
      } finally {
        cancellation.cancel();
      }
    });

    test('rejects wrong MIME, malformed JSON and oversized JSON', () async {
      for (final response in [
        http.Response('{}', 200),
        http.Response('<html>', 200, headers: {'content-type': 'application/json'}),
        jsonResponse({'payload': 'x' * 262144}),
      ]) {
        final service = AssistantHttp(
          client: MockClient(
            (request) async =>
                request.url == AssistantConfiguration.runtimeUri ? configResponse() : response,
          ),
        );
        final cancellation = AssistantCancellation();
        await expectLater(
          service.json('GET', '/rest/v1/example', cancellation: cancellation),
          throwsA(isA<AssistantFailure>()),
        );
        service.close();
        cancellation.cancel();
      }
    });

    for (final mode in ['cancel', 'timeout', 'close']) {
      test('$mode aborts pending response headers and cancels late body', () async {
        final header = Completer<http.StreamedResponse>(), entered = Completer<void>();
        final lateBody = StreamController<List<int>>();
        var cancelled = false, abortObserved = false;
        lateBody.onCancel = () {
          cancelled = true;
        };
        final service = AssistantHttp(
          requestTimeout: const Duration(milliseconds: 30),
          client: MockClient.streaming((request, body) async {
            await body.drain<void>();
            if (request.url == AssistantConfiguration.runtimeUri) {
              return http.StreamedResponse(Stream.value(utf8.encode(runtimeConfiguration())), 200);
            }
            (request as http.AbortableRequest).abortTrigger!.then((_) {
              abortObserved = true;
            });
            entered.complete();
            return header.future;
          }),
        );
        final cancellation = AssistantCancellation();
        final pending = service.json('GET', '/rest/v1/example', cancellation: cancellation);
        final check = expectLater(
          pending,
          throwsA(failure(mode == 'timeout' ? 'assistantTimeout' : 'assistantCancelled')),
        );
        await entered.future;
        if (mode == 'cancel') cancellation.cancel();
        if (mode == 'close') service.close();
        await check;
        header.complete(http.StreamedResponse(lateBody.stream, 200));
        await Future<void>.delayed(Duration.zero);
        expect(cancelled, isTrue);
        expect(abortObserved, isTrue);
        service.close();
        cancellation.cancel();
        await lateBody.close();
      });
    }

    for (final mode in ['cancel', 'idle', 'total', 'close']) {
      test('$mode terminates a stalled response body even if client ignores abort', () async {
        final source = StreamController<List<int>>(), entered = Completer<void>();
        var cancelled = false;
        source.onCancel = () {
          cancelled = true;
        };
        final service = AssistantHttp(
          chatTimeout: mode == 'total'
              ? const Duration(milliseconds: 25)
              : const Duration(seconds: 2),
          idleTimeout: mode == 'idle'
              ? const Duration(milliseconds: 25)
              : const Duration(seconds: 2),
          client: MockClient.streaming((request, body) async {
            await body.drain<void>();
            if (request.url == AssistantConfiguration.runtimeUri) {
              return http.StreamedResponse(Stream.value(utf8.encode(runtimeConfiguration())), 200);
            }
            entered.complete();
            return http.StreamedResponse(
              source.stream,
              200,
              headers: {'content-type': 'text/event-stream'},
            );
          }),
        );
        final cancellation = AssistantCancellation();
        final pending = service
            .chat(
              token: token,
              userId: user,
              requestId: requestId,
              messages: const [],
              cancellation: cancellation,
            )
            .toList();
        final check = expectLater(
          pending,
          throwsA(
            failure(['idle', 'total'].contains(mode) ? 'assistantTimeout' : 'assistantCancelled'),
          ),
        );
        await entered.future;
        // Let the body listener attach before interrupting it.
        await Future<void>.delayed(Duration.zero);
        if (mode == 'cancel') cancellation.cancel();
        if (mode == 'close') service.close();
        await check;
        expect(cancelled, isTrue);
        service.close();
        cancellation.cancel();
        await source.close();
      });
    }

    test('pre-cancelled and closed service perform no request', () async {
      var requests = 0;
      final service = AssistantHttp(
        client: MockClient((_) async {
          requests++;
          return configResponse();
        }),
      );
      final cancellation = AssistantCancellation()..cancel();
      await expectLater(
        service.configuration(cancellation),
        throwsA(failure('assistantCancelled')),
      );
      service.close();
      await expectLater(
        service.configuration(AssistantCancellation()),
        throwsA(failure('assistantCancelled')),
      );
      expect(requests, 0);
    });
  });

  group('one request through streaming and completion', () {
    late List<http.Request> requests;
    late AssistantHttp service;
    late AssistantChatRepository repository;
    late AssistantCancellation cancellation;
    late http.Response Function(http.Request request, int index) respond;
    setUp(() {
      requests = [];
      cancellation = AssistantCancellation();
      service = AssistantHttp(
        client: MockClient((request) async {
          if (request.url == AssistantConfiguration.runtimeUri) return configResponse();
          requests.add(request);
          return respond(request, requests.length);
        }),
      );
      repository = AssistantChatRepository(service);
    });
    tearDown(() {
      service.close();
      cancellation.cancel();
    });
    Stream<AssistantReplyUpdate> answer({String id = requestId, List<AssistantMessage>? history}) =>
        repository.answer(
          accessToken: token,
          userId: user,
          requestId: id,
          history: history ?? [message('question-id', 'BTC trend?')],
          cancellation: cancellation,
        );

    test('completes stream with reasoning and never issues completion request', () async {
      respond = (_, _) => sseResponse(
        '${frame(reasoning: 'context')}${frame(content: 'Answer')}${frame(finish: 'stop')}',
      );
      final updates = await answer().toList();
      expect(updates.last.delivery, AssistantDelivery.complete);
      expect(updates.last.content, 'Answer');
      expect(updates.last.reasoning, 'context');
      expect(requests, hasLength(1));
      expect(jsonDecode(requests.single.body), {
        'stream': true,
        'user': user,
        'request_id': requestId,
        'messages': [
          {'role': 'user', 'content': 'BTC trend?'},
        ],
      });
    });

    for (final stream in ['partial', 'empty', 'length', 'bad-frame', 'http500', 'wrong-mime']) {
      test('$stream falls back with exact same request and context', () async {
        respond = (_, index) => index > 1
            ? jsonResponse({'content': 'Completed', 'reasoning_content': 'fallback'})
            : switch (stream) {
                'partial' => sseResponse(frame(content: 'Part')),
                'empty' => sseResponse('data: [DONE]\n\n'),
                'length' => sseResponse(frame(content: 'Part', finish: 'length')),
                'bad-frame' => sseResponse('data: not-json\n\n'),
                'http500' => jsonResponse({'error': 'secret'}, 500),
                _ => jsonResponse({}),
              };
        final updates = await answer().toList();
        expect(updates.last.content, 'Completed');
        expect(updates.last.delivery, AssistantDelivery.complete);
        expect(requests, hasLength(2));
        final first = jsonDecode(requests.first.body) as Map<String, Object?>;
        final second = jsonDecode(requests.last.body) as Map<String, Object?>;
        expect(second, {...first, 'stream': false});
      });
    }

    test('reasoning-only completion retries final answer once with the same ID', () async {
      respond = (_, index) => switch (index) {
        1 => sseResponse(frame(content: 'Partial')),
        2 => jsonResponse({'reasoning_content': 'explanation'}),
        _ => jsonResponse({'content': 'Final'}),
      };
      final updates = await answer().toList();
      expect(updates.last.content, 'Final');
      expect(updates.last.reasoning, 'explanation');
      expect(requests, hasLength(3));
      final body = jsonDecode(requests.last.body) as Map<String, Object?>;
      expect(body['request_id'], requestId);
      expect((body['messages'] as List).last, {
        'role': 'system',
        'content': 'Please provide only the final answer to the user. Do not include reasoning or thinking process.',
      });
    });

    for (final status in [400, 401, 403, 429]) {
      test('$status never triggers fallback', () async {
        respond = (_, _) => jsonResponse({'error': 'hidden'}, status);
        await expectLater(answer().toList(), throwsA(isA<AssistantFailure>()));
        expect(requests, hasLength(1));
      });
    }

    test('stop during streaming preserves partial response and never completes', () async {
      respond = (_, _) => sseResponse(
        '${frame(content: 'Partial')}${frame(content: 'Later')}${frame(finish: 'stop')}',
      );
      final updates = <AssistantReplyUpdate>[];
      await for (final update in answer()) {
        updates.add(update);
        if (update.content == 'Partial') cancellation.cancel();
      }
      expect(updates.last.content, 'Partial');
      expect(updates.last.delivery, AssistantDelivery.interrupted);
      expect(requests, hasLength(1));
    });

    test('stop when fallback starts prevents a final-answer retry', () async {
      respond = (_, index) {
        if (index == 1) return sseResponse('data: [DONE]\n\n');
        cancellation.cancel();
        return jsonResponse({'reasoning_content': 'not a final answer'});
      };
      final updates = await answer().toList();
      expect(updates.last.delivery, AssistantDelivery.interrupted);
      expect(requests, hasLength(2));
    });

    test('fallback failure preserves original partial answer and safe failure', () async {
      respond = (_, index) => index == 1
          ? sseResponse(frame(content: 'Partial'))
          : jsonResponse({'error': 'secret'}, 503);
      final updates = <AssistantReplyUpdate>[];
      await expectLater(answer().forEach(updates.add), throwsA(failure('assistantUnavailable')));
      expect(updates.last.content, 'Partial');
      expect(updates.last.delivery, AssistantDelivery.failed);
      expect(requests, hasLength(2));
    });

    test('empty fallback never becomes a successful assistant message', () async {
      respond = (_, index) => index == 1 ? sseResponse('data: [DONE]\n\n') : jsonResponse({});
      await expectLater(answer().toList(), throwsA(failure('assistantEmptyReply')));
      expect(requests, hasLength(2));
    });

    test(
      'invalid request ID and oversized / missing final user turn never reach network',
      () async {
        respond = (_, _) {
          fail('must not send invalid input');
        };
        await expectLater(answer(id: 'not-id').toList(), throwsA(failure('assistantInvalidInput')));
        for (final history in <List<AssistantMessage>>[
          [],
          [message('id', '')],
          [message('id', 'x' * 12001)],
          [message('id', 'reply', role: AssistantRole.assistant)],
        ]) {
          await expectLater(
            answer(history: history).toList(),
            throwsA(failure('assistantInvalidInput')),
          );
        }
        expect(requests, isEmpty);
      },
    );
  });
}
