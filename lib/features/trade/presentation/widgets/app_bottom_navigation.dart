import 'dart:math' as math;

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
    void select(AppDestination value) => ref.read(appDestinationProvider.notifier).select(value);
    Widget destination(AppDestination value, String asset, String label) => _Destination(
      destination: value,
      asset: asset,
      label: label,
      selected: selected == value,
      onTap: () => select(value),
    );
    return Material(
      color: AppColors.authBackground,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: destination(AppDestination.futures, 'futures', l10n.navigationFutures),
              ),
              Expanded(child: _SpotsDestination(label: l10n.navigationSpots)),
              Expanded(
                child: _PointsDestination(
                  label: l10n.points,
                  selected: selected == AppDestination.points,
                  onTap: () => select(AppDestination.points),
                ),
              ),
              Expanded(
                child: destination(AppDestination.assistant, 'ask-ai', l10n.navigationAskAi),
              ),
              Expanded(child: destination(AppDestination.portfolio, 'portfolio', l10n.portfolio)),
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
        child: _DestinationBody(
          icon: SvgPicture.asset(
            'assets/navigation/$asset.svg',
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          label: label,
          style: PortfolioTypography.navigation.copyWith(color: color),
        ),
      ),
    );
  }
}

/// Spot trading is announced but not available, so the tab is not tappable.
class _SpotsDestination extends StatelessWidget {
  const _SpotsDestination({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: const ValueKey('navigation-spots'),
      button: true,
      enabled: false,
      label: '$label, ${l10n.navigationSoon}',
      excludeSemantics: true,
      child: Stack(
        children: [
          _DestinationBody(
            icon: SvgPicture.asset(
              'assets/navigation/spots.svg',
              colorFilter: const ColorFilter.mode(AppColors.authSecondary, BlendMode.srcIn),
            ),
            label: label,
            style: PortfolioTypography.navigation.copyWith(color: AppColors.authSecondary),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.authCard,
                border: Border.all(color: AppColors.authBackground),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(l10n.navigationSoon, style: NavigationTypography.badge),
            ),
          ),
        ],
      ),
    );
  }
}

/// The raised centre tab: a rotated accent square behind the trophy icon.
class _PointsDestination extends StatelessWidget {
  const _PointsDestination({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: const ValueKey('navigation-points'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: _DestinationBody(
          iconSize: 46,
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.authAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SvgPicture.asset('assets/navigation/points.svg'),
            ],
          ),
          label: label,
          style: selected
              ? NavigationTypography.selectedPoints
              : PortfolioTypography.navigation.copyWith(color: AppColors.authSecondary),
        ),
      ),
    );
  }
}

class _DestinationBody extends StatelessWidget {
  const _DestinationBody({
    required this.icon,
    required this.label,
    required this.style,
    this.iconSize = 20,
  });
  final Widget icon;
  final String label;
  final TextStyle style;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    // The 46px centre icon extends past the 56px bar row, as in the design.
    return SizedBox(
      height: 56,
      child: OverflowBox(
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: iconSize,
              child: Center(child: icon),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}
