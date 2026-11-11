import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/market_failure.dart';
import '../../../../core/presentation/status_view.dart';
import '../../../../core/strings.dart';
import '../../application/providers.dart';
import '../../../market/domain/market.dart';

/// Reconnects the shared depth/trades feed and waits for its first event.
Future<void> retryOrderBook(WidgetRef ref) async {
  ref.invalidate(bookProvider);
  await ref.read(bookProvider.future);
}

/// Section state while the shared book feed has no rows to show.
class BookFeedState extends ConsumerWidget {
  const BookFeedState({super.key, required this.feed, required this.loading, this.empty});
  final AsyncValue<OrderBook> feed;
  final Widget loading;
  final Widget? empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = feed.isReloading ? null : feed.value;
    final error = feed.error;
    if (feed.hasError || book?.connected == false) {
      return StatusFailureView(
        message: error is MarketFailure ? error.displayMessage : tr(context, 'bookError'),
        onRetry: () => retryOrderBook(ref),
      );
    }
    if (book == null) return loading;
    return empty ?? const StatusEmptyView();
  }
}
