import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';

const _rowHeight = 36.0;

/// 24-hour wheel picker; resolves to `HH:MM` or null when cancelled.
Future<String?> showQuietTimePicker(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  final parts = initial?.split(':');
  return showDialog<String>(
    context: context,
    barrierColor: TradeColors.transparent,
    builder: (_) => QuietTimePicker(
      title: title,
      hour: parts == null ? 0 : int.parse(parts[0]),
      minute: parts == null ? 0 : int.parse(parts[1]),
    ),
  );
}

class QuietTimePicker extends StatefulWidget {
  const QuietTimePicker({super.key, required this.title, required this.hour, required this.minute});
  final String title;
  final int hour, minute;
  @override
  State<QuietTimePicker> createState() => _QuietTimePickerState();
}

class _QuietTimePickerState extends State<QuietTimePicker> {
  late int hour = widget.hour, minute = widget.minute;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dialog(
      key: const Key('quiet-time-picker'),
      backgroundColor: TradeColors.sheet,
      insetPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 24),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: TradeColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 359),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: TradeTypography.symbol.copyWith(fontSize: 14, height: 20 / 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Wheel(
                      key: const Key('quiet-time-hour'),
                      label: l.pushHour,
                      count: 24,
                      initial: hour,
                      onChanged: (value) => hour = value,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Wheel(
                      key: const Key('quiet-time-minute'),
                      label: l.pushMinute,
                      count: 60,
                      initial: minute,
                      onChanged: (value) => minute = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Action(
                      key: const Key('quiet-time-cancel'),
                      label: l.cancel,
                      background: TradeColors.card,
                      foreground: TradeColors.text,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Action(
                      key: const Key('quiet-time-confirm'),
                      label: l.pushConfirm,
                      background: TradeColors.accent,
                      foreground: TradeColors.onAccent,
                      onPressed: () => Navigator.pop(
                        context,
                        '${'$hour'.padLeft(2, '0')}:${'$minute'.padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wheel extends StatefulWidget {
  const _Wheel({
    super.key,
    required this.label,
    required this.count,
    required this.initial,
    required this.onChanged,
  });
  final String label;
  final int count, initial;
  final ValueChanged<int> onChanged;
  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final controller = FixedExtentScrollController(initialItem: widget.initial);
  late int selected = widget.initial;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: TradeTypography.body.copyWith(color: TradeColors.secondary)),
      const SizedBox(height: 8),
      Container(
        height: _rowHeight * 5,
        decoration: BoxDecoration(color: TradeColors.card, borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Center(
              child: Container(
                height: _rowHeight,
                decoration: BoxDecoration(
                  color: TradeColors.control,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: _rowHeight,
              diameterRatio: 100,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                final value = index % widget.count;
                setState(() => selected = value);
                widget.onChanged(value);
              },
              childDelegate: ListWheelChildLoopingListDelegate(
                children: [
                  for (var value = 0; value < widget.count; value++)
                    Center(
                      child: Text(
                        '$value'.padLeft(2, '0'),
                        style: value == selected
                            ? TradeTypography.symbol
                            : TradeTypography.option.copyWith(color: TradeColors.muted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });
  final String label;
  final Color background, foreground;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: TradeTypography.option.copyWith(fontSize: 14, height: 20 / 14),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
}
