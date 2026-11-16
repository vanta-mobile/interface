import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

import '../../support/reown_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestReownModal modal;
  late ReownWalletConnection connection;
  setUp(() {
    modal = TestReownModal();
    connection = ReownWalletConnection(modal, modal.address, '56');
  });
  tearDown(() async {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await connection.release();
    await modal.dispose();
  });

  for (final wallet in ['MetaMask', 'Trust Wallet', 'Rainbow']) {
    test('$wallet uses SDK relay preparation and one SDK signature request', () async {
      modal.walletName = wallet;
      modal.relayGate = Completer<void>();
      final signing = connection.signPersonalMessage('Sign in');
      await pumpEventQueue();
      expect(modal.relayReconnects, 1);
      expect(modal.requests, isEmpty);
      modal.relayGate!.complete();
      expect(await signing, modal.result);
      expect(modal.sdk.pings, 1);
      expect(modal.requests.single.method, 'personal_sign');
      expect(modal.chain, 'eip155:56');
      expect(modal.topic, 'topic');
    });
  }

  for (final error in [ErrorOpeningWallet(), WalletNotInstalled(), UserRejectedRequest()]) {
    test('SDK ${error.runtimeType} releases signing while the RPC is pending', () async {
      final firstGate = Completer<void>(), retryGate = Completer<void>();
      modal.gate = firstGate;
      final first = expectLater(
        connection.signPersonalMessage('first'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.key,
            'key',
            error is UserRejectedRequest ? 'authWalletRejected' : 'authWalletOpenFailed',
          ),
        ),
      );
      await pumpEventQueue();
      modal.onModalError.broadcast(error);
      await first;
      modal.gate = retryGate;
      final retry = connection.signPersonalMessage('retry');
      await pumpEventQueue();
      expect(modal.requests, hasLength(2));
      firstGate.complete();
      await pumpEventQueue();
      await expectLater(connection.signPersonalMessage('duplicate'), throwsA(isA<AuthFailure>()));
      retryGate.complete();
      expect(await retry, modal.result);
    });
  }

  test('SDK async launch errors settle the caller and allow an explicit retry', () async {
    final gate = Completer<void>();
    modal.onRequest = (_) async {
      scheduleMicrotask(() => throw StateError('Unable to open wallet'));
      await gate.future;
      return modal.result;
    };
    await expectLater(
      connection.signPersonalMessage('first'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletUnavailable')),
    );
    modal.onRequest = null;
    expect(await connection.signPersonalMessage('retry'), modal.result);
    gate.complete();
    await pumpEventQueue();
    expect(modal.requests, hasLength(2));
  });

  test('relay preparation timeout never dispatches a late signing request', () {
    fakeAsync((time) {
      modal.relayGate = Completer<void>();
      AuthFailure? failure;
      connection
          .signPersonalMessage('first')
          .then<void>(
            (_) {},
            onError: (Object error) {
              failure = error as AuthFailure;
            },
          );
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 10));
      time.flushMicrotasks();
      // An unreachable relay is a network failure, not evidence about the wallet.
      expect(failure?.key, 'authWalletConnectionTimeout');
      expect(connection.needsReconnect, false);
      modal.relayGate!.complete();
      time.flushMicrotasks();
      expect(modal.requests, isEmpty);
      expect(modal.sdk.pings, 0);
    });
  });

  test('a relay publish failure settles the signature without requiring reconnect', () async {
    modal.gate = Completer<void>();
    final pending = expectLater(
      connection.signPersonalMessage('first'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletUnavailable')),
    );
    await pumpEventQueue();
    modal.sdk.relayErrors.broadcast(ErrorEvent(StateError('publish failed')));
    await pending;
    expect(connection.needsReconnect, false);
    expect(connection.isCurrent, true);
    modal.gate!.complete();
    await pumpEventQueue();
  });

  for (final beforeDispatch in [true, false]) {
    test('relay string errors retain their reason: beforeDispatch=$beforeDispatch', () async {
      final gate = Completer<void>();
      if (beforeDispatch) {
        modal.relayGate = gate;
      } else {
        modal.gate = gate;
      }
      final pending = expectLater(
        connection.signPersonalMessage('first'),
        throwsA(
          isA<AuthFailure>()
              .having((e) => e.key, 'key', 'authWalletUnavailable')
              .having(
                (e) => e.reason,
                'reason',
                'The client closed with pending request "irn_subscribe".',
              ),
        ),
      );
      await pumpEventQueue();
      modal.sdk.relayErrors.broadcast(
        ErrorEvent('The client closed with pending request "irn_subscribe".'),
      );
      await pending;
      expect(modal.requests, hasLength(beforeDispatch ? 0 : 1));
      expect(connection.needsReconnect, false);
      gate.complete();
      await pumpEventQueue();
      expect(modal.requests, hasLength(beforeDispatch ? 0 : 1));
    });
  }

  test('wallet launch failures preserve the SDK description', () async {
    modal.gate = Completer<void>();
    final pending = expectLater(
      connection.signPersonalMessage('first'),
      throwsA(
        isA<AuthFailure>()
            .having((e) => e.key, 'key', 'authWalletOpenFailed')
            .having((e) => e.reason, 'reason', 'Wallet launch was blocked'),
      ),
    );
    await pumpEventQueue();
    modal.onModalError.broadcast(ErrorOpeningWallet(description: 'Wallet launch was blocked'));
    await pending;
    modal.gate!.complete();
    await pumpEventQueue();
  });

  test('disconnect event promptly settles a signature whose SDK future never returns', () async {
    modal.gate = Completer<void>();
    final pending = expectLater(
      connection.signTypedData({}),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    await pumpEventQueue();
    modal.isConnected = false;
    modal.changed();
    await pending;
    expect(connection.needsReconnect, false);
    modal.gate!.complete();
    await pumpEventQueue();
  });

  test('releasing a connection immediately settles its pending signature', () async {
    modal.gate = Completer<void>();
    final pending = expectLater(
      connection.signPersonalMessage('first'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    await pumpEventQueue();
    await connection.release();
    await pending;
    modal.gate!.complete();
    await pumpEventQueue();
  });

  test('a replacement SDK topic never inherits the previous connection', () async {
    modal.gate = Completer<void>();
    final pending = expectLater(
      connection.signPersonalMessage('first'),
      throwsA(isA<AuthFailure>()),
    );
    await pumpEventQueue();
    modal.sessionTopic = 'replacement-topic';
    modal.changed();
    await pending;
    expect(connection.isCurrent, false);
    modal.gate!.complete();
    await pumpEventQueue();
  });

  test('an SDK launch failure cancels its watchdog before a later retry', () {
    fakeAsync((time) {
      modal.gate = Completer<void>();
      connection.signPersonalMessage('first').then<void>((_) {}, onError: (Object _) {});
      time.flushMicrotasks();
      modal.onModalError.broadcast(ErrorOpeningWallet());
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 61));
      time.flushMicrotasks();
      expect(connection.isCurrent, true);
      expect(connection.needsReconnect, false);
      modal.gate!.complete();
      time.flushMicrotasks();
      modal.gate = null;
      var signatures = 0;
      connection.signPersonalMessage('retry').then((_) {
        signatures++;
      });
      time.flushMicrotasks();
      expect(signatures, 1);
      expect(modal.requests, hasLength(2));
    });
  });

  test('account change during relay preparation never opens a signing request', () async {
    modal.relayGate = Completer<void>();
    final first = expectLater(
      connection.signPersonalMessage('first'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    await pumpEventQueue();
    modal.address = '0x${'3' * 40}';
    modal.changed();
    modal.relayGate!.complete();
    await first;
    expect(modal.requests, isEmpty);
  });
}
