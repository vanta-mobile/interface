import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/quick_order_provider.dart';
import '../domain/live_order.dart';
import 'live_order_review.dart';

/// Quick orders use the ordinary market order confirmation (and its saved
/// skip preference); submission goes through the quick-order checks.
Future<void> reviewQuickOrder(BuildContext context, WidgetRef ref, LiveOrderIntent intent) =>
    reviewLiveOrder(
      context,
      ref,
      intent,
      onSubmit: () => ref.read(quickOrderProvider.notifier).submit(intent),
    );
