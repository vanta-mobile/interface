import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/market_providers.dart';

import 'market_quotes_repository_test.dart'
    show QuoteService, instruments, snapshot, ticker, funding;

Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('quote transport exists only while a list consumer is mounted and foregrounded', () async {
    final service = QuoteService();
    final container = ProviderContainer(
      overrides: [
        asterServiceProvider.overrideWithValue(service),
        instrumentsProvider.overrideWith((ref) async => instruments),
      ],
    );
    await container.read(instrumentsProvider.future);
    await flush();
    expect(service.channels, isEmpty);
    final subscription = container.listen(liveMarketQuotesProvider, (_, _) {});
    await flush();
    expect(service.channels, hasLength(1));
    service.events.add({'connected': true});
    await flush();
    service.snapshots.single.complete(snapshot('101'));
    service.events.add(ticker(100, '123'));
    service.events.add(funding(100, '0.0001'));
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final selected = container.read(liveMarketQuotesProvider).requireValue;
    expect(selected.quotes.first.price.toString(), '123');
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    await flush();
    expect(service.cancelled, 1);
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await flush();
    expect(service.channels, hasLength(2));
    // Manual retry keeps the same last quote rather than rebuilding metadata.
    container.read(quoteReconnectProvider.notifier).reconnect();
    await flush();
    expect(service.channels, hasLength(3));
    expect(
      container.read(liveMarketQuotesProvider).requireValue.quotes.first.price.toString(),
      '123',
    );
    subscription.close();
    await flush();
    expect(service.cancelled, 3);
    expect(container.exists(marketQuotesRepositoryProvider), false);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(service.channels, hasLength(3));
    container.dispose();
    await service.close();
  });
}
