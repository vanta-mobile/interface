import 'dart:convert';

import 'api_error_details.dart';

ApiErrorDetails apiErrorDetails(Object? payload, {int? status, ApiErrorCause? cause}) {
  String? message;
  if (payload is Map) {
    for (final candidate in [
      payload['msg'],
      payload['message'],
      payload['error_description'],
      payload['error'],
    ]) {
      message = safeApiMessage(candidate is Map ? candidate['message'] : candidate);
      if (message != null) break;
    }
  }
  return ApiErrorDetails(message: message, status: status, cause: cause);
}

Object? decodeErrorPayload(String text) {
  if (text.length > 65536) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

String? safeApiMessage(Object? value) {
  if (value is! String || value.length > 4096) return null;
  var text = value.trim();
  if (text.isEmpty ||
      RegExp(r'-----BEGIN|mnemonic|seed phrase|private key', caseSensitive: false).hasMatch(text) ||
      text.contains('{') ||
      text.startsWith('{') ||
      text.startsWith('[') ||
      RegExp(
        r'<\s*/?\s*(?:html|script|body|!doctype)|\b(?:SELECT|INSERT|UPDATE|DELETE)\s+.+\s+(?:FROM|INTO|SET)\b',
        caseSensitive: false,
      ).hasMatch(text)) {
    return null;
  }
  // Error fields sometimes contain a trailing stack trace. Preserve the cause.
  text = text
      .split(RegExp(r'\n\s*(?:at |#\d+\s|Traceback|Stack\s*trace)', caseSensitive: false))
      .first;
  text = text.replaceAll(RegExp(r'-----BEGIN[\s\S]*?-----END[^-]*-----'), '•••');
  text = text.replaceAll(RegExp(r'\bBearer\s+[^\s,;]+', caseSensitive: false), 'Bearer •••');
  text = text.replaceAll(RegExp(r'\beyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'), '•••');
  text = text.replaceAll(RegExp(r'https?://[^\s<>]+', caseSensitive: false), '•••');
  text = text.replaceAll(RegExp(r'0x[a-fA-F0-9]{64,}\b|\b[a-fA-F0-9]{64,}\b'), '•••');
  text = text.replaceAllMapped(
    RegExp(
      r'''(["']?(?:token|access[_-]?token|refresh[_-]?token|api[_-]?key|authorization|signature|private[_-]?key|secret|password)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;}]+)''',
      caseSensitive: false,
    ),
    (match) => '${match[1]}•••',
  );
  text = text
      .replaceAll(RegExp(r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) return null;
  return text.length > 800 ? '${text.substring(0, 800)}…' : text;
}
