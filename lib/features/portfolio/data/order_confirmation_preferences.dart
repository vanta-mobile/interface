import 'package:shared_preferences/shared_preferences.dart';

import '../domain/order_confirmation.dart';

abstract interface class OrderConfirmationPreferences {
  Future<bool> read(OrderConfirmationKind kind);
  Future<void> write(OrderConfirmationKind kind, bool required);
}

class LocalOrderConfirmationPreferences implements OrderConfirmationPreferences {
  LocalOrderConfirmationPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;

  // Preserve the existing explicit market choice without applying it to
  // any newly supported mode. Unknown/missing values still require review.
  String _key(OrderConfirmationKind kind) => switch (kind) {
    OrderConfirmationKind.market => 'vanta.confirmMarketOrders',
    OrderConfirmationKind.limit => 'vanta.confirmLimitOrders',
    OrderConfirmationKind.stopLimit => 'vanta.confirmStopLimitOrders',
    OrderConfirmationKind.stopMarket => 'vanta.confirmStopMarketOrders',
    OrderConfirmationKind.trailing => 'vanta.confirmTrailingOrders',
  };
  @override
  Future<bool> read(OrderConfirmationKind kind) async =>
      await _preferences.getBool(_key(kind)) ?? true;
  @override
  Future<void> write(OrderConfirmationKind kind, bool required) =>
      _preferences.setBool(_key(kind), required);
}
