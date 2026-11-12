import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/api_error_details.dart';
import '../errors/api_error_parser.dart';
import '../network/managed_http_client.dart';
import 'vanta_api_failure.dart';

/// JSON transport for the Vanta API contract. Tokens are request scoped and
/// never logged; a redirect is refused so a bearer token cannot change origin.
class VantaApiHttp {
  VantaApiHttp({
    required this.baseUri,
    required http.Client client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = ManagedHttpClient(client, timeout: timeout, maxResponseBytes: 2 * 1024 * 1024);
  final Uri baseUri;
  final Duration timeout;
  final http.Client _client;

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, String>? query,
    String? accessToken,
    Object? Function(String)? decode,
  }) => _send('GET', path, query: query, accessToken: accessToken, decode: decode);

  Future<Map<String, Object?>> post(
    String path, {
    Map<String, Object?>? body,
    String? accessToken,
    String? idempotencyKey,
  }) => _send('POST', path, body: body, accessToken: accessToken, idempotencyKey: idempotencyKey);

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    String? accessToken,
    String? idempotencyKey,
    Object? Function(String)? decode,
  }) async {
    final http.Response response;
    try {
      final request =
          http.Request(
              method,
              baseUri.replace(path: path, queryParameters: query?.isEmpty ?? true ? null : query),
            )
            ..followRedirects = false
            ..headers['Accept'] = 'application/json';
      if (idempotencyKey != null) request.headers['Idempotency-Key'] = idempotencyKey;
      if (accessToken != null) request.headers['Authorization'] = 'Bearer $accessToken';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      response = await http.Response.fromStream(await _client.send(request)).timeout(timeout);
    } on TimeoutException {
      throw _transport(path, ApiErrorCause.timeout);
    } on http.RequestAbortedException {
      throw _transport(path, ApiErrorCause.cancelled);
    } catch (_) {
      throw _transport(path, ApiErrorCause.connection);
    }
    Object? data;
    try {
      data = response.bodyBytes.isEmpty
          ? null
          : (decode ?? jsonDecode)(utf8.decode(response.bodyBytes));
    } on FormatException {
      data = null;
    }
    final status = response.statusCode;
    if (status >= 200 &&
        status < 300 &&
        !(data is Map && data['code'] is String && data['message'] is String)) {
      if (data is Map<String, Object?>) return data;
      throw VantaApiFailure(
        vantaApiDataInvalid,
        details: ApiErrorDetails(
          status: status,
          cause: ApiErrorCause.invalidResponse,
          endpoint: path,
        ),
      );
    }
    final code = data is Map && data['code'] is String ? data['code'] as String : null;
    final message = data is Map ? safeApiMessage(data['message']) : null;
    throw VantaApiFailure(
      status == 429
          ? vantaApiRateLimited
          : status == 401
          ? vantaApiSignInRequired
          : vantaApiRequestFailed,
      code: code,
      details: ApiErrorDetails(
        message: message,
        status: status,
        cause: status == 429 && message == null ? ApiErrorCause.rateLimit : null,
        endpoint: path,
      ),
    );
  }

  VantaApiFailure _transport(String path, ApiErrorCause cause) => VantaApiFailure(
    vantaApiRequestFailed,
    details: ApiErrorDetails(cause: cause, endpoint: path),
  );

  void close() => _client.close();
}
