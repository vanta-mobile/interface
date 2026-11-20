import 'dart:async';

import 'package:decimal/decimal.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../application/api_notification_provider.dart';
import '../application/api_notification_units_provider.dart';
import '../domain/api_notification.dart';
import 'api_notification_labels.dart';
import 'notification_api_error.dart';
import 'notification_detail_components.dart';
import 'notification_labels.dart';

class ApiNotificationDetails extends ConsumerStatefulWidget {
  const ApiNotificationDetails({super.key, required this.initialEntry, required this.ownerAddress});
  final ApiNotification initialEntry;
  final String ownerAddress;
  @override
  ConsumerState<ApiNotificationDetails> createState() => _ApiNotificationDetailsState();
}

class _ApiNotificationDetailsState extends ConsumerState<ApiNotificationDetails> {
  bool _entered = false;
  ApiNotification? _entry() {
    final session = ref.read(vantaApiSessionProvider);
    if (!session.ready ||
        session.address != widget.ownerAddress ||
        ref.read(authProvider).identity?.walletAddress?.toLowerCase() != widget.ownerAddress) {
      return null;
    }
    return ref.read(apiNotificationInboxProvider).cache[widget.initialEntry.key] ??
        widget.initialEntry;
  }

  Future<void> _refresh() async {
    final entry = _entry();
    if (entry == null) return;
    final controller = ref.read(apiNotificationInboxProvider.notifier);
    await Future.wait([
      entry.read ? controller.refresh() : controller.markRead(entry),
      if (entry.symbol != null && entry.payload.market != 'spot')
        ref.refresh(apiNotificationUnitsProvider.future).then((_) {}, onError: (Object _) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    ref.watch(vantaApiSessionProvider);
    final inbox = ref.watch(apiNotificationInboxProvider), entry = _entry();
    final symbols = entry?.symbol != null && entry?.payload.market != 'spot'
        ? ref.watch(apiNotificationUnitsProvider)
        : null;
    final error = inbox.error ?? symbols?.error;
    final retrying = inbox.marking || inbox.loading || symbols?.isLoading == true;
    if (!_entered && entry != null) {
      _entered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        final current = _entry();
        if (current != null && !current.read) {
          unawaited(ref.read(apiNotificationInboxProvider.notifier).markRead(current));
        }
      });
    }
    return Scaffold(
      backgroundColor: NotificationColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NotificationDetailHeader(title: l.notificationDetailsTitle),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                      key: const Key('notification-details'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 4,
                        children: [
                          if (entry == null)
                            StatusEmptyView(message: l.notificationEmpty)
                          else
                            ApiNotificationFacts(entry, units: symbols?.value?[entry.symbol]),
                          if (entry != null && error != null)
                            StatusFailureView(
                              message: notificationApiErrorText(context, error),
                              retrying: retrying,
                              onRetry: retrying ? null : _refresh,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Uses the same cards, type scale and copy controls as the supplied detail
/// design. Sparse API payloads display only facts the backend actually supplies.
class ApiNotificationFacts extends StatelessWidget {
  const ApiNotificationFacts(this.entry, {super.key, this.units});
  final ApiNotification entry;
  final NotificationSymbolUnits? units;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), p = entry.payload;
    final market = apiNotificationMarket(l, entry);
    final amount = p.numbers[NotificationNumber.amount];
    String number(NotificationNumber key) {
      final unit = switch (key) {
        NotificationNumber.quantity ||
        NotificationNumber.executedQuantity => units?.base ?? p.baseAsset,
        NotificationNumber.fee => p.feeAsset,
        NotificationNumber.amount => p.asset,
        _ => units?.quote ?? p.quoteAsset,
      };
      if (key == NotificationNumber.distance) {
        final percent = p.numbers[key]! * Decimal.fromInt(100);
        return TokenAmountFormatter.formatPercent(
          DecimalValue(percent.toString()),
          signed: false,
          preserveSmallValues: true,
        );
      }
      return notificationAmount(p.numbers[key]!, unit, l);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        NotificationDetailSummary(
          title: apiNotificationTitle(l, entry),
          value: amount == null
              ? entry.symbol ?? l.notificationApiType(entry.type.name)
              : number(NotificationNumber.amount),
          status: apiNotificationStatus(l, entry),
          tone: apiNotificationTone(entry),
        ),
        if (p.message != null)
          NotificationDetailCard(
            children: [SelectableText(p.message!, style: NotificationTypography.detailValue)],
          ),
        NotificationDetailCard(
          children: [
            NotificationDetailRow(
              l.notificationApiField('createdAt'),
              DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.createdAt.toLocal()),
            ),
            if (entry.symbol != null)
              NotificationDetailRow(l.notificationApiField('symbol'), entry.symbol!),
            if (market != null) NotificationDetailRow(l.notificationApiField('market'), market),
            if (p.side != null)
              NotificationDetailRow(
                l.notificationApiField('side'),
                p.market == 'spot' ? l.spotOrderSide(p.side!) : l.notificationOrderSide(p.side!),
              ),
            if (p.originalType != null || p.orderType != null)
              NotificationDetailRow(
                l.openOrdersOrderType,
                l.notificationOrderType(p.originalType ?? p.orderType!),
              ),
            if (p.network != null)
              NotificationDetailRow(l.notificationApiField('network'), p.network!),
            for (final key in p.numbers.keys)
              NotificationDetailRow(l.notificationApiField(key.name), number(key)),
            if (p.orderId != null)
              NotificationDetailRow(l.notificationApiField('orderId'), p.orderId!, copyable: true),
            for (final field in {
              'tradeId': p.tradeId,
              'clientOrderId': p.clientOrderId,
              'reference': p.reference,
            }.entries)
              if (field.value != null)
                NotificationDetailRow(
                  l.notificationApiField(field.key),
                  field.value!,
                  copyable: true,
                ),
            if (p.positionSide != null)
              NotificationDetailRow(
                l.notificationApiField('positionSide'),
                notificationSide(l, p.positionSide!),
              ),
            if (p.transferKind != null)
              NotificationDetailRow(
                l.notificationApiField('transferKind'),
                l.notificationTransferKind(p.transferKind!),
              ),
            if (p.transactionHash != null)
              NotificationDetailRow(
                l.notificationApiField('transactionHash'),
                p.transactionHash!,
                copyable: true,
              ),
            NotificationDetailRow(l.notificationApiField('eventKey'), entry.key, copyable: true),
          ],
        ),
      ],
    );
  }
}
