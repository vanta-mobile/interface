import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/deep_link/application/deep_link_provider.dart';
import 'package:vanta/features/deep_link/data/app_link_source.dart';
import 'package:vanta/features/deep_link/domain/app_deep_link.dart';
import 'package:vanta/features/notifications/application/api_notification_provider.dart';
import 'package:vanta/features/notifications/application/push_open_provider.dart';
import 'package:vanta/features/notifications/data/push_open_source.dart';
import 'package:vanta/features/notifications/domain/api_notification.dart';
import 'package:vanta/features/notifications/domain/push_notification_open.dart';

const _owner = '0x00000000000000000000000000000000000000aa';
const _other = '0x00000000000000000000000000000000000000bb';

Map<String, Object?> _event(String type, {String symbol = 'BTCUSDT'}) => {
  'kind': 'event',
  'id': '42',
  'event_key': 'order:7:FILLED',
  'type': type,
  'symbol': symbol,
  'address': _owner.toUpperCase().replaceFirst('0X', '0x'),
};

class _Session extends VantaApiSessionController {
  @override
  VantaApiSessionState build() => const VantaApiSessionState(VantaApiSessionStatus.restoring);
  void set(VantaApiSessionState value) => state = value;
}

class _Auth extends AuthController {
  @override
  AuthSession build() => const AuthSession(phase: AuthPhase.initializing);
  void signIn(String wallet) => state = AuthSession(
    phase: AuthPhase.signedIn,
    identity: AuthIdentity(id: 'user-$wallet', walletAddress: wallet),
  );
}

class _Inbox extends ApiNotificationInboxController {
  final marked = <ApiNotificationReadTarget>[];
  @override
  ApiInboxState build() => ApiInboxState();
  @override
  Future<void> markReadTarget(ApiNotificationReadTarget target) async => marked.add(target);
}

void main() {
  group('payload', () {
    test('each event type opens its module and identifies its inbox entry', () {
      for (final (type, panel) in [
        ('FILL', DeepLinkFuturesPanel.positions),
        ('LIQUIDATION', DeepLinkFuturesPanel.positions),
        ('MARGIN_CALL', DeepLinkFuturesPanel.positions),
        ('ORDER', DeepLinkFuturesPanel.orders),
        ('TRIGGER', DeepLinkFuturesPanel.orders),
      ]) {
        final open = PushNotificationOpen.fromData(_event(type));
        expect(
          (open.link.target, open.link.symbol, open.link.panel),
          (DeepLinkTarget.futures, 'BTCUSDT', panel),
          reason: type,
        );
        expect(
          (open.read?.kind, open.read?.id, open.read?.key),
          (ApiNotificationKind.event, 42, 'order:7:FILLED'),
        );
        expect(open.owner, _owner, reason: 'addresses compare lowercase');
      }
      for (final type in ['FUNDING', 'TRANSFER']) {
        final open = PushNotificationOpen.fromData(_event(type)..remove('symbol'));
        expect((open.link.target, open.read?.key), (DeepLinkTarget.portfolio, 'order:7:FILLED'));
      }
      for (final type in ['ANNOUNCE', 'MAINTENANCE']) {
        final open = PushNotificationOpen.fromData({'kind': 'broadcast', 'id': '9', 'type': type});
        expect(
          (open.link.target, open.read?.kind, open.read?.id, open.owner),
          (DeepLinkTarget.notifications, ApiNotificationKind.broadcast, 9, null),
        );
      }
    });

    test('a missing or malformed field opens the inbox and marks nothing', () {
      Map<String, Object?> without(String key) => _event('FILL')..remove(key);
      Map<String, Object?> replaced(String key, Object? value) => _event('FILL')..[key] = value;
      for (final data in <Map<String, Object?>>[
        {},
        without('kind'),
        without('id'),
        without('event_key'),
        without('type'),
        without('symbol'),
        without('address'),
        replaced('kind', 'broadcast'),
        replaced('type', 'ANNOUNCE'),
        replaced('type', 'fill'),
        replaced('id', '0'),
        replaced('id', '042'),
        replaced('id', '-1'),
        replaced('id', '99999999999999999999'),
        replaced('id', 42),
        replaced('symbol', 'btcusdt'),
        replaced('symbol', 'BTC'),
        replaced('address', '0x123'),
        replaced('address', 'not-an-address'),
        replaced('event_key', ''),
        replaced('event_key', 'k' * 257),
        {'kind': 'broadcast', 'id': '9', 'type': 'FILL'},
      ]) {
        final open = PushNotificationOpen.fromData(data);
        expect(
          (open.link.target, open.read, open.owner),
          (DeepLinkTarget.notifications, null, null),
          reason: '$data',
        );
      }
    });
  });

  group('router', () {
    late StreamController<Map<String, Object?>> taps;
    late Completer<Map<String, Object?>?> launch;
    late ProviderContainer container;
    late _Inbox inbox;
    late _Session session;
    late _Auth auth;
    final opened = <DeepLinkTarget>[];

    setUp(() {
      taps = StreamController();
      launch = Completer();
      opened.clear();
      container = ProviderContainer(
        overrides: [
          appLinkSourceProvider.overrideWithValue(
            AppLinkSource(links: const Stream.empty(), initialLink: () async => null),
          ),
          pushOpenSourceProvider.overrideWithValue(
            PushOpenSource(opened: taps.stream, initial: () => launch.future),
          ),
          apiNotificationInboxProvider.overrideWith(_Inbox.new),
          vantaApiSessionProvider.overrideWith(_Session.new),
          authProvider.overrideWith(_Auth.new),
        ],
      );
      container.listen(deepLinkInboxProvider, (_, link) {
        if (link != null) opened.add(link.target);
      });
      container.listen(pushOpenRouterProvider, (_, _) {});
      inbox = container.read(apiNotificationInboxProvider.notifier) as _Inbox;
      session = container.read(vantaApiSessionProvider.notifier) as _Session;
      auth = container.read(authProvider.notifier) as _Auth;
    });
    tearDown(() {
      container.dispose();
      unawaited(taps.close());
    });

    void ready(String wallet) {
      auth.signIn(wallet);
      session.set(VantaApiSessionState(VantaApiSessionStatus.ready, address: wallet));
    }

    test('a launching tap opens its page now and marks read once its owner signs in', () async {
      launch.complete(_event('ORDER'));
      await pumpEventQueue();
      expect(opened, [DeepLinkTarget.futures]);
      expect(inbox.marked, isEmpty, reason: 'session still restoring');
      auth.signIn(_owner);
      session.set(const VantaApiSessionState(VantaApiSessionStatus.ready, address: _other));
      expect(inbox.marked, isEmpty, reason: 'session and wallet disagree while switching');
      session.set(const VantaApiSessionState(VantaApiSessionStatus.ready, address: _owner));
      expect(inbox.marked.single.key, 'order:7:FILLED');
      session.set(const VantaApiSessionState(VantaApiSessionStatus.signing, address: _owner));
      session.set(const VantaApiSessionState(VantaApiSessionStatus.ready, address: _owner));
      expect(inbox.marked, hasLength(1), reason: 'requested once');
    });

    test('another wallet drops the mark-read; broadcasts mark for whoever is signed in', () async {
      launch.complete(null);
      ready(_other);
      taps.add(_event('FILL'));
      await pumpEventQueue();
      expect(opened, [DeepLinkTarget.futures]);
      expect(inbox.marked, isEmpty);
      ready(_owner);
      expect(inbox.marked, isEmpty, reason: 'the dropped request never resurfaces');

      taps.add({'kind': 'broadcast', 'id': '9', 'type': 'ANNOUNCE'});
      await pumpEventQueue();
      expect(opened.last, DeepLinkTarget.notifications);
      expect(
        (inbox.marked.single.kind, inbox.marked.single.id),
        (ApiNotificationKind.broadcast, 9),
      );
    });

    test('an unattributable tap only opens the inbox', () async {
      launch.complete(null);
      ready(_owner);
      taps.add({'title': 'legacy push'});
      await pumpEventQueue();
      expect(opened, [DeepLinkTarget.notifications]);
      expect(inbox.marked, isEmpty);
    });
  });
}
