import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/errors/api_error_details.dart';
import '../../../core/errors/api_error_parser.dart';
import '../../market/data/market_http_client.dart';
import '../domain/account_snapshot.dart';
import '../domain/asset_metadata.dart';

/// Anonymous catalog and image transport only. No wallet or account data.
class AssetMetadataService {
  AssetMetadataService({http.Client? client, this.timeout = const Duration(seconds: 12)})
    : _client = createMarketHttpClient(client: client, timeout: timeout);
  final http.Client _client;
  final Duration timeout;
  bool _closed = false;
  int _running = 0, _cacheBytes = 0;
  final _waiting = <Completer<void>>[];
  final _aborts = <Completer<void>>{};
  final _cache = <Uri, Uint8List>{};
  final _inflight = <Uri, Future<Uint8List>>{};

  Future<Uint8List> _read(http.Request request, int limit, String type) async {
    final abort = Completer<void>();
    _aborts.add(abort);
    final transport = http.AbortableRequest(request.method, request.url, abortTrigger: abort.future)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes
      ..followRedirects = false;
    try {
      return await (() async {
        if (_closed) throw const AccountReadFailure('accountNetwork');
        final response = await _client.send(transport);
        if (response.statusCode != 200) {
          final bytes = BytesBuilder(copy: false);
          if (type == 'application/json' && (response.contentLength ?? 0) <= 65536) {
            await for (final chunk in response.stream) {
              if (bytes.length + chunk.length > 65536) break;
              bytes.add(chunk);
            }
          } else {
            await response.stream.listen(null).cancel();
          }
          throw AccountReadFailure(
            response.statusCode == 429 ? 'accountRateLimited' : 'accountReadFailed',
            details: apiErrorDetails(
              decodeErrorPayload(utf8.decode(bytes.takeBytes(), allowMalformed: true)),
              status: response.statusCode,
            ),
          );
        }
        if (response.headers['content-type']?.split(';').first.trim().toLowerCase() != type ||
            (response.contentLength ?? 0) > limit) {
          await response.stream.listen(null).cancel();
          throw const AccountReadFailure('accountDataInvalid');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > limit) {
            throw const AccountReadFailure('accountDataInvalid');
          }
          bytes.add(chunk);
        }
        if (bytes.isEmpty) throw const AccountReadFailure('accountDataInvalid');
        return bytes.takeBytes();
      })().timeout(
        timeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw const AccountReadFailure(
            'accountNetwork',
            details: ApiErrorDetails(cause: ApiErrorCause.timeout),
          );
        },
      );
    } on AccountReadFailure {
      rethrow;
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
    } finally {
      _aborts.remove(abort);
    }
  }

  Future<Object?> catalog(AssetMetadataSource source) async {
    final names = source == AssetMetadataSource.names;
    final request = http.Request(
      names ? 'GET' : 'POST',
      Uri.https(
        'www.asterdex.com',
        names
            ? '/bapi/asset/v2/public/asset/asset/ae/get-all-asset'
            : '/bapi/futures/v1/public/future/asset/ae/all-asset-logo',
      ),
    )..headers['Accept'] = 'application/json';
    // This public POST is a read-only logo catalog, never an account operation.
    if (!names) {
      request.headers['Content-Type'] = 'application/json';
      request.body = '{}';
    }
    final bytes = await _read(request, 2097152, 'application/json');
    try {
      final data = jsonDecode(utf8.decode(bytes));
      if (data is Map && data['success'] == false) {
        throw AccountReadFailure('accountReadFailed', details: apiErrorDetails(data, status: 200));
      }
      return data;
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }

  Future<Uint8List> logo(Uri uri) {
    if (assetLogoUri(uri.toString()) != uri || _closed) {
      return Future.error(const AccountReadFailure('accountDataInvalid'));
    }
    final cached = _cache.remove(uri);
    if (cached != null) {
      _cache[uri] = cached;
      return Future.value(cached);
    }
    return _inflight[uri] ??= _loadLogo(uri).whenComplete(() {
      _inflight.remove(uri);
    });
  }

  Future<Uint8List> _loadLogo(Uri uri) async {
    if (_running >= 4) {
      final gate = Completer<void>();
      _waiting.add(gate);
      await gate.future;
    } else {
      _running++;
    }
    try {
      final bytes = await _read(http.Request('GET', uri), 524288, 'image/png');
      // Bound decoded pixel size as well as compressed bytes, before Flutter's
      // decoder sees the image. Thumbnails decode at a fixed small target size.
      final header = ByteData.sublistView(bytes);
      if (bytes.length < 33 ||
          bytes[0] != 137 ||
          ascii.decode(bytes.sublist(1, 4), allowInvalid: true) != 'PNG' ||
          bytes[4] != 13 ||
          bytes[5] != 10 ||
          bytes[6] != 26 ||
          bytes[7] != 10 ||
          header.getUint32(8) != 13 ||
          ascii.decode(bytes.sublist(12, 16), allowInvalid: true) != 'IHDR' ||
          header.getUint32(16) < 1 ||
          header.getUint32(20) < 1 ||
          header.getUint32(16) > 2048 ||
          header.getUint32(20) > 2048) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      if (!_closed) {
        _cache[uri] = bytes;
        _cacheBytes += bytes.length;
        while (_cache.length > 64 || _cacheBytes > 4194304) {
          _cacheBytes -= _cache.remove(_cache.keys.first)!.length;
        }
      }
      return bytes;
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _running--;
      }
    }
  }

  void evictLogo(Uri uri) {
    final old = _cache.remove(uri);
    if (old != null) _cacheBytes -= old.length;
  }

  void close() {
    _closed = true;
    _cache.clear();
    _cacheBytes = 0;
    for (final abort in _aborts) {
      if (!abort.isCompleted) abort.complete();
    }
    _client.close();
    // In-flight/queued reads fail through _read; queued tasks pass permits on.
  }
}
