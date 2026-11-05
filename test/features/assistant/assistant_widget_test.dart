import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/assistant/application/assistant_provider.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';

import '../../support/trade_fixture.dart' as app;
import 'assistant_widget_fixture.dart' as ui;
import 'assistant_session_fixture.dart';

void main() {
  testWidgets('entry is usable signed out and makes no personal requests', (tester) async {
    final h = await ui.mount(tester, connected: false);
    expect(find.byKey(const Key('assistant-connect')), findsOneWidget);
    expect(h.auth.requests, isEmpty);
    expect(h.auth.store.calls, isEmpty);
    await ui.close(tester, h);
  });
  testWidgets('exact message requires separate confirmation, cancellation never signs', (
    tester,
  ) async {
    final h = await ui.mount(tester);
    await ui.tap(tester, 'assistant-authorize');
    final message = tester.widget<SelectableText>(
      find.byKey(const Key('assistant-challenge-message')),
    );
    expect(message.data, assistantChallengeText(address: assistantTestAddress.toLowerCase()));
    expect(h.auth.signer.messages, isEmpty);
    await ui.tap(tester, 'assistant-cancel-sign');
    expect(h.auth.signer.messages, isEmpty);
    await ui.tap(tester, 'assistant-authorize');
    await ui.tap(tester, 'assistant-confirm-sign');
    expect(h.state.authenticated, true);
    expect(h.auth.signer.messages.length, 1);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('compose/send, native Markdown, collapsed explanation and clipboard', (tester) async {
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
    final input = find.byType(TextField);
    await ui.show(tester, input);
    await tester.enterText(input, 'BTC scenarios');
    await tester.pump();
    await ui.tap(tester, 'assistant-send');
    await ui.show(tester, find.byType(MarkdownBody));
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Returned detail'), findsNothing);
    final expansion = find.byKey(ValueKey('assistant-explanation-${h.state.messages.last.id}'));
    await ui.show(tester, expansion);
    await tester.tap(expansion);
    await tester.pumpAndSettle();
    expect(find.text('Returned detail', findRichText: true), findsOneWidget);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final copy = find.byTooltip('Copy message').last;
    await ui.show(tester, copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, contains('**Answer**'));
    expect(find.text('Copied'), findsOneWidget);
    expect(h.state.draft, isEmpty);
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
  testWidgets('stop preserves partial and lets user compose next question', (tester) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    final events = StreamController<AssistantReplyUpdate>();
    h.chat.respond = (_) => events.stream;
    h.controller.setDraft('first');
    late Future<void> sending;
    sending = h.controller.send();
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
    events.add(
      const AssistantReplyUpdate(
        content: 'partial',
        reasoning: '',
        delivery: AssistantDelivery.streaming,
      ),
    );
    await tester.pumpAndSettle();
    final input = find.byType(TextField);
    await ui.show(tester, input);
    await tester.enterText(input, 'next');
    await tester.pump();
    await ui.tap(tester, 'assistant-stop');
    await events.close();
    await sending;
    await tester.pumpAndSettle();
    expect(h.state.draft, 'next');
    expect(h.state.messages.last.content, 'partial');
    expect(h.state.messages.last.delivery, AssistantDelivery.interrupted);
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
  testWidgets(
    'explicit clear removes conversation and draft; forget wording describes local boundary',
    (tester) async {
      final h = await ui.mount(tester);
      await ui.drive(tester, h.login);
      h.controller.setDraft('private');
      await tester.pumpAndSettle();
      await ui.tap(tester, 'assistant-clear');
      await ui.tap(tester, 'assistant-dialog-confirm');
      expect(h.state.messages, isEmpty);
      expect(h.state.draft, isEmpty);
      expect(h.state.historyReady, true);
      await ui.tap(tester, 'assistant-forget');
      expect(find.textContaining('does not revoke the server session'), findsOneWidget);
      await ui.tap(tester, 'assistant-dialog-confirm');
      expect(h.state.authenticated, false);
      expect(tester.takeException(), null);
      await ui.close(tester, h);
    },
  );
  for (final spec in [
    (320.0, 844.0, 'en', 0.0),
    (320.0, 844.0, 'zh', 0.0),
    (844.0, 390.0, 'en', 0.0),
    (768.0, 1024.0, 'zh', 0.0),
    (320.0, 620.0, 'zh', 300.0),
  ]) {
    testWidgets('review, tables, long content and composer fit $spec at text1.5', (tester) async {
      final h = await ui.mount(
        tester,
        width: spec.$1,
        height: spec.$2,
        language: spec.$3,
        scale: 1.5,
        keyboard: spec.$4,
      );
      await ui.tap(tester, 'assistant-authorize');
      await ui.tap(tester, 'assistant-confirm-sign');
      h.chat.respond = (_) async* {
        yield AssistantReplyUpdate(
          content:
              '${'LongWord' * 60}\n\n| Scenario | Risk | Result |\n|---|---|---|\n| ${'long' * 30} | many risks | unknown |\n\n```\n${'code_' * 80}\n```',
          reasoning: 'Explanation',
          delivery: AssistantDelivery.complete,
        );
      };
      final input = find.byType(TextField);
      await ui.show(tester, input);
      await tester.enterText(input, 'BTC 情景');
      await tester.pump();
      await ui.tap(tester, 'assistant-send');
      await ui.show(tester, find.byType(MarkdownBody));
      expect(find.byType(Table), findsOneWidget);
      await ui.show(tester, input);
      expect(tester.takeException(), null);
      await ui.close(tester, h);
    });
  }
  testWidgets('AI bottom navigation opens real page, no request on entry, leaves cleanly', (
    tester,
  ) async {
    final container = app.setup(tester);
    await app.launch(tester, container);
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-page')), findsOneWidget);
    expect(find.byKey(const Key('assistant-connect')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.swap_calls_rounded));
    await tester.pumpAndSettle();
    expect(container.exists(assistantProvider), false);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
