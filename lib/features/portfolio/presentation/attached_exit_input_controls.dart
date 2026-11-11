import 'package:flutter/material.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/attached_exit_input.dart';
import '../domain/attached_order.dart';
import '../domain/live_order.dart';
import '../domain/live_order_attachment.dart';
import '../domain/live_order_trigger.dart';
import 'attached_exit_preview.dart';
import 'live_order_embedded_triggers.dart';

class AttachedExitInputControls extends StatefulWidget {
  const AttachedExitInputControls({
    super.key,
    required this.kind,
    required this.enabled,
    required this.advanced,
    required this.data,
    required this.entry,
    required this.onChanged,
    this.compact = false,
  });
  final LiveOrderTriggerKind kind;

  /// Trade-workspace box: active once a value is entered, market execution.
  final bool compact;
  final bool enabled, advanced;
  final LiveOrderContext data;
  final LiveOrderDraft entry;
  final ValueChanged<AttachedExitInput?> onChanged;
  @override
  State<AttachedExitInputControls> createState() => _AttachedExitInputControlsState();
}

class _AttachedExitInputControlsState extends State<AttachedExitInputControls> {
  // Preserve independent raw inputs across mode switches and dormant settings.
  final values = {for (final mode in AttachedExitInputMode.values) mode: TextEditingController()};
  final limitPrice = TextEditingController();
  bool selected = false, protect = false;
  AttachedExitInputMode mode = AttachedExitInputMode.pnl;
  LiveOrderTriggerBasis basis = LiveOrderTriggerBasis.mark;
  AttachedExitExecution execution = AttachedExitExecution.market;
  String get name => widget.kind == LiveOrderTriggerKind.takeProfit ? 'tp' : 'sl';
  AttachedExitInput get input => AttachedExitInput(
    kind: widget.kind,
    mode: mode,
    value: values[mode]!.text.trim(),
    basis: basis,
    execution: execution,
    limitPrice: limitPrice.text.trim(),
    protect: protect,
  );
  bool get active => widget.compact ? values[mode]!.text.trim().isNotEmpty : selected;
  void emit() => widget.onChanged(active ? input : null);
  @override
  void dispose() {
    for (final value in values.values) {
      value.dispose();
    }
    limitPrice.dispose();
    super.dispose();
  }

  void changed() {
    setState(() {});
    emit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effective = widget.advanced ? input : input.withExecution(AttachedExitExecution.market);
    final resolved = effective.resolve(widget.data, widget.entry);
    final reference = attachedEntryReference(widget.data, widget.entry);
    final label = name == 'tp' ? l10n.attachedOrderTakeProfit : l10n.attachedOrderStopLoss;
    // Missing entry quantity/prices belong to the entry form, not to this
    // already filled exit. Quote renewal must not flash a "please fill" error.
    final needsEntry = const {
      'attachedOrderPreviewUnavailable',
      'liveOrderInvalidQuantity',
    }.contains(resolved.failure);
    final issue = values[mode]!.text.isNotEmpty && resolved.failure != null && !needsEntry
        ? l10n.attachedOrderExitIssue(
            label,
            resolved.failure == 'attachedOrderPriceDirection' && reference != null
                ? l10n.attachedOrderDirectionHint(
                    resolved.exit.rises(!widget.entry.buy) ? '>' : '<',
                    reference.toString(),
                    widget.data.rules.quoteAsset,
                  )
                : tr(context, resolved.failure!),
          )
        : null;
    if (widget.compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: EmbeddedExitField(
          kind: widget.kind,
          controller: values[mode]!,
          mode: mode,
          basis: basis,
          asset: widget.data.rules.quoteAsset,
          enabled: widget.enabled,
          issue: issue,
          onValue: changed,
          onMode: (value) {
            mode = value;
            changed();
          },
          onBasis: (value) {
            basis = value;
            changed();
          },
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          key: Key('attached-$name-enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: selected,
          onChanged: !widget.enabled
              ? null
              : (value) {
                  selected = value ?? false;
                  changed();
                },
        ),
        if (selected) ...[
          _valueControls(l10n),
          _basisControl(l10n),
          if (widget.advanced) _executionControls(l10n),
          AttachedExitPreview(
            data: widget.data,
            entry: widget.entry,
            resolution: resolved,
            derived: mode != AttachedExitInputMode.price,
          ),
          if (issue != null) Text(issue, style: const TextStyle(color: AppColors.negative)),
          CheckboxListTile(
            key: Key('attached-$name-protect'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.attachedOrderPriceProtect),
            value: protect,
            onChanged: !widget.enabled
                ? null
                : (value) {
                    protect = value ?? false;
                    changed();
                  },
          ),
        ],
      ],
    );
  }

  Widget _valueControls(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<AttachedExitInputMode>(
        key: Key('attached-$name-mode'),
        initialValue: mode,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.attachedOrderInputMode),
        items: [
          for (final value in AttachedExitInputMode.values)
            DropdownMenuItem(
              value: value,
              child: Text(switch (value) {
                AttachedExitInputMode.pnl => l10n.attachedOrderPnlMode,
                AttachedExitInputMode.price => l10n.attachedOrderPriceMode,
                AttachedExitInputMode.roi => l10n.attachedOrderRoiMode,
              }),
            ),
        ],
        onChanged: !widget.enabled
            ? null
            : (value) {
                if (value != null) {
                  mode = value;
                  changed();
                }
              },
      ),
      TextField(
        key: Key('attached-$name-price'),
        controller: values[mode],
        readOnly: !widget.enabled,
        keyboardType: TextInputType.numberWithOptions(
          decimal: true,
          signed: mode != AttachedExitInputMode.price,
        ),
        decoration: InputDecoration(
          labelText: switch (mode) {
            AttachedExitInputMode.pnl => l10n.attachedOrderPnlInput(widget.data.rules.quoteAsset),
            AttachedExitInputMode.price => l10n.liveOrderPrice(widget.data.rules.quoteAsset),
            AttachedExitInputMode.roi => l10n.attachedOrderRoiMode,
          },
        ),
        onChanged: (_) => changed(),
      ),
    ],
  );

  Widget _basisControl(AppLocalizations l10n) => DropdownButtonFormField<LiveOrderTriggerBasis>(
    key: Key('attached-$name-basis'),
    initialValue: basis,
    isExpanded: true,
    decoration: InputDecoration(labelText: l10n.attachedOrderBasis),
    items: [
      for (final value in LiveOrderTriggerBasis.values)
        DropdownMenuItem(
          value: value,
          child: Text(
            value == LiveOrderTriggerBasis.last
                ? l10n.openOrdersLastPrice
                : l10n.openOrdersMarkPrice,
          ),
        ),
    ],
    onChanged: !widget.enabled
        ? null
        : (value) {
            if (value != null) {
              basis = value;
              changed();
            }
          },
  );

  Widget _executionControls(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<AttachedExitExecution>(
        key: Key('attached-$name-execution'),
        initialValue: execution,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.attachedOrderExecution),
        items: [
          for (final value in AttachedExitExecution.values)
            DropdownMenuItem(value: value, child: Text(attachedExecutionLabel(l10n, value))),
        ],
        onChanged: !widget.enabled
            ? null
            : (value) {
                if (value != null) {
                  execution = value;
                  changed();
                }
              },
      ),
      if (execution == AttachedExitExecution.manualLimit)
        TextField(
          key: Key('attached-$name-limit'),
          controller: limitPrice,
          readOnly: !widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.attachedOrderLimitPrice(widget.data.rules.quoteAsset),
          ),
          onChanged: (_) => changed(),
        ),
    ],
  );
}
