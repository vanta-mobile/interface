import 'package:flutter_test/flutter_test.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:vanta/features/auth/data/privy_wallet_signer.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

class _User implements PrivyUser {
  @override
  List<EmbeddedEthereumWallet> get embeddedEthereumWallets => [
    EmbeddedEthereumWallet(address: '0x${'1' * 40}', hdWalletIndex: 0),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final typed in [false, true]) {
    test(
      'embedded ${typed ? 'typed' : 'personal'} signing preserves the SDK failure reason',
      () async {
        var requests = 0;
        Future<Result<EthereumRpcResponse>> request(
          EmbeddedEthereumWallet wallet,
          EthereumRpcRequest rpc,
        ) async {
          requests++;
          return const Failure(
            PrivyException('{"message":"Wallet RPC unavailable token=private"}'),
          );
        }

        final user = _User(), address = user.embeddedEthereumWallets.single.address;
        await expectLater(
          typed
              ? signEmbeddedRequest(
                  user: user,
                  expectedAddress: address,
                  typedData: {'primaryType': 'Message'},
                  request: request,
                )
              : signEmbeddedPersonalMessage(
                  user: user,
                  expectedAddress: address,
                  message: 'Sign in',
                  request: request,
                ),
          throwsA(
            isA<AuthFailure>()
                .having((e) => e.key, 'key', 'authWalletUnavailable')
                .having((e) => e.reason, 'reason', 'Wallet RPC unavailable token=•••'),
          ),
        );
        expect(requests, 1);
      },
    );
  }
}
