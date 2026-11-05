import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/navigation_provider.dart';

class AppBottomNavigation extends ConsumerWidget {
  const AppBottomNavigation({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appDestinationProvider), l10n = AppLocalizations.of(context);
    final destinations = [
      (AppDestination.futures, Icons.swap_calls_rounded, l10n.perps),
      (AppDestination.markets, Icons.bar_chart_rounded, l10n.markets),
      (AppDestination.portfolio, Icons.account_balance_wallet_outlined, l10n.portfolio),
      (AppDestination.assistant, Icons.auto_awesome_outlined, l10n.assistantNavigation),
      (AppDestination.points, Icons.diamond_outlined, l10n.points),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
          child: Row(
            children: [
              for (final (destination, icon, label) in destinations)
                Expanded(
                  child: Semantics(
                    selected: selected == destination,
                    button: true,
                    child: InkWell(
                      key: ValueKey('navigation-${destination.name}'),
                      onTap: () => ref.read(appDestinationProvider.notifier).select(destination),
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 23,
                                color: selected == destination ? AppColors.accent : AppColors.muted,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selected == destination
                                      ? AppColors.accent
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
