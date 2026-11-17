import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';

import 'aster_account.dart';
import 'trading_agents.dart';

Future<void> visible(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> tap(WidgetTester tester, String key, {bool settle = true}) async {
  await visible(tester, key);
  await tester.tap(find.byKey(Key(key)));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> field(WidgetTester tester, String key, String value) async {
  await visible(tester, key);
  await tester.enterText(find.byKey(Key(key)), value);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Activates a device trading grant for [signingIdentity] so order facts
/// are read silently.
Future<void> grantTrading(WidgetTester tester, ProviderContainer container) async {
  final store = container.read(tradingAgentStoreProvider);
  await tester.runAsync(() async {
    final agent = await store.prepare(
      signingIdentity.id,
      accountAddress,
      DateTime.now().add(const Duration(days: 30)),
    );
    await store.setStatus(agent, TradingAgentStatus.unknown);
    await store.setStatus(agent, TradingAgentStatus.active);
  });
  container.invalidate(tradingAgentProvider);
  await awaitTradingAgent(tester, container);
}
