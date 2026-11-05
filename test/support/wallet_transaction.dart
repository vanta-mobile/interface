import 'package:vanta/features/auth/domain/wallet_transaction.dart';

EvmWalletTransaction walletTransaction({
  int chainId = 56,
  String from = '0x2222222222222222222222222222222222222222',
  String to = '0x5555555555555555555555555555555555555555',
  String data = '0x095ea7b3',
  BigInt? value,
  BigInt? gasLimit,
  BigInt? gasPrice,
  BigInt? nonce,
}) => EvmWalletTransaction(
  chainId: chainId,
  from: from,
  to: to,
  data: data,
  value: value ?? BigInt.parse('1230000000000000001'),
  gasLimit: gasLimit ?? BigInt.from(25202),
  gasPrice: gasPrice ?? BigInt.from(1000000000),
  nonce: nonce ?? BigInt.from(7),
);
