import 'package:vanta/features/portfolio/data/account_update_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_update.dart';

const accountEventClock = 1793620801000;

Map<String, dynamic> accountBalanceUpdate({
  String asset = 'USDT',
  String wallet = '102.000000000000000001',
}) => {'a': asset, 'wb': wallet, 'cw': '92.000000000000000001', 'bc': '2'};
Map<String, dynamic> accountPositionUpdate({
  String symbol = 'BTCUSDT',
  String side = 'BOTH',
  String quantity = '-0.2',
  String wallet = '1.5',
}) => {
  's': symbol,
  'ps': side,
  'pa': quantity,
  'ep': '80000.000000000000000001',
  'cr': '99999',
  'up': '-0.000000000000001',
  'mt': 'isolated',
  'iw': wallet,
};
Map<String, dynamic> accountUpdatePayload({
  int time = accountEventClock,
  int? transactionTime,
  List<Object?>? balances,
  List<Object?>? positions,
}) => {
  'e': 'ACCOUNT_UPDATE',
  'E': time,
  'T': transactionTime ?? time - 1,
  'a': {
    'm': 'ORDER',
    'B': balances ?? [accountBalanceUpdate()],
    'P': positions ?? [accountPositionUpdate()],
  },
};
AccountUpdate accountUpdate({
  int time = accountEventClock,
  int? transactionTime,
  List<Object?>? balances,
  List<Object?>? positions,
}) => mapAccountUpdate(
  accountUpdatePayload(
    time: time,
    transactionTime: transactionTime,
    balances: balances,
    positions: positions,
  ),
);
