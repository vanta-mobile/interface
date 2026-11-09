import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/push_registration.dart';

/// Native startup injects the initialized repository. Previews and widget tests
/// remain independent of Firebase and native permission dialogs.
final pushMessagingRepositoryProvider = Provider<PushMessagingRepository?>((ref) => null);

final pushRegistrationProvider =
    AsyncNotifierProvider<PushRegistrationController, PushRegistration>(
      PushRegistrationController.new,
    );

class PushRegistrationController extends AsyncNotifier<PushRegistration> {
  @override
  Future<PushRegistration> build() async {
    final repository = ref.watch(pushMessagingRepositoryProvider);
    if (repository == null) {
      return const PushRegistration(permission: PushPermission.unavailable);
    }

    var active = true;
    String? latestInstallationId;
    PushRegistration? registration;
    final subscription = repository.registrationChanges.listen(
      (installationId) {
        if (!active || !ref.mounted || installationId.trim().isEmpty) return;
        latestInstallationId = installationId;
        final current = registration;
        if (current != null && current.canReceive) {
          registration = current.withInstallationId(installationId);
          state = AsyncData(registration!);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        // A transient refresh failure does not invalidate a usable registration.
        // An initial registration failure is exposed by the awaited operation.
      },
    );
    ref.onDispose(() {
      active = false;
      unawaited(subscription.cancel());
    });

    final initial = await repository.register();
    registration = initial.canReceive && latestInstallationId != null
        ? initial.withInstallationId(latestInstallationId!)
        : initial;
    return registration!;
  }
}
