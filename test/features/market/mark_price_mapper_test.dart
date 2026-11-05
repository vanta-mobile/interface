import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/mark_price_mapper.dart';

import '../../support/mark_prices.dart';

void main() {
  test('REST and stream preserve price digits and separate exchange from receipt time', () {
    final receipt = markClock.add(const Duration(seconds: 1));
    final rest = mapMarkPrice(markPayload(), receivedAt: receipt);
    final stream = mapMarkPrice(markEvent(), receivedAt: receipt, stream: true);
    expect(rest.price.toString(), '81000.123456789123456789');
    expect(stream.price.toString(), '82000.123456789123456789');
    expect(rest.eventTime, markClock);
    expect(rest.receivedAt, receipt);
  });
  test('malformed, float, zero, negative and non-mark data cannot manufacture a price', () {
    for (final entry in <String, Object?>{
      'markPrice': 0.01,
      'symbol': 'BTC/USDT',
      'time': 1.0,
    }.entries) {
      expect(
        () => mapMarkPrice(markPayload()..[entry.key] = entry.value, receivedAt: markClock),
        throwsFormatException,
      );
    }
    for (final price in ['0', '-1', 'NaN', 'Infinity', '1e2', '1' * 161]) {
      expect(
        () => mapMarkPrice(markPayload(price: price), receivedAt: markClock),
        throwsFormatException,
      );
    }
    for (final time in [0, -1, 8640000000000001]) {
      expect(
        () => mapMarkPrice(markPayload(time: time), receivedAt: markClock),
        throwsFormatException,
      );
    }
    expect(
      () => mapMarkPrice(markEvent()..['e'] = '24hrTicker', receivedAt: markClock, stream: true),
      throwsFormatException,
    );
    expect(() => mapMarkPrice(null, receivedAt: markClock), throwsFormatException);
  });
}
