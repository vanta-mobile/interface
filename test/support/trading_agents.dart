import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/data/device_trading_agent_store.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';

import 'aster_account.dart';

class MemoryTradingAgentStorage {
  final values = <String, String>{};
  Object? readFailure, writeFailure;
  int writes = 0;

  DeviceTradingAgentStore store(DateTime Function() now) => DeviceTradingAgentStore(
    now: now,
    read: (key) async {
      if (readFailure case final failure?) throw failure;
      return values[key];
    },
    write: (key, value) async {
      if (writeFailure case final failure?) throw failure;
      writes++;
      values[key] = value;
    },
  );
}

/// A device store whose grant for [signingIdentity] is already active, so a
/// signed-in launch passes trading onboarding.
Future<TradingAgentStore> activeAgentStore() async {
  final store = MemoryTradingAgentStorage().store(DateTime.now);
  final agent = await store.prepare(
    signingIdentity.id,
    accountAddress,
    DateTime.now().add(const Duration(days: 30)),
  );
  await store.setStatus(agent, TradingAgentStatus.unknown);
  await store.setStatus(agent, TradingAgentStatus.active);
  return store;
}

/// The device store reads outside fake time; let the grant load, then settle
/// the startup flow it unblocks.
Future<void> awaitTradingAgent(WidgetTester tester, ProviderContainer container) async {
  for (var i = 0; i < 50 && container.read(tradingAgentProvider).isLoading; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
