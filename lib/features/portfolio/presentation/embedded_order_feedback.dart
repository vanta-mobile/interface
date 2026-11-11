import 'package:flutter/material.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/status_view.dart';
import '../domain/account_snapshot.dart';

/// Account read feedback stays within the form; public quotes remain visible.
class EmbeddedOrderFailure extends StatelessWidget {
  const EmbeddedOrderFailure({
    super.key,
    required this.failure,
    required this.retry,
    required this.loading,
  });
  final AccountReadFailure failure;
  final Future<void> Function() retry;
  final bool loading;
  @override
  Widget build(BuildContext context) => StatusFailureView(
    message: accountErrorText(context, failure),
    onRetry: retry,
    retrying: loading,
    retryKey: const Key('trade-order-retry'),
    padding: const EdgeInsets.symmetric(vertical: 24),
  );
}

class EmbeddedOrderSkeleton extends StatelessWidget {
  const EmbeddedOrderSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    key: Key('trade-order-skeleton'),
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(height: 48, radius: 12),
        SizedBox(height: 8),
        SkeletonBox(height: 48, radius: 12),
        SizedBox(height: 12),
        SkeletonBox(height: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 90, radius: 12),
        SizedBox(height: 8),
        SkeletonBox(height: 90, radius: 12),
      ],
    ),
  );
}
