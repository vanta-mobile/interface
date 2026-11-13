import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/formatters/byte_size_formatter.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/core/vanta_api/vanta_api_http.dart';
import 'package:vanta/features/settings/data/app_cache_repository.dart';
import 'package:vanta/features/settings/data/app_update_repository.dart';
import 'package:vanta/features/settings/domain/app_version.dart';

import '../../support/vanta_api.dart';

void main() {
  group('AppVersion', () {
    test('compares dotted releases numerically and ignores build metadata', () {
      final installed = AppVersion.tryParse('0.0.2+2')!;
      expect(installed.text, '0.0.2');
      expect(installed < AppVersion.tryParse('0.0.10')!, isTrue);
      expect(AppVersion.tryParse('1.2')!.compareTo(AppVersion.tryParse('1.2.0')!), 0);
      expect(AppVersion.tryParse('1.3.0')! < AppVersion.tryParse('1.2.9')!, isFalse);
      expect(AppVersion.tryParse('v1'), isNull);
      expect(AppVersion.tryParse(''), isNull);
    });
    test('update is required only below a published minimum', () {
      final current = AppVersion.tryParse('1.0.0')!;
      expect(AppUpdateCheck(current: current).updateRequired, isFalse);
      expect(
        AppUpdateCheck(current: current, minimum: AppVersion.tryParse('1.0.1')).updateRequired,
        isTrue,
      );
      expect(
        AppUpdateCheck(current: current, minimum: AppVersion.tryParse('1.0.0')).updateRequired,
        isFalse,
      );
    });
  });

  test('byte sizes use binary units with one fractional digit', () {
    expect(ByteSizeFormatter.format(0), '0 B');
    expect(ByteSizeFormatter.format(1023), '1023 B');
    expect(ByteSizeFormatter.format(7680), '7.5 KB');
    expect(ByteSizeFormatter.format(2048), '2 KB');
    expect(ByteSizeFormatter.format(5 * 1024 * 1024), '5 MB');
    expect(() => ByteSizeFormatter.format(-1), throwsArgumentError);
  });

  group('AppUpdateRepository', () {
    late Backend backend;
    late AppUpdateRepository repository;
    setUp(() {
      backend = Backend();
      repository = AppUpdateRepository(
        VantaApiHttp(baseUri: Uri.https('api.vanta.test'), client: backend.client),
      );
    });
    tearDown(() => repository.close());
    test('reads the minimum supported version from public bootstrap', () async {
      backend.routes['GET /v1/app/bootstrap'] = (_) => json({
        'symbols': <Object?>[],
        'sessions': <Object?>[],
        'config': {'min_supported_version': '1.4.0'},
      });
      expect((await repository.minimumSupportedVersion())?.text, '1.4.0');
      expect(backend.requests.single.headers['Authorization'], isNull);
    });
    test('absent minimum is not an update requirement', () async {
      backend.routes['GET /v1/app/bootstrap'] = (_) => json({'config': <String, Object?>{}});
      expect(await repository.minimumSupportedVersion(), isNull);
    });
    test('malformed minimum is rejected rather than treated as current', () async {
      backend.routes['GET /v1/app/bootstrap'] = (_) => json({
        'config': {'min_supported_version': 'latest'},
      });
      await expectLater(
        repository.minimumSupportedVersion(),
        throwsA(isA<VantaApiFailure>().having((e) => e.key, 'key', vantaApiDataInvalid)),
      );
    });
    test('server error message is carried to the caller', () async {
      backend.routes['GET /v1/app/bootstrap'] = (_) =>
          json({'code': 'internal_error', 'message': 'Config unavailable'}, 503);
      await expectLater(
        repository.minimumSupportedVersion(),
        throwsA(
          isA<VantaApiFailure>().having((e) => e.details?.message, 'message', 'Config unavailable'),
        ),
      );
    });
  });

  group('AppCacheRepository', () {
    late Directory root;
    setUp(() async => root = await Directory.systemTemp.createTemp('vanta-cache-test'));
    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    test('measures nested files and clears every entry but keeps the root', () async {
      await File('${root.path}/a.bin').writeAsBytes(List.filled(1000, 1));
      await Directory('${root.path}/icons').create();
      await File('${root.path}/icons/b.png').writeAsBytes(List.filled(24, 1));
      final repository = AppCacheRepository(directory: () async => root);
      expect(await repository.size(), 1024);
      await repository.clear();
      expect(await repository.size(), 0);
      expect(await root.exists(), isTrue);
    });
    test('missing directory measures as empty', () async {
      final repository = AppCacheRepository(
        directory: () async => Directory('${root.path}/absent'),
      );
      expect(await repository.size(), 0);
      await repository.clear();
    });
  });
}
