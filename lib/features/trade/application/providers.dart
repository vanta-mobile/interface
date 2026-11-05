import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../market/application/market_providers.dart';
import '../domain/demo_order.dart';
export '../../market/application/selection_providers.dart';
export '../../market/application/market_providers.dart' show currentMarketProvider;

final marketProvider = asterMarketProvider;
final bookProvider = asterBookProvider;
final accountProvider = NotifierProvider<AccountController, DemoAccount>(AccountController.new);

class AccountController extends Notifier<DemoAccount> {
  int _counter = 0;
  @override
  DemoAccount build() => DemoAccount.initial();
  void connect() => state = DemoAccount(connected: true, balance: state.balance);
  void disconnect() => state = DemoAccount.initial();

  String? validate(OrderDraft draft) {
    if (!state.connected) return 'connect';
    final invalid = draft.validate(state.available);
    if (invalid != null) return invalid;
    if (draft.reduceOnly) {
      final matches = state.positions.where(
        (p) =>
            p.draft.symbol == draft.symbol &&
            p.draft.buy != draft.buy &&
            p.draft.parsedQuantity >= draft.parsedQuantity,
      );
      if (matches.isEmpty || !draft.market) return 'reduceHint';
    }
    return null;
  }

  String? submit(OrderDraft draft) {
    final invalid = validate(draft);
    if (invalid != null) return invalid;
    final order = DemoOrder(
      id: 'DEMO-${DateTime.now().millisecondsSinceEpoch}-${++_counter}',
      draft: draft,
      status: draft.market ? 'filled' : 'pending',
    );
    final positions = [...state.positions];
    var realized = Decimal.zero;
    if (draft.reduceOnly) {
      final index = positions.indexWhere(
        (p) =>
            p.draft.symbol == draft.symbol &&
            p.draft.buy != draft.buy &&
            p.draft.parsedQuantity >= draft.parsedQuantity,
      );
      final previous = positions.removeAt(index);
      realized =
          (draft.parsedPrice - previous.draft.parsedPrice) *
          draft.parsedQuantity *
          Decimal.fromInt(previous.draft.buy ? 1 : -1);
      final remaining = previous.draft.parsedQuantity - draft.parsedQuantity;
      if (remaining > Decimal.zero) {
        final p = previous.draft;
        positions.insert(
          index,
          DemoOrder(
            id: previous.id,
            status: previous.status,
            draft: OrderDraft(
              symbol: p.symbol,
              buy: p.buy,
              market: true,
              quantity: remaining.toString(),
              price: p.price,
              leverage: p.leverage,
              precision: p.precision,
            ),
          ),
        );
      }
    } else if (draft.market) {
      positions.add(order);
    }
    state = DemoAccount(
      connected: true,
      balance: state.balance + realized - (draft.market ? draft.fee : Decimal.zero),
      positions: List.unmodifiable(positions),
      orders: draft.market ? state.orders : List.unmodifiable([...state.orders, order]),
      history: List.unmodifiable([order, ...state.history]),
    );
    return null;
  }

  void cancel(String id) {
    state = DemoAccount(
      connected: true,
      balance: state.balance,
      positions: state.positions,
      orders: state.orders.where((o) => o.id != id).toList(),
      history: state.history.map((o) => o.id == id ? o.withStatus('canceledStatus') : o).toList(),
    );
  }

  void close(String id, Decimal exitPrice) {
    final order = state.positions.firstWhere((p) => p.id == id);
    final p = order.draft;
    final pnl = (exitPrice - p.parsedPrice) * p.parsedQuantity * Decimal.fromInt(p.buy ? 1 : -1);
    final fee = exitPrice * p.parsedQuantity * demoFeeRate;
    state = DemoAccount(
      connected: true,
      balance: state.balance + pnl - fee,
      positions: state.positions.where((o) => o.id != id).toList(),
      orders: state.orders,
      history: [
        DemoOrder(
          id: '$id-CLOSE',
          draft: OrderDraft(
            symbol: p.symbol,
            buy: !p.buy,
            market: true,
            quantity: p.quantity,
            price: exitPrice.toString(),
            leverage: p.leverage,
            precision: p.precision,
          ),
          status: 'filled',
        ),
        ...state.history,
      ],
    );
  }
}
