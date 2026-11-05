import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/assistant/application/assistant_history_writer.dart';
import 'package:vanta/features/assistant/domain/assistant_history.dart';
import 'package:vanta/features/assistant/domain/assistant_session.dart';

import 'assistant_session_fixture.dart';

void main() {
  late AssistantAuthHarness h;
  late AssistantHistoryWriter writer;
  late List<String?> results;
  setUp(() {
    h = AssistantAuthHarness();
    results = [];
    writer = AssistantHistoryWriter(
      h.vault,
      AssistantSession(
        scope: h.scope,
        credentials: AssistantCredentials.fromResponse(assistantCredentialResponse()),
        verifiedAt: assistantTestTime,
      ),
      results.add,
    );
  });
  tearDown(() async {
    await writer.closeAndWait();
    h.close();
  });
  Future<AssistantHistory> saved() => h.vault.history(h.scope, assistantTestUser);
  int writes() => h.store.calls.where((c) => c.startsWith('write:')).length;

  test('typing coalesces latest snapshot and explicit flush saves it', () async {
    for (var i = 0; i < 100; i++) {
      writer.schedule(AssistantHistory(draft: 'draft $i'));
    }
    expect(writes(), 0);
    await writer.closeAndWait();
    expect(writes(), 1);
    expect((await saved()).draft, 'draft 99');
    expect(results, isEmpty);
  });
  test('continuous input checkpoints within 400ms rather than postponing indefinitely', () async {
    for (var i = 0; i < 5; i++) {
      writer.schedule(AssistantHistory(draft: 'draft $i'));
      await Future<void>.delayed(const Duration(milliseconds: 110));
    }
    expect(writes(), greaterThanOrEqualTo(1));
    await writer.closeAndWait();
    expect((await saved()).draft, 'draft 4');
  });
  test('one in-flight native save plus latest pending snapshot bounds writes', () async {
    final gate = Completer<void>(), started = Completer<void>();
    h.store.before = (op, key) async {
      if (op == 'write' && !started.isCompleted) {
        started.complete();
        await gate.future;
      }
    };
    writer.schedule(AssistantHistory(draft: 'first'));
    writer.flush();
    await started.future;
    for (var i = 0; i < 1000; i++) {
      writer.schedule(AssistantHistory(draft: 'latest $i'));
      writer.flush();
    }
    expect(writes(), 1);
    gate.complete();
    await writer.closeAndWait();
    expect(writes(), 2);
    expect((await saved()).draft, 'latest 999');
  });
  test('invalidated queued snapshot cannot reappear after explicit delete', () async {
    writer.schedule(AssistantHistory(draft: 'obsolete'));
    writer.invalidatePending();
    await h.vault.clearHistory(h.scope, assistantTestUser);
    await writer.closeAndWait();
    expect(writes(), 0);
    expect((await saved()).draft, isEmpty);
  });
  test('in-flight old write then new writer preserves newer snapshot in order', () async {
    final gate = Completer<void>(), started = Completer<void>();
    h.store.before = (op, key) async {
      if (op == 'write' && !started.isCompleted) {
        started.complete();
        await gate.future;
      }
    };
    writer.schedule(AssistantHistory(draft: 'old'));
    writer.flush();
    await started.future;
    final closing = writer.closeAndWait();
    gate.complete();
    await closing;
    writer = AssistantHistoryWriter(h.vault, writer.session, results.add);
    writer.schedule(AssistantHistory(draft: 'new'));
    await writer.closeAndWait();
    expect((await saved()).draft, 'new');
  });
  test('native failure is safe and later explicit save can recover', () async {
    h.store.before = (op, key) async {
      if (op == 'write') throw StateError('sensitive platform error');
    };
    writer.schedule(AssistantHistory(draft: 'preserve'));
    writer.flush();
    await Future<void>.delayed(Duration.zero);
    expect(results, ['assistantStorage']);
    h.store.before = null;
    writer.schedule(AssistantHistory(draft: 'preserve'));
    writer.flush();
    await Future<void>.delayed(Duration.zero);
    expect(results.last, null);
    expect((await saved()).draft, 'preserve');
  });
  test('closing suppresses late callbacks and later schedules', () async {
    final gate = Completer<void>(), started = Completer<void>();
    h.store.before = (op, key) async {
      if (op == 'write') {
        started.complete();
        await gate.future;
      }
    };
    writer.schedule(AssistantHistory(draft: 'old scope'));
    writer.flush();
    await started.future;
    final closing = writer.closeAndWait();
    writer.schedule(AssistantHistory(draft: 'new scope'));
    gate.complete();
    await closing;
    expect(results, isEmpty);
    expect((await saved()).draft, 'old scope');
    expect(writes(), 1);
  });
}
