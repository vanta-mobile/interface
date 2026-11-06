import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/navigation_provider.dart';

class AppBottomNavigation extends ConsumerWidget {
  const AppBottomNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appDestinationProvider);
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (AppDestination.markets, 'markets', l10n.markets),
      (AppDestination.futures, 'trade', l10n.tradeNavigation),
      (AppDestination.explore, 'explore', l10n.exploreNavigation),
      (AppDestination.portfolio, 'portfolio', l10n.portfolio),
    ];
    return Material(
      color: AppColors.authBackground,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (destination, asset, label) in destinations)
                Expanded(
                  child: _Destination(
                    destination: destination,
                    asset: asset,
                    label: label,
                    selected:
                        selected == destination ||
                        destination == AppDestination.explore &&
                            {AppDestination.assistant, AppDestination.points}.contains(selected),
                    onTap: () => ref.read(appDestinationProvider.notifier).select(destination),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.destination,
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final AppDestination destination;
  final String asset, label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.authAccent : AppColors.authSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('navigation-${destination.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/navigation/$asset.svg',
                      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: PortfolioTypography.navigation.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
