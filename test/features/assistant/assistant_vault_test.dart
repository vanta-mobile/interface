import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/assistant/data/assistant_history_codec.dart';
import 'package:vanta/features/assistant/data/assistant_secure_store.dart';
import 'package:vanta/features/assistant/data/assistant_vault.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';
import 'package:vanta/features/assistant/domain/assistant_history.dart';
import 'package:vanta/features/assistant/domain/assistant_session.dart';

import 'assistant_protocol_test.dart' show failure, message;
import 'assistant_session_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final scope = AssistantWalletScope.fromIdentity(assistantIdentity());
  final credentials = AssistantCredentials.fromResponse(assistantCredentialResponse());
  group('private native vault', () {
    late AssistantTestStore store;
    late AssistantVault vault;
    setUp(() {
      store = AssistantTestStore();
      vault = AssistantVault(store);
    });
    test('credentials survive reconstruction but do not carry authenticated status', () async {
      await vault.saveCredentials(scope, credentials, isCurrent: () => true);
      final restored = await AssistantVault(store).credentials(scope);
      expect(restored!.refreshToken, credentials.refreshToken);
      expect(restored.userId, assistantTestUser);
      final raw = jsonDecode(store.values.values.single) as Map;
      expect(raw.keys, unorderedEquals(['version', 'scope', 'credentials']));
      expect(raw, isNot(contains('verifiedAt')));
      expect(store.values.keys.single, isNot(contains(scope.identityId)));
      expect(store.values.keys.single, isNot(contains(scope.address)));
    });
    for (final other in [
      assistantIdentity(id: 'other'),
      assistantIdentity(kind: WalletKind.embedded),
      assistantIdentity(address: '0x${'22' * 20}'),
    ]) {
      test(
        'credential lookup isolated for ${other.id}/${other.walletKind}/${other.walletAddress}',
        () async {
          await vault.saveCredentials(scope, credentials, isCurrent: () => true);
          expect(await vault.credentials(AssistantWalletScope.fromIdentity(other)), isNull);
        },
      );
    }
    test('scope envelopes reject copied credential and history payloads', () async {
      final other = AssistantWalletScope.fromIdentity(assistantIdentity(id: 'other'));
      await vault.saveCredentials(scope, credentials, isCurrent: () => true);
      await vault.saveCredentials(other, credentials, isCurrent: () => true);
      final keys = store.values.keys.toList();
      store.values[keys.last] = store.values[keys.first]!;
      await expectLater(vault.credentials(other), throwsA(failure('assistantStorage')));
    });
    for (final raw in ['{broken', 'null', '{}', '{"version":2}', 'x' * 32769]) {
      test('corrupt credential remains stored until explicit deletion: ${raw.length}', () async {
        await vault.saveCredentials(scope, credentials, isCurrent: () => true);
        store.values[store.values.keys.single] = raw;
        await expectLater(vault.credentials(scope), throwsA(failure('assistantStorage')));
        expect(store.values.values.single, raw);
        await vault.forgetCredentials(scope);
        expect(await vault.credentials(scope), isNull);
      });
    }
    test('changed scope stops queued writes before they reach native storage', () async {
      final gate = Completer<void>(), entered = Completer<void>();
      store.before = (operation, _) async {
        if (operation == 'read') {
          entered.complete();
          await gate.future;
        }
      };
      final read = vault.credentials(scope);
      await entered.future;
      var current = true;
      final write = vault.saveCredentials(scope, credentials, isCurrent: () => current);
      final check = expectLater(write, throwsA(failure('assistantSessionChanged')));
      current = false;
      gate.complete();
      expect(await read, isNull);
      await check;
      expect(store.calls.where((e) => e.startsWith('write:')), isEmpty);
    });
    test('clear is serialized after in-flight save and never deletes other namespaces', () async {
      final gate = Completer<void>(), entered = Completer<void>();
      store.values['privy:unrelated'] = 'unrelated';
      store.before = (operation, _) async {
        if (operation == 'write') {
          entered.complete();
          await gate.future;
        }
      };
      final save = vault.saveCredentials(scope, credentials, isCurrent: () => true);
      await entered.future;
      final clear = vault.forgetCredentials(scope);
      gate.complete();
      await save;
      await clear;
      expect(store.values, {'privy:unrelated': 'unrelated'});
    });
    for (final operation in ['read', 'write', 'delete']) {
      test('native $operation failure is safe and does not poison operation queue', () async {
        store.before = (op, _) async {
          if (op == operation) throw StateError('private stack/token');
        };
        final failed = switch (operation) {
          'read' => vault.credentials(scope),
          'write' => vault.saveCredentials(scope, credentials, isCurrent: () => true),
          _ => vault.forgetCredentials(scope),
        };
        await expectLater(failed, throwsA(failure('assistantStorage')));
        store.before = null;
        await vault.saveCredentials(scope, credentials, isCurrent: () => true);
        expect((await vault.credentials(scope))!.userId, assistantTestUser);
      });
    }
    test('history clear and credential forget have independent scopes', () async {
      await vault.saveCredentials(scope, credentials, isCurrent: () => true);
      await vault.saveHistory(
        scope,
        assistantTestUser,
        AssistantHistory(messages: [message('q', 'question')], draft: 'draft'),
        isCurrent: () => true,
      );
      expect((await vault.history(scope, assistantOtherUser)).messages, isEmpty);
      await vault.clearHistory(scope, assistantTestUser);
      expect(await vault.credentials(scope), isNotNull);
      expect((await vault.history(scope, assistantTestUser)).draft, '');
      await vault.saveHistory(
        scope,
        assistantTestUser,
        AssistantHistory(draft: 'retained'),
        isCurrent: () => true,
      );
      await vault.forgetCredentials(scope);
      expect((await vault.history(scope, assistantTestUser)).draft, 'retained');
    });
  });

  group('bounded history codec', () {
    test(
      'reconstruction retains draft/partial but marks interrupted and never resumes generation',
      () {
        final history = AssistantHistory(
          messages: [
            message('q', '问题'),
            message(
              'a',
              '部分',
              role: AssistantRole.assistant,
              reasoning: '解释',
              delivery: AssistantDelivery.streaming,
            ),
          ],
          draft: '尚未发送',
        );
        final raw = AssistantHistoryCodec.encode(scope, assistantTestUser, history);
        final restored = AssistantHistoryCodec.decode(scope, assistantTestUser, raw);
        expect(restored.draft, '尚未发送');
        expect(restored.messages.last.content, '部分');
        expect(restored.messages.last.reasoning, '解释');
        expect(restored.messages.last.delivery, AssistantDelivery.interrupted);
        expect(() => restored.messages.clear(), throwsUnsupportedError);
      },
    );
    test('retains latest200 and bounds UTF8 bytes without truncating individual content', () {
      final history = AssistantHistory(
        messages: [for (var i = 0; i < 210; i++) message('$i', '你好' * 3000)],
      );
      final raw = AssistantHistoryCodec.encode(scope, assistantTestUser, history);
      expect(utf8.encode(raw).length, lessThanOrEqualTo(AssistantHistoryCodec.maxBytes));
      final restored = AssistantHistoryCodec.decode(scope, assistantTestUser, raw);
      expect(restored.messages.length, lessThanOrEqualTo(200));
      expect(restored.messages.last.id, '209');
      expect(restored.messages.first.content, history.messages.first.content);
    });
    test('a single large escaped reply fails safely rather than silently truncating', () {
      final history = AssistantHistory(
        messages: [message('a', '\x01' * 131072, role: AssistantRole.assistant)],
      );
      expect(
        () => AssistantHistoryCodec.encode(scope, assistantTestUser, history),
        throwsA(failure('assistantStorageCapacity')),
      );
    });
    final base = AssistantHistoryCodec.encode(
      scope,
      assistantTestUser,
      AssistantHistory(messages: [message('q', 'question')]),
    );
    final invalid = <void Function(Map<String, Object?>)>[
      (m) => m['version'] = 2,
      (m) => m['scope'] = 'other',
      (m) => m['user'] = assistantOtherUser,
      (m) => m['draft'] = 'x' * 12001,
      (m) => m['messages'] = 'not-list',
      (m) => (m['messages'] as List).add((m['messages'] as List).single),
      (m) => ((m['messages'] as List).single as Map)['role'] = 'system',
      (m) => ((m['messages'] as List).single as Map)['delivery'] = 'unknown',
      (m) => ((m['messages'] as List).single as Map)['createdAt'] = '2026-02-31',
      (m) => ((m['messages'] as List).single as Map)['reasoning'] = 'user must not have reasoning',
      (m) => ((m['messages'] as List).single as Map)['content'] = 'x' * 12001,
      (m) => ((m['messages'] as List).single as Map)['id'] = '',
    ];
    for (final (index, mutate) in invalid.indexed) {
      test('rejects corrupt/scoped history $index', () {
        final value = jsonDecode(base) as Map<String, Object?>;
        mutate(value);
        expect(
          () => AssistantHistoryCodec.decode(scope, assistantTestUser, jsonEncode(value)),
          throwsA(failure('assistantStorage')),
        );
      });
    }
    test('bounds oversized stored input before parsing', () {
      expect(
        () => AssistantHistoryCodec.decode(
          scope,
          assistantTestUser,
          'x' * (AssistantHistoryCodec.maxBytes + 1),
        ),
        throwsA(failure('assistantStorage')),
      );
    });
  });

  group('native plugin configuration (synthetic channel only)', () {
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('$platform isolates AI values and never calls deleteAll', () async {
        debugDefaultTargetPlatformOverride = platform;
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call);
            return call.method == 'read' ? 'stored' : null;
          },
        );
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });
        final store = NativeAssistantSecureStore();
        await store.write('scoped-key', 'test-value');
        expect(await store.read('scoped-key'), 'stored');
        await store.delete('scoped-key');
        expect(calls.map((c) => c.method), ['write', 'read', 'delete']);
        final options = (calls.first.arguments as Map)['options'] as Map;
        if (platform == TargetPlatform.android) {
          expect(options['storageNamespace'], 'vanta_assistant_v1');
          expect(options['resetOnError'], 'false');
        } else {
          expect(options['accountName'], 'vanta_assistant_v1');
          expect(options['accessibility'], 'unlocked_this_device');
          expect(options['synchronizable'], 'false');
        }
      });
    }
  });
}
