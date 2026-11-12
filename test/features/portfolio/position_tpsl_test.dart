import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/position_tpsl_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/position_tpsl.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';

Decimal d(String value) => Decimal.parse(value);

const _takeProfit = PositionTpSlLeg(
  kind: LiveOrderTriggerKind.takeProfit,
  trigger: '82000',
  basis: LiveOrderTriggerBasis.mark,
);
const _stopLoss = PositionTpSlLeg(
  kind: LiveOrderTriggerKind.stop,
  trigger: '76000',
  basis: LiveOrderTriggerBasis.last,
);

void main() {
  group('PositionTpSlLeg', () {
    test('partial legs reduce the chosen quantity on the closing side', () {
      final draft = _takeProfit.draft(
        side: 'BOTH',
        long: true,
        scope: PositionTpSlScope.partial,
        quantity: '0.005',
      );
      expect(draft.buy, isFalse);
      expect(draft.market, isTrue);
      expect(draft.closingSide, 'BOTH');
      expect(draft.quantity, '0.005');
      expect(draft.orderType, 'TAKE_PROFIT_MARKET');
      expect(draft.trigger?.basis, LiveOrderTriggerBasis.mark);
      expect(liveCloseContext().validate(draft), isNull);
    });

    test('limit legs carry their price or BBO peg', () {
      const limit = PositionTpSlLeg(
        kind: LiveOrderTriggerKind.stop,
        trigger: '76000',
        basis: LiveOrderTriggerBasis.last,
        limitPrice: '75900',
      );
      final priced = limit.draft(
        side: 'BOTH',
        long: true,
        scope: PositionTpSlScope.partial,
        quantity: '0.005',
      );
      expect((priced.market, priced.price, priced.orderType), (false, '75900', 'STOP'));
      const pegged = PositionTpSlLeg(
        kind: LiveOrderTriggerKind.stop,
        trigger: '76000',
        basis: LiveOrderTriggerBasis.last,
        peg: LiveOrderPeg.queue,
      );
      final draft = pegged.draft(
        side: 'SHORT',
        long: false,
        scope: PositionTpSlScope.partial,
        quantity: '0.005',
      );
      expect(
        (draft.buy, draft.market, draft.price, draft.peg),
        (true, false, '', LiveOrderPeg.queue),
      );
    });

    test('entire legs close the position at market, ignoring limit inputs', () {
      const limit = PositionTpSlLeg(
        kind: LiveOrderTriggerKind.takeProfit,
        trigger: '82000',
        basis: LiveOrderTriggerBasis.mark,
        limitPrice: '81900',
      );
      final draft = limit.draft(
        side: 'BOTH',
        long: true,
        scope: PositionTpSlScope.entire,
        quantity: '0.005',
      );
      expect((draft.entireClose, draft.market, draft.quantity, draft.price), (true, true, '', ''));
      expect(liveCloseContext().validate(draft), isNull);
    });
  });

  test('estimates PnL and ROI at a trigger price for either direction', () {
    expect(
      estimatedTriggerPnl(entry: d('100'), long: true, quantity: d('-2'), trigger: d('110')),
      d('20'),
    );
    expect(
      estimatedTriggerPnl(entry: d('100'), long: false, quantity: d('2'), trigger: d('110')),
      d('-20'),
    );
    expect(
      estimatedTriggerRoi(entry: d('3'), long: true, leverage: 20, trigger: d('3.1')),
      d('66.67'),
    );
    expect(estimatedTriggerRoi(entry: d('100'), long: true, leverage: 0, trigger: d('1')), isNull);
  });

  test('quote amounts become base quantities floored to the step', () {
    final data = liveCloseContext();
    expect(closeQuantityForQuote(data, d('100'), d('80000')), d('0.001'));
    expect(closeQuantityForQuote(data, d('50'), d('80000')), isNull);
    expect(closeQuantityForQuote(data, null, d('80000')), isNull);
  });

  group('PositionTpSlController', () {
    late ProviderContainer container;
    late TestIdentityRepository identity;
    late TestLiveOrderRepository repository;
    late TestAccountChangeRepository events;
    setUp(() async {
      identity = TestIdentityRepository()..restored = signingIdentity;
      repository = TestLiveOrderRepository()..context = liveCloseContext();
      events = TestAccountChangeRepository()..now = liveOrderClock;
      container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          accountChangeRepositoryProvider.overrideWithValue(events),
          accountChangeClockProvider.overrideWithValue(() => liveOrderClock),
          liveOrderRepositoryProvider.overrideWithValue(repository),
          liveOrderClockProvider.overrideWithValue(() => liveOrderClock),
        ],
      );
      container.read(authProvider);
      container.read(liveOrderProvider);
      container.listen(positionTpSlProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
    });
    tearDown(() async {
      container.dispose();
      await identity.dispose();
      await events.dispose();
    });

    List<PositionTpSlLegBuilder> legs() => [
      for (final leg in [_takeProfit, _stopLoss])
        (
          kind: leg.kind,
          draft: (LiveOrderContext _) => leg.draft(
            side: 'BOTH',
            long: true,
            scope: PositionTpSlScope.partial,
            quantity: '0.005',
          ),
        ),
    ];

    test('places each leg after its own fresh context read', () async {
      await container.read(positionTpSlProvider.notifier).submit('BTCUSDT', legs());
      final state = container.read(positionTpSlProvider);
      expect(state.busy, isFalse);
      expect(state.results.map((r) => r.outcome), [
        PositionOrderOutcome.placed,
        PositionOrderOutcome.placed,
      ]);
      expect((repository.reads, repository.submits), (2, 2));
      expect(repository.lastIntent?.draft.trigger?.kind, LiveOrderTriggerKind.stop);
    });

    test('a rejected leg stops the sequence without sending later legs', () async {
      repository.result = const LiveOrderResult(
        rejected: true,
        failure: AccountReadFailure('liveOrderTriggerImmediate'),
      );
      await container.read(positionTpSlProvider.notifier).submit('BTCUSDT', legs());
      final results = container.read(positionTpSlProvider).results;
      expect(results.single.kind, LiveOrderTriggerKind.takeProfit);
      expect(results.single.outcome, PositionOrderOutcome.failed);
      expect(results.single.failure?.key, 'liveOrderTriggerImmediate');
      expect(repository.submits, 1);
    });

    test('an unconfirmed leg is reported unknown and never resubmitted', () async {
      repository
        ..failure = const AccountReadFailure('liveOrderResultUnknown')
        ..throwAfterSubmit = true;
      await container.read(positionTpSlProvider.notifier).submit('BTCUSDT', legs());
      final results = container.read(positionTpSlProvider).results;
      expect(results.single.outcome, PositionOrderOutcome.unknown);
      expect((repository.submits, repository.checks), (1, 0));
    });

    test('an invalid leg is not submitted', () async {
      await container.read(positionTpSlProvider.notifier).submit('BTCUSDT', [
        (
          kind: LiveOrderTriggerKind.stop,
          draft: (LiveOrderContext _) => const PositionTpSlLeg(
            kind: LiveOrderTriggerKind.stop,
            trigger: '81000',
            basis: LiveOrderTriggerBasis.last,
          ).draft(side: 'BOTH', long: true, scope: PositionTpSlScope.partial, quantity: '0.005'),
        ),
      ]);
      final result = container.read(positionTpSlProvider).results.single;
      expect(result.outcome, PositionOrderOutcome.failed);
      expect(result.failure?.key, 'liveOrderTriggerImmediate');
      expect(repository.submits, 0);
    });
  });
}
