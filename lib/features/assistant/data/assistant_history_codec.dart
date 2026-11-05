import 'dart:convert';

import '../domain/assistant.dart';
import '../domain/assistant_history.dart';
import '../domain/assistant_session.dart';

class AssistantHistoryCodec {
  static const maxBytes = 512 * 1024, maxMessages = 200;
  static String encode(AssistantWalletScope scope, String userId, AssistantHistory history) {
    if (!assistantUuid(userId) || history.draft.length > 12000) {
      throw const AssistantFailure('assistantStorage');
    }
    final messages = history.messages.map(_encodeMessage).toList();
    if (messages.map((m) => m['id']).toSet().length != messages.length) {
      throw const AssistantFailure('assistantStorage');
    }
    while (messages.length > maxMessages) {
      messages.removeAt(0);
    }
    String result(List<Map<String, Object?>> rows) => jsonEncode({
      'version': 1,
      'scope': scope.storageIdentity,
      'user': userId,
      'draft': history.draft,
      'messages': rows,
    });
    var budget = maxBytes - utf8.encode(result(const [])).length;
    final retained = <Map<String, Object?>>[];
    // Encode only the suffix that can fit. Re-encoding the entire history for
    // every eviction is quadratic and can stall a phone on large responses.
    for (final row in messages.reversed) {
      final size = utf8.encode(jsonEncode(row)).length + (retained.isEmpty ? 0 : 1);
      if (size > budget) {
        if (retained.isEmpty) throw const AssistantFailure('assistantStorageCapacity');
        break;
      }
      retained.add(row);
      budget -= size;
    }
    final value = result(retained.reversed.toList());
    if (utf8.encode(value).length > maxBytes) {
      throw const AssistantFailure('assistantStorageCapacity');
    }
    return value;
  }

  static AssistantHistory decode(AssistantWalletScope scope, String userId, String source) {
    try {
      if (source.length > maxBytes || utf8.encode(source).length > maxBytes) {
        throw const FormatException();
      }
      final value = jsonDecode(source);
      if (value is! Map<String, Object?> ||
          value['version'] != 1 ||
          value['scope'] != scope.storageIdentity ||
          value['user'] != userId ||
          !assistantUuid(userId) ||
          value['draft'] is! String ||
          (value['draft'] as String).length > 12000 ||
          value['messages'] is! List) {
        throw const FormatException();
      }
      final rows = value['messages'] as List;
      if (rows.length > maxMessages) throw const FormatException();
      final messages = rows.map(_decodeMessage).toList();
      if (messages.map((m) => m.id).toSet().length != messages.length) {
        throw const FormatException();
      }
      return AssistantHistory(messages: messages, draft: value['draft'] as String);
    } catch (_) {
      throw const AssistantFailure('assistantStorage');
    }
  }

  static Map<String, Object?> _encodeMessage(AssistantMessage message) {
    if (message.id.isEmpty ||
        message.id.length > 128 ||
        message.id.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
        message.content.length + message.reasoning.length > 131072 ||
        (message.role == AssistantRole.user &&
            (message.content.length > 12000 ||
                message.reasoning.isNotEmpty ||
                message.delivery != AssistantDelivery.complete))) {
      throw const AssistantFailure('assistantStorage');
    }
    return {
      'id': message.id,
      'role': message.role.name,
      'content': message.content,
      'reasoning': message.reasoning,
      'delivery': message.delivery.name,
      'createdAt': message.createdAt.toUtc().toIso8601String(),
    };
  }

  static AssistantMessage _decodeMessage(Object? value) {
    if (value is! Map<String, Object?> ||
        value['id'] is! String ||
        value['role'] is! String ||
        value['content'] is! String ||
        value['reasoning'] is! String ||
        value['delivery'] is! String ||
        value['createdAt'] is! String ||
        (value['createdAt'] as String).length > 40) {
      throw const FormatException();
    }
    final role = AssistantRole.values.byName(value['role'] as String),
        delivery = AssistantDelivery.values.byName(value['delivery'] as String),
        time = DateTime.parse(value['createdAt'] as String);
    if (time.toUtc().toIso8601String() != value['createdAt']) throw const FormatException();
    final message = AssistantMessage(
      id: value['id'] as String,
      role: role,
      content: value['content'] as String,
      reasoning: value['reasoning'] as String,
      createdAt: time,
      delivery: delivery,
    );
    _encodeMessage(message);
    return delivery == AssistantDelivery.streaming
        ? message.withReply(
            content: message.content,
            reasoning: message.reasoning,
            delivery: AssistantDelivery.interrupted,
          )
        : message;
  }
}
