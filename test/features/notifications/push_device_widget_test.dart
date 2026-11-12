import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/application/push_device_provider.dart';
import 'package:vanta/features/notifications/domain/push_registration.dart';
import 'package:vanta/features/notifications/presentation/notification_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/api_notifications.dart';
import '../../support/push_device.dart';
import '../../support/vanta_api.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets(
      'no server visibility explicitly explains missing background notifications: $language',
      (tester) async {
        final f = InboxFixture();
        addTearDown(f.dispose);
        f.items.add(inboxItem());
        f.backend.routes['GET /v1/push/status'] = (_) => json({
          ...pushStatusJson(status: 'no_server_visibility', devices: 0),
          'reason': '-5052',
        });
        await f.mount(tester, language: language, size: const Size(320, 740), scale: 1.5);
        final l = AppLocalizations.of(tester.element(find.byType(NotificationScreen)));
        expect(find.text(l.pushNoServerVisibility), findsOneWidget);
        expect(find.byKey(const Key('notification-event:1')), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(f.signer.calls, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('inbox refresh stays active until push status has also settled', (tester) async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    await f.mount(tester);
    final gate = Completer<void>();
    var started = false, done = false;
    f.backend.routes['GET /v1/push/status'] = (_) async {
      started = true;
      await gate.future;
      return json(pushStatusJson(status: 'inbox_only', devices: 0));
    };
    final indicator = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator));
    final refresh = indicator.show().then((_) => done = true);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(started, isTrue);
    expect(done, isFalse);
    gate.complete();
    await tester.pumpAndSettle();
    await refresh;
    expect(done, isTrue);
    expect(find.byKey(const Key('push-no-server-visibility')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('resume from system settings unbinds revoked permission and updates device state', (
    tester,
  ) async {
    final native = DevicePushRepository();
    final fixture = InboxFixture(messaging: native);
    addTearDown(fixture.dispose);
    addTearDown(native.changes.close);
    fixture.backend.routes['POST /v1/push/register'] = (_) =>
        json({'registered': true, 'device_id': 1, 'status': 'full'});
    fixture.backend.routes['POST /v1/push/unregister'] = (_) =>
        json({'removed': 1, 'status': 'inbox_only'});
    fixture.container.listen(pushDeviceLifecycleProvider, (_, _) {});
    await fixture.mount(tester);
    expect(fixture.container.read(pushDeviceProvider).bound, isTrue);
    native.value = const PushRegistration(permission: PushPermission.denied);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fixture.container.read(pushDeviceProvider).bound, isFalse);
    expect(fixture.backend.paths, contains('POST /v1/push/unregister'));
    await tester.pumpWidget(const SizedBox());
  });
}
