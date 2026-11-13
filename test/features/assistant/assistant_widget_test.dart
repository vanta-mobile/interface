import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/assistant/application/assistant_provider.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';
import 'package:vanta/features/assistant/presentation/assistant_wallet_auth_screen.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

import '../../support/trade_fixture.dart' as app;
import '../../support/navigation_fixture.dart' show tapNavigationControl;
import 'assistant_widget_fixture.dart' as ui;
import 'assistant_session_fixture.dart';

void main() {
  testWidgets('signed out entry asks for wallet authentication and makes no requests', (
    tester,
  ) async {
    final h = await ui.mount(tester, connected: false);
    expect(find.byKey(const Key('assistant-auth-prompt')), findsOneWidget);
    expect(find.byKey(const Key('assistant-remaining')), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await ui.tap(tester, 'assistant-authenticate');
    expect(find.byType(AssistantWalletAuthScreen), findsOneWidget);
    expect(find.byKey(const Key('assistant-auth-connect')), findsOneWidget);
    expect(h.auth.requests, isEmpty);
    expect(h.auth.store.calls, isEmpty);
    await ui.close(tester, h);
  });
  testWidgets('one wallet signature authenticates, returns and shows remaining quota', (
    tester,
  ) async {
    final h = await ui.mount(tester);
    expect(h.auth.signer.messages, isEmpty);
    await ui.tap(tester, 'assistant-authenticate');
    expect(find.byKey(const Key('assistant-auth-sign')), findsOneWidget);
    expect(h.auth.signer.messages, isEmpty);
    await ui.tap(tester, 'assistant-auth-action');
    expect(h.state.authenticated, true);
    expect(
      h.auth.signer.messages.single,
      assistantChallengeText(address: assistantTestAddress.toLowerCase()),
    );
    expect(find.byType(AssistantWalletAuthScreen), findsNothing);
    expect(find.byKey(const Key('assistant-welcome')), findsOneWidget);
    expect(find.text('Remaining today: 3/5'), findsOneWidget);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('rejected signature stays unauthenticated with Try Again', (tester) async {
    final h = await ui.mount(tester);
    h.auth.signer.respond = (_) async => throw const AuthFailure('authWalletCancelled');
    await ui.tap(tester, 'assistant-authenticate');
    await ui.tap(tester, 'assistant-auth-action');
    expect(h.state.authenticated, false);
    expect(find.byKey(const Key('assistant-auth-canceled')), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    h.auth.signer.respond = null;
    await ui.tap(tester, 'assistant-auth-action');
    expect(h.state.authenticated, true);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('external wallet without a live session is sent to Connect, not to signing', (
    tester,
  ) async {
    final h = await ui.mount(tester);
    h.identity.events.add(assistantIdentity(signing: false));
    await tester.pumpAndSettle();
    await ui.tap(tester, 'assistant-authenticate');
    expect(find.byKey(const Key('assistant-auth-connect')), findsOneWidget);
    expect(h.auth.signer.messages, isEmpty);
    await ui.close(tester, h);
  });
  testWidgets('stored session opens straight into the conversation without signing', (
    tester,
  ) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    expect(h.state.authenticated, true);
    await tester.pumpWidget(const SizedBox());
    h.container.invalidate(assistantProvider);
    expect(h.state.authenticated, false);
    final signatures = h.auth.signer.messages.length;
    await ui.mount(tester, harness: h, settle: false);
    // The first frame, before the stored session is looked up, is not the prompt.
    expect(find.byKey(const Key('assistant-auth-prompt')), findsNothing);
    expect(find.byKey(const Key('assistant-skeleton')), findsOneWidget);
    await tester.pump();
    // Restoring shows the page skeleton instead of a prompt or spinner.
    expect(find.byKey(const Key('assistant-skeleton')), findsOneWidget);
    expect(find.byKey(const Key('assistant-auth-prompt')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
    expect(h.state.authenticated, true);
    expect(h.auth.signer.messages, hasLength(signatures));
    expect(find.byKey(const Key('assistant-welcome')), findsOneWidget);
    expect(find.byKey(const Key('assistant-skeleton')), findsNothing);
    await ui.close(tester, h);
  });
  testWidgets('suggested question sends, renders Markdown with time and keeps the draft', (
    tester,
  ) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    await tester.pumpAndSettle();
    h.chat.respond = (_) async* {
      yield const AssistantReplyUpdate(
        content: '**Answer**\n\n| A | B |\n|---|---|\n| 1 | 2 |',
        reasoning: 'Returned detail',
        delivery: AssistantDelivery.complete,
      );
    };
    h.controller.setDraft('my draft');
    await tester.pump();
    await ui.tap(tester, 'assistant-suggestion-0');
    expect(h.chat.sentHistory!.last.content, 'What moved BTC over the last 24h?');
    await ui.show(tester, find.byType(MarkdownBody));
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Returned detail'), findsNothing);
    expect(find.text('What moved BTC over the last 24h?'), findsOneWidget);
    expect(h.state.draft, 'my draft');
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('remote image is blocked; link activation is explicit and HTTPS only', (
    tester,
  ) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    h.chat.respond = (_) async* {
      yield const AssistantReplyUpdate(
        content:
            '![remote](https://example.org/private.png)\n\n[Safe link](https://example.org/page)',
        reasoning: '',
        delivery: AssistantDelivery.complete,
      );
    };
    h.controller.setDraft('images');
    await ui.drive(tester, h.controller.send);
    await tester.pumpAndSettle();
    await ui.show(tester, find.byType(MarkdownBody));
    expect(find.text('Remote image hidden'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(h.links, isEmpty);
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    markdown.onTapLink!('Safe link', 'https://example.org/page', '');
    await tester.pump();
    expect(h.links.single.path, '/page');
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('thinking, streaming and stop keep partial content and the next draft', (
    tester,
  ) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    final events = StreamController<AssistantReplyUpdate>();
    h.chat.respond = (_) => events.stream;
    h.controller.setDraft('first');
    final sending = h.controller.send();
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.byKey(const Key('assistant-thinking')), findsOneWidget);
    expect(find.byKey(const Key('assistant-stop')), findsOneWidget);
    events.add(
      const AssistantReplyUpdate(
        content: 'partial',
        reasoning: '',
        delivery: AssistantDelivery.streaming,
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('assistant-thinking')), findsNothing);
    expect(find.text('partial', findRichText: true), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'next');
    await tester.pump();
    await ui.tap(tester, 'assistant-stop');
    await events.close();
    await sending;
    await tester.pumpAndSettle();
    expect(h.state.draft, 'next');
    expect(h.state.messages.last.content, 'partial');
    expect(h.state.messages.last.delivery, AssistantDelivery.interrupted);
    expect(find.text('This response was manually interrupted.'), findsOneWidget);
    expect(find.byKey(const Key('assistant-send')), findsOneWidget);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('failed reply retries the same question with its original request ID', (
    tester,
  ) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    h.chat.respond = (_) async* {
      yield const AssistantReplyUpdate(
        content: 'partial',
        reasoning: '',
        delivery: AssistantDelivery.failed,
      );
      throw const AssistantFailure('assistantUnavailable');
    };
    h.controller.setDraft('question');
    await ui.drive(tester, h.controller.send);
    await tester.pumpAndSettle();
    final reply = h.state.messages.last;
    expect(reply.delivery, AssistantDelivery.failed);
    expect(find.text("Couldn't generate a response"), findsOneWidget);
    expect(find.text('partial', findRichText: true), findsOneWidget);
    h.chat.respond = null;
    await ui.tap(tester, 'assistant-retry');
    expect(h.chat.requestIds, hasLength(2));
    expect(h.chat.requestIds.toSet(), hasLength(1));
    expect(h.state.messages, hasLength(2));
    expect(h.state.messages.last.id, reply.id);
    expect(h.state.messages.last.delivery, AssistantDelivery.complete);
    expect(find.byKey(const Key('assistant-retry')), findsNothing);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('daily limit keeps the question as draft, shows notice and blocks sending', (
    tester,
  ) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    h.chat.respond = (_) async* {
      throw const AssistantFailure(
        'assistantQuotaExceeded',
        status: 429,
        quota: AssistantQuota(day: '2026-11-04', used: 8, limit: 8, remaining: 0),
      );
    };
    h.controller.setDraft('question');
    await ui.drive(tester, h.controller.send);
    await tester.pumpAndSettle();
    expect(h.state.messages, isEmpty);
    expect(h.state.draft, 'question');
    expect(find.byKey(const Key('assistant-limit')), findsOneWidget);
    expect(find.text('Remaining today: 0/8'), findsOneWidget);
    expect(h.state.canSend, false);
    await ui.tap(tester, 'assistant-suggestion-0');
    expect(h.chat.calls, 1);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('rejected session shows expiry and re-authentication', (tester) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    h.chat.respond = (_) async* {
      throw const AssistantFailure('assistantAuthorization', status: 401);
    };
    h.controller.setDraft('question');
    await ui.drive(tester, h.controller.send);
    await tester.pumpAndSettle();
    expect(h.state.authenticated, false);
    expect(find.byKey(const Key('assistant-session-expired')), findsOneWidget);
    expect(find.byKey(const Key('assistant-authenticate')), findsOneWidget);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('clear confirmation from old wallet cannot clear new wallet', (tester) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    h.controller.setDraft('private');
    await tester.pumpAndSettle();
    await ui.tap(tester, 'assistant-clear');
    h.identity.events.add(assistantIdentity(id: 'other'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-dialog-confirm')));
    await tester.pumpAndSettle();
    expect(h.auth.store.calls.where((e) => e.startsWith('delete:')), isEmpty);
    expect(h.state.authenticated, false);
    expect(h.state.draft, isEmpty);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('explicit clear removes conversation and draft', (tester) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    h.controller.setDraft('private');
    await ui.drive(tester, h.controller.send);
    h.controller.setDraft('draft');
    await tester.pumpAndSettle();
    await ui.tap(tester, 'assistant-clear');
    await ui.tap(tester, 'assistant-dialog-confirm');
    expect(h.state.messages, isEmpty);
    expect(h.state.draft, isEmpty);
    expect(h.state.historyReady, true);
    expect(find.byKey(const Key('assistant-welcome')), findsOneWidget);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  for (final spec in [
    (320.0, 844.0, 'en', 0.0),
    (320.0, 844.0, 'zh', 0.0),
    (844.0, 390.0, 'en', 0.0),
    (768.0, 1024.0, 'zh', 0.0),
    (320.0, 620.0, 'zh', 300.0),
  ]) {
    testWidgets('tables, long content and composer fit $spec at text1.5', (tester) async {
      final h = await ui.mount(
        tester,
        width: spec.$1,
        height: spec.$2,
        language: spec.$3,
        scale: 1.5,
        keyboard: spec.$4,
      );
      await ui.show(tester, find.byKey(const Key('assistant-authenticate')));
      expect(tester.takeException(), null);
      await ui.drive(tester, h.login);
      await tester.pumpAndSettle();
      h.chat.respond = (_) async* {
        yield AssistantReplyUpdate(
          content:
              '${'LongWord' * 60}\n\n| Scenario | Risk | Result |\n|---|---|---|\n| ${'long' * 30} | many risks | unknown |\n\n```\n${'code_' * 80}\n```',
          reasoning: 'Explanation',
          delivery: AssistantDelivery.complete,
        );
      };
      final input = find.byType(TextField);
      await tester.enterText(input, 'BTC 情景 ${'multi line question ' * 20}');
      await tester.pump();
      await ui.tap(tester, 'assistant-send');
      await ui.show(tester, find.byType(MarkdownBody));
      expect(find.byType(Table), findsOneWidget);
      await tester.enterText(input, List.filled(12, 'line').join('\n'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await ui.close(tester, h);
    });
  }
  testWidgets('Ask AI is a primary destination that keeps the app navigation', (tester) async {
    final container = app.setup(tester);
    await app.launch(tester, container);
    await tapNavigationControl(tester, 'navigation-assistant');
    expect(find.byKey(const Key('assistant-page')), findsOneWidget);
    expect(find.byKey(const Key('assistant-auth-prompt')), findsOneWidget);
    expect(find.byKey(const Key('assistant-back')), findsNothing);
    await tapNavigationControl(tester, 'navigation-futures');
    expect(find.byKey(const Key('assistant-page')), findsNothing);
    expect(container.exists(assistantProvider), false);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
