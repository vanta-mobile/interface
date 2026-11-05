import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_event_reconciliation.dart';
import 'package:vanta/features/portfolio/domain/account_update_book.dart';

import '../../support/account_updates.dart';
import '../../support/aster_account.dart';
import '../../support/position_risk.dart';

void main() {
  test(
    'updates individual records; totals and unavailable risk fields cannot retain old values',
    () {
      final book = AccountUpdateBook()..add(accountUpdate());
      final account = reconcileAccountUpdates(accountFixture(), book, since: 0);
      final risk = reconcileRiskUpdates(positionRiskFixture(), book, since: 0);
      expect(account.assets.first.walletBalance.toString(), '102.000000000000000001');
      expect(account.assets.first.availableBalance, null);
      expect(account.assets.last.asset, 'BNB');
      expect(account.walletBalance, null);
      expect(account.marginBalance, null);
      expect(account.initialMargin, null);
      final p = risk.positions.first;
      expect(p.quantity.toString(), '-0.2');
      expect(p.units?.base, 'BTC');
      expect(p.markPrice, null);
      expect(p.liquidationPrice, null);
      expect(p.isolatedMargin, null);
      expect(p.leverage, null);
      expect(p.notional, null);
      expect(risk.positions.last.symbol, 'ETHUSDT');
      expect(risk.receivedAt, positionRiskFixture().receivedAt);
      expect(risk.lastEventAt, accountUpdate().eventTime);
    },
  );
  test('balance-only event does not close any position or update risk receipt time', () {
    final original = positionRiskFixture();
    final book = AccountUpdateBook()..add(accountUpdate(positions: []));
    expect(reconcileRiskUpdates(original, book, since: 0), same(original));
  });
  test('explicit zero removes only that side; negative isolated debt stays visible', () {
    final book = AccountUpdateBook()
      ..add(
        accountUpdate(
          positions: [accountPositionUpdate(quantity: '0', wallet: '0')],
        ),
      );
    final closed = reconcileRiskUpdates(positionRiskFixture(), book, since: 0);
    expect(closed.positions.single.symbol, 'ETHUSDT');
    expect(closed.positionUpdatedAt['BTCUSDT:BOTH'], accountUpdate().transactionTime);
    book.add(
      accountUpdate(
        time: accountEventClock + 1,
        positions: [accountPositionUpdate(quantity: '0', wallet: '-2')],
      ),
    );
    final debt = reconcileRiskUpdates(closed, book, since: 1);
    expect(debt.positions.last.balanceOnly, true);
    expect(debt.positions.last.isolatedWallet.toString(), '-2');
  });
  test('closing marker rejects old events but permits a genuinely newer reopening', () {
    final book = AccountUpdateBook();
    book.add(
      accountUpdate(
        positions: [accountPositionUpdate(quantity: '0', wallet: '0')],
      ),
    );
    final closed = reconcileRiskUpdates(positionRiskFixture(), book, since: 0);
    expect(book.add(accountUpdate(time: accountEventClock - 1)), false);
    expect(reconcileRiskUpdates(closed, book, since: 1), same(closed));
    book.add(accountUpdate(time: accountEventClock + 1));
    final opened = reconcileRiskUpdates(closed, book, since: 2);
    expect(opened.positions.any((p) => p.symbol == 'BTCUSDT'), true);
  });
  test('exact duplicate is ignored and ambiguous same timestamp conflicts fail atomically', () {
    final book = AccountUpdateBook()..add(accountUpdate());
    expect(book.add(accountUpdate()), false);
    final conflicting = accountUpdate(
      balances: [
        accountBalanceUpdate(asset: 'NEW'),
        accountBalanceUpdate(wallet: '999'),
      ],
    );
    expect(() => book.add(conflicting), throwsFormatException);
    expect(book.balances({}, since: 0).map((p) => p.value.asset), ['USDT']);
  });
  test('per-key E and transaction ordering reject either regressing clock', () {
    final book = AccountUpdateBook()..add(accountUpdate());
    expect(
      book.add(accountUpdate(time: accountEventClock + 1, transactionTime: accountEventClock - 2)),
      false,
    );
    expect(
      book.add(accountUpdate(time: accountEventClock - 1, transactionTime: accountEventClock + 1)),
      false,
    );
    final newAsset = accountUpdate(
      time: accountEventClock - 10,
      balances: [accountBalanceUpdate(asset: 'BNB')],
      positions: [],
    );
    expect(book.add(newAsset), true);
    expect(book.balances({}, since: 0).length, 2);
  });
  test('newer E advances a position even at equal transaction millisecond', () {
    final book = AccountUpdateBook()..add(accountUpdate());
    final first = reconcileRiskUpdates(positionRiskFixture(), book, since: 0);
    book.add(
      accountUpdate(
        time: accountEventClock + 1,
        transactionTime: accountEventClock - 1,
        positions: [accountPositionUpdate(quantity: '-0.3')],
      ),
    );
    final second = reconcileRiskUpdates(first, book, since: 1);
    expect(second.positions.first.quantity.toString(), '-0.3');
  });
  test('newer and equal-time REST wins; pre-read missing records are not resurrected', () {
    final book = AccountUpdateBook()..add(accountUpdate());
    final clock = accountEventClock - 1;
    final rest = mapPositionRisk(
      [
        positionRiskRow()
          ..['positionAmt'] = '0'
          ..['isolatedWallet'] = '0'
          ..['updateTime'] = clock,
      ],
      address: accountAddress,
      receivedAt: DateTime.utc(2026, 11, 3),
    );
    expect(reconcileRiskUpdates(rest, book, since: 0), same(rest));
    final missing = mapPositionRisk([], address: accountAddress, receivedAt: rest.receivedAt);
    expect(reconcileRiskUpdates(missing, book, since: book.revision), same(missing));
    expect(reconcileRiskUpdates(missing, book, since: 0).positions.single.symbol, 'BTCUSDT');
  });
  test(
    'newer balance REST updateTime wins over stale event without using the local receipt clock',
    () {
      final payload = accountPayload();
      (payload['assets']! as List).first['updateTime'] = accountEventClock + 1;
      final rest = mapAsterAccount(
        payload,
        address: accountAddress,
        receivedAt: DateTime.utc(2020),
      );
      final book = AccountUpdateBook()..add(accountUpdate(positions: []));
      expect(reconcileAccountUpdates(rest, book, since: 0), same(rest));
    },
  );
  test('hedge sides remain separate; incompatible active one-way and hedge state fails closed', () {
    final book = AccountUpdateBook()
      ..add(
        accountUpdate(
          positions: [
            accountPositionUpdate(side: 'LONG', quantity: '1'),
            accountPositionUpdate(side: 'SHORT', quantity: '-2'),
          ],
        ),
      );
    final empty = mapPositionRisk([], address: accountAddress, receivedAt: DateTime.utc(2026));
    final result = reconcileRiskUpdates(empty, book, since: 0);
    expect(result.positions.map((p) => p.side), ['LONG', 'SHORT']);
    expect(result.positions.every((p) => p.units == null), true);
    expect(
      () => reconcileRiskUpdates(positionRiskFixture(), book, since: 0),
      throwsFormatException,
    );
  });
  test('capacity failure does not evict zero records or partially add balances', () {
    final book = AccountUpdateBook(capacity: 2)..add(accountUpdate());
    expect(
      () => book.add(
        accountUpdate(
          time: accountEventClock + 1,
          balances: [accountBalanceUpdate(asset: 'NEW')],
        ),
      ),
      throwsA(isA<AccountEventsFull>()),
    );
    expect(book.revision, 1);
    expect(book.balances({}, since: 0).single.value.asset, 'USDT');
  });

  test(
    'missing REST update clock cannot overwrite a known event or resurrect its closed record',
    () {
      final book = AccountUpdateBook()
        ..add(
          accountUpdate(
            positions: [accountPositionUpdate(quantity: '0', wallet: '0')],
          ),
        );
      final rest = mapPositionRisk(
        [positionRiskRow()..remove('updateTime')],
        address: accountAddress,
        receivedAt: DateTime.utc(2026, 11, 3),
      );
      final result = reconcileRiskUpdates(rest, book, since: book.revision);
      expect(result.positions, isEmpty);
      expect(result.lastEventAt, accountUpdate().eventTime);
      final a = reconcileAccountUpdates(accountFixture(), book, since: book.revision);
      expect(a.assets.first.walletBalance.toString(), '102.000000000000000001');
      expect(a.positions, isEmpty);
    },
  );
}
