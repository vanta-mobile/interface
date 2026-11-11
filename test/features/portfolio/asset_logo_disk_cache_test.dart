import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/asset_logo_disk_cache.dart';
import 'package:vanta/features/portfolio/data/asset_metadata_service.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/asset_metadata.dart';

void main() {
  late Directory directory;
  late DateTime now;
  AssetLogoDiskCache cache({int maxEntries = 512, int maxBytes = 32 * 1024 * 1024}) =>
      AssetLogoDiskCache(
        directory: () async => directory,
        now: () => now,
        maxEntries: maxEntries,
        maxBytes: maxBytes,
      );
  Future<List<File>> files() async => (await directory.list().toList()).whereType<File>().toList();
  AssetMetadataService service(AssetLogoDiskCache disk, {void Function(Uri)? onRequest}) {
    final result = AssetMetadataService(
      diskCache: disk,
      client: MockClient((request) async {
        onRequest?.call(request.url);
        return http.Response.bytes(metadataPng, 200, headers: {'content-type': 'image/png'});
      }),
    );
    addTearDown(result.close);
    return result;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vanta-icon-cache-');
    now = DateTime.now().toUtc();
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('token and network images survive new service and cache instances without HTTP', () async {
    var requests = 0;
    final first = service(cache(), onRequest: (_) => requests++);
    await first.logo(metadataLogo());
    await first.networkLogo(42161);
    first.close();
    final second = service(cache(), onRequest: (_) => requests++);
    expect(await second.logo(metadataLogo()), metadataPng);
    expect(await second.networkLogo(42161), metadataPng);
    expect(requests, 2);
    expect((await files()).length, 2);
    expect((await files()).every((file) => file.path.endsWith('.png')), true);
  });

  test('full URL is the key and paths contain no remote filename', () async {
    final disk = cache();
    final a = metadataLogo('same');
    final b = Uri.parse(a.toString().replaceFirst('20251010', '20251111'));
    final changed = metadataImage(2, 2);
    await disk.write(a, metadataPng);
    await disk.write(b, changed);
    expect(await disk.read(a), metadataPng);
    expect(await disk.read(b), changed);
    for (final file in await files()) {
      expect(file.uri.pathSegments.last, matches(RegExp(r'^[0-9a-f]{64}\.png$')));
    }
  });

  test('30-day expiry uses download time even after a recent cache hit', () async {
    final disk = cache();
    await disk.write(metadataLogo(), metadataPng);
    now = now.add(const Duration(days: 29));
    expect(await disk.read(metadataLogo()), metadataPng);
    now = now.add(const Duration(days: 1));
    var requests = 0;
    expect(await service(cache(), onRequest: (_) => requests++).logo(metadataLogo()), metadataPng);
    expect(requests, 1);
  });

  test('entry budget evicts least recently accessed file across restart', () async {
    final disk = cache(maxEntries: 2);
    await disk.write(metadataLogo('a'), metadataPng);
    now = now.add(const Duration(minutes: 1));
    await disk.write(metadataLogo('b'), metadataPng);
    now = now.add(const Duration(minutes: 1));
    await disk.read(metadataLogo('a'));
    now = now.add(const Duration(minutes: 1));
    final restarted = cache(maxEntries: 2);
    await restarted.write(metadataLogo('c'), metadataPng);
    expect(await restarted.read(metadataLogo('b')), isNull);
    expect(await restarted.read(metadataLogo('a')), metadataPng);
    expect(await restarted.read(metadataLogo('c')), metadataPng);
    expect((await files()).length, 2);
  });

  test('byte budget is enforced and oversized single entries are not stored', () async {
    final disk = cache(maxBytes: metadataPng.length * 2 - 1);
    await disk.write(metadataLogo('a'), metadataPng);
    now = now.add(const Duration(seconds: 1));
    await disk.write(metadataLogo('b'), metadataPng);
    expect(await disk.read(metadataLogo('a')), isNull);
    expect(await disk.read(metadataLogo('b')), metadataPng);
    await cache(maxBytes: 1).write(metadataLogo('c'), metadataPng);
    expect(await disk.read(metadataLogo('c')), isNull);
  });

  for (final damage in ['header', 'dimensions', 'oversize']) {
    test('invalid $damage on disk is discarded and downloaded again', () async {
      final disk = cache();
      await disk.write(metadataLogo(), metadataPng);
      final file = (await files()).single;
      await file.writeAsBytes(switch (damage) {
        'dimensions' => metadataImage(4096, 1),
        'oversize' => Uint8List(524289),
        _ => [1, 2, 3],
      });
      var requests = 0;
      expect(await service(disk, onRequest: (_) => requests++).logo(metadataLogo()), metadataPng);
      expect(requests, 1);
      expect(await cache().read(metadataLogo()), metadataPng);
    });
  }

  test('startup removes expired files and incomplete atomic writes', () async {
    await cache().write(metadataLogo(), metadataPng);
    await File('${directory.path}/unfinished.png.tmp').writeAsBytes(metadataPng);
    now = now.add(const Duration(days: 31));
    expect(await cache().read(metadataLogo('missing')), isNull);
    expect(await files(), isEmpty);
  });

  test('cache directory deletion is recoverable', () async {
    final disk = cache();
    await disk.write(metadataLogo(), metadataPng);
    await directory.delete(recursive: true);
    expect(await disk.read(metadataLogo()), isNull);
    await disk.write(metadataLogo(), metadataPng);
    expect(await disk.read(metadataLogo()), metadataPng);
  });

  test('unavailable cache storage never breaks images or poisons later operations', () async {
    final blocked = File('${directory.path}/not-a-directory');
    await blocked.writeAsString('blocked');
    var unavailable = true;
    final disk = AssetLogoDiskCache(
      directory: () async {
        if (unavailable) throw const FileSystemException('unavailable');
        return Directory(blocked.path);
      },
    );
    final loader = service(disk);
    expect(await loader.logo(metadataLogo()), metadataPng);
    unavailable = false;
    expect(await loader.networkLogo(1), metadataPng);
    await blocked.delete();
    await disk.write(metadataLogo(), metadataPng);
    expect(await disk.read(metadataLogo()), metadataPng);
  });

  test('failed network and malformed PNG responses are not persisted', () async {
    var requests = 0;
    final loader = AssetMetadataService(
      diskCache: cache(),
      client: MockClient((_) async {
        requests++;
        return http.Response(
          'invalid',
          requests == 1 ? 500 : 200,
          headers: {'content-type': 'image/png'},
        );
      }),
    );
    addTearDown(loader.close);
    for (var i = 0; i < 2; i++) {
      await expectLater(loader.logo(metadataLogo()), throwsA(isA<AccountReadFailure>()));
    }
    expect(await files(), isEmpty);
  });

  test('concurrent duplicate reads share download and persist one atomic file', () async {
    var requests = 0;
    final loader = service(cache(), onRequest: (_) => requests++);
    final images = await Future.wait(List.generate(12, (_) => loader.logo(metadataLogo())));
    expect(images.every((image) => identical(image, images.first)), true);
    expect(requests, 1);
    expect((await files()).length, 1);
  });

  test('explicit retry removes both memory and disk before the next read', () async {
    var requests = 0;
    final disk = cache();
    final loader = service(disk, onRequest: (_) => requests++);
    await loader.logo(metadataLogo());
    loader.evictLogo(metadataLogo());
    await loader.logo(metadataLogo());
    expect(requests, 2);
    expect(await cache().read(metadataLogo()), metadataPng);
  });

  test('evicted in-flight image cannot overwrite newer memory or disk bytes', () async {
    final started = Completer<void>(), oldResponse = Completer<http.Response>();
    final changed = metadataImage(2, 2);
    var requests = 0;
    final loader = AssetMetadataService(
      diskCache: cache(),
      client: MockClient((_) async {
        if (++requests == 1) {
          started.complete();
          return oldResponse.future;
        }
        return http.Response.bytes(changed, 200, headers: {'content-type': 'image/png'});
      }),
    );
    addTearDown(loader.close);
    final old = loader.logo(metadataLogo());
    await started.future;
    loader.evictLogo(metadataLogo());
    expect(await loader.logo(metadataLogo()), changed);
    oldResponse.complete(
      http.Response.bytes(metadataPng, 200, headers: {'content-type': 'image/png'}),
    );
    await old;
    expect(await loader.logo(metadataLogo()), changed);
    expect(await cache().read(metadataLogo()), changed);
    expect(requests, 2);
  });

  test('disposal while directory resolves never starts HTTP or fills cache', () async {
    final gate = Completer<Directory>(), started = Completer<void>();
    final disk = AssetLogoDiskCache(
      directory: () {
        started.complete();
        return gate.future;
      },
    );
    var requests = 0;
    final loader = service(disk, onRequest: (_) => requests++);
    final pending = loader.logo(metadataLogo());
    final failure = expectLater(pending, throwsA(isA<AccountReadFailure>()));
    await started.future;
    loader.close();
    gate.complete(directory);
    await failure;
    expect(requests, 0);
    expect(await files(), isEmpty);
  });
}
