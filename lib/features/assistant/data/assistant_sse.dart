import 'dart:async';
import 'dart:convert';

import '../domain/assistant.dart';

/// UTF-8 decoding and line framing are incremental, including CR/LF split
/// across network chunks. No frame, response, or model string is unbounded.
Stream<AssistantDelta> decodeAssistantSse(
  Stream<List<int>> bytes, {
  int maxFrameCharacters = 65536,
  int maxResponseBytes = 2 * 1024 * 1024,
  int maxAnswerCharacters = 131072,
}) async* {
  var received = 0, answerSize = 0;
  final bounded = bytes.map((chunk) {
    received += chunk.length;
    if (received > maxResponseBytes) throw const AssistantFailure('assistantTooLarge');
    return chunk;
  });
  final frame = <String>[];
  var frameSize = 0, lineSize = 0;
  // Bound a single unterminated line before LineSplitter can accumulate it.
  final decoded = bounded.transform(utf8.decoder).map((chunk) {
    for (final char in chunk.codeUnits) {
      if (char == 10 || char == 13) {
        lineSize = 0;
      } else if (++lineSize > maxFrameCharacters) {
        throw const AssistantFailure('assistantTooLarge');
      }
    }
    return chunk;
  });
  final safeDecoded = decoded.handleError((Object _) {
    throw const AssistantFailure('assistantInvalidResponse');
  }, test: (error) => error is FormatException);
  await for (final line in safeDecoded.transform(const LineSplitter())) {
    if (line.isNotEmpty) {
      frameSize += line.length;
      if (frameSize > maxFrameCharacters) throw const AssistantFailure('assistantTooLarge');
      frame.add(line);
      continue;
    }
    final delta = _frame(frame);
    frame.clear();
    frameSize = 0;
    if (delta == null) continue;
    answerSize += delta.content.length + delta.reasoning.length;
    if (answerSize > maxAnswerCharacters) throw const AssistantFailure('assistantTooLarge');
    yield delta;
    if (delta.done || delta.truncated) return;
  }
  final tail = _frame(frame);
  if (tail != null) {
    answerSize += tail.content.length + tail.reasoning.length;
    if (answerSize > maxAnswerCharacters) throw const AssistantFailure('assistantTooLarge');
    yield tail;
  }
}

AssistantDelta? _frame(List<String> lines) {
  final data = lines
      .where((line) => line.startsWith('data:'))
      .map((line) => line.substring(5).replaceFirst(RegExp(r'^ '), ''))
      .join('\n')
      .trim();
  if (data.isEmpty) return null;
  if (data == '[DONE]') return const AssistantDelta(done: true);
  Object? parsed;
  try {
    parsed = jsonDecode(data);
  } on FormatException {
    throw const AssistantFailure('assistantInvalidResponse');
  }
  if (parsed is! Map<String, Object?>) throw const AssistantFailure('assistantInvalidResponse');
  // Some providers send a usage-only frame after choices have completed.
  final choices = parsed['choices'];
  if (choices is List && choices.isEmpty) return null;
  if (choices is! List || choices.firstOrNull is! Map<String, Object?>) {
    throw const AssistantFailure('assistantInvalidResponse');
  }
  final choice = choices.first as Map<String, Object?>;
  final rawDelta = choice['delta'];
  if (rawDelta != null && rawDelta is! Map<String, Object?>) {
    throw const AssistantFailure('assistantInvalidResponse');
  }
  final delta = rawDelta as Map<String, Object?>? ?? const {};
  String text(String key) {
    final value = delta[key];
    if (value == null) return '';
    if (value is! String) throw const AssistantFailure('assistantInvalidResponse');
    return value;
  }

  final reasoning = text('reasoning_content');
  final finish = choice['finish_reason'];
  if (finish != null && finish is! String) throw const AssistantFailure('assistantInvalidResponse');
  return AssistantDelta(
    content: text('content'),
    reasoning: reasoning.isNotEmpty ? reasoning : text('thinking_delta'),
    done: finish == 'stop' || finish == 'end_turn',
    truncated: finish == 'length',
  );
}
