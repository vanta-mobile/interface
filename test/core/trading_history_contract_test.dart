import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/trading_history_repository.dart';
import 'package:yaml/yaml.dart';

void main() {
  final spec =
      loadYaml(File('docs/contracts/vanta-api/openapi.yaml').readAsStringSync()) as YamlMap;
  final paths = spec['paths'] as YamlMap;
  final schemas = (spec['components'] as YamlMap)['schemas'] as YamlMap;
  test('history routes and cursor envelope exist in the pinned OpenAPI', () {
    for (final path in [
      ...ApiTradingHistoryRepository.paths.values,
      ApiTradingHistoryRepository.transfersPath,
    ]) {
      final get = (paths[path] as YamlMap)['get'] as YamlMap;
      expect(get['security'], isNotEmpty, reason: path);
      final parameters = get['parameters'] as YamlList;
      expect(
        parameters.map((p) => (p as YamlMap)[r'$ref']),
        contains('#/components/parameters/Cursor'),
      );
    }
    final page = schemas['HistoryPage'] as YamlMap;
    expect(
      page['required'],
      containsAll(['items', 'next_cursor', 'partial', 'symbol_filter_ignored']),
    );
  });
  test('every consumed history field remains declared', () {
    final fields = {
      'Order': [
        'order_id',
        'symbol',
        'side',
        'position_side',
        'type',
        'orig_type',
        'status',
        'executed_qty',
        'orig_qty',
        'price',
        'avg_price',
        'reduce_only',
        'order_time',
        'update_time',
      ],
      'Fill': [
        'trade_id',
        'order_id',
        'symbol',
        'side',
        'position_side',
        'price',
        'qty',
        'notional',
        'fee',
        'fee_asset',
        'realized_profit',
        'trade_time',
      ],
      'PositionCycle': [
        'id',
        'symbol',
        'side',
        'opened_at',
        'closed_at',
        'entry_price',
        'exit_price',
        'max_qty',
        'realized_pnl',
        'fees',
        'status',
        'inferred',
        'liquidated',
      ],
      'IncomeItem': ['occurred_at', 'kind', 'symbol', 'asset', 'amount'],
      'TransferItem': ['id', 'occurred_at', 'kind', 'symbol', 'asset', 'amount'],
    };
    for (final entry in fields.entries) {
      final properties = (schemas[entry.key] as YamlMap)['properties'] as YamlMap;
      expect(properties.keys, containsAll(entry.value), reason: entry.key);
    }
  });
}
