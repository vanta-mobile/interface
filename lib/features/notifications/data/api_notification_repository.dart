import '../../../core/exact_json.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../auth/data/vanta_api_session_repository.dart';
import '../domain/api_notification.dart';
import '../domain/notification_status.dart' show NotificationFilter;
import 'api_notification_mapper.dart';

class ApiNotificationRepository {
  ApiNotificationRepository(this.session);
  final VantaApiSessionRepository session;

  Future<ApiNotificationPage> read({
    required NotificationFilter category,
    required bool unreadOnly,
    String? cursor,
  }) async {
    final json = await session.get(
      '/v1/notifications',
      query: {
        'category': category.name,
        'unread_only': '$unreadOnly',
        'limit': '50',
        'cursor': ?cursor,
      },
      decode: decodeNotificationJson,
    );
    try {
      return mapNotificationPage(json);
    } on FormatException {
      throw const VantaApiFailure(vantaApiDataInvalid);
    }
  }

  Future<void> markRead({ApiNotification? entry, required String idempotencyKey}) async {
    final result = await session.postIdempotent(
      '/v1/notifications/read',
      body: {
        if (entry == null)
          'all': true
        else if (entry.kind == ApiNotificationKind.broadcast)
          'broadcast_up_to': entry.id
        else
          'event_keys': [entry.key],
      },
      idempotencyKey: idempotencyKey,
    );
    final marked = result['marked'];
    if (marked != null && (marked is! int || marked < 0)) {
      throw const VantaApiFailure(vantaApiDataInvalid);
    }
  }
}

/// Keep numeric payload lexemes exact without changing other API consumers.
Object? decodeNotificationJson(String source) {
  Object? normalize(Object? value) => switch (value) {
    FundingJsonNumber n => n.integer ?? n.text,
    List<dynamic> list => list.map(normalize).toList(),
    Map<String, dynamic> map => map.map((k, v) => MapEntry(k, normalize(v))),
    _ => value,
  };
  return normalize(decodeFundingJson(source, maxSourceLength: 2 * 1024 * 1024));
}
