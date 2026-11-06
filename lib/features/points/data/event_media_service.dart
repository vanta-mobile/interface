import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../market/data/market_http_client.dart';
import '../domain/points.dart';
import 'event_document_mapper.dart';

class EventMediaService {
  EventMediaService({http.Client? client}) : _client = createMarketHttpClient(client: client);
  final http.Client _client;
  Future<Uint8List> read(Uri uri) async {
    if (eventLink(uri.toString(), image: true) != uri) {
      throw const PointsFailure('pointsDataInvalid');
    }
    try {
      return await (() async {
        final request = http.Request('GET', uri)..followRedirects = false;
        final response = await _client.send(request);
        final type = response.headers['content-type']?.split(';').first.trim().toLowerCase();
        if (response.statusCode != 200 ||
            !const {'image/png', 'image/jpeg', 'image/webp', 'image/gif'}.contains(type) ||
            (response.contentLength ?? 0) > 5242880) {
          await response.stream.listen(null).cancel();
          throw const PointsFailure('pointsDataInvalid');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 5242880) throw const PointsFailure('pointsDataInvalid');
          bytes.add(chunk);
        }
        if (bytes.isEmpty) throw const PointsFailure('pointsDataInvalid');
        return bytes.takeBytes();
      })().timeout(const Duration(seconds: 12));
    } on PointsFailure {
      rethrow;
    } catch (_) {
      throw const PointsFailure('pointsNetwork');
    }
  }

  void close() => _client.close();
}
