import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/points.dart';
import 'points_status.dart';

/// Points values in the design show one rounded decimal; integers drop `.0`.
String pointsValue(Decimal value) =>
    TokenAmountFormatter.formatRounded(DecimalValue(value.toString()), maxFractionDigits: 1);

/// Compact wallet identifier, e.g. `0x77cd…ff13`.
String pointsShortAddress(String address) => address.length <= 12
    ? address
    : '${address.substring(0, 6)}…${address.substring(address.length - 4)}';

/// Selector label: the parenthesised period of a campaign name, such as
/// `Season 1 · Epoch 17` from `Vanta Genesis … (Season 1 Epoch 17)`.
String pointsPeriodLabel(PointsCampaign? campaign, int number, AppLocalizations l10n) {
  if (campaign == null) return l10n.pointsCycleNumber('$number');
  final period = RegExp(r'\(([^()]+)\)\s*$').firstMatch(campaign.name)?[1]?.trim();
  if (period == null || period.isEmpty) return pointsCampaignName(campaign, l10n);
  return period.replaceFirstMapped(
    RegExp(r'^(Season \d+) (Epoch \d+)$'),
    (match) => '${match[1]} · ${match[2]}',
  );
}

String pointsPeriodDates(PointsCampaign campaign, AppLocalizations l10n) {
  final format = DateFormat(l10n.pointsDatePattern, 'en');
  return l10n.pointsPeriodDates(
    format.format(campaign.start.toUtc()),
    format.format(campaign.end.toUtc()),
  );
}
