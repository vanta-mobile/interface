import '../../deep_link/domain/app_deep_link.dart';
import 'api_notification.dart';

/// What a tapped system notification asks for: a page to open and, when the
/// push identifies its inbox entry, that entry to mark read for its owner.
class PushNotificationOpen {
  const PushNotificationOpen(this.link, {this.read, this.owner});

  /// Opened for any push the app cannot attribute to an inbox entry.
  static const inbox = PushNotificationOpen(AppDeepLink(DeepLinkTarget.notifications));

  final AppDeepLink link;
  final ApiNotificationReadTarget? read;

  /// Lowercase wallet the event belongs to; broadcasts belong to everyone.
  final String? owner;

  /// Reads the `data` fields agreed with the backend. Any missing or malformed
  /// field opens the inbox and marks nothing read, so a bad payload can never
  /// mark another entry or account. Push contents never carry financial state.
  factory PushNotificationOpen.fromData(Map<String, Object?> data) {
    String? text(String key) => switch (data[key]) {
      final String value when value.isNotEmpty && value.length <= 256 => value,
      _ => null,
    };
    final kind = switch (text('kind')) {
      'event' => ApiNotificationKind.event,
      'broadcast' => ApiNotificationKind.broadcast,
      _ => null,
    };
    final rawId = text('id');
    final id = rawId != null && RegExp(r'^[1-9]\d{0,18}$').hasMatch(rawId)
        ? int.tryParse(rawId)
        : null;
    final type = _types[text('type')];
    if (kind == null || id == null || type == null) return inbox;
    final broadcast =
        type == ApiNotificationType.announce || type == ApiNotificationType.maintenance;
    if (broadcast != (kind == ApiNotificationKind.broadcast)) return inbox;
    if (broadcast) {
      return PushNotificationOpen(inbox.link, read: ApiNotificationReadTarget.broadcast(id));
    }

    final key = text('event_key');
    final owner = text('address')?.toLowerCase();
    if (key == null || owner == null || !RegExp(r'^0x[0-9a-f]{40}$').hasMatch(owner)) {
      return inbox;
    }
    final symbol = text('symbol');
    final market = symbol != null && normalizeDeepLinkSymbol(symbol) == symbol ? symbol : null;
    final link = switch (type) {
      ApiNotificationType.fill ||
      ApiNotificationType.liquidation ||
      ApiNotificationType.marginCall => _futures(market, DeepLinkFuturesPanel.positions),
      ApiNotificationType.order ||
      ApiNotificationType.trigger => _futures(market, DeepLinkFuturesPanel.orders),
      ApiNotificationType.funding ||
      ApiNotificationType.transfer => const AppDeepLink(DeepLinkTarget.portfolio),
      ApiNotificationType.announce || ApiNotificationType.maintenance => inbox.link,
    };
    if (link == null) return inbox;
    return PushNotificationOpen(
      link,
      read: ApiNotificationReadTarget.event(key, id: id),
      owner: owner,
    );
  }
}

/// Trading events need their market; without it the push is not attributable.
AppDeepLink? _futures(String? symbol, DeepLinkFuturesPanel panel) =>
    symbol == null ? null : AppDeepLink(DeepLinkTarget.futures, symbol: symbol, panel: panel);

const _types = {
  'FILL': ApiNotificationType.fill,
  'TRIGGER': ApiNotificationType.trigger,
  'ORDER': ApiNotificationType.order,
  'LIQUIDATION': ApiNotificationType.liquidation,
  'MARGIN_CALL': ApiNotificationType.marginCall,
  'FUNDING': ApiNotificationType.funding,
  'TRANSFER': ApiNotificationType.transfer,
  'ANNOUNCE': ApiNotificationType.announce,
  'MAINTENANCE': ApiNotificationType.maintenance,
};
