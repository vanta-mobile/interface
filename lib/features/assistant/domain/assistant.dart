import 'dart:async';

enum AssistantRole { user, assistant }

enum AssistantDelivery { complete, streaming, interrupted, truncated, failed }

class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.reasoning = '',
    this.delivery = AssistantDelivery.complete,
  });
  final String id, content, reasoning;
  final AssistantRole role;
  final DateTime createdAt;
  final AssistantDelivery delivery;

  AssistantMessage withReply({
    required String content,
    required String reasoning,
    required AssistantDelivery delivery,
  }) => AssistantMessage(
    id: id,
    role: role,
    content: content,
    reasoning: reasoning,
    delivery: delivery,
    createdAt: createdAt,
  );
}

class AssistantFailure implements Exception {
  const AssistantFailure(this.key, {this.status, this.quota});
  final String key;
  final int? status;
  final AssistantQuota? quota;
  bool get canComplete => status == null || status! >= 500;
  @override
  String toString() => 'AssistantFailure($key)';
}

class AssistantQuota {
  const AssistantQuota({required this.day, this.used, this.limit, this.remaining, this.resetAt});
  final String day;
  final int? used, limit, remaining;
  final DateTime? resetAt;
}

/// One explicit operation owns cancellation across headers, body, and fallback.
class AssistantCancellation {
  final _completer = Completer<void>();
  Future<void> get whenCancelled => _completer.future;
  bool get isCancelled => _completer.isCompleted;
  void cancel() {
    if (!isCancelled) _completer.complete();
  }

  void check() {
    if (isCancelled) throw const AssistantFailure('assistantCancelled');
  }
}

class AssistantDelta {
  const AssistantDelta({
    this.content = '',
    this.reasoning = '',
    this.done = false,
    this.truncated = false,
  });
  final String content, reasoning;
  final bool done, truncated;
}

class AssistantReply {
  const AssistantReply({required this.content, this.reasoning = ''});
  final String content, reasoning;
}

class AssistantReplyUpdate {
  const AssistantReplyUpdate({
    required this.content,
    required this.reasoning,
    required this.delivery,
  });
  final String content, reasoning;
  final AssistantDelivery delivery;
}

/// Match the website's 12,000 UTF-16 character context, without sending
/// reasoning, display statuses, request references, or failed partial replies.
List<Map<String, String>> assistantContext(Iterable<AssistantMessage> messages) {
  final result = messages
      .where((m) => m.delivery == AssistantDelivery.complete && m.content.trim().isNotEmpty)
      .map((m) => {'role': m.role.name, 'content': m.content.trim()})
      .toList();
  var size = result.fold(0, (total, m) => total + m['content']!.length);
  while (result.length > 1 && size > 12000) {
    size -= result.removeAt(0)['content']!.length;
  }
  return List.unmodifiable(result.map(Map<String, String>.unmodifiable));
}
