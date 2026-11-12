import 'package:vanta/features/notifications/application/push_messaging_provider.dart';
import 'package:vanta/features/notifications/application/push_device_provider.dart';
import 'package:vanta/features/notifications/domain/push_registration.dart';
import 'package:vanta/features/notifications/domain/push_device.dart';

import 'push_device.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/data/vanta_api_session_repository.dart';
import 'package:vanta/features/auth/data/vanta_api_session_store.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/notifications/application/api_notification_provider.dart';
import 'package:vanta/features/notifications/presentation/notification_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import 'vanta_api.dart';
import 'notifications.dart';

import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';

class InboxAuth extends AuthController {
  InboxAuth(this.initial);
  final AuthIdentity? initial;
  @override
  AuthSession build() => initial == null
      ? const AuthSession(phase: AuthPhase.signedOut)
      : AuthSession(phase: AuthPhase.signedIn, identity: initial);
  void setWallet(String? address) => state = address == null
      ? const AuthSession(phase: AuthPhase.signedOut)
      : AuthSession(phase: AuthPhase.signedIn, identity: inboxIdentity(address));
}

AuthIdentity inboxIdentity(String address) => AuthIdentity(
  id: address,
  walletAddress: address,
  walletKind: WalletKind.external,
  signingAvailable: true,
);

Map<String, Object?> inboxItem({
  int id = 1,
  String type = 'FILL',
  bool read = false,
  bool broadcast = false,
  String? symbol = 'BTCUSDT',
  Map<String, Object?> payload = const {},
}) => {
  'kind': broadcast ? 'broadcast' : 'event',
  'id': id,
  'event_key': broadcast ? 'broadcast:$id' : 'event:$id',
  'type': type,
  'severity': ['LIQUIDATION', 'MARGIN_CALL'].contains(type) ? 'critical' : 'low',
  'payload': payload,
  'read': read,
  'symbol': symbol,
  'created_at': DateTime.utc(2026, 11, 12, 8, 0, id).toIso8601String(),
};

class InboxFixture {
  InboxFixture({
    bool signedIn = true,
    bool storedSession = true,
    PushMessagingRepository? messaging,
    Future<PushDeviceMetadata> Function()? metadataReader,
  }) {
    if (storedSession) {
      store.value = VantaApiCredentials(
        address: vantaTestAddress.toLowerCase(),
        accessToken: 'stored',
        refreshToken: 'refresh',
        accessExpiresAt: vantaTestNow.add(const Duration(hours: 1)),
      );
    }
    repository = vantaTestRepository(
      backend,
      store: store,
      signer: signer,
      now: () => vantaTestNow,
    );
    backend.routes['GET /v1/notifications'] = (request) async {
      await listGate?.future;
      if (listFailure) {
        return json({'code': 'internal_error', 'message': 'Inbox temporarily unavailable'}, 503);
      }
      final q = request.url.queryParameters;
      final filtered = items.where((e) {
        if (q['unread_only'] == 'true' && e['read'] == true) return false;
        return switch (q['category']) {
          'orders' => ['FILL', 'TRIGGER', 'ORDER'].contains(e['type']),
          'transfers' => ['FUNDING', 'TRANSFER'].contains(e['type']),
          _ => true,
        };
      }).toList();
      return json({
        'items': filtered,
        'next_cursor': null,
        'unread': items.where((e) => e['read'] == false).length + extraUnread,
      });
    };
    backend.routes['POST /v1/notifications/read'] = (request) async {
      await writeGate?.future;
      if (writeFailure) {
        return json({'code': 'internal_error', 'message': 'Read marker unavailable'}, 503);
      }
      final body = jsonDecode(request.body) as Map;
      var marked = 0;
      for (final item in items) {
        if (body['all'] == true ||
            (body['event_keys'] is List &&
                (body['event_keys'] as List).contains(item['event_key'])) ||
            (body['broadcast_up_to'] is int &&
                item['kind'] == 'broadcast' &&
                (item['id'] as int) <= (body['broadcast_up_to'] as int))) {
          if (item['read'] == false) marked++;
          item['read'] = true;
        }
      }
      if (body['all'] == true) extraUnread = 0;
      return json({'marked': marked});
    };
    backend.routes['GET /v1/push/status'] = (_) =>
        json(pushStatusJson(status: 'inbox_only', devices: 0));
    container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(journal),
        pushMessagingRepositoryProvider.overrideWithValue(messaging),
        pushDeviceMetadataReaderProvider.overrideWithValue(
          metadataReader ?? () async => pushMetadata,
        ),
        pushUtcOffsetProvider.overrideWithValue(() => utcOffset),
        authProvider.overrideWith(
          () => auth = InboxAuth(signedIn ? inboxIdentity(vantaTestAddress) : null),
        ),
        vantaApiSessionRepositoryProvider.overrideWithValue(repository),
        vantaApiClockProvider.overrideWithValue(() => vantaTestNow),
      ],
    );
    container.read(authProvider);
  }
  final journal = LocalNotificationRepository(MemoryNotificationStorage());
  final backend = Backend();
  final signer = KeySigner();
  final store = MemoryStore();
  late final VantaApiSessionRepository repository;
  late final ProviderContainer container;
  late InboxAuth auth;
  final items = <Map<String, Object?>>[];
  int extraUnread = 0;
  int utcOffset = 480;
  bool listFailure = false, writeFailure = false;
  Completer<void>? listGate, writeGate;
  ApiNotificationInboxController get controller =>
      container.read(apiNotificationInboxProvider.notifier);
  ApiInboxState get state => container.read(apiNotificationInboxProvider);
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await pumpEventQueue();
    }
  }

  Future<void> start() async {
    container.listen(apiNotificationInboxProvider, (_, _) {});
    await settle();
  }

  Future<void> mount(
    WidgetTester tester, {
    String language = 'en',
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const NotificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void dispose() {
    container.dispose();
    repository.close();
    unawaited(journal.dispose());
  }
}
