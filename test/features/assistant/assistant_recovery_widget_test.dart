import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/assistant/application/assistant_provider.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';
import 'package:vanta/features/assistant/domain/assistant_history.dart';
import 'package:vanta/features/market/application/market_providers.dart';

import 'assistant_widget_fixture.dart' as ui;
import 'assistant_session_fixture.dart';

void main() {
  testWidgets('damaged history stays readonly and explicit clear is recoverable', (tester) async {
    final h = await ui.mount(tester);
    await ui.drive(
      tester,
      () => h.auth.vault.saveHistory(
        h.auth.scope,
        assistantTestUser,
        AssistantHistory(draft: 'old'),
        isCurrent: () => true,
      ),
    );
    final key = h.auth.store.values.keys.single;
    h.auth.store.values[key] = 'corrupt';
    await ui.drive(tester, h.login);
    await tester.pumpAndSettle();
    await ui.show(tester, find.byKey(const Key('assistant-retry-history')));
    expect(h.state.historyReady, false);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    expect(h.auth.store.values[key], 'corrupt');
    await ui.tap(tester, 'assistant-clear');
    await ui.tap(tester, 'assistant-dialog-confirm');
    expect(h.state.historyReady, true);
    expect(h.auth.store.values.containsKey(key), false);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('failed save displays safe notice and retry saves preserved draft', (tester) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    h.auth.store.before = (op, key) async {
      if (op == 'write' && key.contains('.history.')) throw StateError('secret');
    };
    h.controller.setDraft('saved later');
    h.controller.retrySave();
    await tester.pumpAndSettle();
    await ui.show(tester, find.byKey(const Key('assistant-retry-save')));
    expect(find.textContaining('secret'), findsNothing);
    expect(h.state.draft, 'saved later');
    h.auth.store.before = null;
    await ui.tap(tester, 'assistant-retry-save');
    expect(h.state.storageFailureKey, null);
    await ui.drive(tester, () async {
      expect((await h.auth.vault.history(h.auth.scope, assistantTestUser)).draft, 'saved later');
    });
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('header shows read usage against the known limit; refresh reads it again', (
    tester,
  ) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    await tester.pumpAndSettle();
    expect(find.text('Remaining today: 3/5'), findsOneWidget);
    final reads = h.auth.requests.where((r) => r.url.path.endsWith('ai_daily_usage')).length;
    await ui.drive(tester, h.controller.readUsage);
    expect(
      h.auth.requests.where((r) => r.url.path.endsWith('ai_daily_usage')),
      hasLength(reads + 1),
    );
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    h.auth.time = DateTime.utc(2026, 11, 5, 1);
    h.container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await tester.pumpAndSettle();
    expect(find.text('Remaining today: –/5'), findsOneWidget);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('UTF16 length counts emoji correctly and disables oversize send', (tester) async {
    final h = await ui.mount(tester);
    await ui.drive(tester, h.login);
    await tester.pumpAndSettle();
    final input = find.byType(TextField);
    await ui.show(tester, input);
    await tester.enterText(input, '😀' * 6001);
    await tester.pump();
    expect(h.state.draft.length, 12002);
    expect(h.state.canSend, false);
    expect(tester.widget<InkWell>(find.byKey(const Key('assistant-send'))).onTap, null);
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
  testWidgets('stream update does not pull reader away from older content', (tester) async {
    final h = await ui.mount(tester);
    await ui.drive(
      tester,
      () => h.auth.vault.saveHistory(
        h.auth.scope,
        assistantTestUser,
        AssistantHistory(
          messages: [
            for (var i = 0; i < 8; i++)
              AssistantMessage(
                id: 'old-$i',
                role: AssistantRole.assistant,
                content: List.filled(20, 'Earlier market analysis.').join('\n\n'),
                createdAt: assistantTestTime,
              ),
          ],
        ),
        isCurrent: () => true,
      ),
    );
    await ui.drive(tester, h.login);
    final events = StreamController<AssistantReplyUpdate>();
    h.chat.respond = (_) => events.stream;
    h.controller.setDraft('new');
    final sending = h.controller.send();
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    final scroll = ui.scrollController(tester);
    scroll.jumpTo(400);
    await tester.pump();
    final before = scroll.offset;
    events.add(
      const AssistantReplyUpdate(
        content: 'new partial content',
        reasoning: '',
        delivery: AssistantDelivery.streaming,
      ),
    );
    await tester.pumpAndSettle();
    expect(scroll.offset, before);
    h.controller.stop();
    await events.close();
    await sending;
    expect(tester.takeException(), null);
    await ui.close(tester, h);
  });
}
