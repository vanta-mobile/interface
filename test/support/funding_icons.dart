import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/asset_metadata_service.dart';

/// Public image snapshots; their original CDN URLs are recorded alongside them.
class FundingIconFixture {
  FundingIconFixture() {
    final sources = jsonDecode(File('$directory/sources.json').readAsStringSync()) as Map;
    urls = sources.map((key, value) => MapEntry(key as String, Uri.parse(value as String)));
  }
  static const directory = 'test/fixtures/funding_icons';
  late final Map<String, Uri> urls;
  final requests = <http.Request>[];
  final failures = <Uri>{};
  final gates = <Uri, Completer<http.Response>>{};
  final catalog = Uri.https(
    'www.asterdex.com',
    '/bapi/futures/v1/public/future/asset/ae/all-asset-logo',
  );

  AssetMetadataService service() => AssetMetadataService(
    client: MockClient((request) async {
      requests.add(request);
      if (gates[request.url] case final gate?) return gate.future;
      if (failures.contains(request.url)) return http.Response('unavailable', 503);
      if (request.url == catalog) {
        return http.Response(
          jsonEncode({
            'code': '000000',
            'data': [
              for (final entry in urls.entries.where((e) => !e.key.startsWith('network-')))
                {'assetCode': entry.key.toUpperCase(), 'logoUrl': entry.value.toString()},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      final name = urls.entries.singleWhere((e) => e.value == request.url).key;
      return http.Response.bytes(
        File('$directory/$name.png').readAsBytesSync(),
        200,
        headers: {'content-type': 'image/png'},
      );
    }),
  );
}
