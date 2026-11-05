import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/assistant/data/assistant_configuration.dart';
import 'package:vanta/features/assistant/data/assistant_sse.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';

String runtimeConfiguration({
  String? url,
  String role = 'anon',
  String ref = 'nltkngcwiuydkpmqrili',
}) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final key = '${part({'alg': 'HS256'})}.${part({'role': role, 'ref': ref})}.ZmFrZQ';
  return 'window.__RUNTIME_CONFIG__ = ${jsonEncode({'VITE_SUPABASE_URL': url ?? AssistantConfiguration.trustedOrigin.origin, 'VITE_SUPABASE_ANON_KEY': key})};';
}

String frame({String? content, String? reasoning, String? thinking, String? finish}) =>
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': ?content, 'reasoning_content': ?reasoning, 'thinking_delta': ?thinking},
          'finish_reason': finish,
        },
      ],
    })}\r\n\r\n';

Matcher failure(String key) => isA<AssistantFailure>().having((e) => e.key, 'safe key', key);

AssistantMessage message(
  String id,
  String content, {
  AssistantRole role = AssistantRole.user,
  String reasoning = '',
  AssistantDelivery delivery = AssistantDelivery.complete,
}) => AssistantMessage(
  id: id,
  role: role,
  content: content,
  reasoning: reasoning,
  createdAt: DateTime.utc(2026, 11, 4),
  delivery: delivery,
);

void main() {
  group('runtime config boundary', () {
    test('parses public JSON wrapper without exposing key through toString', () {
      final config = AssistantConfiguration.fromRuntime(runtimeConfiguration());
      expect(config.origin, AssistantConfiguration.trustedOrigin);
      expect(config.toString(), isNot(contains(config.publicKey)));
    });
    for (final url in [
      'http://nltkngcwiuydkpmqrili.supabase.co',
      'https://nltkngcwiuydkpmqrili.supabase.co.evil.invalid',
      'https://evil.invalid',
      '${AssistantConfiguration.trustedOrigin.origin}/',
      '${AssistantConfiguration.trustedOrigin.origin}/other',
    ]) {
      test('rejects changed configured origin $url', () {
        expect(
          () => AssistantConfiguration.fromRuntime(runtimeConfiguration(url: url)),
          throwsA(failure('assistantConfiguration')),
        );
      });
    }
    for (final source in [
      'window.__RUNTIME_CONFIG__ = {}; alert(1);',
      'window.__RUNTIME_CONFIG__ = (() => ({}))();',
      'export default {};',
      '{}',
      'window.__RUNTIME_CONFIG__ = {"__proto__": {}};',
      'window.__RUNTIME_CONFIG__ = {"VITE_SUPABASE_URL": null};',
    ]) {
      test('rejects executable or incomplete runtime data ${source.length}', () {
        expect(
          () => AssistantConfiguration.fromRuntime(source),
          throwsA(failure('assistantConfiguration')),
        );
      });
    }
    test('rejects privileged and wrong-project public keys', () {
      for (final source in [
        runtimeConfiguration(role: 'service_role'),
        runtimeConfiguration(ref: 'other'),
      ]) {
        expect(
          () => AssistantConfiguration.fromRuntime(source),
          throwsA(failure('assistantConfiguration')),
        );
      }
    });
    test('rejects oversized runtime data', () {
      expect(
        () => AssistantConfiguration.fromRuntime('${runtimeConfiguration()}${' ' * 65536}'),
        throwsA(failure('assistantConfiguration')),
      );
    });
  });

  group('incremental SSE', () {
    final wire =
        ': keepalive\r\n\r\n${frame(content: '你好 🦋', reasoning: '背景')}'
        '${frame(content: ' conclusion', thinking: ' next')}${frame(finish: 'stop')}';
    final encoded = utf8.encode(wire);
    for (final size in [1, 2, 3, 4, 7, 64, 65536]) {
      test('preserves UTF8 and split CRLF with $size byte chunks', () async {
        final chunks = <List<int>>[];
        for (var i = 0; i < encoded.length; i += size) {
          chunks.add(encoded.sublist(i, (i + size).clamp(0, encoded.length)));
        }
        final values = await decodeAssistantSse(Stream.fromIterable(chunks)).toList();
        expect(values.map((e) => e.content).join(), '你好 🦋 conclusion');
        expect(values.map((e) => e.reasoning).join(), '背景 next');
        expect(values.last.done, isTrue);
      });
    }
    for (final finish in ['stop', 'end_turn', 'length']) {
      test('maps terminal $finish and ignores bytes after termination', () async {
        final values = await decodeAssistantSse(
          Stream.value(utf8.encode('${frame(content: 'answer', finish: finish)}data: bad\n\n')),
        ).toList();
        expect(values, hasLength(1));
        expect(values.single.done, finish != 'length');
        expect(values.single.truncated, finish == 'length');
      });
    }
    test('accepts DONE sentinel and a final frame without blank line', () async {
      final done = await decodeAssistantSse(Stream.value(utf8.encode('data: [DONE]'))).toList();
      expect(done.single.done, isTrue);
      final tail = await decodeAssistantSse(
        Stream.value(utf8.encode(frame(content: 'tail').trimRight())),
      ).toList();
      expect(tail.single.content, 'tail');
    });
    test('supports multiline data and role / usage-only frames', () async {
      final values = await decodeAssistantSse(
        Stream.value(
          utf8.encode(
            'event: message\ndata: {"choices":\ndata: [{"delta":{"role":"assistant"}}]}\n\n'
            'data: {"choices":[],"usage":{"tokens":1}}\n\n'
            'data: [DONE]\n\n',
          ),
        ),
      ).toList();
      expect(values, hasLength(2));
      expect(values.last.done, isTrue);
    });
    for (final bad in [
      'oops',
      'null',
      '[]',
      '{}',
      '{"choices":null}',
      '{"choices":[null]}',
      '{"choices":[{"delta":false}]}',
      '{"choices":[{"delta":{"content":7}}]}',
      '{"choices":[{"delta":{"reasoning_content":[]}}]}',
      '{"choices":[{"finish_reason":4}]}',
    ]) {
      test('rejects malformed frame $bad', () async {
        await expectLater(
          decodeAssistantSse(Stream.value(utf8.encode('data: $bad\n\n'))).toList(),
          throwsA(failure('assistantInvalidResponse')),
        );
      });
    }
    test('rejects invalid UTF8', () async {
      await expectLater(
        decodeAssistantSse(Stream.value([0xff])).toList(),
        throwsA(failure('assistantInvalidResponse')),
      );
    });
    test('bounds unterminated lines even across chunks', () async {
      await expectLater(
        decodeAssistantSse(
          Stream.fromIterable([utf8.encode('data:'), utf8.encode('a' * 60), utf8.encode('b' * 60)]),
          maxFrameCharacters: 100,
        ).toList(),
        throwsA(failure('assistantTooLarge')),
      );
    });
    test('bounds aggregate multiline frame', () async {
      await expectLater(
        decodeAssistantSse(
          Stream.value(utf8.encode('${': x\n' * 100}\n')),
          maxFrameCharacters: 50,
        ).toList(),
        throwsA(failure('assistantTooLarge')),
      );
    });
    test('bounds total bytes across frames', () async {
      await expectLater(
        decodeAssistantSse(
          Stream.value(utf8.encode(frame(content: 'x'))),
          maxResponseBytes: 10,
        ).toList(),
        throwsA(failure('assistantTooLarge')),
      );
    });
    test('bounds answer plus reasoning including tail', () async {
      for (final wire in [
        frame(content: '12', reasoning: '34'),
        frame(content: '1234').trimRight(),
      ]) {
        await expectLater(
          decodeAssistantSse(Stream.value(utf8.encode(wire)), maxAnswerCharacters: 3).toList(),
          throwsA(failure('assistantTooLarge')),
        );
      }
    });
    test('terminal frame cancels the upstream stream', () async {
      var cancelled = false;
      final source = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final result = decodeAssistantSse(source.stream).toList();
      source.add(utf8.encode('data: [DONE]\n\n'));
      expect((await result).single.done, isTrue);
      expect(cancelled, isTrue);
      await source.close();
    });
  });

  group('context and cancellation', () {
    test('drops oldest context to 12000 without exposing reasoning or IDs', () {
      final context = assistantContext([
        message('secret-id', 'a' * 7000, role: AssistantRole.assistant, reasoning: 'not context'),
        message('new', 'b' * 6000),
      ]);
      expect(context, [
        {'role': 'user', 'content': 'b' * 6000},
      ]);
      expect(() => context.add({}), throwsUnsupportedError);
      expect(() => context.single['role'] = 'system', throwsUnsupportedError);
    });
    test('does not resend unsuccessful partial replies or empty messages', () {
      final context = assistantContext([
        for (final state in AssistantDelivery.values.where((e) => e != AssistantDelivery.complete))
          message(state.name, 'partial', delivery: state, role: AssistantRole.assistant),
        message('blank', '  '),
        message('valid', '  question  '),
      ]);
      expect(context, [
        {'role': 'user', 'content': 'question'},
      ]);
    });
    test('cancellation is idempotent and safe to stringify', () async {
      final cancellation = AssistantCancellation();
      cancellation.check();
      cancellation.cancel();
      cancellation.cancel();
      await cancellation.whenCancelled;
      expect(cancellation.check, throwsA(failure('assistantCancelled')));
      expect(
        const AssistantFailure('assistantUnavailable').toString(),
        'AssistantFailure(assistantUnavailable)',
      );
    });
  });
}
