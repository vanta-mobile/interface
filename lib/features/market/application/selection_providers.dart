import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../../../core/localization/locale_provider.dart';

final symbolProvider = NotifierProvider<SymbolController, String>(SymbolController.new);

class SymbolController extends Notifier<String> {
  @override
  String build() => 'BTCUSDT';
  void select(String symbol) => state = symbol;
}

final intervalProvider = NotifierProvider<IntervalController, String>(IntervalController.new);

class IntervalController extends Notifier<String> {
  @override
  String build() => '1m';
  void select(String interval) => state = interval;
}

final favoriteSymbolsProvider = NotifierProvider<FavoriteSymbolsController, Set<String>>(
  FavoriteSymbolsController.new,
);

class FavoriteSymbolsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String symbol) {
    final next = {...state};
    if (!next.add(symbol)) next.remove(symbol);
    state = Set.unmodifiable(next);
  }
}

final orderPriceProvider = NotifierProvider<OrderPriceController, String>(OrderPriceController.new);

class OrderPriceController extends Notifier<String> {
  @override
  String build() => '';
  void setPrice(String price) => state = price;
}
