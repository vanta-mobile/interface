import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/subaccounts/data/subaccount_balance_repository.dart';
import 'package:vanta/features/subaccounts/data/subaccount_wallet_store.dart';

import '../../support/aster_account.dart';

void main() {
  for (final phase in ['headers', 'body', 'malformed', 'success']) {
    test('device balance read $phase uses its own signer and cancellable scope', () async {
      final storage = <String, String>{};
      final store = DeviceSubaccountWalletStore(
        read: (k) async => storage[k],
        write: (k, v) async {
          storage[k] = v;
        },
      );
      final wallet = await store.generate(owner: accountAddress, name: 'Local');
      await store.acknowledgeBackup(wallet.address);
      final saved = (await store.list()).single;
      var current = true;
      final entered = Completer<void>(), aborted = Completer<void>();
      final response = Completer<http.StreamedResponse>();
      final body = StreamController<List<int>>.broadcast();
      final service = AsterAccountService(
        client: MockClient.streaming((request, bytes) async {
          await bytes.drain<void>();
          if (request.url.path == AsterAccountService.accountPath) {
            expect(request.url.queryParameters['user'], saved.address);
            expect(request.url.queryParameters['signer'], saved.address);
            expect(request.url.queryParameters['signature'], isNotEmpty);
            (request as http.Abortable).abortTrigger!.then((_) {
              if (!aborted.isCompleted) aborted.complete();
            });
            entered.complete();
            if (phase == 'headers') return response.future;
            if (phase == 'body') return http.StreamedResponse(body.stream, 200);
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode(phase == 'malformed' ? {'assets': 'bad'} : accountPayload()),
                ),
              ),
              200,
            );
          }
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode(
                  request.url.path.endsWith('/time')
                      ? {'serverTime': DateTime.now().millisecondsSinceEpoch}
                      : contractPayload(),
                ),
              ),
            ),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final repository = SubaccountBalanceRepository(service, store, AsterReadNonces());
      if (phase == 'success') {
        final account = await repository.read(saved, () => current);
        expect(account.address, saved.address);
        expect(account.assets.first.walletBalance.toString(), '100.000000000000000001');
      } else {
        final pending = repository.read(saved, () => current);
        final failure = expectLater(pending, throwsA(isA<AccountReadFailure>()));
        await entered.future;
        if (phase != 'malformed') {
          current = false;
          await aborted.future.timeout(const Duration(seconds: 2));
        }
        await failure.timeout(const Duration(seconds: 2));
        if (phase == 'headers') response.complete(http.StreamedResponse(Stream.value([]), 200));
      }
      await body.close();
      expect((await store.list()).single.backedUp, true);
      // Releasing a read connection must not invalidate another consumer.
      final other = store.connection(saved);
      expect(other.isCurrent, true);
      await other.release();
    });
  }
}
