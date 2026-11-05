part of 'account_notification.dart';

class TransferNotification extends AccountNotification {
  const TransferNotification({required DateTime eventTime, required this.record})
    : super(eventTime);
  final TransferRecord record;
  String get category => 'FUND_TRANSFER';
  String get eventType => '${record.type.name}_${record.status.name}'.toUpperCase();
  @override
  String get dedupeKey => jsonEncode(['FUND_TRANSFER', record.stateKey]);
  @override
  bool get critical => false;
}
