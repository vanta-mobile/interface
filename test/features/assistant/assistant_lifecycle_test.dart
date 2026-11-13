import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta/features/assistant/application/assistant_provider.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';
import 'package:vanta/features/assistant/domain/assistant_history.dart';
import 'package:vanta/features/assistant/domain/assistant_session.dart';
import 'package:vanta/features/market/application/market_providers.dart';

import 'assistant_application_fixture.dart';
import 'assistant_session_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AssistantApplicationHarness h;
  setUp(() async {
    h = AssistantApplicationHarness();
    await h.ready();
  });
  tearDown(() => h.close());
  test('expired challenge is discarded on resume and does not sign', () async {
    await h.controller.prepare();
    final original = h.state.challenge!;
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    h.auth.time = h.auth.time.add(const Duration(minutes: 5));
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await h.controller.confirm(original);
    expect(h.auth.signer.messages, isEmpty);
    expect(h.state.challenge, null);
    expect(h.state.phase, AssistantPhase.idle);
  });
  test('reauthorization rejection retains existing conversation and draft', () async {
    await h.login();
    h.controller.setDraft('first');
    await h.controller.send();
    h.controller.setDraft('next');
    await h.controller.prepare();
    h.auth.signer.respond = (_) async => throw const AssistantFailure('assistantCancelled');
    await h.controller.confirm(h.state.challenge!);
    expect(h.state.authenticated, true);
    expect(h.state.historyReady, true);
    expect(h.state.messages.last.content, 'A useful answer');
    expect(h.state.draft, 'next');
    expect(h.state.failureKey, 'assistantCancelled');
  });
  test('reauthorization for same server user keeps memory and latest draft', () async {
    await h.login();
    h.controller.setDraft('first');
    await h.controller.send();
    h.controller.setDraft('next');
    await h.controller.prepare();
    await h.controller.confirm(h.state.challenge!);
    expect(h.state.messages.length, 2);
    expect(h.state.draft, 'next');
    expect(h.state.historyReady, true);
    expect((await h.auth.vault.history(h.auth.scope, assistantTestUser)).draft, 'next');
  });
  test('restored interrupted messages and draft never resume chat automatically', () async {
    await h.auth.vault.saveHistory(
      h.auth.scope,
      assistantTestUser,
      AssistantHistory(
        draft: 'unsent',
        messages: [
          AssistantMessage(
            id: 'partial',
            role: AssistantRole.assistant,
            content: 'partial',
            createdAt: assistantTestTime,
            delivery: AssistantDelivery.streaming,
          ),
        ],
      ),
      isCurrent: () => true,
    );
    await h.auth.vault.saveCredentials(
      h.auth.scope,
      AssistantCredentials.fromResponse(assistantCredentialResponse()),
      isCurrent: () => true,
    );
    await h.controller.restore();
    expect(h.state.messages.single.delivery, AssistantDelivery.interrupted);
    expect(h.state.draft, 'unsent');
    expect(h.chat.calls, 0);
    expect(h.auth.signer.messages, isEmpty);
  });
  test('failed history load retries explicitly without losing stored data', () async {
    await h.auth.vault.saveHistory(
      h.auth.scope,
      assistantTestUser,
      AssistantHistory(draft: 'saved'),
      isCurrent: () => true,
    );
    h.auth.store.before = (op, key) async {
      if (op == 'read' && key.contains('.history.')) throw StateError('locked');
    };
    await h.login();
    expect(h.state.historyReady, false);
    expect(h.state.storageFailureKey, 'assistantStorage');
    h.auth.store.before = null;
    await h.controller.retryHistory();
    expect(h.state.historyReady, true);
    expect(h.state.draft, 'saved');
    expect(h.state.storageFailureKey, null);
  });
  test('disposal during clear cannot resurrect data from in-flight native write', () async {
    await h.login();
    final gate = Completer<void>(), started = Completer<void>();
    h.auth.store.before = (op, key) async {
      if (op == 'write' && key.contains('.history.') && !started.isCompleted) {
        started.complete();
        await gate.future;
      }
    };
    h.controller.setDraft('delete me');
    h.controller.retrySave();
    await started.future;
    final clearing = h.controller.clearHistory(h.state.scopeVersion);
    final closing = h.close();
    gate.complete();
    await clearing;
    await closing;
    final saved = await h.auth.vault.history(h.auth.scope, assistantTestUser);
    expect(saved.messages, isEmpty);
    expect(saved.draft, isEmpty);
  });
  test('wallet switch during read ignores old response and does not adopt history', () async {
    await h.login();
    bool usage(http.Request r) => r.url.path.endsWith('ai_daily_usage');
    final reads = h.auth.requests.where(usage).length;
    final gate = Completer<http.Response?>(), started = Completer<void>();
    h.auth.respond = (r) async {
      if (r.url.path == '/auth/v1/user') {
        started.complete();
        return gate.future;
      }
      return null;
    };
    final reading = h.controller.readUsage();
    await started.future;
    h.identity.events.add(assistantIdentity(id: 'new'));
    await h.ready();
    gate.complete(AssistantAuthHarness.response({'id': assistantTestUser}));
    await reading;
    expect(h.state.authenticated, false);
    expect(h.state.quota, null);
    expect(h.state.messages, isEmpty);
    expect(h.auth.requests.where(usage), hasLength(reads));
  });
  test('a completed send reads usage again instead of guessing the new count', () async {
    await h.login();
    bool usage(http.Request r) => r.url.path.endsWith('ai_daily_usage');
    final reads = h.auth.requests.where(usage).length;
    expect(h.state.quotaStale, false);
    h.controller.setDraft('next');
    await h.controller.send();
    expect(h.auth.requests.where(usage), hasLength(reads + 1));
    expect(h.state.quotaStale, false);
    expect(h.state.quota!.used, 2);
  });
  test('quota error drops the refused turn, keeps the input and blocks another send', () async {
    await h.login();
    h.chat.respond = (_) async* {
      throw const AssistantFailure(
        'assistantQuotaExceeded',
        quota: AssistantQuota(day: '2026-11-04', remaining: 0),
      );
    };
    h.controller.setDraft('question');
    await h.controller.send();
    expect(h.state.remaining, 0);
    // Without a reported limit the website default is kept for display only.
    expect(h.state.quota!.limit, assistantDefaultDailyLimit);
    expect(h.state.limitReachedAt, isNotNull);
    expect(h.state.messages, isEmpty);
    expect(h.state.canSend, false);
    await h.controller.send();
    await h.controller.send(prompt: 'suggested');
    expect(h.chat.calls, 1);
    expect(h.state.draft, 'question');
  });
  test('new UTC date and clock rollback mark quota stale without automatic network', () async {
    await h.login();
    await h.controller.readUsage();
    final count = h.auth.requests.length;
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    h.auth.time = h.auth.time.subtract(const Duration(seconds: 1));
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    expect(h.state.quotaStale, true);
    expect(h.auth.requests.length, count);
  });
  test('oversized prompt is retained visibly but cannot be submitted', () async {
    await h.login();
    h.controller.setDraft('😀' * 6001);
    await h.controller.send();
    expect(h.state.draft.length, 12002);
    expect(h.state.failureKey, 'assistantInvalidInput');
    expect(h.chat.calls, 0);
  });
}
