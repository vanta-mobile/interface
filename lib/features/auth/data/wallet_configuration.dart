class WalletConfiguration {
  const WalletConfiguration({required this.projectId, this.origin = 'https://app.vanta.exchange'});
  const WalletConfiguration.environment()
    : projectId = const String.fromEnvironment('REOWN_PROJECT_ID'),
      origin = const String.fromEnvironment(
        'WALLET_LOGIN_ORIGIN',
        defaultValue: 'https://app.vanta.exchange',
      );

  final String projectId, origin;
  static const redirect = 'vanta://wallet';
  static const chains = ['1', '56', '42161', '8453'];
  Uri? get relyingParty {
    final uri = Uri.tryParse(origin.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty
        ? Uri.parse(uri.origin)
        : null;
  }

  bool get isConfigured => projectId.trim().isNotEmpty && relyingParty != null;
}
