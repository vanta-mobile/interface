import '../errors/api_error_details.dart';

/// [key] is the stable localization/recovery key; [code] is the contract's
/// machine `ErrorCode`. Neither is inferred from the human-readable message.
class VantaApiFailure implements Exception, DetailedApiFailure {
  const VantaApiFailure(this.key, {this.code, this.details});
  final String key;
  final String? code;
  @override
  final ApiErrorDetails? details;

  /// The session cannot be refreshed; a new SIWE signature is required.
  bool get requiresSignIn =>
      key == vantaApiSignInRequired || const {'unauthenticated', 'session_revoked'}.contains(code);
  bool get sessionExpired => code == 'session_expired';

  @override
  String toString() => 'VantaApiFailure($key, $code)';
}

const vantaApiUnavailable = 'vantaApiUnavailable';
const vantaApiSignInRequired = 'vantaApiSignIn';
const vantaApiRequestFailed = 'vantaApiFailed';
const vantaApiDataInvalid = 'vantaApiInvalid';
const vantaApiRateLimited = 'vantaApiRateLimited';
