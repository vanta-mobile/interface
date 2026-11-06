import '../../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../market/domain/market_quotes.dart';
import 'primitives.dart';

class MarketQuoteStatus extends StatelessWidget {
  const MarketQuoteStatus({super.key, required this.quotes, required this.onRetry});
  final MarketQuotes quotes;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final connected = quotes.connection == QuoteConnection.live;
    final key = switch (quotes.connection) {
      QuoteConnection.connecting => 'quotesConnecting',
      QuoteConnection.live => 'quotesLive',
      QuoteConnection.partial => 'quotesPartial',
      QuoteConnection.offline => 'quotesOffline',
    };
    final updatedAt = quotes.updatedAt?.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MutedText(tr(context, key), color: connected ? AppColors.positive : AppColors.warning),
            if (updatedAt != null)
              MutedText(
                '${tr(context, 'quotesUpdatedAt')} '
                '${DateFormat.Md(Localizations.localeOf(context).toLanguageTag()).add_Hms().format(updatedAt)}',
              ),
            if (!connected || quotes.failure != null)
              TextButton(
                key: const Key('retry-market-quotes'),
                onPressed: quotes.refreshing ? null : onRetry,
                child: Text(tr(context, 'retry')),
              ),
          ],
        ),
        if (quotes.failure != null)
          MutedText(
            apiErrorText(
              context,
              quotes.failure == QuoteFailure.snapshot
                  ? 'quotesSnapshotFailure'
                  : 'quotesDataFailure',
              quotes.errorDetails,
            ),
            color: AppColors.warning,
          ),
      ],
    );
  }
}
