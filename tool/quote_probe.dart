import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/market/data/market_catalog_repository.dart';
import 'package:vanta/features/market/data/market_quotes_repository.dart';
import 'package:vanta/features/market/domain/market_quotes.dart';

Future<void> main() async {
  final client = http.Client();
  final service = AsterService(client);
  final instruments = await MarketCatalogRepository(service).read();
  final repository = MarketQuotesRepository(service, instruments);
  final records = <Map<String, Object?>>[];
  final done = Completer<void>();
  final subscription = repository.events.listen((state) {
    final quote = state.quotes.first;
    records.add({
      'receivedAt': DateTime.now().toUtc().toIso8601String(),
      'connection': state.connection.name,
      'failure': state.failure?.name,
      'updatedAt': state.updatedAt?.toUtc().toIso8601String(),
      'symbolCount': state.quotes.length,
      'symbol': quote.symbol,
      'price': quote.price?.toString(),
      'change': quote.change?.toString(),
      'quoteVolume': quote.quoteVolume?.toString(),
      'funding': quote.funding?.toString(),
    });
    if (state.connection == QuoteConnection.live && records.length >= 15 && !done.isCompleted) {
      done.complete();
    }
  });
  try {
    await done.future.timeout(const Duration(seconds: 35));
  } on TimeoutException {
    // Record the observed state rather than claiming a successful live stream.
  }
  await subscription.cancel();
  await repository.dispose();
  client.close();
  await File('docs/reference/market-quotes-live.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'purpose': 'Anonymous public all-market ticker and mark stream verification',
      'streams': ['!ticker@arr', '!markPrice@arr@1s'],
      'records': records,
    }),
  );
  stdout.writeln(
    'Observed ${records.length} states; live=${records.any((record) => record['connection'] == 'live')}',
  );
}
