import 'assistant.dart';

class AssistantHistory {
  AssistantHistory({Iterable<AssistantMessage> messages = const [], this.draft = ''})
    : messages = List.unmodifiable(messages);
  final List<AssistantMessage> messages;
  final String draft;
}
