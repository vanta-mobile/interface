import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/live_order_entry_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';

import '../../support/live_order.dart';

void main() {
  for (final mode in LiveOrderEntryMode.values) {
    test('$mode is an explicit product entry with independent strategy routing', () {
      expect(
        mode.inline,
        ![
          LiveOrderEntryMode.chase,
          LiveOrderEntryMode.scaled,
          LiveOrderEntryMode.twap,
        ].contains(mode),
      );
      expect(
        mode.conditional,
        [LiveOrderEntryMode.stopLimit, LiveOrderEntryMode.stopMarket].contains(mode),
      );
      expect(
        mode.marketExecution,
        [
          LiveOrderEntryMode.market,
          LiveOrderEntryMode.stopMarket,
          LiveOrderEntryMode.trailing,
        ].contains(mode),
      );
      expect(
        mode.defaultPolicy,
        mode == LiveOrderEntryMode.postOnly
            ? LiveOrderTimeInForce.postOnly
            : LiveOrderTimeInForce.gtc,
      );
    });
  }
  for (final policy in LiveOrderTimeInForce.values) {
    test('$policy ordinary limit mapping reserves a dedicated Post Only entry', () {
      expect(
        liveOrderEntryMode(liveDraft(timeInForce: policy)),
        policy == LiveOrderTimeInForce.postOnly
            ? LiveOrderEntryMode.postOnly
            : LiveOrderEntryMode.limit,
      );
      expect(
        liveOrderEntryMode(liveDraft(market: true, timeInForce: policy)),
        LiveOrderEntryMode.market,
      );
    });
  }
  for (final trigger in LiveOrderTriggerKind.values) {
    for (final market in [false, true]) {
      test(
        '$trigger market=$market maps to its conditional entry independently of exit direction',
        () {
          expect(
            liveOrderEntryMode(
              liveDraft(
                market: market,
                timeInForce: LiveOrderTimeInForce.postOnly,
                trigger: LiveOrderTrigger(kind: trigger, price: '81000'),
              ),
            ),
            market ? LiveOrderEntryMode.stopMarket : LiveOrderEntryMode.stopLimit,
          );
        },
      );
    }
  }
  test('Trailing never becomes an ordinary market entry', () {
    expect(
      liveOrderEntryMode(
        liveDraft(market: true, trailing: const LiveOrderTrailing(callbackRate: '1')),
      ),
      LiveOrderEntryMode.trailing,
    );
  });
}
