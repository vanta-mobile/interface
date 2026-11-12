import 'evm_account_address.dart';

/// EIP-4361 message for `POST /v1/auth/siwe`. The server derives identity from
/// the recovered signer, so the address appears only inside the signed text.
class VantaSiweMessage {
  VantaSiweMessage({
    required this.relyingParty,
    required String address,
    required this.nonce,
    required this.issuedAt,
    required this.expiresAt,
    this.chainId = 1,
  }) : address = canonicalEvmAddress(address) ?? (throw const FormatException('Invalid address')) {
    // EIP-4361 nonce grammar: at least eight alphanumeric characters.
    if (!RegExp(r'^[A-Za-z0-9]{8,128}$').hasMatch(nonce) || !expiresAt.isAfter(issuedAt)) {
      throw const FormatException('Invalid SIWE challenge');
    }
  }

  /// Fixed protocol text; the backend does not interpret it (contract `SiweLogin`).
  static const statement = 'Sign in to Vanta to view your account statistics.';

  final Uri relyingParty;
  final String address, nonce;
  final DateTime issuedAt, expiresAt;
  final int chainId;

  String get text => [
    '${relyingParty.authority} wants you to sign in with your Ethereum account:',
    address,
    '',
    statement,
    '',
    'URI: ${relyingParty.origin}',
    'Version: 1',
    'Chain ID: $chainId',
    'Nonce: $nonce',
    'Issued At: ${_time(issuedAt)}',
    'Expiration Time: ${_time(expiresAt)}',
  ].join('\n');

  static String _time(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
    ).toIso8601String();
  }
}
