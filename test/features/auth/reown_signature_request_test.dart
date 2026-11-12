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
      expect(failure?.key, 'authWalletUnavailable');
      expect(connection.needsReconnect, false);
      modal.relayGate!.complete();
      time.flushMicrotasks();
      expect(modal.requests, isEmpty);
      expect(modal.sdk.pings, 0);
    });
  });

  test('an orphaned peer session settles the signature as soon as its ping fails', () async {
    modal.gate = Completer<void>();
    modal.sdk.pingFailure = JsonRpcError(code: 7001, message: 'Session not found');
    await expectLater(
      connection.signPersonalMessage('first'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletSessionUnverified')),
    );
    expect(modal.isConnected, true);
    expect(connection.isCurrent, false);
    expect(connection.needsReconnect, true);
    expect(modal.sdk.pings, 1);
    expect(modal.requests, hasLength(1));
    modal.gate!.complete();
    await pumpEventQueue();
  });

  test('a wallet that never opens and never answers fails within the probe window', () {
    fakeAsync((time) {
      modal.gate = Completer<void>();
      modal.sdk.pingGate = Completer<void>();
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
      expect(modal.requests, hasLength(1));
      time.elapse(const Duration(seconds: 9));
      time.flushMicrotasks();
      expect(failure, isNull);
      time.elapse(const Duration(seconds: 1));
      time.flushMicrotasks();
      expect(failure?.key, 'authWalletSessionUnverified');
      expect(connection.needsReconnect, true);
      modal.sdk.pingGate!.complete();
      modal.gate!.complete();
      time.flushMicrotasks();
    });
  });

  test('time spent in the wallet never counts toward the probe window', () {
    fakeAsync((time) {
      final binding = TestWidgetsFlutterBinding.instance;
      modal.gate = Completer<void>();
      modal.sdk.pingGate = Completer<void>();
      String? signature;
      connection.signPersonalMessage('first').then((value) => signature = value);
      time.flushMicrotasks();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      time.elapse(const Duration(seconds: 30));
      time.flushMicrotasks();
      // The wallet came to the foreground and answered the queued ping.
      modal.sdk.pingGate!.complete();
      time.flushMicrotasks();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      time.flushMicrotasks();
      expect(modal.relayReconnects, 2);
      time.elapse(const Duration(seconds: 20));
      time.flushMicrotasks();
      expect(connection.needsReconnect, false);
      modal.gate!.complete();
      time.flushMicrotasks();
      expect(signature, modal.result);
    });
  });

  test('returning from the wallet without a peer answer fails within the probe window', () {
    fakeAsync((time) {
      final binding = TestWidgetsFlutterBinding.instance;
      modal.gate = Completer<void>();
      modal.sdk.pingGate = Completer<void>();
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
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      time.elapse(const Duration(seconds: 30));
      time.flushMicrotasks();
      expect(failure, isNull);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      time.elapse(const Duration(seconds: 10));
      time.flushMicrotasks();
      expect(failure?.key, 'authWalletSessionUnverified');
      expect(connection.needsReconnect, true);
      modal.sdk.pingGate!.complete();
      modal.gate!.complete();
      time.flushMicrotasks();
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

  test('a live wallet that never signs times out without requiring reconnect', () {
    fakeAsync((time) {
      modal.gate = Completer<void>();
      AuthFailure? failure;
      var signatures = 0;
      connection
          .signPersonalMessage('first')
          .then<void>(
            (_) {
              signatures++;
            },
            onError: (Object error) {
              failure = error as AuthFailure;
            },
          );
      time.flushMicrotasks();
      expect(modal.requests, hasLength(1));
      time.elapse(const Duration(seconds: 60));
      time.flushMicrotasks();
      expect(failure?.key, 'authWalletResponseTimeout');
      expect(connection.needsReconnect, false);
      modal.gate!.complete();
      time.flushMicrotasks();
      expect(signatures, 0);
      expect(modal.requests, hasLength(1));
    });
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

  test('resume never pings an idle connection', () async {
    modal.sdk.pingFailure = StateError('Session missing');
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(modal.sdk.pings, 0);
    expect(connection.needsReconnect, false);
    expect(connection.isCurrent, true);
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
