import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

void main() {
  test('HTTP 200 business failure keeps the BAPI reason', () async {
    final service = AsterAccountService(
      client: MockClient(
        (_) async => http.Response(
          '{"success":false,"code":"RATE_LIMIT","message":"Please try again later"}',
          200,
        ),
      ),
    );
    addTearDown(service.close);
    await expectLater(
      service.get('/bapi/public/read'),
      throwsA(
        isA<AccountReadFailure>().having(
          (e) => e.details?.message,
          'business reason',
          'Please try again later',
        ),
      ),
    );
  });
  for (final status in [200, 400, 401, 429, 500]) {
    test('HTTP $status preserves code and sanitized server reason', () async {
      final service = AsterAccountService(
        client: MockClient(
          (_) async => http.Response(
            '{"code":-2019,"msg":"Margin is insufficient. signature=secret-value"}',
            status,
          ),
        ),
      );
      addTearDown(service.close);
      await expectLater(
        service.get('/fapi/v3/account'),
        throwsA(
          isA<AccountReadFailure>()
              .having((e) => e.code, 'code', -2019)
              .having((e) => e.details?.status, 'HTTP status', status)
              .having(
                (e) => e.details?.message,
                'safe reason',
                'Margin is insufficient. signature=•••',
              ),
        ),
      );
    });
  }
  test('non-JSON gateway failure keeps HTTP status without leaking HTML', () async {
    final service = AsterAccountService(
      client: MockClient((_) async => http.Response('<html>internal proxy details</html>', 502)),
    );
    addTearDown(service.close);
    await expectLater(
      service.get('/fapi/v3/account'),
      throwsA(
        isA<AccountReadFailure>()
            .having((e) => e.details?.status, 'status', 502)
            .having((e) => e.details?.message, 'message', isNull),
      ),
    );
  });
  test('timeout and connection failure have distinct known causes', () async {
    for (final timeout in [true, false]) {
      final service = AsterAccountService(
        client: MockClient((_) async {
          if (timeout) throw TimeoutException('private-url');
          throw http.ClientException('secret connection diagnostic');
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.get('/fapi/v3/time'),
        throwsA(
          isA<AccountReadFailure>()
              .having(
                (e) => e.details?.cause,
                'cause',
                timeout ? ApiErrorCause.timeout : ApiErrorCause.connection,
              )
              .having((e) => e.details?.message, 'raw diagnostics excluded', isNull),
        ),
      );
    }
  });
}
