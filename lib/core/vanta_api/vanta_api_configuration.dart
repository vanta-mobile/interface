/// Public compile-time origin of the Vanta backend (`docs/contracts/vanta-api`).
/// Paths in the contract already carry `/v1`; an empty origin disables the API.
class VantaApiConfiguration {
  const VantaApiConfiguration({this.origin = ''});
  const VantaApiConfiguration.environment()
    : origin = const String.fromEnvironment('VANTA_API_ORIGIN');

  final String origin;

  Uri? get baseUri {
    final uri = Uri.tryParse(origin.trim());
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty &&
            (uri.path.isEmpty || uri.path == '/') &&
            !uri.hasQuery &&
            !uri.hasFragment
        ? Uri.parse(uri.origin)
        : null;
  }

  bool get isConfigured => baseUri != null;
}
