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
