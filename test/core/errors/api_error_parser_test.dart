import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_parser.dart';

void main() {
  test('prefers concrete API messages and never serializes raw payloads', () {
    expect(
      apiErrorDetails({
        'msg': '保证金不足',
        'message': 'fallback',
        'data': {'secret': 'hidden'},
      }, status: 400).message,
      '保证金不足',
    );
    expect(
      apiErrorDetails({
        'error': {'message': 'Amount exceeds available balance', 'data': 'hidden'},
      }).message,
      'Amount exceeds available balance',
    );
    expect(
      apiErrorDetails({
        'code': -1,
        'data': {'message': 'private'},
      }).message,
      isNull,
    );
    expect(apiErrorDetails({'msg': 123}).message, isNull);
  });

  test('strips credentials, signed URLs, tokens, signatures and trailing stack traces', () {
    final signature = '0x${'ab' * 65}';
    final text = safeApiMessage(
      'Signature expired; signature=$signature; access_token="private-value"; Bearer hidden-value; https://example.com/path?signature=hidden\n at service.dart:2',
    );
    expect(text, contains('Signature expired'));
    for (final secret in [signature, 'private-value', 'hidden-value', 'https://', 'service.dart']) {
      expect(text, isNot(contains(secret)));
    }
    expect(
      safeApiMessage('Session expired: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl'),
      'Session expired: •••',
    );
  });

  test('rejects HTML, raw JSON, database diagnostics and oversized messages', () {
    for (final value in [
      null,
      42,
      '',
      '<html>secret</html>',
      '{"token":"private"}',
      '["private"]',
      'SELECT secret FROM users',
      'x' * 4097,
    ]) {
      expect(safeApiMessage(value), isNull);
    }
  });

  test('preserves financial reasons, Unicode and actionable text', () {
    for (final message in [
      'Insufficient margin.',
      'Order does not exist.',
      '签名已过期，请重新签名。',
      'Minimum quantity is 0.001 BTC',
    ]) {
      expect(safeApiMessage(message), message);
    }
    expect(safeApiMessage('Request\u202espoof\nfailed'), 'Request spoof failed');
    expect(decodeErrorPayload('<html>bad gateway</html>'), isNull);
  });
}
