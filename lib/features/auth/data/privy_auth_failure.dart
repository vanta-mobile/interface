import '../domain/auth_session.dart';

AuthFailure failureFromPrivy(String message) {
  final lower = message.toLowerCase();
  final key = lower.contains('network') || lower.contains('timeout') || lower.contains('connection')
      ? 'authNetwork'
      : lower.contains('rate') || lower.contains('too many')
      ? 'authRateLimited'
      : lower.contains('expired') && (lower.contains('code') || lower.contains('otp'))
      ? 'authCodeExpired'
      : lower.contains('code') || lower.contains('otp') || lower.contains('expired')
      ? 'authInvalidCode'
      : lower.contains('client') || lower.contains('app id') || lower.contains('configuration')
      ? 'authConfiguration'
      : 'authUnavailable';
  // Retain a concise SDK reason, without code values, credentials or payloads.
  var reason = message.split('\n').first.trim();
  reason = reason.replaceAll(
    RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'),
    '[redacted]',
  );
  reason = reason.replaceAll(
    RegExp(
      r'(?:[a-z_]*token|[a-z_]*secret|private[_ -]?key|password|signature|authorization|code|otp)\s*[:=]\s*[^\s,;]+',
      caseSensitive: false,
    ),
    '[redacted]',
  );
  reason = reason.replaceAll(RegExp(r'\b\d{6}\b|0x[a-fA-F0-9]{64,}'), '[redacted]');
  reason = reason.replaceAll(RegExp(r'\bBearer\s+[^\s,;]+', caseSensitive: false), '[redacted]');
  reason = reason.replaceAll(RegExp(r'\b[a-fA-F0-9]{64}\b'), '[redacted]');
  if (reason.contains('{') || reason.contains('Exception(') || reason.length > 200) reason = '';
  return AuthFailure(key, reason: reason.isEmpty ? null : reason);
}
