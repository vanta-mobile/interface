import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/scaled_order_provider.dart';
import '../domain/scaled_order.dart';
import 'scaled_order_details.dart';

class ScaledOrderStatus extends ConsumerWidget {
  const ScaledOrderStatus({super.key, required this.symbol});
  final String symbol;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scaledOrderProvider), intent = state.intent;
    if (intent == null || intent.context.symbol != symbol) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final controller = ref.read(scaledOrderProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(l10n.scaledResults, style: Theme.of(context).textTheme.titleMedium),
        SelectableText(intent.address),
        SelectableText(intent.context.symbol),
        Text(l10n.scaledRisk),
        if (state.busy) ...[
          const LinearProgressIndicator(),
          Text(l10n.accountReadPreparing),
          OutlinedButton(
            key: const Key('scaled-stop'),
            onPressed: state.stopRequested ? null : controller.stop,
            child: Text(l10n.batchCancelStop),
          ),
        ],
        if (state.stopRequested) Text(l10n.scaledStopped),
        ScaledResultsList(state: state),
        Text(l10n.liveOrderQueryScope),
        if (state.needsRecheck)
          OutlinedButton(
            key: const Key('scaled-recheck'),
            onPressed: state.busy || auth.busy || auth.identity?.signingAvailable != true
                ? null
                : controller.recheck,
            child: Text(l10n.liveOrderRecheck),
          ),
      ],
    );
  }
}

class ScaledResultsList extends StatefulWidget {
  const ScaledResultsList({super.key, required this.state});
  final ScaledOrderState state;
  @override
  State<ScaledResultsList> createState() => _ScaledResultsListState();
}

class _ScaledResultsListState extends State<ScaledResultsList> {
  static const pageSize = 10;
  int page = 0;
  @override
  void didUpdateWidget(ScaledResultsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state.intent, widget.state.intent)) page = 0;
    final index = widget.state.currentIndex;
    if (index != null && index != oldWidget.state.currentIndex) page = index ~/ pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state, start = page * pageSize;
    final end = math.min(start + pageSize, state.items.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = start; i < end; i++) ScaledItemResult(item: state.items[i], state: state),
        ScaledChildrenPager(
          prefix: 'scaled-results',
          page: page,
          size: pageSize,
          count: state.items.length,
          onChanged: (value) => setState(() => page = value),
        ),
      ],
    );
  }
}

class ScaledItemResult extends StatelessWidget {
  const ScaledItemResult({super.key, required this.item, required this.state});
  final ScaledOrderItem item;
  final ScaledOrderState state;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), intent = state.intent!;
    final result = item.result, failure = item.failure ?? result?.failure;
    return Padding(
      key: ValueKey('scaled-result-${item.index}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScaledChildDetails(
            index: item.index,
            order: item.draft,
            data: intent.context,
            total: intent.plan.totalQuantity,
            clientId: item.clientId,
          ),
          Text(
            state.busy && state.currentIndex == item.index
                ? l10n.batchCancelInProgress
                : !item.submitted
                ? l10n.batchCancelNotSubmitted
                : item.needsRecheck
                ? l10n.liveOrderOutcomeUnknown
                : l10n.liveOrderVerifiedResult(
                    result!.status!,
                    result.executedQuantity!.toString(),
                    result.orderId!,
                  ),
          ),
          if (result?.orderId case final id?) SelectableText(id),
          if (failure != null)
            Text(
              '${tr(context, failure.key)}${failure.code == null ? '' : '\n${l10n.accountErrorCode(failure.code!)}'}',
              style: const TextStyle(color: AppColors.negative),
            ),
        ],
      ),
    );
  }
}
