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
    String? latestToken;
    PushRegistration? registration;
    final subscription = repository.registrationChanges.listen(
      (token) {
        if (!active || !ref.mounted || token.trim().isEmpty) return;
        latestToken = token;
        final current = registration;
        if (current != null && current.canReceive) {
          registration = current.withToken(token);
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
    registration = initial.canReceive && latestToken != null
        ? initial.withToken(latestToken!)
        : initial;
    return registration!;
  }
}
