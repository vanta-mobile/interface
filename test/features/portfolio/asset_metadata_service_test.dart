import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/asset_metadata_repository.dart';
import 'package:vanta/features/portfolio/data/asset_metadata_service.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/asset_metadata.dart';

import '../../support/asset_metadata.dart';

void main() {
  const jsonType = {'content-type': 'application/json'};
  const pngType = {'content-type': 'image/png'};
  test(
    'fixed anonymous catalog GET/readonly POST have no wallet/auth fields, map independently',
    () async {
      final requests = <http.Request>[];
      final service = AssetMetadataService(
        client: MockClient((r) async {
          requests.add(r);
          expect(r.followRedirects, false);
          return http.Response(
            jsonEncode(
              metadataPayload(
                r.method == 'GET' ? AssetMetadataSource.names : AssetMetadataSource.logos,
              ),
            ),
            200,
            headers: jsonType,
          );
        }),
      );
      addTearDown(service.close);
      final repo = PublicAssetMetadataRepository(service);
      expect((await repo.read(AssetMetadataSource.names)).forSymbol('USDT')!.name, 'TetherUS');
      expect(
        (await repo.read(AssetMetadataSource.logos)).forSymbol('ASBNB')!.logo,
        metadataLogo('asbnb'),
      );
      expect(requests.map((r) => r.url.toString()), [
        'https://www.asterdex.com/bapi/asset/v2/public/asset/asset/ae/get-all-asset',
        'https://www.asterdex.com/bapi/futures/v1/public/future/asset/ae/all-asset-logo',
      ]);
      expect(requests.first.method, 'GET');
      expect(requests.first.body, '');
      expect(requests.last.method, 'POST');
      expect(requests.last.body, '{}');
      for (final r in requests) {
        expect(
          r.headers.keys.map((k) => k.toLowerCase()).toSet().difference({'accept', 'content-type'}),
          isEmpty,
        );
        expect(r.url.query, isEmpty);
      }
    },
  );
  for (final status in [302, 401, 403, 429, 500]) {
    test('catalog HTTP $status does not follow redirects or retry', () async {
      var calls = 0;
      final s = AssetMetadataService(
        client: MockClient((_) async {
          calls++;
          return http.Response('raw payload', status, headers: jsonType);
        }),
      );
      addTearDown(s.close);
      await expectLater(s.catalog(AssetMetadataSource.names), throwsA(isA<AccountReadFailure>()));
      expect(calls, 1);
    });
  }
  for (final type in ['text/html', 'image/png', 'application/json-bad']) {
    test('wrong catalog MIME $type fails before parsing', () async {
      final s = AssetMetadataService(
        client: MockClient((_) async => http.Response('{}', 200, headers: {'content-type': type})),
      );
      addTearDown(s.close);
      await expectLater(s.catalog(AssetMetadataSource.names), throwsA(isA<AccountReadFailure>()));
    });
  }
  test('streaming catalog size remains bounded without Content-Length', () async {
    final s = AssetMetadataService(
      client: MockClient.streaming(
        (_, _) async =>
            http.StreamedResponse(Stream.value(List.filled(2097153, 32)), 200, headers: jsonType),
      ),
    );
    addTearDown(s.close);
    await expectLater(s.catalog(AssetMetadataSource.names), throwsA(isA<AccountReadFailure>()));
  });
  test('malformed JSON maps to safe error', () async {
    final s = AssetMetadataService(
      client: MockClient((_) async => http.Response('not-json', 200, headers: jsonType)),
    );
    addTearDown(s.close);
    await expectLater(
      s.catalog(AssetMetadataSource.names),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountDataInvalid')),
    );
  });
  test('timeout is terminal without an automatic retry', () async {
    final gate = Completer<http.Response>();
    var calls = 0;
    final s = AssetMetadataService(
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) {
        calls++;
        return gate.future;
      }),
    );
    addTearDown(s.close);
    await expectLater(s.catalog(AssetMetadataSource.names), throwsA(isA<AccountReadFailure>()));
    gate.complete(http.Response('{}', 200, headers: jsonType));
    expect(calls, 1);
  });
  test('timeout aborts native transport instead of leaving an unbounded request running', () async {
    final aborted = Completer<void>();
    final s = AssetMetadataService(
      timeout: const Duration(milliseconds: 2),
      client: MockClient.streaming((r, _) async {
        await (r as http.Abortable).abortTrigger;
        aborted.complete();
        throw http.RequestAbortedException(r.url);
      }),
    );
    addTearDown(s.close);
    await expectLater(s.catalog(AssetMetadataSource.names), throwsA(isA<AccountReadFailure>()));
    await aborted.future;
  });
  test('service disposal aborts active reads and releases queued logo requests', () async {
    var started = 0;
    final active = Completer<void>();
    final s = AssetMetadataService(
      client: MockClient.streaming((r, _) async {
        started++;
        if (started == 4) active.complete();
        await (r as http.Abortable).abortTrigger;
        throw http.RequestAbortedException(r.url);
      }),
    );
    final results = [
      for (var i = 0; i < 6; i++)
        expectLater(s.logo(metadataLogo('close$i')), throwsA(isA<AccountReadFailure>())),
    ];
    await active.future;
    s.close();
    await Future.wait(results);
    expect(started, 4);
  });
  test('same logo in-flight and success are cached, explicit retry evicts it', () async {
    var calls = 0;
    final gate = Completer<http.Response>();
    final s = AssetMetadataService(
      client: MockClient((r) {
        calls++;
        expect(r.method, 'GET');
        expect(r.body, '');
        expect(r.followRedirects, false);
        return gate.future;
      }),
    );
    addTearDown(s.close);
    final first = s.logo(metadataLogo()), second = s.logo(metadataLogo());
    expect(identical(first, second), true);
    gate.complete(http.Response.bytes(metadataPng, 200, headers: pngType));
    expect(await first, metadataPng);
    expect(await second, metadataPng);
    expect(await s.logo(metadataLogo()), metadataPng);
    expect(calls, 1);
    s.evictLogo(metadataLogo());
    await s.logo(metadataLogo());
    expect(calls, 2);
  });
  test('failed image is not cached and can be explicitly retried', () async {
    var calls = 0;
    final s = AssetMetadataService(
      client: MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('bad', 500)
            : http.Response.bytes(metadataPng, 200, headers: pngType);
      }),
    );
    addTearDown(s.close);
    await expectLater(s.logo(metadataLogo()), throwsA(isA<AccountReadFailure>()));
    expect(await s.logo(metadataLogo()), metadataPng);
    expect(calls, 2);
  });
  test('unapproved image never starts network', () async {
    var calls = 0;
    final s = AssetMetadataService(
      client: MockClient((_) async {
        calls++;
        return http.Response('', 200);
      }),
    );
    addTearDown(s.close);
    await expectLater(
      s.logo(Uri.https('untrusted.invalid', '/a.png')),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(calls, 0);
  });
  for (final value in [
    metadataImage(0, 1),
    metadataImage(2049, 1),
    metadataImage(1, 2049),
    <int>[1, 2, 3],
    List<int>.filled(524289, 0),
  ]) {
    test(
      'invalid PNG header/dimensions/bytes ${value.length}/${value.hashCode} is rejected',
      () async {
        final s = AssetMetadataService(
          client: MockClient((_) async => http.Response.bytes(value, 200, headers: pngType)),
        );
        addTearDown(s.close);
        await expectLater(s.logo(metadataLogo()), throwsA(isA<AccountReadFailure>()));
      },
    );
  }
  test('image streaming bytes are bounded without Content-Length', () async {
    final s = AssetMetadataService(
      client: MockClient.streaming(
        (_, _) async =>
            http.StreamedResponse(Stream.value(List.filled(524289, 0)), 200, headers: pngType),
      ),
    );
    addTearDown(s.close);
    await expectLater(s.logo(metadataLogo()), throwsA(isA<AccountReadFailure>()));
  });
  for (final type in ['text/html', 'image/svg+xml']) {
    test('unapproved image MIME $type is rejected', () async {
      final s = AssetMetadataService(
        client: MockClient(
          (_) async => http.Response.bytes(metadataPng, 200, headers: {'content-type': type}),
        ),
      );
      addTearDown(s.close);
      await expectLater(s.logo(metadataLogo()), throwsA(isA<AccountReadFailure>()));
    });
  }
  test('image cache evicts oldest after64 entries', () async {
    var calls = 0;
    final s = AssetMetadataService(
      client: MockClient((_) async {
        calls++;
        return http.Response.bytes(metadataPng, 200, headers: pngType);
      }),
    );
    addTearDown(s.close);
    for (var i = 0; i < 65; i++) {
      await s.logo(metadataLogo('a$i'));
    }
    await s.logo(metadataLogo('a64'));
    expect(calls, 65);
    await s.logo(metadataLogo('a0'));
    expect(calls, 66);
  });
  test('image concurrency max4, queued requests release and close prevents new network', () async {
    final gates = <Completer<http.Response>>[];
    final s = AssetMetadataService(
      client: MockClient((_) {
        final c = Completer<http.Response>();
        gates.add(c);
        return c.future;
      }),
    );
    addTearDown(s.close);
    final futures = [for (var i = 0; i < 6; i++) s.logo(metadataLogo('a$i'))];
    await Future<void>.delayed(Duration.zero);
    expect(gates.length, 4);
    gates.first.complete(http.Response.bytes(metadataPng, 200, headers: pngType));
    await futures.first;
    await Future<void>.delayed(Duration.zero);
    expect(gates.length, 5);
    for (var i = 1; i < 5; i++) {
      gates[i].complete(http.Response.bytes(metadataPng, 200, headers: pngType));
    }
    await Future<void>.delayed(Duration.zero);
    expect(gates.length, 6);
    gates.last.complete(http.Response.bytes(metadataPng, 200, headers: pngType));
    await Future.wait(futures);
    s.close();
    await expectLater(s.logo(metadataLogo('another')), throwsA(isA<AccountReadFailure>()));
  });
}
