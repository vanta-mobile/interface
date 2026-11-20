import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

export '../../../core/localization/locale_provider.dart';
export 'favorite_symbols_provider.dart' show favoriteSymbolsProvider, FavoriteSymbolsController;

const _symbolPrefKey = 'vanta.lastSymbol';

/// Reads the previously persisted symbol from local storage.
Future<String?> readSavedSymbol() async {
  try {
    return await SharedPreferencesAsync().getString(_symbolPrefKey);
  } catch (_) {
    return null;
  }
}

/// Override at startup with the value from [readSavedSymbol] so the app
/// reopens on the last-used market.
final initialSymbolProvider = Provider<String>((_) => 'BTCUSDT');

final symbolProvider = NotifierProvider<SymbolController, String>(SymbolController.new);

class SymbolController extends Notifier<String> {
  @override
  String build() => ref.watch(initialSymbolProvider);

  void select(String symbol) {
    state = symbol;
    try {
      SharedPreferencesAsync().setString(_symbolPrefKey, symbol).ignore();
    } catch (_) {}
  }
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
