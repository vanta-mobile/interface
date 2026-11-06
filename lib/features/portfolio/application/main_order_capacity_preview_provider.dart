import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/live_order.dart';
import '../domain/account_snapshot.dart';
import 'main_order_pricing_provider.dart';
import '../domain/live_order_size.dart';
import '../domain/main_order_capacity_preview.dart';
import 'live_order_provider.dart';
import 'main_order_capacity_provider.dart';
import 'symbol_settings_activity.dart';

typedef MainOrderPreviewInput = ({
  LiveOrderContext context,
  LiveOrderDraft draft,
  OrderSizeUnit unit,
  String input,
  int? percent,
});

final mainOrderCapacityPreviewProvider = Provider.autoDispose
    .family<MainOrderCapacityPreview?, MainOrderPreviewInput>((ref, input) {
      ref.watch(mainOrderCapacityProvider);
      ref.watch(liveOrderProvider);
      ref.watch(symbolSettingsActivityProvider);
      final pricing = ref.watch(mainOrderPricingProvider);
      try {
        final data = ref.read(mainOrderCapacityProvider.notifier).current;
        if (data == null || data.context != input.context) {
          final live = ref.read(liveOrderProvider);
          if (input.percent != null || live.context != input.context || live.stale) return null;
          return MainOrderCapacityPreview.manual(
            context: pricing.priceContext(input.context),
            draft: input.draft,
            unit: input.unit,
            input: input.input,
          );
        }
        return MainOrderCapacityPreview(
          snapshot: data,
          valuation: pricing.revalue(data),
          draft: input.draft,
          unit: input.unit,
          input: input.input,
          percent: input.percent,
        );
      } on AccountReadFailure catch (failure) {
        return MainOrderCapacityPreview.unavailable(failure);
      }
    });
