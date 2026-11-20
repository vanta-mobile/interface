// Exercise the patched modal initialization with real SDK stores and events.
// ignore_for_file: depend_on_referenced_packages, implementation_imports

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:reown_appkit/modal/services/explorer_service/explorer_service.dart';
import 'package:reown_appkit/modal/services/explorer_service/i_explorer_service.dart';
import 'package:reown_appkit/modal/services/magic_service/i_magic_service.dart';
import 'package:reown_appkit/modal/services/magic_service/models/magic_events.dart';
import 'package:reown_core/crypto/i_crypto.dart';

import '../../support/reown_modal.dart';

void main() {
  late _LocalAppKit sdk;
  late _Catalog catalog;
  late ReownAppKitModal modal;

  Future<void> mount(WidgetTester tester) async {
    await GetIt.I.reset();
    sdk = _LocalAppKit();
    catalog = _Catalog(sdk.core);
    GetIt.I.registerSingleton<IExplorerService>(catalog);
    GetIt.I.registerSingleton<IMagicService>(_Magic());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (_) async => {
        'appName': 'Vanta test',
        'packageName': 'test.vanta',
        'version': '1',
        'buildNumber': '1',
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            modal = ReownAppKitModal(
              context: context,
              appKit: sdk,
              enableAnalytics: false,
              // Match the native adapter's compatibility flag in AppKit 1.9.
              // ignore: deprecated_member_use
              featuresConfig: FeaturesConfig(email: false, socials: const []),
              disconnectOnDispose: false,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    addTearDown(() async {
      await sdk.core.relayClient.disconnect();
      sdk.core.heartbeat.stop();
      await GetIt.I.reset();
    });
  }

  testWidgets('real modal finishes restore offline without loading the wallet catalog', (
    tester,
  ) async {
    await mount(tester);
    await modal.init(restoreOnly: true);
    expect(modal.status, ReownAppKitModalStatus.initialized);
    expect(sdk.core.relayClient.isConnected, false);
    expect(catalog.calls, 0);
    expect(sdk.calls, 1);
    await tester.runAsync(modal.dispose);
  });

  testWidgets('real modal shares an in-flight restore and retries failed initialization', (
    tester,
  ) async {
    await mount(tester);
    sdk.gate = Completer<void>();
    sdk.failure = StateError('Storage temporarily unavailable');
    final first = expectLater(modal.init(restoreOnly: true), throwsStateError);
    final second = expectLater(modal.init(restoreOnly: true), throwsStateError);
    expect(sdk.calls, 1);
    sdk.gate!.complete();
    await first;
    await second;
    expect(modal.status, ReownAppKitModalStatus.error);
    sdk.failure = null;
    await modal.init(restoreOnly: true);
    expect(modal.status, ReownAppKitModalStatus.initialized);
    expect(sdk.calls, 2);
    expect(catalog.calls, 0);
    expect(sdk.core.relayClient.onRelayClientConnect.subscriberCount, 1);
    await tester.runAsync(modal.dispose);
  });

  testWidgets('wallet catalog failures can retry after a completed local restore', (tester) async {
    await mount(tester);
    await modal.init(restoreOnly: true);
    for (var attempt = 1; attempt <= 2; attempt++) {
      await expectLater(modal.init(), throwsStateError);
      expect(catalog.calls, attempt);
      expect(modal.status, ReownAppKitModalStatus.initialized);
      expect(sdk.calls, 1);
    }
    await tester.runAsync(modal.dispose);
  });
}

class _Catalog extends ExplorerService {
  _Catalog(IReownCore core) : super(core: core, referer: 'Vanta');
  int calls = 0;
  @override
  Future<void> init() async {
    calls++;
    throw StateError('Restoration must not load the wallet catalog');
  }
}

class _LocalAppKit extends ReownAppKit {
  _LocalAppKit()
    : super(
        core: ReownCore(projectId: '11111111111111111111111111111111', memoryStore: true),
        metadata: const PairingMetadata(
          name: 'Vanta test',
          description: 'Test',
          url: 'https://example.com',
          icons: [],
        ),
      ) {
    core.crypto = _Crypto();
    core.relayClient = TestRelayClient()..isConnected = false;
  }
  int calls = 0;
  Completer<void>? gate;
  Object? failure;
  @override
  void registerEventHandler({
    required String chainId,
    required String event,
    void Function(String, dynamic)? handler,
  }) {}
  @override
  Future<void> init() async {
    calls++;
    await gate?.future;
    if (failure case final error?) throw error;
    await core.storage.init();
    await pairings.init();
    await sessions.init();
  }
}

class _Crypto implements ICrypto {
  @override
  Future<String> getClientId() async => 'fixture-client';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Magic implements IMagicService {
  @override
  final onMagicConnect = Event<MagicConnectEvent>();
  @override
  final onMagicLoginSuccess = Event<MagicLoginEvent>();
  @override
  final onMagicError = Event<MagicErrorEvent>();
  @override
  final onMagicUpdate = Event<MagicSessionEvent>();
  @override
  final onMagicRpcRequest = Event<MagicRequestEvent>();
  @override
  Future<void> init({String? chainId}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
