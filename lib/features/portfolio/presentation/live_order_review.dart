import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/trade_theme.dart';
import '../application/live_order_provider.dart';
import '../application/main_order_allocation_provider.dart';
import '../application/order_confirmation_provider.dart';
import '../application/order_review_activity_provider.dart';
import '../application/main_order_review_provider.dart';
import '../application/main_order_review_submission_provider.dart';
import '../application/main_order_refresh_provider.dart';
import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import '../domain/main_order_allocation.dart';
import '../domain/live_order_size.dart';
import '../domain/order_confirmation.dart';
import 'order_confirmation_dialog.dart';

Future<void> reviewLiveOrder(
  BuildContext context,
  WidgetRef ref,
  LiveOrderIntent intent, {
  OrderSizeResolution? sizing,
  Future<void> Function()? onSubmit,
  MainOrderAllocationReview? allocationReview,
  bool alwaysConfirm = false,
}) async {
  // One review at a time: a second request while a confirmation (or a direct
  // submission it started) is open must not open another route.
  if (ref.read(orderReviewActivityProvider) > 0) return;
  // A fixed review keeps the facts it opened with: stop a background read that
  // is already running so its late result cannot replace them. The main
  // confirmation (with an allocation review) keeps renewing in place.
  if (allocationReview == null && ref.read(mainOrderRefreshProvider).background) {
    ref.read(mainOrderRefreshProvider.notifier).stop();
  }
  final activity = ref.read(orderReviewActivityProvider.notifier);
  activity.begin();
  try {
    await _reviewLiveOrder(
      context,
      ref,
      intent,
      sizing: sizing,
      onSubmit: onSubmit,
      allocationReview: allocationReview,
      alwaysConfirm: alwaysConfirm,
    );
  } finally {
    activity.end();
  }
}

Future<void> _reviewLiveOrder(
  BuildContext context,
  WidgetRef ref,
  LiveOrderIntent intent, {
  OrderSizeResolution? sizing,
  Future<void> Function()? onSubmit,
  MainOrderAllocationReview? allocationReview,
  required bool alwaysConfirm,
}) async {
  final controller = ref.read(liveOrderProvider.notifier);
  Future<void> submit() => onSubmit?.call() ?? controller.submit(intent);
  final identity = ref.read(authProvider).identity;
  final container = ProviderScope.containerOf(context, listen: false);
  Future<OrderSubmissionOutcome> submitCurrent() async {
    if (!identical(identity, container.read(authProvider).identity)) {
      return const OrderSubmissionOutcome(OrderSubmissionKind.notSubmitted);
    }
    if (allocationReview case final original?) {
      return _observe(
        container,
        original.intent,
        () => container.read(mainOrderReviewSubmissionProvider.notifier).submit(original),
      );
    }
    return _observe(container, intent, submit);
  }

  final preference = ref.read(orderConfirmationProvider(orderConfirmationKind(intent.draft)));
  // Reducing and entire-position close flows keep their dedicated review.
  // Terms filled from outside the app (a deep link) are always confirmed.
  if (!alwaysConfirm && !intent.draft.reducing && preference.canSkip) {
    await submitCurrent();
    return;
  }
  // The dialog can outlive the form (for example after a logout), so its
  // submission reads through the container rather than the form's ref.
  await showDialog<void>(
    context: context,
    // A stray touch must not dismiss a financial confirmation.
    barrierDismissible: false,
    barrierColor: TradeColors.scrim,
    builder: (_) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Consumer(
        builder: (_, ref, _) {
          final current = allocationReview == null
              ? null
              : ref.watch(mainOrderReviewProvider(allocationReview));
          final live = ref.watch(liveOrderProvider);
          final frozen = live.busy && live.intent?.clientOrderId == intent.clientOrderId
              ? live.intent
              : null;
          return OrderConfirmationDialog(
            intent: frozen ?? current?.review?.intent ?? intent,
            sizing: current?.review?.side.size ?? sizing,
            ready: frozen != null || current == null || current.review != null,
            submitWhileUpdating: allocationReview != null,
            submit: submitCurrent,
          );
        },
      ),
    ),
  );
}

/// Reads the settled order and allocation state around one submission.
Future<OrderSubmissionOutcome> _observe(
  ProviderContainer ref,
  LiveOrderIntent intent,
  Future<void> Function() submit,
) async {
  final before = ref.read(liveOrderProvider), allocation = ref.read(mainOrderAllocationProvider);
  try {
    await submit();
  } on AccountReadFailure catch (failure) {
    return OrderSubmissionOutcome(OrderSubmissionKind.notSubmitted, failure);
  }
  final after = ref.read(liveOrderProvider);
  if (identical(before, after)) {
    final current = ref.read(mainOrderAllocationProvider);
    return OrderSubmissionOutcome(
      OrderSubmissionKind.notSubmitted,
      identical(allocation, current) ? null : current.failure,
    );
  }
  final result = after.intent?.clientOrderId == intent.clientOrderId ? after.result : null;
  if (result != null && result.failure == null && !result.needsRecheck) {
    return const OrderSubmissionOutcome(OrderSubmissionKind.success);
  }
  if (after.needsRecheck) {
    return OrderSubmissionOutcome(OrderSubmissionKind.unknown, result?.failure);
  }
  return OrderSubmissionOutcome(OrderSubmissionKind.failed, after.failure ?? result?.failure);
}
