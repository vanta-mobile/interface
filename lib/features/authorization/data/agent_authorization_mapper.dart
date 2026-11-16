import '../domain/trading_agent.dart';

/// Account canTrade/read success alone does not verify an individual Agent.
bool hasTradingAgentGrant(Object? payload, TradingAgent expected, DateTime now) {
  if (payload is! List || payload.length > 1000) throw const FormatException();
  final addresses = <String>{};
  var ready = false;
  for (final item in payload) {
    if (item is! Map<String, dynamic> ||
        item['agentAddress'] is! String ||
        !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(item['agentAddress'] as String) ||
        item['expired'] is! int ||
        item['canRead'] is! bool ||
        item['canSpotTrade'] is! bool ||
        item['canPerpTrade'] is! bool ||
        item['canWithdraw'] is! bool ||
        item['ipWhitelist'] is! String) {
      throw const FormatException();
    }
    final address = (item['agentAddress'] as String).toLowerCase();
    if (!addresses.add(address)) throw const FormatException();
    if (address == expected.address.toLowerCase()) {
      ready =
          item['canRead'] == true &&
          item['canSpotTrade'] == true &&
          item['canPerpTrade'] == true &&
          item['canWithdraw'] == false &&
          item['ipWhitelist'] == '' &&
          (item['expired'] as int) >= expected.expiresAt.millisecondsSinceEpoch &&
          (item['expired'] as int) > now.millisecondsSinceEpoch;
    }
  }
  return ready;
}
