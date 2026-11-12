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
    await repository.tokens.close();
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
    expect((await initial).token, 'initial-token');
    repository.tokens.add('rotated-token');
    expect(container.read(pushRegistrationProvider).requireValue.token, 'rotated-token');
    expect(repository.calls, 1);
    first.close();
    second.close();
  });

  test('registration updates during initialization win over the initial result', () async {
    final pending = container.read(pushRegistrationProvider.future);
    repository.tokens.add('newer-token');
    repository.registration.complete(authorized);
    expect((await pending).token, 'newer-token');
  });

  test('permission denial cannot be overridden by a native registration event', () async {
    final pending = container.read(pushRegistrationProvider.future);
    repository.tokens.add('early-token');
    repository.registration.complete(const PushRegistration(permission: PushPermission.denied));
    expect((await pending).token, isNull);
    repository.tokens.add('later-token');
    expect(container.read(pushRegistrationProvider).requireValue.token, isNull);
    expect(container.read(pushRegistrationProvider).requireValue.permission, PushPermission.denied);
  });

  test('late APNs registration supplies an ID without restarting registration', () async {
    final pending = container.read(pushRegistrationProvider.future);
    repository.registration.complete(const PushRegistration(permission: PushPermission.authorized));
    expect((await pending).token, isNull);
    repository.tokens.add('apns-ready-token');
    expect(container.read(pushRegistrationProvider).requireValue.token, 'apns-ready-token');
    expect(repository.calls, 1);
  });

  test('empty IDs and refresh errors preserve the usable registration', () async {
    final pending = container.read(pushRegistrationProvider.future);
    repository.registration.complete(authorized);
    await pending;
    repository.tokens.add(' ');
    repository.tokens.addError(StateError('temporary refresh failure'));
    expect(container.read(pushRegistrationProvider).requireValue.token, 'initial-token');
  });

  test('initial errors remain observable and disposal cancels listeners', () async {
    final pending = container.read(pushRegistrationProvider.future);
    final failure = StateError('registration unavailable');
    repository.registration.completeError(failure);
    await expectLater(pending, throwsA(same(failure)));
    expect(container.read(pushRegistrationProvider).hasError, isTrue);
    container.dispose();
    container = ProviderContainer();
    expect(repository.tokens.hasListener, isFalse);
  });

  test('replacing a repository cancels old listeners and ignores its pending result', () async {
    container.listen(pushRegistrationProvider, (_, _) {});
    final old = repository;
    final replacement = TestPushRepository();
    addTearDown(replacement.tokens.close);
    container.updateOverrides([pushMessagingRepositoryProvider.overrideWithValue(replacement)]);
    final pending = container.read(pushRegistrationProvider.future);
    replacement.registration.complete(
      const PushRegistration(permission: PushPermission.authorized, token: 'replacement-token'),
    );
    await pending;
    old.registration.complete(authorized);
    old.tokens.add('stale-token');
    await Future<void>.delayed(Duration.zero);
    expect(old.tokens.hasListener, isFalse);
    expect(container.read(pushRegistrationProvider).requireValue.token, 'replacement-token');
  });
}

const authorized = PushRegistration(permission: PushPermission.authorized, token: 'initial-token');

class TestPushRepository implements PushMessagingRepository {
  final registration = Completer<PushRegistration>();
  final tokens = StreamController<String>.broadcast(sync: true);
  int calls = 0;
  @override
  Stream<String> get registrationChanges => tokens.stream;
  @override
  Future<PushRegistration> register() {
    calls++;
    return registration.future;
  }
}
