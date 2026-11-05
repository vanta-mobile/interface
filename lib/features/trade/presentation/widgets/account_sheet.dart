import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../auth/presentation/identity_panel.dart';
import '../../application/providers.dart';
import 'primitives.dart';

void showAccountSheet(BuildContext context) => showAppSheet<void>(context, const AccountSheet());

class AccountSheet extends ConsumerWidget {
  const AccountSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const IdentityPanel(),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Image.asset('assets/branding/mark.webp', height: 40, width: 40),
        ),
        const SizedBox(height: 24),
        Text(
          tr(context, 'demo'),
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          tr(context, account.connected ? 'demoExitHint' : 'demoAccountHint'),
          style: const TextStyle(color: AppColors.secondary, height: 1.8),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          key: const Key('enter-demo'),
          onPressed: () {
            final controller = ref.read(accountProvider.notifier);
            account.connected ? controller.disconnect() : controller.connect();
            Navigator.pop(context);
          },
          icon: Icon(account.connected ? Icons.logout_rounded : Icons.bolt_rounded, size: 18),
          label: Text(tr(context, account.connected ? 'demoReset' : 'enterDemo')),
        ),
        const SizedBox(height: 12),
        Text(
          tr(context, 'demoBalance'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    );
  }
}
