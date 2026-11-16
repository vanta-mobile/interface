import '../../../core/errors/api_error_details.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../../core/vanta_api/vanta_api_http.dart';
import '../domain/app_version.dart';

/// Public platform-specific update metadata, owned by the settings page.
class AppUpdateRepository {
  AppUpdateRepository(this._http);
  final VantaApiHttp _http;

  Future<AppVersion?> minimumSupportedVersion() async => (await read('android')).minimum;

  Future<AppUpdateConfiguration> read(String platform) async {
    final json = await _http.get('/v1/app/bootstrap');
    try {
      return mapAppUpdateConfiguration(json['config'], platform);
    } on FormatException {
      throw const VantaApiFailure(
        vantaApiDataInvalid,
        details: ApiErrorDetails(
          cause: ApiErrorCause.invalidResponse,
          endpoint: '/v1/app/bootstrap',
        ),
      );
    }
  }

  void close() => _http.close();
}

AppUpdateConfiguration mapAppUpdateConfiguration(Object? value, String platform) {
  if (!{'ios', 'android'}.contains(platform)) throw const FormatException('platform');
  if (value == null) return const AppUpdateConfiguration();
  if (value is! Map<String, Object?>) throw const FormatException('config');
  final raw = value['min_supported_version'];
  final minimum = raw == null || raw is String && raw.trim().isEmpty ? null : _version(raw);
  final updates = value['update'];
  if (updates != null && updates is! Map<String, Object?>) throw const FormatException('update');
  final selected = (updates as Map<String, Object?>?)?[platform];
  if (selected == null) return AppUpdateConfiguration(minimum: minimum);
  if (selected is! Map<String, Object?>) throw const FormatException('release');
  final latest = _version(selected['latest_version']);
  final force = selected['force_update'], notes = selected['release_notes'];
  if (force is! bool || notes is! Map<String, Object?> || minimum != null && latest < minimum) {
    throw const FormatException('release metadata');
  }
  final mappedNotes = <String, String>{};
  for (final entry in notes.entries) {
    if (entry.value is! String) throw const FormatException('release notes');
    final text = entry.value! as String;
    if (text.trim().isNotEmpty) mappedNotes[entry.key] = text;
  }
  final url = selected['store_url'];
  Uri? store;
  if (url != null) {
    if (url is! String) throw const FormatException('store URL');
    store = Uri.tryParse(url);
    if (store == null ||
        !{'https', 'http'}.contains(store.scheme) ||
        store.host.isEmpty ||
        store.userInfo.isNotEmpty) {
      throw const FormatException('store URL');
    }
  }
  return AppUpdateConfiguration(
    minimum: minimum,
    release: AppRelease(
      latest: latest,
      forceUpdate: force,
      releaseNotes: mappedNotes,
      storeUri: store,
    ),
  );
}

AppVersion _version(Object? raw) => raw is String && AppVersion.tryParse(raw) != null
    ? AppVersion.tryParse(raw)!
    : throw const FormatException('version');
