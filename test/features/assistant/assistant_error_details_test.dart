import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/assistant/data/assistant_configuration.dart';
import 'package:vanta/features/assistant/data/assistant_http.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';

import 'assistant_protocol_test.dart' show runtimeConfiguration;

void main() {
  for (final quota in [false, true]) {
    test(
      '${quota ? 'daily quota' : 'temporary rate limit'} retains safe cause without conflating quota',
      () async {
        final service = AssistantHttp(
          client: MockClient((request) async {
            if (request.url == AssistantConfiguration.runtimeUri) {
              return http.Response(runtimeConfiguration(), 200);
            }
            return http.Response(
              jsonEncode({
                'code': quota ? 'daily_quota_exceeded' : 'rate_limit_exceeded',
                'message': quota
                    ? 'Daily allowance reached.'
                    : 'Too many requests. Retry in 10 seconds. access_token=private-token',
                if (quota) 'remaining': 0,
              }),
              429,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(service.close);
        final cancellation = AssistantCancellation();
        addTearDown(cancellation.cancel);
        await expectLater(
          service.json('GET', '/rest/v1/test', cancellation: cancellation),
          throwsA(
            isA<AssistantFailure>()
                .having(
                  (e) => e.key,
                  'classification',
                  quota ? 'assistantQuotaExceeded' : 'assistantRateLimited',
                )
                .having((e) => e.quota?.remaining, 'remaining', quota ? 0 : null)
                .having(
                  (e) => e.details?.message,
                  'cause',
                  quota
                      ? 'Daily allowance reached.'
                      : 'Too many requests. Retry in 10 seconds. access_token=•••',
                ),
          ),
        );
      },
    );
  }
}
