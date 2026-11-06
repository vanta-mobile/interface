import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/order_book_mapper.dart';

void main() {
  test('depth maps valid numbers, removes zero quantities and sorts each side', () {
    final bids = mapBookLevels([
      ['2', '3'],
      ['4', '0'],
      ['3', '1'],
    ], descending: true);
    expect(bids.map((level) => level.price), [3, 2]);
    expect(() => bids.clear(), throwsUnsupportedError);
    final asks = mapBookLevels([
      [2, 3],
      [1, 1],
    ], descending: false);
    expect(asks.map((level) => level.price), [1, 2]);
  });
  test('malformed, nonfinite and negative depth data is rejected', () {
    for (final value in [
      null,
      <String, Object?>{},
      [null],
      [
        ['1'],
      ],
      [
        ['NaN', '1'],
      ],
      [
        ['Infinity', '1'],
      ],
      [
        ['0', '1'],
      ],
      [
        ['1', '-1'],
      ],
    ]) {
      expect(() => mapBookLevels(value, descending: true), throwsFormatException);
    }
  });
  test('trade validates direction, timestamp, price and quantity', () {
    final trade = mapBookTrade({'p': '12.5', 'q': '2', 'T': 123, 'm': false});
    expect(trade.buy, isTrue);
    expect(trade.price, 12.5);
    for (final override in [
      {'p': 'NaN'},
      {'q': '0'},
      {'T': '123'},
      {'T': 0},
      {'m': 'false'},
    ]) {
      expect(
        () => mapBookTrade({'p': '12.5', 'q': '2', 'T': 123, 'm': false, ...override}),
        throwsFormatException,
      );
    }
  });
}
