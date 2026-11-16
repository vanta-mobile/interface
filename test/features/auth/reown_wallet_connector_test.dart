import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/data/wallet_configuration.dart';
import 'package:vanta/features/auth/data/wallet_redirect_handler.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

import '../../support/reown_modal.dart';
import 'reown_connector_fixture.dart';

void main() {
  late ConnectorTestModal modal;
  late ReownWalletConnector connector;
  late BuildContext host;
  late StreamController<Uri> links;

  setUp(() {
    modal = ConnectorTestModal();
    links = StreamController<Uri>(sync: true);
    connector = ReownWalletConnector(
      const WalletConfiguration(projectId: 'test'),
      createModal: (_) => modal,
      preparationTimeout: const Duration(seconds: 1),
      redirects: WalletRedirectHandler(links: links.stream, initialLink: () async => null),
    );
  });

  tearDown(() async {
    if (modal.initGate case final gate? when !gate.isCompleted) gate.complete();
    await connector.dispose();
    await links.close();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            modal.host = context;
            return const SizedBox();
          },
        ),
      ),
    );
  }

  testWidgets('stored session requires fresh wallet approval before returning a signer', (
    tester,
  ) async {
    await mount(tester);
    modal.isConnected = true;
    modal.openGate = Completer<void>();
    final pending = connector.connect(host);
    await tester.pump();
    expect(modal.calls, ['init', 'disconnect', 'open']);
    expect(modal.disconnectAll, false);
    expect(modal.isConnected, false);
    modal.approve();
    final connection = await pending;
    expect(connection.isCurrent, true);
    expect(connection.address, modal.address);
    await connection.release();
  });

  testWidgets('cancelled reconnect can retry without reinitializing the SDK', (tester) async {
    await mount(tester);
    modal.cancel = true;
    await expectLater(
      connector.connect(host),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletCancelled')),
    );
    modal.cancel = false;
    final connection = await connector.connect(host);
    expect(modal.calls, ['init', 'open', 'open']);
    await connection.release();
  });

  testWidgets('restores an approved session without disconnecting or opening wallet UI', (
    tester,
  ) async {
    await mount(tester);
    modal.isConnected = true;
    final connection = await connector.restore(host, expectedAddress: modal.address);
    expect(connection?.isCurrent, true);
    expect(modal.calls, ['init']);
    expect(modal.appKit.pings, 0);
    var invalidations = 0;
    final subscription = connection!.invalidations.listen((_) => invalidations++);
    modal.finishDisconnect();
    await tester.pump();
    expect(connection.isCurrent, false);
    expect(invalidations, 1);
    addTearDown(() async {
      await subscription.cancel();
      await connection.release();
    });
  });

  testWidgets('restore skips the remote catalog and explicit connection prepares it', (
    tester,
  ) async {
    await mount(tester);
    modal.isConnected = true;
    modal.catalogGate = Completer<void>();
    final restored = await connector.restore(host, expectedAddress: modal.address);
    expect(restored?.isCurrent, true);
    expect(modal.initializationModes, [true]);
    final pending = connector.connect(host);
    await tester.pump();
    expect(modal.initializationModes, [true, false]);
    expect(modal.calls, ['init']);
    modal.catalogGate!.complete();
    final fresh = await pending;
    expect(modal.calls, ['init', 'disconnect', 'open']);
    await restored!.release();
    await fresh.release();
  });

  testWidgets('a sleeping wallet peer never blocks or downgrades session restore', (tester) async {
    await mount(tester);
    modal.isConnected = true;
    // Mobile wallets cannot answer pings while backgrounded. Restoring must not
    // treat that silence as a disconnect; signing verifies the peer instead.
    modal.appKit.pingGate = Completer<void>();
    modal.appKit.pingFailure = JsonRpcError(code: 7001, message: 'Session not found');
    final connection = await connector.restore(host, expectedAddress: modal.address);
    expect(connection?.isCurrent, true);
    expect(modal.appKit.pings, 0);
    expect(modal.calls, ['init']);
    await connection!.release();
  });

  testWidgets('restoration cannot resurrect a session that just failed its peer check', (
    tester,
  ) async {
    await mount(tester);
    modal.isConnected = true;
    final connection = await connector.restore(host, expectedAddress: modal.address);
    modal.requestGate = Completer<dynamic>();
    modal.appKit.pingFailure = JsonRpcError(code: 7001, message: 'Session not found');
    await expectLater(
      connection!.signPersonalMessage('Sign in'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletSessionUnverified')),
    );
    await expectLater(
      connector.restore(host, expectedAddress: modal.address),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletSessionUnverified')),
    );
    expect(modal.calls.where((call) => call == 'open'), isEmpty);
    await connection.release();
    final oldRequest = modal.requestGate!;
    modal.requestGate = null;
    modal.appKit.pingFailure = null;
    final fresh = await connector.connect(host);
    expect(await fresh.signPersonalMessage('Sign in'), '0x${'1' * 130}');
    expect(modal.calls.where((call) => call == 'open'), hasLength(1));
    oldRequest.complete('0x${'1' * 130}');
    await fresh.release();
  });

  testWidgets('missing, expired and different-address sessions cannot restore', (tester) async {
    await mount(tester);
    expect(await connector.restore(host, expectedAddress: modal.address), isNull);
    modal.isConnected = true;
    expect(await connector.restore(host, expectedAddress: '0x${'3' * 40}'), isNull);
    modal.expiry = 1;
    expect(await connector.restore(host, expectedAddress: modal.address), isNull);
    expect(modal.calls, ['init']);
  });

  testWidgets('wallet return received during init is delivered only after SDK is ready', (
    tester,
  ) async {
    await mount(tester);
    modal.isConnected = true;
    modal.initGate = Completer<void>();
    final pending = connector.restore(host, expectedAddress: modal.address);
    await tester.pump();
    expect(links.hasListener, isTrue);
    final response = Uri.parse('vantaapp://wallet?topic=topic&wc_ev=encrypted');
    links.add(response);
    expect(modal.envelopes, isEmpty);
    modal.initGate!.complete();
    final connection = await pending;
    await tester.pump();
    expect(modal.envelopes, [response.toString()]);
    expect(modal.calls, ['init']);
    await connection!.release();
  });

  testWidgets('resume retries an unconsumed return and dispose stops link delivery', (
    tester,
  ) async {
    await mount(tester);
    modal.isConnected = true;
    final connection = await connector.restore(host, expectedAddress: modal.address);
    modal.acceptEnvelope = false;
    final response = Uri.parse('vantaapp://wallet?topic=topic&wc_ev=encrypted');
    links.add(response);
    await tester.pump();
    expect(modal.envelopes, hasLength(1));
    modal.acceptEnvelope = true;
    connector.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(modal.envelopes, hasLength(2));
    await connection!.release();
    await tester.runAsync(connector.dispose);
    expect(links.hasListener, isFalse);
    links.add(Uri.parse('vantaapp://wallet?topic=topic&wc_ev=late'));
    await tester.pump();
    expect(modal.envelopes, hasLength(2));
  });

  testWidgets('connection cleanup event settles before wallet selection opens', (tester) async {
    await mount(tester);
    modal.isConnected = true;
    modal.deferDisconnect = true;
    final pending = connector.connect(host);
    await tester.pump();
    expect(modal.calls, ['init', 'disconnect']);
    modal.finishDisconnect();
    final connection = await pending;
    expect(modal.calls, ['init', 'disconnect', 'open']);
    await connection.release();
  });

  testWidgets('setup timeout does not open late UI or overlap SDK initialization', (tester) async {
    await mount(tester);
    modal.initGate = Completer<void>();
    Future<void> expectTimeout(Future<Object?> pending) => expectLater(
      pending,
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletConnectionTimeout')),
    );
    final first = expectTimeout(connector.connect(host));
    await tester.pump(const Duration(seconds: 2));
    await first;
    expect((modal.appKit.core.relayClient as TestRelayClient).disconnects, 1);
    final second = expectTimeout(connector.connect(host));
    await tester.pump(const Duration(seconds: 2));
    await second;
    expect(modal.calls, ['init']);
    modal.initGate!.complete();
    modal.initGate = null;
    await tester.pump();
    expect(modal.calls, ['init']);
    final connection = await connector.connect(host);
    expect(modal.calls, ['init', 'open']);
    await connection.release();
  });

  testWidgets('preparation relay failure retains its cause and settles before the watchdog', (
    tester,
  ) async {
    await mount(tester);
    modal.initGate = Completer<void>();
    final pending = expectLater(
      connector.restore(host, expectedAddress: modal.address),
      throwsA(isA<AuthFailure>().having((e) => e.reason, 'reason', 'Relay handshake refused')),
    );
    await tester.pump();
    final relay = modal.appKit.core.relayClient as TestRelayClient;
    relay.onRelayClientError.broadcast(ErrorEvent('Relay handshake refused'));
    await tester.pump();
    await pending;
    expect(relay.disconnects, 1);
    expect(relay.onRelayClientError.subscriberCount, 0);
    expect(modal.calls, ['init']);
    modal.initGate!.complete();
    await tester.pump();
    expect(modal.calls, ['init']);
  });

  testWidgets('explicit retry after a timed-out restore runs fresh connection preparation', (
    tester,
  ) async {
    await mount(tester);
    modal.isConnected = true;
    modal.initGate = Completer<void>();
    final expired = expectLater(
      connector.restore(host, expectedAddress: modal.address),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletConnectionTimeout')),
    );
    await tester.pump(const Duration(seconds: 2));
    await expired;
    final pending = connector.connect(host);
    await tester.pump();
    expect(modal.calls, ['init']);
    modal.initGate!.complete();
    final fresh = await pending;
    expect(modal.initializationModes, [true, false]);
    expect(modal.calls, ['init', 'disconnect', 'open']);
    await fresh.release();
  });

  testWidgets('disposal during setup never opens a wallet prompt', (tester) async {
    await mount(tester);
    modal.initGate = Completer<void>();
    final pending = expectLater(
      connector.connect(host),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletCancelled')),
    );
    await tester.pump();
    final disposal = tester.runAsync(connector.dispose);
    modal.initGate!.complete();
    modal.initGate = null;
    await pending;
    await disposal;
    expect(modal.calls, ['init']);
  });
}
