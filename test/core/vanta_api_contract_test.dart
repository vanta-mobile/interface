import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/portfolio_stats_repository.dart';
import 'package:vanta/features/portfolio/domain/portfolio_stats.dart';
import 'package:yaml/yaml.dart';

/// The client is written against the pinned contract, not the backend source.
/// A contract sync that renames or drops a field the data layer reads fails here.
typedef Json = Map<Object?, Object?>;

void main() {
  final spec = loadYaml(File('docs/contracts/vanta-api/openapi.yaml').readAsStringSync()) as Json;

  Json resolve(Object? node) {
    var value = node as Json;
    for (var ref = value[r'$ref']; ref is String; ref = value[r'$ref']) {
      value = ref.substring(2).split('/').fold<Object?>(spec, (m, k) => (m as Json)[k]) as Json;
    }
    return value;
  }

  Json operation(String method, String path) {
    final item = (spec['paths'] as Json)[path] as Json?;
    expect(item?[method], isNotNull, reason: '$method $path is not in the contract');
    return item![method] as Json;
  }

  Json okSchema(Json operation) {
    final response = resolve((operation['responses'] as Json)['200']);
    return resolve((((response['content'] as Json)['application/json'] as Json)['schema']));
  }

  Set<String> properties(Json schema) => {...((schema['properties'] as Json?) ?? {}).keys.cast()};

  Json requestSchema(Json operation) => resolve(
    (((resolve(operation['requestBody'])['content'] as Json)['application/json']
        as Json)['schema']),
  );

  test(
    'notification list filters, global unread and idempotent read markers match the contract',
    () {
      final list = operation('get', '/v1/notifications');
      expect(list['security'], isNotEmpty);
      final parameters = {
        for (final p in list['parameters'] as List) resolve(p)['name']: resolve(p),
      };
      expect(parameters.keys, containsAll(['category', 'unread_only', 'cursor', 'limit']));
      expect(
        (parameters['category']!['schema'] as Json)['enum'],
        containsAll(['all', 'orders', 'transfers']),
      );
      final page = okSchema(list);
      expect(page['required'], containsAll(['items', 'next_cursor', 'unread']));
      final notification = resolve(((page['properties'] as Json)['items'] as Json)['items']);
      expect(
        notification['required'],
        containsAll([
          'kind',
          'id',
          'event_key',
          'type',
          'severity',
          'payload',
          'read',
          'created_at',
        ]),
      );
      final read = operation('post', '/v1/notifications/read');
      expect(read['security'], isNotEmpty);
      expect(
        properties(requestSchema(read)),
        containsAll(['event_keys', 'broadcast_up_to', 'all']),
      );
      final key = (read['parameters'] as List)
          .map(resolve)
          .singleWhere((p) => p['name'] == 'Idempotency-Key');
      expect(key['in'], 'header');
      expect(key['required'], isTrue);
    },
  );

  test('push registration, unregistration, preferences and capability match the contract', () {
    final register = operation('post', '/v1/push/register');
    expect(requestSchema(register)['required'], containsAll(['platform', 'token', 'app_id']));
    expect(
      properties(requestSchema(register)),
      containsAll(['environment', 'locale', 'app_version', 'utcOffsetMinutes']),
    );
    expect(okSchema(register)['required'], containsAll(['registered', 'device_id', 'status']));
    final unregister = operation('post', '/v1/push/unregister');
    expect(requestSchema(unregister)['required'], contains('token'));
    final prefs = operation('post', '/v1/push/prefs');
    expect(
      properties(requestSchema(prefs)),
      containsAll([
        'fills',
        'triggers',
        'orders',
        'funding',
        'transfers',
        'announcements',
        'quiet_start',
        'quiet_end',
        'min_notional',
      ]),
    );
    expect(properties(requestSchema(prefs)), isNot(contains('liquidation')));
    expect(properties(requestSchema(prefs)), isNot(contains('margin_call')));
    for (final op in [register, unregister, prefs]) {
      expect(op['security'], isNotEmpty);
      final key = (op['parameters'] as List)
          .map(resolve)
          .singleWhere((p) => p['name'] == 'Idempotency-Key');
      expect(key['required'], isTrue);
    }
    final status = operation('get', '/v1/push/status');
    expect(status['security'], isNotEmpty);
    expect(okSchema(status)['required'], containsAll(['status', 'devices', 'prefs']));
  });

  test('SIWE sign-in, refresh and logout use declared fields', () {
    final nonce = operation('get', '/v1/auth/nonce');
    expect((nonce['parameters'] as List).map((p) => resolve(p)['name']), contains('address'));
    expect(properties(okSchema(nonce)), containsAll(['nonce', 'expires_at']));

    final siwe = operation('post', '/v1/auth/siwe');
    expect(properties(requestSchema(siwe)), containsAll(['message', 'signature', 'platform']));
    final issued = okSchema(siwe);
    expect(
      issued['required'],
      containsAll(['access_token', 'refresh_token', 'expires_in', 'user']),
    );
    expect(properties(resolve((issued['properties'] as Json)['user'])), contains('wallet'));

    final refresh = operation('post', '/v1/auth/refresh');
    expect(properties(requestSchema(refresh)), contains('refresh_token'));
    expect(okSchema(refresh), same(issued));
    expect(operation('post', '/v1/auth/logout')['security'], isNotEmpty);
  });

  test('error codes the session branches on are stable contract codes', () {
    final codes = resolve(((spec['components'] as Json)['schemas'] as Json)['ErrorCode'])['enum'];
    expect(codes, containsAll(['unauthenticated', 'session_expired', 'session_revoked']));
  });

  test('portfolio reads match the summary, curve and calendar schemas', () {
    final periods = resolve(((spec['components'] as Json)['schemas'] as Json)['PeriodValue']);
    expect(
      PortfolioStatsPeriod.values.map((p) => p.query),
      unorderedEquals(periods['enum'] as List),
    );

    final summary = operation('get', PortfolioStatsRepository.summaryPath);
    expect(summary['security'], isNotEmpty);
    expect(
      properties(okSchema(summary)),
      containsAll([
        'from',
        'to',
        'realized_pnl_usd',
        'fees_usd',
        'funding_fee_usd',
        'volume_usd',
        'equity_start_usd',
        'equity_end_usd',
        'partial',
      ]),
    );

    final curve = operation('get', PortfolioStatsRepository.curvePath);
    expect(
      (curve['parameters'] as List).map((p) => resolve(p)['name']),
      containsAll(['period', 'metric']),
    );
    final shapes = {
      for (final shape in okSchema(curve)['oneOf'] as List)
        ((resolve(shape)['properties'] as Json)['metric'] as Json)['const']: resolve(
          ((resolve(shape)['properties'] as Json)['points'] as Json)['items'],
        ),
    };
    expect(properties(shapes['value']!), containsAll(['bucket', 'equity_close_usd']));
    expect(
      properties(shapes['pnl']!),
      containsAll(['bucket', 'realized_pnl_usd', 'fees_usd', 'funding_fee_usd']),
    );

    final calendar = operation('get', PortfolioStatsRepository.calendarPath);
    expect(
      (calendar['parameters'] as List).map((p) => resolve(p)['name']),
      containsAll(['from', 'to']),
    );
    final day = resolve(((okSchema(calendar)['properties'] as Json)['items'] as Json)['items']);
    expect(
      properties(day),
      containsAll(['day', 'realized_pnl_usd', 'fees_usd', 'funding_fee_usd']),
    );
  });
}
