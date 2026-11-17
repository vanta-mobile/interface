import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_order_capacity_provider.dart';

/// Advertised maximum leverage per symbol, remembered from signed bracket
/// reads for this session. The trade header falls back to the public
/// brackets (`publicLeverageProvider`) for symbols not read yet; the public
/// `exchangeInfo` margin percent is not a reliable source.
final symbolMaximumLeverageProvider =
    NotifierProvider<SymbolMaximumLeverageController, Map<String, int>>(
      SymbolMaximumLeverageController.new,
    );

class SymbolMaximumLeverageController extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    ref.listen(mainOrderCapacityProvider.select((s) => s.snapshot), (_, snapshot) {
      final symbol = snapshot?.context.symbol, value = snapshot?.maximumLeverage;
      if (symbol == null || value == null || value <= 0 || state[symbol] == value) return;
      state = Map.unmodifiable({...state, symbol: value});
    });
    return const {};
  }
}
