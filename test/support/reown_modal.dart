import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:reown_appkit/reown_appkit.dart';
// AppKit exposes the relay client type only through reown_core.
// ignore: depend_on_referenced_packages, implementation_imports
import 'package:reown_core/relay_client/i_relay_client.dart';

import 'wallet_connection.dart';

class TestReownModal extends ChangeNotifier implements ReownAppKitModal {
  @override
  late final IReownAppKit appKit = TestReownAppKit();
  TestReownAppKit get sdk => appKit as TestReownAppKit;
  String walletName = 'MetaMask';
  @override
  final onModalError = Event<ModalError>();
  int relayReconnects = 0;
  Completer<void>? relayGate;
  Object? relayFailure;
  @override
  Future<void> reconnectRelay() async {
    relayReconnects++;
    await relayGate?.future;
    if (relayFailure case final error?) throw error;
  }

  List<String> methods = [
    'eth_sendTransaction',
    'personal_sign',
    'eth_signTypedData_v4',
    'wallet_switchEthereumChain',
    'wallet_addEthereumChain',
  ];
  String selectedChainId = '56';
  List<String>? approvedAccounts;
  final requests = <SessionRequestParams>[];
  Future<Object?> Function(SessionRequestParams)? onRequest;
  String approvedChain = '56';
  bool get observesSession => hasListeners;
  @override
  Future<void> dispose() async => super.dispose();
  String address = '0x2222222222222222222222222222222222222222';
  int expiry = 9999999999;
  String sessionTopic = 'topic';
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
  ReownAppKitModalSession get session => ReownAppKitModalSession(
    sessionData: SessionData(
      topic: sessionTopic,
      pairingTopic: 'pairing',
      relay: Relay('irn'),
      expiry: expiry,
      acknowledged: true,
      controller: 'key',
      self: metadata,
      peer: ConnectionMetadata(
        publicKey: 'wallet-key',
        metadata: PairingMetadata(
          name: walletName,
          description: 'Connected wallet',
          url: 'https://example.com/wallet',
          icons: [],
        ),
      ),
      namespaces: {
        'eip155': Namespace(
          accounts: approvedAccounts ?? ['eip155:$approvedChain:$address'],
          methods: methods,
          events: [],
        ),
      },
    ),
  );
  @override
  bool isConnected = true;
  @override
  ReownAppKitModalNetworkInfo? get selectedChain =>
      ReownAppKitModalNetworks.getNetworkInfo('eip155', selectedChainId);
  @override
  Future<void> selectChain(
    ReownAppKitModalNetworkInfo? chainInfo, {
    bool switchChain = false,
    bool logEvent = true,
  }) async {
    selectedChainId = chainInfo!.chainId.split(':').last;
    changed();
  }

  SessionRequestParams? requested;
  String? topic, chain;
  String result = TestWalletConnection.signature;
  Object? failure;
  Completer<void>? gate;
  int disconnections = 0;
  void changed() => notifyListeners();
  @override
  Future<dynamic> request({
    required String? topic,
    required String chainId,
    String? switchToChainId,
    required SessionRequestParams request,
  }) async {
    this.topic = topic;
    chain = chainId;
    requested = request;
    requests.add(request);
    await gate?.future;
    if (failure case final error?) throw error;
    if (onRequest case final handler?) return handler(request);
    return result;
  }

  @override
  Future<void> disconnect({bool disconnectAllSessions = true}) async {
    disconnections++;
    isConnected = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestReownAppKit implements IReownAppKit {
  @override
  final IReownCore core = TestReownCore();
  Event<ErrorEvent> get relayErrors => core.relayClient.onRelayClientError;
  int pings = 0;
  String? pingTopic;
  Completer<void>? pingGate;
  Object? pingFailure;
  @override
  Future<void> ping({required String topic}) async {
    pings++;
    pingTopic = topic;
    await pingGate?.future;
    if (pingFailure case final failure?) throw failure;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestReownCore implements IReownCore {
  @override
  IRelayClient relayClient = TestRelayClient();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestRelayClient implements IRelayClient {
  @override
  final onRelayClientError = Event<ErrorEvent>();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
