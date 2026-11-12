import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/motion/animated_number_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/points_provider.dart';
import '../domain/points.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import 'points_labels.dart';
import 'points_status.dart';

PointsCampaign? _campaign(WidgetRef ref, int? number) {
  if (number == null) return null;
  final current = ref.watch(currentPointsCampaignProvider).snapshot?.value;
  if (current?.number == number) return current;
  final campaigns = ref.watch(pointsCampaignsProvider).snapshot?.value;
  return campaigns?.where((c) => c.number == number).firstOrNull;
}

/// "Points by period": selector plus the selected campaign's pool and points.
class PointsPeriodSection extends ConsumerWidget {
  const PointsPeriodSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final period = ref.watch(pointsPeriodProvider);
    final campaigns = ref.watch(pointsCampaignsProvider);
    final campaign = _campaign(ref, period);
    if (period == null) {
      // Neither the current campaign nor the list is known yet.
      final current = ref.watch(currentPointsCampaignProvider);
      final Widget body;
      if (campaigns.failureKey case final key? when current.failureKey != null) {
        body = StatusFailureView(
          message: pointsFailureText(context, key, campaigns.errorDetails),
          retryKey: const Key('points-refresh-cycles'),
          retrying: campaigns.loading || current.loading,
          onRetry: () => Future.wait([
            ref.read(currentPointsCampaignProvider.notifier).refresh(),
            ref.read(pointsCampaignsProvider.notifier).refresh(),
          ]),
        );
      } else if (campaigns.snapshot?.value.isEmpty == true && current.snapshot != null) {
        body = Text(l10n.pointsNoPeriods, style: PointsTypography.scope);
      } else {
        body = const _CampaignCard(campaign: null);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.pointsByPeriod, style: PointsTypography.section),
          const SizedBox(height: 12),
          body,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.pointsByPeriod, style: PointsTypography.section)),
            const SizedBox(width: 8),
            Flexible(
              child: _PeriodSelector(
                label: pointsPeriodLabel(campaign, period, l10n),
                onTap: () => _showPeriodSheet(context, period),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CampaignCard(campaign: campaign, period: period),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Material(
      color: PointsColors.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: const Key('points-period-selector'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PointsTypography.labelPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                const PortfolioIcon('chevron-down.svg', size: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CampaignCard extends ConsumerWidget {
  const _CampaignCard({required this.campaign, this.period});
  final PointsCampaign? campaign;
  final int? period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final campaign = this.campaign;
    final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    final signedIn = address != null && isPointsEvmAddress(address);
    final history = ref.watch(walletPointsHistoryProvider);
    final mine = history.snapshot?.value.rows.where((r) => r.campaign == period).firstOrNull;
    final myLoading = signedIn && history.snapshot == null && history.failureKey == null;
    return Container(
      key: const Key('points-period-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PointsColors.section,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (campaign != null)
            Text(pointsCampaignName(campaign, l10n), style: PointsTypography.campaign)
          else if (period != null)
            Text(l10n.pointsCycleNumber('$period'), style: PointsTypography.campaign)
          else
            const _Bar(width: 220, height: 16),
          const SizedBox(height: 8),
          SizedBox(
            height: 24,
            child: campaign == null
                ? const Align(alignment: Alignment.centerLeft, child: _Bar(width: 184, height: 10))
                : _CampaignMetadata(campaign: campaign),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Metric(
                  label: l10n.pointsPeriodPool,
                  value: campaign == null ? null : pointsValue(campaign.pool),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  key: const Key('points-period-mine'),
                  label: l10n.pointsMyPoints,
                  value: myLoading
                      ? null
                      : mine == null
                      ? '—'
                      : pointsValue(mine.points),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CampaignMetadata extends StatelessWidget {
  const _CampaignMetadata({required this.campaign});
  final PointsCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = campaign.status == 'ACTIVE';
    final color = active ? PointsColors.accent : PointsColors.secondary;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? PointsColors.activeTint : PointsColors.neutralTint,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/points/status-dot.svg',
                width: 5,
                height: 5,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(width: 4),
              Text(
                pointsCampaignStatus(campaign.status, l10n),
                style: PointsTypography.status.copyWith(color: color),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            active ? pointsPeriodDates(campaign, l10n) : l10n.pointsHistoricalPeriod,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PointsTypography.caption,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({super.key, required this.label, required this.value});
  final String label;

  /// Null while loading.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: PointsColors.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PointsTypography.label),
          const SizedBox(height: 4),
          if (value case final value?)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedNumberText(value, style: PointsTypography.metric),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: _Bar(width: 104, height: 24, color: PointsColors.loadingValue),
            ),
          const SizedBox(height: 4),
          Text(l10n.pointsUnit, style: PointsTypography.caption),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, this.color = PointsColors.card});
  final double width, height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(height < 12 ? 3 : 4),
    ),
  );
}

Future<void> _showPeriodSheet(BuildContext context, int selected) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  backgroundColor: PointsColors.section,
  barrierColor: PointsColors.scrim,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => _PeriodSheet(selected: selected),
);

class _PeriodSheet extends ConsumerWidget {
  const _PeriodSheet({required this.selected});
  final int selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final campaigns = [...?ref.watch(pointsCampaignsProvider).snapshot?.value]
      ..sort((a, b) => b.number.compareTo(a.number));
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.pointsSelectPeriod, style: PointsTypography.header)),
              SizedBox(
                width: 24,
                height: 24,
                child: OverflowBox(
                  maxWidth: 44,
                  maxHeight: 44,
                  child: IconButton(
                    key: const Key('points-period-close'),
                    tooltip: l10n.close,
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    icon: SvgPicture.asset('assets/points/close.svg', width: 24, height: 24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 408),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final campaign in campaigns)
                  _PeriodOption(
                    label: pointsPeriodLabel(campaign, campaign.number, l10n),
                    number: campaign.number,
                    selected: campaign.number == selected,
                    onTap: () {
                      ref.read(selectedPointsCampaignProvider.notifier).select(campaign.number);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodOption extends StatelessWidget {
  const _PeriodOption({
    required this.label,
    required this.number,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? PointsColors.card : PointsColors.section,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('points-period-$number'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text(label, style: PointsTypography.option)),
              if (selected) ...[
                const SizedBox(width: 12),
                const PortfolioIcon('check-circle.svg', size: 16),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
