import 'package:vanta/features/authorization/data/device_trading_agent_store.dart';

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
