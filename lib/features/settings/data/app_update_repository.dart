import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../../core/vanta_api/vanta_api_http.dart';
import '../domain/app_version.dart';

/// Reads the public `config.min_supported_version` from `/v1/app/bootstrap`.
class AppUpdateRepository {
  AppUpdateRepository(this._http);
  final VantaApiHttp _http;

  Future<AppVersion?> minimumSupportedVersion() async {
    final json = await _http.get('/v1/app/bootstrap');
    final config = json['config'];
    if (config == null) return null;
    if (config is! Map<String, Object?>) throw const VantaApiFailure(vantaApiDataInvalid);
    final raw = config['min_supported_version'];
    if (raw == null || raw is String && raw.trim().isEmpty) return null;
    final version = raw is String ? AppVersion.tryParse(raw) : null;
    if (version == null) throw const VantaApiFailure(vantaApiDataInvalid);
    return version;
  }

  void close() => _http.close();
}
