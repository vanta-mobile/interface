import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/data/evm_account_address.dart';

void main() {
  test('canonical address output satisfies Privy SIWE EIP-55 requirement', () {
    const checksummed = '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf';

    expect(canonicalEvmAddress(checksummed.toLowerCase()), checksummed);
    expect(canonicalEvmAddress(checksummed), checksummed);
    expect(canonicalEvmAddress('0x1234'), null);
  });
}
