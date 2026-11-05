import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_futures_asset_mode_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/asset_rebalance.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';

import '../../support/aster_account.dart';
import '../../support/rebalance.dart';
import '../../support/wallet_connection.dart';

void main() {
  for (final usdt in <String?>[null, '-0.000000000000000001', '0', '1.000000000000000001']) {
    test(
      'single-asset switch reads actual current debt $usdt and blocks unknown/negative before POST',
      () async {
        final requests = <http.Request>[];
        final service = AsterAccountService(
          client: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(switch (r.url.path) {
                '/fapi/v3/time' => {'serverTime': 1793779200000},
                '/fapi/v3/multiAssetsMargin' => {'multiAssetsMargin': true},
                '/fapi/v3/positionRisk' => <Object?>[],
                _ => {
                  'assets': [
                    if (usdt != null) {'asset': 'USDT', 'walletBalance': usdt},
                  ],
                  'positions': <Object?>[],
                },
              }),
              200,
            );
          }),
        );
        addTearDown(service.close);
        final repository = SignedFuturesAssetModeRepository(
          service,
          ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
          nonces: AsterReadNonces(),
        );
        final context = await repository.read(
          address: accountAddress,
          isCurrent: () => true,
          onStep: (_) {},
        );
        expect(context.usdtWalletBalance, usdt == null ? null : Decimal.parse(usdt));
        expect(context.blocks(FuturesAssetMode.single), usdt == null || usdt.startsWith('-'));
        expect(requests.where((r) => r.url.path == AsterAccountService.accountPath).length, 1);
        if (context.blocks(FuturesAssetMode.single)) {
          await expectLater(
            repository.change(
              intent: AssetModeIntent(
                context: context,
                target: FuturesAssetMode.single,
                revision: 0,
              ),
              isCurrent: () => true,
              canSubmit: () => true,
              onStep: (_) {},
            ),
            throwsA(isA<AccountReadFailure>()),
          );
          expect(requests.where((r) => r.method == 'POST'), isEmpty);
        }
      },
    );
  }
  test(
    'immutable comparison includes summary/positions, and reported reply cannot be replaced',
    () {
      final c = rebalanceContext(), r = rebalanceRecord();
      expect(c.terms, contains('summary'));
      final reported = r.reported(rebalanceReply());
      expect(() => reported.reported(const RebalanceReply.noExchange()), throwsFormatException);
    },
  );
}
