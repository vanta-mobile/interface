class PrivyConfiguration {
  const PrivyConfiguration({required this.appId, required this.clientId});
  const PrivyConfiguration.environment()
    : appId = const String.fromEnvironment('PRIVY_APP_ID'),
      clientId = const String.fromEnvironment('PRIVY_CLIENT_ID');

  final String appId, clientId;
  bool get isConfigured => appId.trim().isNotEmpty && clientId.trim().isNotEmpty;
}
