enum PushPermission {
  unavailable,
  notDetermined,
  denied,
  deniedPermanently,
  authorized,
  provisional,
}

/// APNs/FCM delivery tokens identify an app instance, not a wallet.
class PushRegistration {
  const PushRegistration({required this.permission, this.token});

  final PushPermission permission;
  final String? token;

  bool get canReceive =>
      permission == PushPermission.authorized || permission == PushPermission.provisional;

  PushRegistration withToken(String value) =>
      PushRegistration(permission: permission, token: value);
}

abstract interface class PushMessagingRepository {
  Future<PushRegistration> register();
  Stream<String> get registrationChanges;
}
