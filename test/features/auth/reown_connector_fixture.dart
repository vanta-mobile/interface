import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../../support/reown_modal.dart';

class ConnectorTestModal extends ChangeNotifier implements ReownAppKitModal {
  @override
  final onModalError = Event<ModalError>();
  @override
  final TestReownAppKit appKit = TestReownAppKit();
  bool get observesSession => hasListeners;
  @override
  Future<void> reconnectRelay() async {
    calls.add('relay');
  }

  final calls = <String>[];
  final envelopes = <String>[];
  Completer<dynamic>? requestGate;
  @override
  Future<dynamic> request({
    required String? topic,
    required String chainId,
    required SessionRequestParams request,
    String? switchToChainId,
  }) async {
    calls.add('request');
    return requestGate == null ? '0x${'1' * 130}' : requestGate!.future;
  }

  bool acceptEnvelope = true;
  final address = '0x2222222222222222222222222222222222222222';
  int expiry = 9999999999;
  BuildContext? host;
  Completer<void>? initGate, openGate, catalogGate;
  final initializationModes = <bool>[];
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
  Future<void> init({bool restoreOnly = false}) async {
    initializationModes.add(restoreOnly);
    if (status != ReownAppKitModalStatus.initialized) {
      calls.add('init');
      await initGate?.future;
      status = ReownAppKitModalStatus.initialized;
    }
    if (!restoreOnly) await catalogGate?.future;
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
