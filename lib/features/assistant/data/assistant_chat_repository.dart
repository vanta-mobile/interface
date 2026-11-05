import '../domain/assistant.dart';
import 'assistant_http.dart';

/// One caller-generated request ID covers streaming and both website-defined
/// completion attempts. A stop cancels the entire operation, including fallback.
class AssistantChatRepository {
  const AssistantChatRepository(this.http);
  final AssistantHttp http;

  Stream<AssistantReplyUpdate> answer({
    required String accessToken,
    required String userId,
    required String requestId,
    required List<AssistantMessage> history,
    required AssistantCancellation cancellation,
  }) async* {
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuid.hasMatch(userId) ||
        !uuid.hasMatch(requestId) ||
        accessToken.isEmpty ||
        accessToken.length > 16384 ||
        accessToken.contains(RegExp(r'\s')) ||
        history.isEmpty ||
        history.last.role != AssistantRole.user ||
        history.last.delivery != AssistantDelivery.complete ||
        history.last.content.trim().isEmpty ||
        history.last.content.length > 12000) {
      throw const AssistantFailure('assistantInvalidInput');
    }
    final messages = assistantContext(history);
    var content = '', reasoning = '';
    var done = false, truncated = false;
    AssistantReplyUpdate update(AssistantDelivery delivery) =>
        AssistantReplyUpdate(content: content, reasoning: reasoning, delivery: delivery);
    try {
      cancellation.check();
      try {
        await for (final delta in http.chat(
          token: accessToken,
          userId: userId,
          requestId: requestId,
          messages: messages,
          cancellation: cancellation,
        )) {
          cancellation.check();
          content += delta.content;
          reasoning += delta.reasoning;
          done = done || delta.done;
          truncated = truncated || delta.truncated;
          yield update(AssistantDelivery.streaming);
        }
      } on AssistantFailure catch (failure) {
        if (cancellation.isCancelled || !failure.canComplete) rethrow;
      }
      cancellation.check();
      if (done && !truncated && content.trim().isNotEmpty) {
        yield update(AssistantDelivery.complete);
        return;
      }
      if (truncated) yield update(AssistantDelivery.truncated);
      // No new ID and no new user turn. Backend deduplication / quota behavior
      // still needs live acceptance; local code never calls this after stop.
      var reply = await http.complete(
        token: accessToken,
        userId: userId,
        requestId: requestId,
        messages: messages,
        cancellation: cancellation,
      );
      cancellation.check();
      if (reply.content.isEmpty && reply.reasoning.isNotEmpty) {
        if (reasoning.isEmpty) reasoning = reply.reasoning;
        yield update(AssistantDelivery.streaming);
        reply = await http.complete(
          token: accessToken,
          userId: userId,
          requestId: requestId,
          messages: messages,
          cancellation: cancellation,
          finalAnswerOnly: true,
        );
      }
      cancellation.check();
      if (reply.content.isEmpty) throw const AssistantFailure('assistantEmptyReply');
      content = reply.content;
      if (reasoning.isEmpty) reasoning = reply.reasoning;
      yield update(AssistantDelivery.complete);
    } on AssistantFailure catch (failure) {
      if (cancellation.isCancelled || failure.key == 'assistantCancelled') {
        yield update(AssistantDelivery.interrupted);
        return;
      }
      yield update(truncated ? AssistantDelivery.truncated : AssistantDelivery.failed);
      rethrow;
    } finally {
      cancellation.cancel();
    }
  }
}
