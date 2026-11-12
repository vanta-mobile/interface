import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/presentation/app_toast.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/points.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import 'points_labels.dart';
import 'points_status.dart';

const pointsPageSize = 20;

/// Label/value pill shared by the total and period rank.
class PointsRankBadge extends StatelessWidget {
  const PointsRankBadge({super.key, required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: PointsColors.rankBadge,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label, style: PointsTypography.caption),
          const WidgetSpan(child: SizedBox(width: 6)),
          TextSpan(text: value, style: PointsTypography.labelPrimary),
        ],
      ),
    ),
  );
}

/// Ranked rows, 20 per page, with the shared podium for the top three.
class PointsLeaderboardTable extends StatefulWidget {
  const PointsLeaderboardTable({
    super.key,
    required this.rows,
    required this.points,
    required this.valueHeading,
    this.secondary,
    this.address,
  });
  final List<PointsRanking> rows;
  final String valueHeading;
  final String Function(PointsRanking row) points;
  final String Function(PointsRanking row)? secondary;

  /// The signed-in wallet, highlighted wherever it appears.
  final String? address;

  @override
  State<PointsLeaderboardTable> createState() => _PointsLeaderboardTableState();
}

class _PointsLeaderboardTableState extends State<PointsLeaderboardTable> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final pages = math.max(1, (rows.length + pointsPageSize - 1) ~/ pointsPageSize);
    final current = page.clamp(0, pages - 1);
    final you = widget.address == null ? null : pointsAddressKey(widget.address!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PointsPodium(rows: rows.take(3).toList(), points: widget.points),
        const SizedBox(height: 16),
        _TableHeadings(value: widget.valueHeading),
        SizedBox(height: widget.secondary == null ? 4 : 8),
        for (final row in rows.skip(current * pointsPageSize).take(pointsPageSize)) ...[
          PointsLeaderboardRow(
            key: ValueKey('points-row-${row.rank}'),
            row: row,
            points: widget.points(row),
            secondary: widget.secondary?.call(row),
            mine: you != null && pointsAddressKey(row.address) == you,
          ),
          const Divider(height: 1, thickness: 1, color: PointsColors.divider),
        ],
        if (pages > 1) ...[
          const SizedBox(height: 12),
          PointsPagination(
            page: current,
            pages: pages,
            onPage: (value) => setState(() => page = value),
          ),
        ],
      ],
    );
  }
}

class _TableHeadings extends StatelessWidget {
  const _TableHeadings({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Flexible(
        child: Text(
          AppLocalizations.of(context).pointsRankAddress,
          style: PointsTypography.caption,
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(value, textAlign: TextAlign.end, style: PointsTypography.caption),
      ),
    ],
  );
}

class PointsLeaderboardRow extends StatelessWidget {
  const PointsLeaderboardRow({
    super.key,
    required this.row,
    required this.points,
    this.secondary,
    this.mine = false,
  });
  final PointsRanking row;
  final String points;
  final String? secondary;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final address = pointsShortAddress(row.address);
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: mine
          ? BoxDecoration(color: PointsColors.card, borderRadius: BorderRadius.circular(8))
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${row.rank}',
              style: mine ? PointsTypography.label : PointsTypography.rank,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => copyPointsAddress(context, row.address),
              child: Semantics(
                label: mine ? l10n.pointsYouSuffix(row.address) : row.address,
                excludeSemantics: true,
                child: Text(
                  mine ? l10n.pointsYouSuffix(address) : address,
                  style: PointsTypography.address,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 108),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(points, style: PointsTypography.points),
                if (secondary != null) Text(secondary!, style: PointsTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void copyPointsAddress(BuildContext context, String address) {
  Clipboard.setData(ClipboardData(text: address));
  AppToast.showSuccess(context, AppLocalizations.of(context).pointsAddressCopied);
}

class PointsPagination extends StatelessWidget {
  const PointsPagination({
    super.key,
    required this.page,
    required this.pages,
    required this.onPage,
  });
  final int page, pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget button(String key, String tooltip, bool enabled, int target, int turns) => Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: PointsColors.card,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: Key(key),
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? () => onPage(target) : null,
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: RotatedBox(
                  quarterTurns: turns,
                  child: const PortfolioIcon('history-chevron-right.svg', size: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        button('points-board-previous', l10n.pointsPrevious, page > 0, page - 1, 2),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Text(
            l10n.pointsPageIndicator(page + 1, pages),
            textAlign: TextAlign.center,
            style: PointsTypography.label,
          ),
        ),
        const SizedBox(width: 12),
        button('points-board-next', l10n.pointsNext, page < pages - 1, page + 1, 0),
      ],
    );
  }
}

/// Fixed 361×270 design composition, scaled down on narrow screens.
class _PodiumFrame extends StatelessWidget {
  const _PodiumFrame({required this.podium, required this.children});
  final String podium;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 361,
        height: 270,
        child: Stack(
          children: [
            Positioned.fill(child: SvgPicture.asset('assets/points/$podium', fit: BoxFit.fill)),
            ...children,
          ],
        ),
      ),
    ),
  );
}

// Left/top of each identity column, ordered rank 1, 2, 3; numerals sit lower.
const _podiumSlots = [
  (left: 125.5, top: 0.0, numeral: 171.0),
  (left: 10.5, top: 38.0, numeral: 194.0),
  (left: 240.5, top: 66.0, numeral: 212.0),
];
const _awards = [
  (asset: 'award-gold.webp', width: 32.0, height: 23.544),
  (asset: 'award-silver.webp', width: 32.0, height: 26.323),
  (asset: 'award-bronze.webp', width: 28.16, height: 32.0),
];

class PointsPodium extends StatelessWidget {
  const PointsPodium({super.key, required this.rows, required this.points});
  final List<PointsRanking> rows;
  final String Function(PointsRanking row) points;

  @override
  Widget build(BuildContext context) => _PodiumFrame(
    podium: 'podium.svg',
    children: [
      for (var i = 0; i < 3; i++) ...[
        Positioned(
          left: _podiumSlots[i].left,
          top: _podiumSlots[i].numeral,
          width: 110,
          child: _PodiumNumeral(i + 1),
        ),
        if (i < rows.length)
          Positioned(
            left: _podiumSlots[i].left,
            top: _podiumSlots[i].top,
            width: 110,
            child: _PodiumIdentity(row: rows[i], points: points(rows[i]), place: i),
          ),
      ],
    ],
  );
}

class PointsPodiumSkeleton extends StatelessWidget {
  const PointsPodiumSkeleton({super.key});

  @override
  Widget build(BuildContext context) => _PodiumFrame(
    podium: 'podium-skeleton.svg',
    children: [
      for (final slot in _podiumSlots)
        Positioned(
          left: slot.left,
          top: slot.top,
          width: 110,
          child: Column(
            children: [
              _bar(48, 48, 24),
              const SizedBox(height: 6),
              _bar(72, 16, 4),
              const SizedBox(height: 6),
              _bar(100, 24, 6),
            ],
          ),
        ),
    ],
  );

  static Widget _bar(double width, double height, double radius) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: PointsColors.card,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _PodiumNumeral extends StatelessWidget {
  const _PodiumNumeral(this.place);
  final int place;

  @override
  Widget build(BuildContext context) => Center(
    child: ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [PointsColors.numeralTop, PointsColors.numeralMiddle, PointsColors.numeralBottom],
        stops: [0, 0.6, 1],
      ).createShader(bounds),
      child: Text('$place', style: PointsTypography.numeral, textScaler: TextScaler.noScaling),
    ),
  );
}

class _PodiumIdentity extends StatelessWidget {
  const _PodiumIdentity({required this.row, required this.points, required this.place});
  final PointsRanking row;
  final String points;
  final int place;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final award = _awards[place];
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PointsColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: PointsColors.divider),
          ),
          child: Image.asset(
            'assets/points/${award.asset}',
            width: award.width,
            height: award.height,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onLongPress: () => copyPointsAddress(context, row.address),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(pointsShortAddress(row.address), style: PointsTypography.caption),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 104,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: place == 0 ? PointsColors.leaderPoints : PointsColors.card,
            borderRadius: BorderRadius.circular(6),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: points, style: PointsTypography.podiumPoints),
                  const WidgetSpan(child: SizedBox(width: 4)),
                  TextSpan(text: l10n.pointsUnit, style: PointsTypography.unit),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Loading rows match the real table's column widths.
class PointsLeaderboardSkeleton extends StatelessWidget {
  const PointsLeaderboardSkeleton({super.key, required this.valueHeading});
  final String valueHeading;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width) => Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(color: PointsColors.card, borderRadius: BorderRadius.circular(4)),
    );
    return Column(
      key: const Key('points-board-loading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PointsPodiumSkeleton(),
        const SizedBox(height: 16),
        _TableHeadings(value: valueHeading),
        const SizedBox(height: 4),
        for (var i = 0; i < 5; i++) ...[
          SizedBox(
            height: 54,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Align(alignment: Alignment.centerLeft, child: bar(16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: bar(94)),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 108,
                  child: Align(alignment: Alignment.centerRight, child: bar(80)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: PointsColors.divider),
        ],
      ],
    );
  }
}

class PointsLeaderboardEmpty extends StatelessWidget {
  const PointsLeaderboardEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: const Key('points-board-empty'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Image.asset('assets/points/no-ranking.webp', width: 80, height: 80),
          const SizedBox(height: 8),
          Text(l10n.pointsNoRankingsTitle, style: PointsTypography.section),
          const SizedBox(height: 8),
          Text(
            l10n.pointsNoRankingsMessage,
            textAlign: TextAlign.center,
            style: PointsTypography.scope,
          ),
        ],
      ),
    );
  }
}

/// Data when a snapshot exists (kept during refreshes), a retryable failure
/// when the first read failed, and the section skeleton otherwise.
class PointsSectionState<T> extends StatelessWidget {
  const PointsSectionState({
    super.key,
    required this.state,
    required this.loading,
    required this.data,
    required this.onRetry,
    required this.retryKey,
  });
  final PointsLoadState<T> state;
  final Widget loading;
  final Widget Function(T value) data;
  final Future<void> Function() onRetry;
  final Key retryKey;

  @override
  Widget build(BuildContext context) {
    if (state.snapshot case final snapshot?) return data(snapshot.value);
    if (state.failureKey case final key?) {
      return StatusFailureView(
        message: pointsFailureText(context, key, state.errorDetails),
        retryKey: retryKey,
        retrying: state.loading,
        onRetry: onRetry,
      );
    }
    return loading;
  }
}
