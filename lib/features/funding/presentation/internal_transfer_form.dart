import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/futures_asset_mode_status.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/internal_transfer_provider.dart';
import '../application/internal_transfer_storage_provider.dart';
import '../domain/internal_transfer.dart';

String internalTransferDirectionLabel(AppLocalizations l10n, InternalTransferDirection d) =>
    d == InternalTransferDirection.spotToFutures
    ? l10n.internalTransferToFutures
    : l10n.internalTransferToSpot;

class InternalTransferForm extends ConsumerStatefulWidget {
  const InternalTransferForm({super.key});
  @override
  ConsumerState<InternalTransferForm> createState() => _InternalTransferFormState();
}

class _InternalTransferFormState extends ConsumerState<InternalTransferForm> {
  late final _amount = TextEditingController(text: ref.read(internalTransferProvider).amount);
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(internalTransferProvider),
        controller = ref.read(internalTransferProvider.notifier),
        l10n = AppLocalizations.of(context);
    ref.listen(internalTransferProvider.select((s) => s.amount), (_, value) {
      if (_amount.text != value) {
        _amount.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    });
    final c = state.context;
    final editable = !state.busy && ref.watch(pendingInternalTransfersProvider).isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(l10n.internalTransferDirection),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in InternalTransferDirection.values)
              ChoiceChip(
                key: Key('internal-transfer-${d.name}'),
                label: Text(internalTransferDirectionLabel(l10n, d)),
                selected: state.direction == d,
                onSelected: editable && c != null && d != state.direction
                    ? (_) => controller.select(direction: d)
                    : null,
              ),
          ],
        ),
        if (c != null) ...[
          const SizedBox(height: 12),
          _AssetSelector(state: state, enabled: editable),
          InternalTransferSnapshot(contextData: c, stale: state.stale),
        ],
        TextField(
          key: const Key('internal-transfer-amount'),
          controller: _amount,
          enabled: editable,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          maxLength: 80,
          decoration: InputDecoration(labelText: l10n.internalTransferAmount),
          onChanged: controller.setAmount,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            key: const Key('internal-transfer-max'),
            onPressed: editable && !state.stale && c?.maxInput != null ? controller.max : null,
            child: Text(l10n.internalTransferMax),
          ),
        ),
        if (state.amount.isNotEmpty && c != null && c.validate(state.amount) != null)
          Text(
            tr(context, c.validate(state.amount)!),
            style: const TextStyle(color: AppColors.warning),
          ),
        Text(l10n.internalTransferPrecisionHint),
      ],
    );
  }
}

class _AssetSelector extends ConsumerWidget {
  const _AssetSelector({required this.state, required this.enabled});
  final InternalTransferState state;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = state.context!.catalog.assets, l10n = AppLocalizations.of(context);
    if (assets.isEmpty) return Text(l10n.internalTransferEmpty);
    return DropdownButtonFormField<String>(
      key: ValueKey(('internal-transfer-asset', state.asset, assets.map((a) => a.asset).join(','))),
      initialValue: assets.any((a) => a.asset == state.asset) ? state.asset : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.internalTransferAsset),
      items: [for (final a in assets) DropdownMenuItem(value: a.asset, child: Text(a.asset))],
      onChanged: enabled
          ? (asset) {
              if (asset != null && asset != state.asset) {
                ref.read(internalTransferProvider.notifier).select(asset: asset);
              }
            }
          : null,
    );
  }
}

class InternalTransferSnapshot extends StatelessWidget {
  const InternalTransferSnapshot({super.key, required this.contextData, required this.stale});
  final InternalTransferContext contextData;
  final bool stale;
  @override
  Widget build(BuildContext context) {
    final c = contextData, l10n = AppLocalizations.of(context);
    String quantity(Object? value) => value == null ? '—' : '$value ${c.assetName}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stale)
          Text(l10n.internalTransferStale, style: const TextStyle(color: AppColors.warning)),
        ValueRow(l10n.rebalanceCurrentMode, assetModeLabel(l10n, c.mode)),
        ValueRow(l10n.internalTransferMaximum, quantity(c.maximum)),
        ValueRow(l10n.internalTransferSpotFree, quantity(c.spotFree)),
        ValueRow(l10n.internalTransferFuturesWallet, quantity(c.futuresWallet)),
        Text(l10n.accountSnapshotTime(c.receivedAt.toUtc().toIso8601String())),
        Text(l10n.internalTransferLimitHint),
      ],
    );
  }
}
