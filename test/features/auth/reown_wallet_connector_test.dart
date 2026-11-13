import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/data/wallet_configuration.dart';
import 'package:vanta/features/auth/data/wallet_redirect_handler.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

import '../../support/reown_modal.dart';

void main() {
  late _Modal modal;
  late ReownWalletConnector connector;
  late BuildContext host;
  late StreamController<Uri> links;

  setUp(() {
    modal = _Modal();
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

class _Modal extends ChangeNotifier implements ReownAppKitModal {
  @override
  final TestReownAppKit appKit = TestReownAppKit();
  bool get observesSession => hasListeners;
  @override
  Future<void> reconnectRelay() async {
    calls.add('relay');
  }

  final calls = <String>[];
  final envelopes = <String>[];
  bool acceptEnvelope = true;
  final address = '0x2222222222222222222222222222222222222222';
  int expiry = 9999999999;
  BuildContext? host;
  Completer<void>? initGate, openGate;
  bool cancel = false, deferDisconnect = false;
  bool? disconnectAll;
  @override
  bool isConnected = false;
  @override
  bool isOpen = false;
  @override
  ReownAppKitModalStatus status = ReownAppKitModalStatus.idle;
  @override
  BuildContext? get modalContext => host;
  @override
  Future<void> init() async {
    calls.add('init');
    await initGate?.future;
    status = ReownAppKitModalStatus.initialized;
  }

  @override
  Future<bool> dispatchEnvelope(String url) async {
    expect(status, ReownAppKitModalStatus.initialized);
    envelopes.add(url);
    return acceptEnvelope;
  }

  @override
  Future<void> disconnect({bool disconnectAllSessions = true}) async {
    disconnectAll = disconnectAllSessions;
    calls.add('disconnect');
    status = ReownAppKitModalStatus.initializing;
    if (!deferDisconnect) finishDisconnect();
  }

  void finishDisconnect() {
    isConnected = false;
    status = ReownAppKitModalStatus.initialized;
    notifyListeners();
  }

  @override
  Future<void> openModalView([Widget? startWidget]) async {
    calls.add('open');
    isOpen = true;
    await openGate?.future;
    isOpen = false;
    isConnected = !cancel;
  }

  void approve() => openGate!.complete();

  @override
  ReownAppKitModalSession? get session => isConnected
      ? ReownAppKitModalSession(
          sessionData: SessionData(
            topic: 'topic',
            pairingTopic: 'pairing',
            relay: Relay('irn'),
            expiry: expiry,
            acknowledged: true,
            controller: 'key',
            self: metadata,
            peer: metadata,
            namespaces: {
              'eip155': Namespace(
                accounts: ['eip155:56:$address'],
                methods: ['personal_sign', 'eth_signTypedData_v4'],
                events: [],
              ),
            },
          ),
        )
      : null;
  static const metadata = ConnectionMetadata(
    publicKey: 'key',
    metadata: PairingMetadata(
      name: 'test',
      description: 'test',
      url: 'https://example.com',
      icons: [],
    ),
  );
  @override
  ReownAppKitModalNetworkInfo? get selectedChain => const ReownAppKitModalNetworkInfo(
    name: 'BNB Chain',
    chainId: 'eip155:56',
    currency: 'BNB',
    rpcUrl: 'https://example.com',
    explorerUrl: 'https://example.com',
  );
  bool disposed = false;
  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
