import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/data/wallet_configuration.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

void main() {
  late _Modal modal;
  late ReownWalletConnector connector;
  late BuildContext host;

  setUp(() {
    modal = _Modal();
    connector = ReownWalletConnector(
      const WalletConfiguration(projectId: 'test'),
      createModal: (_) => modal,
      preparationTimeout: const Duration(seconds: 1),
    );
  });

  tearDown(() async {
    if (modal.initGate case final gate? when !gate.isCompleted) gate.complete();
    await connector.dispose();
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

  testWidgets('missing, expired and different-address sessions cannot restore', (tester) async {
    await mount(tester);
    expect(await connector.restore(host, expectedAddress: modal.address), isNull);
    modal.isConnected = true;
    expect(await connector.restore(host, expectedAddress: '0x${'3' * 40}'), isNull);
    modal.expiry = 1;
    expect(await connector.restore(host, expectedAddress: modal.address), isNull);
    expect(modal.calls, ['init']);
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
    final disposal = connector.dispose();
    modal.initGate!.complete();
    modal.initGate = null;
    await pending;
    await disposal;
    expect(modal.calls, ['init']);
  });
}

class _Modal extends ChangeNotifier implements ReownAppKitModal {
  final calls = <String>[];
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
