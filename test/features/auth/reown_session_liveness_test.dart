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

  test('an orphaned peer session settles the signature as soon as its ping fails', () async {
    modal.gate = Completer<void>();
    modal.sdk.pingFailure = JsonRpcError(code: 7001, message: 'Session not found');
    await expectLater(
      connection.signPersonalMessage('first'),
      throwsA(
        isA<AuthFailure>()
            .having((e) => e.key, 'key', 'authWalletSessionUnverified')
            .having((e) => e.reason, 'reason', 'Session not found'),
      ),
    );
    expect(modal.isConnected, true);
    expect(connection.isCurrent, false);
    expect(connection.needsReconnect, true);
    expect(modal.sdk.pings, 1);
    expect(modal.requests, hasLength(1));
    modal.gate!.complete();
    await pumpEventQueue();
  });

  test('MetaMask Invalid Id for an unknown session topic requires reconnection', () async {
    // MetaMask answers pings at SDK level even after its manager dropped the topic.
    modal.failure = JsonRpcError(code: 1, message: 'Invalid Id');
    await expectLater(
      connection.signTypedData({'types': {}}),
      throwsA(
        isA<AuthFailure>()
            .having((e) => e.key, 'key', 'authWalletSessionUnverified')
            .having((e) => e.reason, 'reason', 'Invalid Id'),
      ),
    );
    expect(connection.isCurrent, false);
    expect(connection.needsReconnect, true);
    expect(modal.requests, hasLength(1));
  });

  test('other wallet JSON-RPC errors keep the session', () async {
    modal.failure = JsonRpcError(code: -32602, message: 'Invalid parameters');
    await expectLater(
      connection.signTypedData({'types': {}}),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletUnavailable')),
    );
    expect(connection.isCurrent, true);
    expect(connection.needsReconnect, false);
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
      expect(modal.relayReconnects, 1);
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

  test('a cancel made in the wallet after 60 s wins over the timeout on return', () {
    fakeAsync((time) {
      final binding = TestWidgetsFlutterBinding.instance;
      modal.gate = Completer<void>();
      AuthFailure? failure;
      connection
          .signPersonalMessage('first')
          .then<void>((_) {}, onError: (Object error) => failure = error as AuthFailure);
      time.flushMicrotasks();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      time.elapse(const Duration(seconds: 90));
      time.flushMicrotasks();
      expect(failure, isNull);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      time.elapse(const Duration(seconds: 2));
      modal.onModalError.broadcast(UserRejectedRequest());
      time.flushMicrotasks();
      expect(failure?.key, 'authWalletRejected');
      time.elapse(const Duration(seconds: 20));
      time.flushMicrotasks();
      expect(failure?.key, 'authWalletRejected');
      modal.gate!.complete();
      time.flushMicrotasks();
    });
  });

  test('a signature returned after 60 s in the wallet still completes', () {
    fakeAsync((time) {
      final binding = TestWidgetsFlutterBinding.instance;
      modal.gate = Completer<void>();
      String? signature;
      Object? error;
      connection
          .signPersonalMessage('first')
          .then(
            (value) => signature = value,
            onError: (Object e) {
              error = e;
              return '';
            },
          );
      time.flushMicrotasks();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      time.elapse(const Duration(seconds: 90));
      time.flushMicrotasks();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      time.elapse(const Duration(seconds: 3));
      modal.gate!.complete();
      time.flushMicrotasks();
      expect(error, isNull);
      expect(signature, modal.result);
    });
  });

  test('back from the wallet after 60 s with no answer, the timeout follows', () {
    fakeAsync((time) {
      final binding = TestWidgetsFlutterBinding.instance;
      modal.gate = Completer<void>();
      AuthFailure? failure;
      connection
          .signPersonalMessage('first')
          .then<void>((_) {}, onError: (Object error) => failure = error as AuthFailure);
      time.flushMicrotasks();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      time.elapse(const Duration(seconds: 90));
      time.flushMicrotasks();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      time.elapse(const Duration(seconds: 9));
      time.flushMicrotasks();
      expect(failure, isNull);
      time.elapse(const Duration(seconds: 1));
      time.flushMicrotasks();
      expect(failure?.key, 'authWalletResponseTimeout');
      expect(connection.needsReconnect, false);
      modal.gate!.complete();
      time.flushMicrotasks();
    });
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

  test('a reconnect that remains offline never pings or dispatches a wallet request', () async {
    (modal.sdk.core.relayClient as TestRelayClient).isConnected = false;
    await expectLater(
      connection.signPersonalMessage('Sign in'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authNetwork')),
    );
    expect(modal.requests, isEmpty);
    expect(modal.sdk.pings, 0);
    expect(connection.needsReconnect, false);
  });

  test('a previous pong cannot hide a wallet session lost while in MetaMask', () async {
    modal.gate = Completer<void>();
    final pending = expectLater(
      connection.signPersonalMessage('Sign in'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletSessionUnverified')),
    );
    await pumpEventQueue();
    expect(modal.sdk.pings, 1);
    modal.sdk.pingFailure = JsonRpcError(code: 7001, message: 'Session not found');
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pending;
    expect(modal.sdk.pings, 2);
    expect(connection.needsReconnect, true);
    expect(modal.requests, hasLength(1));
    modal.gate!.complete();
    await pumpEventQueue();
  });

  test('relay recovery on resume probes the peer without another signature request', () async {
    modal.gate = Completer<void>();
    final pending = connection.signPersonalMessage('Sign in');
    await pumpEventQueue();
    final relay = modal.sdk.core.relayClient as TestRelayClient;
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    relay.isConnected = false;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(modal.sdk.pings, 1);
    relay.isConnected = true;
    relay.onRelayClientConnect.broadcast(EventArgs());
    await pumpEventQueue();
    expect(modal.sdk.pings, 2);
    expect(modal.requests, hasLength(1));
    modal.gate!.complete();
    expect(await pending, modal.result);
  });
}
