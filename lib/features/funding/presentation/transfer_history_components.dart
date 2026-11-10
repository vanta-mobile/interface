import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../domain/transfer_history.dart';
import 'transfer_record_details.dart';

String historyTypeLabel(AppLocalizations l, TransferType type) =>
    type == TransferType.deposit ? l.fundingDeposit : l.fundingWithdraw;

String historyTime(DateTime time) =>
    '${DateFormat('yyyy-MM-dd HH:mm:ss').format(time.toUtc())} UTC';

/// Record amounts are identifiers of an exact transfer, so keep every decimal.
/// The shared adaptive balance formatter intentionally rounds and is unsuitable.
String historyAmount(TransferRecord record, {bool signed = false}) =>
    '${signed && record.type == TransferType.withdraw
        ? '−'
        : signed && record.status == TransferStatus.success
        ? '+'
        : ''}${record.amount} ${record.asset}';

class HistoryStatus extends StatelessWidget {
  const HistoryStatus(this.status, {super.key});
  final TransferStatus status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: switch (status) {
        TransferStatus.success => PortfolioColors.onAccent,
        TransferStatus.processing => PortfolioColors.button,
        TransferStatus.failed => PortfolioColors.negativeSurface,
      },
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      AppLocalizations.of(context).assetHistoryStatus(status.name),
      style: HistoryTypography.status.copyWith(
        color: switch (status) {
          TransferStatus.success => PortfolioColors.positive,
          TransferStatus.processing => PortfolioColors.secondary,
          TransferStatus.failed => PortfolioColors.negative,
        },
      ),
    ),
  );
}

class HistoryRecordCard extends StatelessWidget {
  const HistoryRecordCard(this.record, {super.key, required this.onTap});
  final TransferRecord record;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: PortfolioColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: ValueKey('transfer-${record.key}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(historyTypeLabel(l, record.type), style: AccountTypography.body),
                  ),
                  const SizedBox(width: 8),
                  HistoryStatus(record.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l.assetHistoryAmountNetwork(
                  historyAmount(record),
                  transferNetworkLabel(l, record.chainId),
                ),
                style: AccountTypography.body,
              ),
              const SizedBox(height: 8),
              Text(
                '${record.market == TransferMarket.perp ? l.assetHistoryFutures : l.spot} · ${historyTime(record.recordTime)}',
                style: PortfolioTypography.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryFilters extends StatelessWidget {
  const HistoryFilters({super.key, required this.selected, required this.onChanged});
  final TransferType? selected;
  final ValueChanged<TransferType?> onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in [null, ...TransferType.values])
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Semantics(
                selected: selected == type,
                button: true,
                child: InkWell(
                  key: ValueKey('transfer-filter-${type?.name ?? 'all'}'),
                  onTap: () => onChanged(type),
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: type == TransferType.withdraw ? 100 : 86,
                      minHeight: 44,
                    ),
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type == null ? l.portfolioAll : historyTypeLabel(l, type),
                          style: AccountTypography.body.copyWith(
                            color: selected == type
                                ? PortfolioColors.text
                                : PortfolioColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: type == TransferType.withdraw ? 72 : 50,
                          height: 2,
                          color: selected == type
                              ? PortfolioColors.accent
                              : PortfolioColors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Preserve the source SVG's intrinsic dimensions inside its design icon slot.
class HistoryGlyph extends StatelessWidget {
  const HistoryGlyph(this.asset, {super.key, this.size = 24, this.turns = 0});
  final String asset;
  final double size;
  final int turns;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Center(
      child: RotatedBox(quarterTurns: turns, child: SvgPicture.asset('assets/portfolio/$asset')),
    ),
  );
}

class HistoryHeader extends StatelessWidget {
  const HistoryHeader({super.key, required this.title, this.close = false});
  final String title;
  final bool close;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(close ? 16 : 2, 7, close ? 6 : 16, 12),
    child: Row(
      children: [
        if (!close)
          IconButton(
            key: const Key('transfer-details-back'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.pop(context),
            icon: const HistoryGlyph('history-back.svg'),
          ),
        Expanded(child: Text(title, style: PortfolioTypography.heading)),
        if (close)
          IconButton(
            key: const Key('transfer-history-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.pop(context),
            icon: const PortfolioIcon('close.svg', size: 24),
          ),
      ],
    ),
  );
}

class HistoryPagination extends StatelessWidget {
  const HistoryPagination({
    super.key,
    required this.page,
    required this.pages,
    required this.onChanged,
  });
  final int page, pages;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        key: const Key('transfer-history-previous'),
        tooltip: AppLocalizations.of(context).historyPrev,
        onPressed: page > 0 ? () => onChanged(page - 1) : null,
        icon: Opacity(
          opacity: page > 0 ? 1 : .35,
          child: const HistoryGlyph('history-chevron-right.svg', size: 16, turns: 2),
        ),
      ),
      SizedBox(
        width: 80,
        child: Text(
          '${page + 1} / $pages',
          textAlign: TextAlign.center,
          style: PortfolioTypography.caption,
        ),
      ),
      IconButton(
        key: const Key('transfer-history-next'),
        tooltip: AppLocalizations.of(context).historyNext,
        onPressed: page + 1 < pages ? () => onChanged(page + 1) : null,
        icon: Opacity(
          opacity: page + 1 < pages ? 1 : .35,
          child: const HistoryGlyph('history-chevron-right.svg', size: 16),
        ),
      ),
    ],
  );
}

class HistoryRecordList extends StatelessWidget {
  const HistoryRecordList({
    super.key,
    required this.records,
    required this.loaded,
    required this.page,
    required this.pages,
    required this.onPage,
    required this.onOpen,
  });
  final List<TransferRecord> records;
  final bool loaded;
  final int page, pages;
  final ValueChanged<int> onPage;
  final ValueChanged<TransferRecord> onOpen;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final record in records.skip(page * 5).take(5)) ...[
          HistoryRecordCard(record, onTap: () => onOpen(record)),
          const SizedBox(height: 16),
        ],
        if (loaded && records.isEmpty) StatusEmptyView(title: l.assetHistoryEmpty),
        if (records.isNotEmpty && pages == 1)
          Text(
            l.assetHistoryLoaded,
            key: const Key('transfer-history-end'),
            textAlign: TextAlign.center,
            style: PortfolioTypography.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        if (pages > 1) HistoryPagination(page: page, pages: pages, onChanged: onPage),
      ],
    );
  }
}
