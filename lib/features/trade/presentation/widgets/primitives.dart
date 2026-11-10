import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
export 'coin_icon.dart';

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = EdgeInsets.zero, this.flat = false});
  final bool flat;
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: flat ? AppColors.authBackground : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: flat ? null : Border.all(color: AppColors.line.withValues(alpha: .45)),
    ),
    child: child,
  );
}

class MutedText extends StatelessWidget {
  const MutedText(this.text, {super.key, this.size = 11, this.color = AppColors.secondary});
  final String text;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: size, color: color),
  );
}

class TabChoices extends StatelessWidget {
  const TabChoices({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.underlined = false,
  });
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool underlined;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(
        items.length,
        (i) => InkWell(
          onTap: () => onSelect(i),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: !underlined && selected == i ? AppColors.raised : null,
              borderRadius: underlined ? null : BorderRadius.circular(6),
              border: underlined && selected == i
                  ? const Border(bottom: BorderSide(color: AppColors.accent, width: 2))
                  : null,
            ),
            child: Text(
              items[i],
              style: TextStyle(
                color: selected == i ? AppColors.text : AppColors.secondary,
                fontSize: 12,
                fontWeight: selected == i ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ValueRow extends StatelessWidget {
  const ValueRow(this.label, this.value, {super.key, this.color, this.size = 11});
  final String label, value;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: size, color: AppColors.secondary),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: size,
              color: color ?? AppColors.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

void message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<T?> showAppSheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 520),
  builder: (context) => Padding(
    padding: EdgeInsets.only(
      left: 24,
      right: 24,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 28,
    ),
    child: SingleChildScrollView(child: child),
  ),
);
