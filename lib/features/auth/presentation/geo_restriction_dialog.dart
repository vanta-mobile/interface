import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/presentation/no_press_feedback.dart';

Future<void> showGeoRestrictionDialog(BuildContext context) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: '',
  barrierColor: PortfolioColors.transparent,
  transitionDuration: const Duration(milliseconds: 200),
  pageBuilder: (context, animation, secondaryAnimation) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: const ColoredBox(color: AppColors.authOverlay),
          ),
        ),
      ),
      const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _GeoRestrictionDialog(),
        ),
      ),
    ],
  ),
);

class _GeoRestrictionDialog extends StatefulWidget {
  const _GeoRestrictionDialog();

  @override
  State<_GeoRestrictionDialog> createState() => _GeoRestrictionDialogState();
}

class _GeoRestrictionDialogState extends State<_GeoRestrictionDialog> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: PortfolioColors.inset,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.authLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ExplanationSection(title: l.geoRestrictionTitle),
            const SizedBox(height: 16),
            _DescriptionSection(
              description: l.geoRestrictionDescription,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
              viewAllLabel: l.geoRestrictionViewAll,
              foldLabel: l.geoRestrictionFold,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  const _ExplanationSection({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 120,
        height: 100,
        child: Center(child: Image.asset('assets/auth/geo_lock.webp', width: 100, height: 100)),
      ),
      const SizedBox(height: 8),
      Text(
        title,
        style: PortfolioTypography.heading.copyWith(color: AppColors.authText),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({
    required this.description,
    required this.expanded,
    required this.onToggle,
    required this.viewAllLabel,
    required this.foldLabel,
  });

  final String description;
  final bool expanded;
  final VoidCallback onToggle;
  final String viewAllLabel;
  final String foldLabel;

  @override
  Widget build(BuildContext context) {
    final textStyle = AuthTypography.body.copyWith(color: AppColors.authSecondary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DescriptionText(text: description, style: textStyle, expanded: expanded),
        const SizedBox(height: 8),
        _ToggleButton(
          expanded: expanded,
          onTap: onToggle,
          viewAllLabel: viewAllLabel,
          foldLabel: foldLabel,
        ),
      ],
    );
  }
}

class _DescriptionText extends StatelessWidget {
  const _DescriptionText({required this.text, required this.style, required this.expanded});

  final String text;
  final TextStyle style;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (expanded) {
      return Text(text, style: style, textAlign: TextAlign.center);
    }
    return SizedBox(
      height: 100,
      child: ClipRect(
        child: Text(text, style: style, textAlign: TextAlign.center),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.expanded,
    required this.onTap,
    required this.viewAllLabel,
    required this.foldLabel,
  });

  final bool expanded;
  final VoidCallback onTap;
  final String viewAllLabel;
  final String foldLabel;

  @override
  Widget build(BuildContext context) {
    final label = expanded ? foldLabel : viewAllLabel;
    final angle = expanded ? -1.5708 : 1.5708; // -90° or +90° in radians
    return NoPressFeedback(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: PortfolioColors.muted,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AuthTypography.body.copyWith(color: PortfolioColors.muted)),
            const SizedBox(width: 4),
            Transform.rotate(angle: angle, child: SvgPicture.asset('assets/auth/geo_fold.svg')),
          ],
        ),
      ),
    );
  }
}
