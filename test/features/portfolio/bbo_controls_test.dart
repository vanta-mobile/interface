import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/live_order_draft.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';

void main() {
  test('Post Only rejects opposing BBO for either direction', () {
    for (final buy in [false, true]) {
      for (final peg in LiveOrderPeg.values) {
        final draft = LiveOrderDraft(
          buy: buy,
          market: false,
          quantity: '1',
          price: '',
          timeInForce: LiveOrderTimeInForce.postOnly,
          peg: peg,
        );
        expect(draft.validPegShape, peg == LiveOrderPeg.queue);
      }
    }
  });
}
