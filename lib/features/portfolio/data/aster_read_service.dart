import '../../../core/errors/api_error_details.dart';
import '../../../core/errors/api_error_parser.dart';
import '../../../core/network/safe_read_retry.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../market/data/market_http_client.dart';
import '../domain/account_snapshot.dart';

class AsterEmptyResponse {
  const AsterEmptyResponse();
}

/// Account transport. No signed URL, raw payload or signature is logged.
class AsterReadService {
  AsterReadService({
    required this.origin,
    this.timePath,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
    Object? Function(String)? decodeResponse,
  }) : _client = createMarketHttpClient(client: client, timeout: timeout),
       _decodeResponse = decodeResponse ?? jsonDecode;
  final Uri origin;
  final String? timePath;
  final http.Client _client;
  final _readRetry = SafeReadRetry();
  final Object? Function(String) _decodeResponse;
  final Duration timeout;

  Future<Object?> get(String path, {String? query}) => _request('GET', path, query: query);

  Future<Object?> _request(
    String method,
    String path, {
    String? query,
    String? body,
    bool allowEmptyResponse = false,
  }) async {
    try {
      // A redirect must not forward an account signature to another origin.
      Future<http.Response> send() async {
        final request = http.Request(method, origin.replace(path: path, query: query))
          ..followRedirects = false
          ..headers['Accept'] = 'application/json';
        if (body != null) {
          request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
          request.body = body;
        }
        return http.Response.fromStream(await _client.send(request));
      }

      final response = await (method == 'GET' ? _readRetry.run(send) : send());
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw AccountReadFailure(
          'accountReadFailed',
          details: ApiErrorDetails(status: response.statusCode),
        );
      }
      Object? data;
      try {
        final source = utf8.decode(response.bodyBytes);
        data = allowEmptyResponse && source.trim().isEmpty
            ? const AsterEmptyResponse()
            : _decodeResponse(source);
      } on FormatException {
        throw AccountReadFailure(
          response.statusCode == 429 || response.statusCode == 418
              ? 'accountRateLimited'
              : response.statusCode == 200
              ? 'accountDataInvalid'
              : 'accountReadFailed',
          details: ApiErrorDetails(
            status: response.statusCode,
            cause: response.statusCode == 200 ? ApiErrorCause.invalidResponse : null,
            endpoint: path,
          ),
        );
      }
      final code = data is Map<String, dynamic> ? data['code'] : null;
      if ((code is int && code < 0) ||
          (data is Map && data['success'] == false) ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw AccountReadFailure(
          response.statusCode == 429 || response.statusCode == 418
              ? 'accountRateLimited'
              : _failureKey(
                  code,
                  response.statusCode,
                  missingAgent: method == 'GET' && _missingAgent(data),
                ),
          code: code is int ? code : null,
          details: apiErrorDetails(data, status: response.statusCode),
        );
      }
      return data;
    } on AccountReadFailure {
      rethrow;
    } on TimeoutException {
      throw const AccountReadFailure(
        'accountNetwork',
        details: ApiErrorDetails(cause: ApiErrorCause.timeout),
      );
    } on http.RequestAbortedException {
      throw const AccountReadFailure(
        'accountNetwork',
        details: ApiErrorDetails(cause: ApiErrorCause.cancelled),
      );
    } catch (_) {
      throw const AccountReadFailure(
        'accountNetwork',
        details: ApiErrorDetails(cause: ApiErrorCause.connection),
      );
    }
  }

  Future<int> serverTime() async {
    final path = timePath;
    if (path == null) throw const AccountReadFailure('accountDataInvalid');
    final data = await get(path);
    if (data case {'serverTime': int time} when time > 0) return time;
    throw const AccountReadFailure('accountDataInvalid');
  }

  Future<Object?> signedGet(String path, {required String query, required String signature}) {
    return _signed('GET', path, query: query, signature: signature);
  }

  /// Funding documentation signs a query string and appends signature last.
  Future<Object?> signedPostQuery(
    String path, {
    required String query,
    required String signature,
  }) => _signed('POST', path, query: query, signature: signature);

  /// V3 non-GET endpoints accept the exact signed bytes in a form body.
  Future<Object?> signedPost(
    String path, {
    required String query,
    required String signature,
    bool allowEmptyResponse = false,
  }) {
    if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) {
      throw const AccountReadFailure('authWalletSignature');
    }
    return _request(
      'POST',
      path,
      body: '$query&signature=$signature',
      allowEmptyResponse: allowEmptyResponse,
    );
  }

  /// Used only by the futures service's explicit order cancellation method.
  Future<Object?> signedDelete(String path, {required String query, required String signature}) {
    return _signed('DELETE', path, query: query, signature: signature);
  }

  /// Used only by the futures service's explicit LIMIT order modification.
  Future<Object?> signedPut(String path, {required String query, required String signature}) {
    return _signed('PUT', path, query: query, signature: signature);
  }

  Future<Object?> _signed(
    String method,
    String path, {
    required String query,
    required String signature,
  }) {
    if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) {
      throw const AccountReadFailure('authWalletSignature');
    }
    return _request(method, path, query: '$query&signature=$signature');
  }

  void close() {
    _readRetry.close();
    _client.close();
  }
}

// Aster also uses generic -1000 for a missing agent. Recognize only this
// explicit read response; never use its display text to classify a write as
// safely rejected or replayable.
bool _missingAgent(Object? data) {
  if (data is! Map || data['code'] != -1000) return false;
  final message = data['msg'] ?? data['message'];
  return message is String && message.trim() == 'No agent found';
}

String _failureKey(Object? code, int status, {bool missingAgent = false}) => switch (code) {
  -1000 when missingAgent => 'accountPermissionRequired',
  -5050 => 'accountDepositRequired',
  -1021 || -4225 => 'accountSignatureExpired',
  -1022 => 'accountSignatureRejected',
  -2014 || -2015 => 'accountPermissionRequired',
  _ => status == 401 || status == 403 ? 'accountPermissionRequired' : 'accountReadFailed',
};
