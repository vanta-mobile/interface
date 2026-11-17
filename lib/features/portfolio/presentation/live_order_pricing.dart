import '../../../l10n/generated/app_localizations.dart';
import '../domain/live_order_peg.dart';

String liveOrderPegLabel(AppLocalizations l10n, LiveOrderPeg peg) =>
    peg == LiveOrderPeg.counterparty
    ? l10n.attachedEntryCounterparty(1)
    : l10n.attachedEntryQueue(1);
