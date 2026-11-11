import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../../../core/network/request_scope.dart';
import '../domain/auth_session.dart';
import '../domain/wallet_connection.dart';
import '../domain/wallet_transaction.dart';
import '../domain/wallet_signing_preparation.dart';
import 'evm_account_address.dart';
import 'wallet_transaction_dispatch.dart';
import 'wallet_configuration.dart';
import 'reown_auth_failure.dart';
import 'reown_signing_network.dart';
import 'wallet_redirect_handler.dart';

part 'reown_wallet_connection.dart';

abstract interface class WalletConnector {
  Future<WalletConnection> connect(BuildContext context);
  Future<void> dispose();
}

abstract interface class WalletSessionRestorer {
  Future<WalletConnection?> restore(BuildContext context, {required String expectedAddress});
}

typedef WalletModalFactory = ReownAppKitModal Function(BuildContext context);

/// BuildContext is used only to host the SDK's native wallet-selection UI.
/// SDK clients, sessions, and signature payloads stay behind this adapter.
class ReownWalletConnector
    with WidgetsBindingObserver
    implements WalletConnector, WalletSessionRestorer {
  ReownWalletConnector(
    this.configuration, {
    this.createModal,
    this.preparationTimeout = const Duration(seconds: 20),
    WalletRedirectHandler? redirects,
  }) : _redirects = redirects ?? WalletRedirectHandler();
  final WalletConfiguration configuration;
  final WalletModalFactory? createModal;
  final Duration preparationTimeout;
  ReownAppKitModal? _modal;
  Future<void>? _preparation;
  Future<WalletConnection>? _pending;
  bool _disposed = false;
  final WalletRedirectHandler _redirects;
  bool _observing = false;

  ReownAppKitModal _getModal(BuildContext host) {
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
      _redirects.start();
    }
    return _modal ??= createModal?.call(host) ?? _createModal(host);
  }

  void _acceptRedirects(ReownAppKitModal modal) {
    if (_disposed || !identical(_modal, modal)) return;
    _redirects.attach(modal.dispatchEnvelope);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_disposed && state == AppLifecycleState.resumed) _redirects.retry();
  }

  @override
  Future<WalletConnection?> restore(BuildContext context, {required String expectedAddress}) =>
      _sdkCall(() async {
        if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
        if (!configuration.isConfigured) throw const AuthFailure('authWalletConfiguration');
        final host = Navigator.of(context).context;
        final modal = _getModal(host);
        final preparation = _preparation ??= _sdkCall(() async {
          if (modal.status != ReownAppKitModalStatus.initialized) await modal.init();
        }).whenComplete(() => _preparation = null);
        await preparation.timeout(
          preparationTimeout,
          onTimeout: () => throw const AuthFailure('authWalletConnectionTimeout'),
        );
        if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
        _acceptRedirects(modal);
        final session = modal.session;
        final address = canonicalEvmAddress(session?.getAddress('eip155') ?? '');
        final chain = modal.selectedChain?.chainId;
        final expiry = session?.expiry;
        if (!modal.isConnected ||
            address == null ||
            address.toLowerCase() != expectedAddress.toLowerCase() ||
            chain == null ||
            !chain.startsWith('eip155:') ||
            !WalletConfiguration.chains.contains(chain.substring(7)) ||
            expiry == null ||
            expiry <= DateTime.now().millisecondsSinceEpoch ~/ 1000) {
          return null;
        }
        return ReownWalletConnection(modal, address, chain.substring(7));
      });

  @override
  Future<WalletConnection> connect(BuildContext context) => _pending ??= _sdkCall(() async {
    if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
    if (!configuration.isConfigured) throw const AuthFailure('authWalletConfiguration');
    final previous = _modal;
    if (previous != null && previous.modalContext == null) {
      await _preparation?.timeout(
        preparationTimeout,
        onTimeout: () => throw const AuthFailure('authWalletConnectionTimeout'),
      );
      _redirects.detach();
      await previous.dispose();
      _modal = null;
    }
    if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
    // Keep the host alive after the account sheet closes, so subsequent
    // signatures can still launch the connected wallet app.
    final host = Navigator.of(context).context;
    final modal = _getModal(host);
    // A stored WalletConnect session is not proof that its peer can still
    // sign. An explicit connect/reconnect must offer fresh wallet approval.
    // Keep preparation separate from the modal: timing out must never open
    // wallet UI later or run another SDK initialization concurrently.
    final preparation = _preparation ??= _sdkCall(() => _prepare(modal))
        .whenComplete(() => _preparation = null);
    await preparation.timeout(
      preparationTimeout,
      onTimeout: () => throw const AuthFailure('authWalletConnectionTimeout'),
    );
    if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
    if (modal.status != ReownAppKitModalStatus.initialized || modal.isConnected || modal.isOpen) {
      throw const AuthFailure('authWalletUnavailable');
    }
    await modal.openModalView();
    if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
    final sessionAddress = modal.session?.getAddress('eip155');
    final chain = modal.selectedChain?.chainId;
    if (!modal.isConnected || sessionAddress == null || chain == null) {
      throw const AuthFailure('authWalletCancelled');
    }
    final address = canonicalEvmAddress(sessionAddress);
    if (!chain.startsWith('eip155:') ||
        !WalletConfiguration.chains.contains(chain.substring(7)) ||
        address == null) {
      throw const AuthFailure('authWalletUnsupported');
    }
    return ReownWalletConnection(modal, address, chain.substring(7));
  }).whenComplete(() => _pending = null);

  Future<void> _prepare(ReownAppKitModal modal) async {
    if (modal.status != ReownAppKitModalStatus.initialized) await modal.init();
    _acceptRedirects(modal);
    if (_disposed || !modal.isConnected) return;
    final disconnected = Completer<void>();
    void check() {
      if (!modal.isConnected &&
          modal.status == ReownAppKitModalStatus.initialized &&
          !disconnected.isCompleted) {
        disconnected.complete();
      }
    }

    modal.addListener(check);
    try {
      await modal.disconnect(disconnectAllSessions: false);
      check();
      // Reown finishes local cleanup in an asynchronous session-delete event.
      await disconnected.future.timeout(
        preparationTimeout,
        onTimeout: () => throw const AuthFailure('authWalletConnectionTimeout'),
      );
    } finally {
      modal.removeListener(check);
    }
  }

  ReownAppKitModal _createModal(BuildContext context) => ReownAppKitModal(
    context: context,
    projectId: configuration.projectId.trim(),
    metadata: PairingMetadata(
      name: 'Vanta',
      description: 'Vanta wallet connection',
      url: configuration.relyingParty!.toString(),
      redirect: Redirect(native: WalletConfiguration.redirect),
    ),
    optionalNamespaces: {
      'eip155': RequiredNamespace(
        chains: WalletConfiguration.chains.map((chain) => 'eip155:$chain').toList(),
        methods: const ['personal_sign', 'eth_signTypedData_v4', 'eth_sendTransaction'],
        events: const ['accountsChanged', 'chainChanged'],
      ),
    },
    // Reown 1.9 still reads this deprecated flag when building its login UI.
    // ignore: deprecated_member_use
    featuresConfig: FeaturesConfig(email: false, socials: const [], showMainWallets: true),
    enableAnalytics: false,
    logLevel: LogLevel.nothing,
    disconnectOnDispose: false,
  );

  @override
  Future<void> dispose() async {
    _disposed = true;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    await _redirects.close();
    final modal = _modal;
    _modal = null;
    try {
      final preparation = _preparation;
      if (preparation != null) await preparation;
    } catch (_) {
      // Preparation failures belong to the connect operation.
    }
    if (modal != null) await _sdkCall(modal.dispose);
  }
}

/// Reown has async-void modal callbacks; contain their errors inside this
/// operation while forwarding errors that arrive after completion.
Future<T> _sdkCall<T>(Future<T> Function() operation) {
  final result = Completer<T>();
  final parent = Zone.current;
  void fail(Object error, StackTrace stack) {
    if (result.isCompleted) {
      parent.handleUncaughtError(error, stack);
      return;
    }
    result.completeError(failureFromReown(error), stack);
  }

  runZonedGuarded(() async {
    try {
      final value = await operation();
      if (!result.isCompleted) result.complete(value);
    } catch (error, stack) {
      if (!result.isCompleted) fail(error, stack);
    }
  }, fail);
  return result.future;
}
