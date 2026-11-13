import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../../../core/localization/locale_provider.dart';
export 'favorite_symbols_provider.dart' show favoriteSymbolsProvider, FavoriteSymbolsController;

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

final orderPriceProvider = NotifierProvider<OrderPriceController, String>(OrderPriceController.new);

class OrderPriceController extends Notifier<String> {
  @override
  String build() => '';
  void setPrice(String price) => state = price;
}
