enum PushPermission {
  unavailable,
  notDetermined,
  denied,
  deniedPermanently,
  authorized,
  provisional,
}

/// Device registration only; a Firebase Installation ID does not authorize a wallet.
class PushRegistration {
  const PushRegistration({required this.permission, this.installationId});

  final PushPermission permission;
  final String? installationId;

  bool get canReceive =>
      permission == PushPermission.authorized || permission == PushPermission.provisional;

  PushRegistration withInstallationId(String value) =>
      PushRegistration(permission: permission, installationId: value);
}

abstract interface class PushMessagingRepository {
  Future<PushRegistration> register();
  Stream<String> get registrationChanges;
}
