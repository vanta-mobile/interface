import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/attached_exit_input.dart';
import '../domain/live_order.dart';
import '../domain/live_order_attachment.dart';
import '../domain/live_order_trigger.dart';
import 'attached_exit_input_controls.dart';

class LiveOrderAttachmentControls extends StatefulWidget {
  const LiveOrderAttachmentControls({
    super.key,
    required this.allowed,
    required this.enabled,
    required this.data,
    required this.entry,
    required this.onChanged,
  });
  final bool allowed, enabled;
  final LiveOrderContext data;
  final LiveOrderDraft entry;
  final ValueChanged<AttachedOrderInput?> onChanged;
  @override
  State<LiveOrderAttachmentControls> createState() => _LiveOrderAttachmentControlsState();
}

class _LiveOrderAttachmentControlsState extends State<LiveOrderAttachmentControls> {
  bool selected = false, advanced = false;
  AttachedExitInput? takeProfit, stopLoss;
  AttachedExitInput? effective(AttachedExitInput? input) =>
      advanced ? input : input?.withExecution(AttachedExitExecution.market);
  void emit() => widget.onChanged(
    selected
        ? AttachedOrderInput(takeProfit: effective(takeProfit), stopLoss: effective(stopLoss))
        : null,
  );
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Visibility(
      visible: widget.allowed,
      maintainState: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: const Key('live-order-attached'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.attachedOrderTitle),
            value: selected,
            onChanged: !widget.enabled
                ? null
                : (value) {
                    setState(() => selected = value);
                    emit();
                  },
          ),
          Visibility(
            visible: selected,
            maintainState: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.attachedOrderLifecycle),
                SwitchListTile(
                  key: const Key('attached-advanced'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.attachedOrderAdvanced),
                  value: advanced,
                  onChanged: !widget.enabled
                      ? null
                      : (value) {
                          setState(() => advanced = value);
                          emit();
                        },
                ),
                for (final kind in LiveOrderTriggerKind.values.reversed)
                  AttachedExitInputControls(
                    key: ValueKey(kind),
                    kind: kind,
                    enabled: widget.enabled,
                    advanced: advanced,
                    data: widget.data,
                    entry: widget.entry,
                    onChanged: (input) {
                      if (kind == LiveOrderTriggerKind.takeProfit) {
                        takeProfit = input;
                      } else {
                        stopLoss = input;
                      }
                      emit();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
