import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/percent_share.dart';

import '../../support/live_order.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);
  test('maxima above one unit use whole partial stops and an exact maximum', () {
    expect(percentShare(d('909.909'), 25), d('227'));
    expect(percentShare(d('909.909'), 75), d('682'));
    expect(percentShare(d('909.909'), 100), d('909.909'));
    expect(percentShare(d('1.5'), 50), d('0'));
  });
  test('maxima of one unit or less keep fractional stops', () {
    expect(percentShare(d('1'), 25), d('0.25'));
    expect(percentShare(d('0.333'), 50), d('0.1665'));
    expect(percentShare(d('0.333'), 100), d('0.333'));
  });
  test('slider amounts move in whole units above one, exact only at the end', () {
    final fine = d('0.001');
    expect(sliderAmount(d('909.909'), 0.37, fine), d('336'));
    expect(sliderAmount(d('909.909'), 0.999, fine), d('908'));
    expect(sliderAmount(d('909.909'), 1, fine), d('909.909'));
    expect(sliderAmount(d('909.909'), 0, fine), d('0'));
    expect(sliderAmount(d('0.5'), 0.37, fine), d('0.185'));
    expect(sliderAmount(d('0.5'), 0.3333, fine), d('0.166'));
  });
  test('close slider uses whole units above one and the exact position at the end', () {
    final data = liveCloseContext(quantity: '12.345');
    expect(data.closeAmount('BOTH', 0.5, market: true), d('6'));
    expect(data.closeAmount('BOTH', 0.999, market: true), d('12'));
    expect(data.closeAmount('BOTH', 1, market: true), d('12.345'));
    expect(data.closeAmount('BOTH', 0, market: true), d('0'));
    final small = liveCloseContext(quantity: '0.01');
    expect(small.closeAmount('BOTH', 0.75, market: true), d('0.007'));
  });
}
