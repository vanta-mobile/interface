import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta/features/assistant/application/assistant_provider.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';
import 'package:vanta/features/assistant/domain/assistant_history.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
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
  tearDown(() async {
    await h.close();
  });

  test('entry neither reads native credentials nor signs or calls personal APIs', () {
    expect(h.state.authenticated, false);
    expect(h.auth.store.calls, isEmpty);
    expect(h.auth.requests, isEmpty);
    expect(h.auth.signer.messages, isEmpty);
    expect(h.chat.calls, 0);
  });
  test('separate exact challenge confirmation authenticates and loads scoped history', () async {
    await h.controller.prepare();
    expect(h.state.phase, AssistantPhase.review);
    expect(
      h.state.challenge!.message,
      assistantChallengeText(address: assistantTestAddress.toLowerCase()),
    );
    expect(h.auth.signer.messages, isEmpty);
    expect(h.state.authenticated, false);
    await h.controller.confirm(h.state.challenge!);
    expect(h.state.authenticated, true);
    expect(h.state.historyReady, true);
    expect(h.auth.signer.messages, [
      assistantChallengeText(address: assistantTestAddress.toLowerCase()),
    ]);
    expect(h.state.toString(), isNot(contains('test-refresh')));
    expect(h.identity.wallets, 0);
  });
  test('challenge review blocks sending and draft changes during reauthorization', () async {
    await h.login();
    h.controller.setDraft('preserve');
    await h.controller.prepare();
    h.controller.setDraft('replace');
    expect(h.state.draft, 'preserve');
    expect(h.state.canSend, false);
    await h.controller.send();
    expect(h.chat.calls, 0);
    h.controller.stop();
    expect(h.state.draft, 'preserve');
    expect(h.state.canSend, true);
  });
  test('no saved session does not silently sign or create wallet', () async {
    await h.controller.restore();
    expect(h.state.failureKey, 'assistantNoSavedSession');
    expect(h.auth.requests, isEmpty);
    expect(h.auth.signer.messages, isEmpty);
    expect(h.identity.wallets, 0);
  });
  test('expected external-wallet background waits for foreground before verify POST', () async {
    await h.controller.prepare();
    final signature = Completer<String>();
    h.auth.signer.respond = (_) => signature.future;
    final confirming = h.controller.confirm(h.state.challenge!);
    await h.ready();
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    signature.complete(
      assistantTestSignature(assistantChallengeText(address: assistantTestAddress.toLowerCase())),
    );
    await h.ready();
    expect(h.state.phase, AssistantPhase.signing);
    expect(h.auth.requests.where((r) => r.url.path.endsWith('/verify-wallet')), isEmpty);
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await confirming;
    expect(h.state.authenticated, true);
  });
  test('stop while awaiting foreground prevents a late verify or wallet adoption', () async {
    await h.controller.prepare();
    final signature = Completer<String>();
    h.auth.signer.respond = (_) => signature.future;
    final confirming = h.controller.confirm(h.state.challenge!);
    await h.ready();
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    signature.complete(
      assistantTestSignature(assistantChallengeText(address: assistantTestAddress.toLowerCase())),
    );
    await h.ready();
    h.controller.stop();
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await confirming;
    expect(h.state.authenticated, false);
    expect(h.auth.requests.where((r) => r.url.path.endsWith('/verify-wallet')), isEmpty);
  });
  for (final next in [
    assistantIdentity(id: 'other'),
    assistantIdentity(address: '0x${'22' * 20}'),
    assistantIdentity(kind: WalletKind.embedded),
    assistantIdentity(signing: false),
  ]) {
    test('identity scope or signing change clears personal view: $next', () async {
      await h.login();
      h.controller.setDraft('private');
      final version = h.state.scopeVersion;
      h.identity.events.add(next);
      await h.ready();
      expect(h.state.authenticated, false);
      expect(h.state.messages, isEmpty);
      expect(h.state.draft, isEmpty);
      expect(h.state.scopeVersion, greaterThan(version));
      await h.controller.clearHistory(version);
      expect(h.auth.store.calls.where((c) => c.startsWith('delete:')), isEmpty);
    });
  }
  test(
    'preflight persists turn before chat; context has no automatic wallet/account attachment',
    () async {
      await h.login();
      h.controller.setDraft('Question');
      h.chat.respond = (_) async* {
        final stored = await h.auth.vault.history(h.auth.scope, assistantTestUser);
        expect(stored.messages.first.content, 'Question');
        expect(stored.messages.last.delivery, AssistantDelivery.interrupted);
        yield const AssistantReplyUpdate(
          content: 'Answer',
          reasoning: '',
          delivery: AssistantDelivery.complete,
        );
      };
      await h.controller.send();
      expect(h.state.messages.last.content, 'Answer');
      expect(h.state.draft, '');
      expect(h.chat.sentHistory!.single.content, 'Question');
      expect(h.chat.requestIds.single, matches(RegExp(r'^[a-f0-9-]{36}$')));
      expect(h.state.messages.last.delivery, AssistantDelivery.complete);
    },
  );
  test('failed staging native write preserves input and sends no chat', () async {
    await h.login();
    h.auth.store.before = (op, key) async {
      if (op == 'write' && key.contains('.history.')) throw StateError('secret platform error');
    };
    h.controller.setDraft('keep me');
    await h.controller.send();
    expect(h.chat.calls, 0);
    expect(h.state.draft, 'keep me');
    expect(h.state.failureKey, 'assistantStorage');
    expect(h.state.messages, isEmpty);
  });
  test(
    'stopped preflight does not send, and late native staging is overwritten with unsent draft',
    () async {
      await h.login();
      final gate = Completer<void>(), started = Completer<void>();
      h.auth.store.before = (op, key) async {
        if (op == 'write' && key.contains('.history.') && !started.isCompleted) {
          started.complete();
          await gate.future;
        }
      };
      h.controller.setDraft('unsent');
      final sending = h.controller.send();
      await started.future;
      h.controller.stop();
      gate.complete();
      await sending;
      await h.ready();
      expect(h.chat.calls, 0);
      expect(h.state.draft, 'unsent');
      expect(h.state.messages, isEmpty);
      final stored = await h.auth.vault.history(h.auth.scope, assistantTestUser);
      expect(stored.messages, isEmpty);
      expect(stored.draft, 'unsent');
    },
  );
  test('stop keeps partial response/new draft and ignores late stream update', () async {
    await h.login();
    final events = StreamController<AssistantReplyUpdate>();
    h.chat.respond = (_) => events.stream;
    h.controller.setDraft('first');
    final sending = h.controller.send();
    await h.ready();
    events.add(
      const AssistantReplyUpdate(
        content: 'partial',
        reasoning: '',
        delivery: AssistantDelivery.streaming,
      ),
    );
    await h.ready();
    h.controller.setDraft('next');
    h.controller.stop();
    events.add(
      const AssistantReplyUpdate(
        content: 'late',
        reasoning: '',
        delivery: AssistantDelivery.complete,
      ),
    );
    await events.close();
    await sending;
    expect(h.state.messages.last.content, 'partial');
    expect(h.state.messages.last.delivery, AssistantDelivery.interrupted);
    expect(h.state.draft, 'next');
    expect(h.chat.calls, 1);
  });
  test('chat failure preserves new draft over previous prompt', () async {
    await h.login();
    final gate = Completer<void>();
    h.chat.respond = (_) async* {
      await gate.future;
      throw const AssistantFailure('assistantUnavailable');
    };
    h.controller.setDraft('first');
    final sending = h.controller.send();
    await h.ready();
    h.controller.setDraft('next');
    gate.complete();
    await sending;
    expect(h.state.draft, 'next');
    expect(h.state.failureKey, 'assistantUnavailable');
    expect(h.state.messages.last.delivery, AssistantDelivery.failed);
  });
  test('background interrupts chat without automatic request after resume', () async {
    await h.login();
    final events = StreamController<AssistantReplyUpdate>();
    h.chat.respond = (_) => events.stream;
    h.controller.setDraft('first');
    final sending = h.controller.send();
    await h.ready();
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await events.close();
    await sending;
    expect(h.state.messages.last.delivery, AssistantDelivery.interrupted);
    expect(h.chat.calls, 1);
  });
  test(
    'bad history is readonly; retry or explicit clear required without silent overwrite',
    () async {
      await h.auth.vault.saveHistory(
        h.auth.scope,
        assistantTestUser,
        AssistantHistory(draft: 'original'),
        isCurrent: () => true,
      );
      final key = h.auth.store.values.keys.single;
      h.auth.store.values[key] = 'corrupt';
      await h.login();
      expect(h.state.historyReady, false);
      h.controller.setDraft('replace');
      await h.controller.send();
      expect(h.chat.calls, 0);
      expect(h.auth.store.values[key], 'corrupt');
      await h.controller.clearHistory(h.state.scopeVersion);
      expect(h.state.historyReady, true);
      expect(h.auth.store.values.containsKey(key), false);
      expect(h.state.failureKey, null);
    },
  );
  test('local forget removes only credentials and retains recoverable history', () async {
    await h.login();
    h.controller.setDraft('retained');
    await h.controller.forgetSession(h.state.scopeVersion);
    expect(h.state.authenticated, false);
    expect(h.state.draft, '');
    expect(await h.auth.vault.credentials(h.auth.scope), null);
    final saved = await h.auth.vault.history(h.auth.scope, assistantTestUser);
    expect(saved.draft, 'retained');
    expect(h.auth.requests.where((r) => r.url.path.contains('logout')), isEmpty);
  });
  test(
    'authentication reads used count; remaining uses the known limit; next UTC day resets',
    () async {
      expect(h.state.quota, null);
      await h.login();
      expect(h.state.quota!.used, 2);
      expect(h.state.quota!.remaining, null);
      expect(h.state.remaining, assistantDefaultDailyLimit - 2);
      expect(h.state.quotaStale, false);
      h.container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
      h.auth.time = DateTime.utc(2026, 11, 5);
      h.container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
      expect(h.state.quotaStale, true);
      expect(h.state.quota, null);
      expect(h.state.limitReached, false);
    },
  );
  test('usage failure keeps prior result but labels it stale', () async {
    await h.login();
    await h.controller.readUsage();
    h.auth.respond = (r) async =>
        r.url.path.endsWith('ai_daily_usage') ? http.Response('{}', 503) : null;
    await h.controller.readUsage();
    expect(h.state.quota!.used, 2);
    expect(h.state.quotaStale, true);
    expect(h.state.failureKey, 'assistantUnavailable');
  });
  test('only manual HTTPS links reach native opener', () async {
    for (final value in [
      'javascript:alert(1)',
      'http://example.org',
      'data:text/plain,a',
      'https://u:p@example.org',
      null,
    ]) {
      await h.controller.openLink(value);
      expect(h.links, isEmpty);
      expect(h.state.failureKey, 'assistantLinkUnavailable');
    }
    await h.controller.openLink('https://example.org/page');
    expect(h.links.single.host, 'example.org');
  });
}
