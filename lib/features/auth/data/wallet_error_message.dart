import '../../../core/errors/api_error_parser.dart';

/// Extract the provider's explanation without exposing request payloads or
/// session credentials. Wallets may wrap the JSON-RPC message as JSON text.
String? walletReason(String? message) {
  var text = message?.trim();
  // A plain Exception's display wrapper is not the provider's explanation.
  if (text == 'Exception') return null;
  if (text?.startsWith('Exception:') == true) text = text!.substring(10).trim();
  for (var depth = 0; text != null && depth < 3 && text.startsWith('{'); depth++) {
    final payload = decodeErrorPayload(text);
    final inner = payload is Map ? payload['message'] : null;
    text = inner is String ? inner.trim() : null;
  }
  if (text == null ||
      RegExp(
        r'^(?:#\d+\s|at\s|Traceback\b|Stack\s*trace\b)',
        caseSensitive: false,
      ).hasMatch(text) ||
      RegExp(r'wc:|symKey|sessionTopic|requestId=', caseSensitive: false).hasMatch(text)) {
    return null;
  }
  return safeApiMessage(text);
}
