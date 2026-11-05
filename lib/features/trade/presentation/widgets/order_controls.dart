import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import 'primitives.dart';

class OrderOptionButton extends StatelessWidget {
  const OrderOptionButton({super.key, required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 12), const SizedBox(width: 4)],
          Flexible(child: Text(label, style: const TextStyle(fontSize: 11))),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 13),
        ],
      ),
    ),
  );
}

class OrderInput extends StatelessWidget {
  const OrderInput({
    super.key,
    required this.controller,
    required this.label,
    required this.unit,
    required this.fieldKey,
    required this.onChanged,
    this.trailing,
  });
  final TextEditingController controller;
  final String label, unit, fieldKey;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
    decoration: BoxDecoration(
      color: AppColors.input,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: MutedText(label, size: 10)),
            MutedText(unit, size: 9),
          ],
        ),
        TextField(
          key: Key(fieldKey),
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: '0.00',
            isDense: true,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            suffixIconConstraints: const BoxConstraints(minWidth: 22),
            suffixIcon: trailing,
          ),
        ),
      ],
    ),
  );
}

class LeverageSheet extends StatefulWidget {
  const LeverageSheet({super.key, required this.value});
  final int value;
  @override
  State<LeverageSheet> createState() => LeverageSheetState();
}

class LeverageSheetState extends State<LeverageSheet> {
  late double value = widget.value.toDouble();
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        tr(context, 'leverage'),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 24),
      Text(
        '${value.round()}×',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w600, color: AppColors.accent),
      ),
      Slider(
        value: value,
        min: 1,
        max: 100,
        divisions: 99,
        onChanged: (v) => setState(() => value = v),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final v in [1, 5, 10, 25, 50, 100])
            TextButton(
              onPressed: () => setState(() => value = v.toDouble()),
              style: TextButton.styleFrom(
                minimumSize: const Size(32, 44),
                padding: EdgeInsets.zero,
              ),
              child: Text('$v×', style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        tr(context, 'leverageHint'),
        style: const TextStyle(color: AppColors.warning, fontSize: 12),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => Navigator.pop(context, value.round()),
        child: Text(tr(context, 'confirm')),
      ),
    ],
  );
}
