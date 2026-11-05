import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/strategy_execution_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/order_query.dart';
import '../domain/strategy_execution.dart';
import 'strategy_execution_leg_card.dart';

void openStrategyExecution(BuildContext context, OrderQuery order, String strategyId) {
  // A route rebuild (for example a locale change) must keep the same provider key.
  final query = StrategyExecutionQuery(order: order, strategyId: strategyId);
  Navigator.of(context)
      .push<void>(MaterialPageRoute(builder: (_) => StrategyExecutionScreen(query: query)));
}

class StrategyExecutionScreen extends ConsumerStatefulWidget {
  const StrategyExecutionScreen({super.key, required this.query});
  final StrategyExecutionQuery query;
  @override
  ConsumerState<StrategyExecutionScreen> createState() => _StrategyExecutionScreenState();
}

class _StrategyExecutionScreenState extends ConsumerState<StrategyExecutionScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      ref.read(strategyExecutionProvider(widget.query).notifier).onLifecycleChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), query = widget.query;
    final state = ref.watch(strategyExecutionProvider(query));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.strategyExecutionTitle)),
      body: SafeArea(
        child: ListView(
          key: const Key('strategy-execution-page'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.strategyExecutionScope),
            SelectableText(query.order.symbol),
            SelectableText(query.order.address),
            SelectableText(query.order.clientOrderId),
            SelectableText(query.strategyId),
            const SizedBox(height: 12),
            Text(l10n.strategyExecutionSignHint),
            _ReadControls(query: query),
            if (state.failure case final failure?)
              Text(
                '${tr(context, failure.key)}${failure.code == null ? '' : ' ${l10n.accountErrorCode(failure.code!)}'}',
                style: const TextStyle(color: AppColors.negative),
              ),
            if (state.stale)
              Text(l10n.strategyExecutionStale, style: const TextStyle(color: AppColors.warning)),
            if (state.snapshot case final snapshot?) ...[
              ValueRow(l10n.attachedOrderStrategyStatus, snapshot.strategy.status),
              ValueRow(
                l10n.strategyExecutionStrategyTime,
                DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(snapshot.strategyCheckedAt.toUtc()),
              ),
              for (final leg in snapshot.legs)
                StrategyExecutionLegCard(leg: leg, query: query.order, units: snapshot.units),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadControls extends ConsumerWidget {
  const _ReadControls({required this.query});
  final StrategyExecutionQuery query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(strategyExecutionProvider(query));
    final auth = ref.watch(authProvider), activity = ref.watch(symbolSettingsActivityProvider);
    final controller = ref.read(strategyExecutionProvider(query).notifier);
    final sameWallet =
        auth.identity?.walletAddress?.toLowerCase() == query.order.address.toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const Key('strategy-execution-read'),
          onPressed:
              state.busy ||
                  auth.busy ||
                  !sameWallet ||
                  auth.identity?.signingAvailable != true ||
                  activity.owner != null
              ? null
              : controller.read,
          child: Text(l10n.strategyExecutionRead),
        ),
        if (state.busy) ...[
          const LinearProgressIndicator(),
          Text(
            state.sequence == null
                ? l10n.strategyExecutionCheckingStrategy
                : l10n.strategyExecutionCheckingLeg(state.sequence!),
          ),
          OutlinedButton(
            key: const Key('strategy-execution-stop'),
            onPressed: controller.stop,
            child: Text(l10n.strategyExecutionStop),
          ),
        ],
        if (!sameWallet)
          Text(l10n.authWalletChanged, style: const TextStyle(color: AppColors.warning)),
      ],
    );
  }
}
