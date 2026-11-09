import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/application/push_messaging_provider.dart';
import 'package:vanta/features/notifications/domain/push_registration.dart';

void main() {
  late TestPushRepository repository;
  late ProviderContainer container;
  setUp(() {
    repository = TestPushRepository();
    container = ProviderContainer(
      overrides: [pushMessagingRepositoryProvider.overrideWithValue(repository)],
    );
  });
  tearDown(() async {
    container.dispose();
    await repository.installationIds.close();
  });

  test('previews and tests without a native repository remain available', () async {
    final preview = ProviderContainer();
    addTearDown(preview.dispose);
    expect(
      (await preview.read(pushRegistrationProvider.future)).permission,
      PushPermission.unavailable,
    );
  });

  test('starts once for multiple consumers and tracks registration updates', () async {
    final first = container.listen(pushRegistrationProvider, (_, _) {});
    final second = container.listen(pushRegistrationProvider, (_, _) {});
    final initial = container.read(pushRegistrationProvider.future);
    repository.registration.complete(authorized);
    expect((await initial).installationId, 'initial-installationId');
    repository.installationIds.add('rotated-installationId');
    expect(
      container.read(pushRegistrationProvider).requireValue.installationId,
      'rotated-installationId',
    );
    expect(repository.calls, 1);
    first.close();
    second.close();
  });

  test('registration updates during initialization win over the initial result', () async {
    final pending = container.read(pushRegistrationProvider.future);
    repository.installationIds.add('newer-installationId');
    repository.registration.complete(authorized);
    expect((await pending).installationId, 'newer-installationId');
  });

  test('permission denial cannot be overridden by a native registration event', () async {
    final pending = container.read(pushRegistrationProvider.future);
    repository.installationIds.add('early-installationId');
    repository.registration.complete(const PushRegistration(permission: PushPermission.denied));
    expect((await pending).installationId, isNull);
    repository.installationIds.add('later-installationId');
    expect(container.read(pushRegistrationProvider).requireValue.installationId, isNull);
    expect(container.read(pushRegistrationProvider).requireValue.permission, PushPermission.denied);
  });

  test('late APNs registration supplies an ID without restarting registration', () async {
    final pending = container.read(pushRegistrationProvider.future);
    repository.registration.complete(const PushRegistration(permission: PushPermission.authorized));
    expect((await pending).installationId, isNull);
    repository.installationIds.add('apns-ready-installationId');
    expect(
      container.read(pushRegistrationProvider).requireValue.installationId,
      'apns-ready-installationId',
    );
    expect(repository.calls, 1);
  });

  test('empty IDs and refresh errors preserve the usable registration', () async {
    final pending = container.read(pushRegistrationProvider.future);
    repository.registration.complete(authorized);
    await pending;
    repository.installationIds.add(' ');
    repository.installationIds.addError(StateError('temporary refresh failure'));
    expect(
      container.read(pushRegistrationProvider).requireValue.installationId,
      'initial-installationId',
    );
  });

  test('initial errors remain observable and disposal cancels listeners', () async {
    final pending = container.read(pushRegistrationProvider.future);
    final failure = StateError('registration unavailable');
    repository.registration.completeError(failure);
    await expectLater(pending, throwsA(same(failure)));
    expect(container.read(pushRegistrationProvider).hasError, isTrue);
    container.dispose();
    container = ProviderContainer();
    expect(repository.installationIds.hasListener, isFalse);
  });

  test('replacing a repository cancels old listeners and ignores its pending result', () async {
    container.listen(pushRegistrationProvider, (_, _) {});
    final old = repository;
    final replacement = TestPushRepository();
    addTearDown(replacement.installationIds.close);
    container.updateOverrides([pushMessagingRepositoryProvider.overrideWithValue(replacement)]);
    final pending = container.read(pushRegistrationProvider.future);
    replacement.registration.complete(
      const PushRegistration(
        permission: PushPermission.authorized,
        installationId: 'replacement-installationId',
      ),
    );
    await pending;
    old.registration.complete(authorized);
    old.installationIds.add('stale-installationId');
    await Future<void>.delayed(Duration.zero);
    expect(old.installationIds.hasListener, isFalse);
    expect(
      container.read(pushRegistrationProvider).requireValue.installationId,
      'replacement-installationId',
    );
  });
}

const authorized = PushRegistration(
  permission: PushPermission.authorized,
  installationId: 'initial-installationId',
);

class TestPushRepository implements PushMessagingRepository {
  final registration = Completer<PushRegistration>();
  final installationIds = StreamController<String>.broadcast(sync: true);
  int calls = 0;
  @override
  Stream<String> get registrationChanges => installationIds.stream;
  @override
  Future<PushRegistration> register() {
    calls++;
    return registration.future;
  }
}
