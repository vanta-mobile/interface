import 'package:flutter/material.dart';

class NotificationField extends StatelessWidget {
  const NotificationField(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        SelectableText(value),
      ],
    ),
  );
}
