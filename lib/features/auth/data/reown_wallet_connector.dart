import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../domain/auth_session.dart';
import '../domain/wallet_connection.dart';
import '../domain/wallet_transaction.dart';
import '../domain/wallet_signing_preparation.dart';
import 'evm_account_address.dart';
import 'wallet_transaction_dispatch.dart';
import 'wallet_configuration.dart';
import 'reown_auth_failure.dart';
import 'reown_signing_network.dart';

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
class ReownWalletConnector implements WalletConnector, WalletSessionRestorer {
  ReownWalletConnector(
    this.configuration, {
    this.createModal,
    this.preparationTimeout = const Duration(seconds: 20),
  });
  final WalletConfiguration configuration;
  final WalletModalFactory? createModal;
  final Duration preparationTimeout;
  ReownAppKitModal? _modal;
  Future<void>? _preparation;
  Future<WalletConnection>? _pending;
  bool _disposed = false;

  @override
  Future<WalletConnection?> restore(BuildContext context, {required String expectedAddress}) =>
      _sdkCall(() async {
        if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
        if (!configuration.isConfigured) throw const AuthFailure('authWalletConfiguration');
        final host = Navigator.of(context).context;
        final modal = _modal ??= createModal?.call(host) ?? _createModal(host);
        final preparation = _preparation ??= _sdkCall(() async {
          if (modal.status != ReownAppKitModalStatus.initialized) await modal.init();
        }).whenComplete(() => _preparation = null);
        await preparation.timeout(
          preparationTimeout,
          onTimeout: () => throw const AuthFailure('authWalletConnectionTimeout'),
        );
        if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
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
      await previous.dispose();
      _modal = null;
    }
    if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
    // Keep the host alive after the account sheet closes, so subsequent
    // signatures can still launch the connected wallet app.
    final host = Navigator.of(context).context;
    final modal = _modal ??= createModal?.call(host) ?? _createModal(host);
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
    final modal = _modal;
    _modal = null;
    try {
      await _preparation;
    } catch (_) {
      // Preparation failures belong to the connect operation.
    }
    if (modal != null) await _sdkCall(modal.dispose);
  }
}

class ReownWalletConnection implements WalletConnection, WalletSigningPreparation {
  ReownWalletConnection(this.modal, this.address, String chainId) : _chainId = chainId {
    modal.addListener(_check);
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final expiry = modal.session?.expiry;
    if (expiry != null) {
      _expiryTimer = Timer(
        Duration(milliseconds: expiry * 1000 - DateTime.now().millisecondsSinceEpoch),
        _check,
      );
    }
  }

  final ReownAppKitModal modal;
  @override
  final String address;
  @override
  String get chainId => _chainId;
  String _chainId;
  String? _switchingTo;
  bool _signing = false;
  Timer? _expiryTimer;
  @override
  String? get walletName {
    final name = modal.session?.connectedWalletName?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  final _invalidations = StreamController<void>.broadcast(sync: true);
  bool _invalid = false, _closed = false;

  @override
  bool get isCurrent =>
      !_invalid &&
      !_closed &&
      modal.isConnected &&
      (modal.session?.expiry == null ||
          modal.session!.expiry! > DateTime.now().millisecondsSinceEpoch ~/ 1000) &&
      modal.session?.getAddress('eip155')?.toLowerCase() == address.toLowerCase() &&
      (modal.selectedChain?.chainId == 'eip155:$chainId' ||
          _switchingTo != null && modal.selectedChain?.chainId == 'eip155:$_switchingTo');

  @override
  Future<void> prepareSigning({
    required String expectedAddress,
    required int chainId,
    required bool Function() isCurrent,
  }) => _sdkCall(() async {
    if (_signing || _sending || _switchingTo != null) throw const AuthFailure('authWalletBusy');
    if (!this.isCurrent || !isCurrent() || address.toLowerCase() != expectedAddress.toLowerCase()) {
      throw const AuthFailure('authWalletChanged');
    }
    if (!WalletConfiguration.chains.contains('$chainId')) {
      throw const AuthFailure('authWalletUnsupported');
    }
    _switchingTo = '$chainId';
    try {
      await prepareReownSigningNetwork(
        modal: modal,
        address: address,
        fromChain: this.chainId,
        chainId: chainId,
        isCurrent: () => this.isCurrent && isCurrent(),
      );
      _chainId = '$chainId';
    } finally {
      _switchingTo = null;
      _check();
    }
  });

  void _check() {
    if (!_invalid && !_closed && !isCurrent) {
      _invalidate();
    } else if (!_invalid && !_closed) {
      _scheduleExpiry();
    }
  }

  void _invalidate() {
    if (_invalid || _closed) return;
    _invalid = true;
    _expiryTimer?.cancel();
    _invalidations.add(null);
  }

  @override
  Stream<void> get invalidations => _invalidations.stream;

  Future<String> _request(String method, List<Object?> parameters) => _sdkCall(() async {
    if (_signing || _switchingTo != null) throw const AuthFailure('authWalletBusy');
    if (!isCurrent) throw const AuthFailure('authWalletChanged');
    _signing = true;
    try {
      final result = await modal.request(
        topic: modal.session!.topic,
        chainId: 'eip155:$chainId',
        request: SessionRequestParams(method: method, params: parameters),
      );
      if (!isCurrent) throw const AuthFailure('authWalletChanged');
      if (result is! String || !RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(result)) {
        throw const AuthFailure('authWalletSignature');
      }
      return result;
    } finally {
      _signing = false;
    }
  });

  @override
  Future<String> signPersonalMessage(String message) => _request('personal_sign', [
    '0x${utf8.encode(message).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}',
    address,
  ]);

  @override
  Future<String> signTypedData(Map<String, Object?> data) =>
      _request('eth_signTypedData_v4', [address, jsonEncode(data)]);

  bool _sending = false;
  @override
  Future<WalletTransactionResult> sendTransaction({
    required EvmWalletTransaction transaction,
    required bool Function() isCurrent,
  }) async {
    if (_sending || _signing || _switchingTo != null) {
      throw const WalletTransactionNotSent('walletTransactionBusy');
    }
    if (!this.isCurrent ||
        !isCurrent() ||
        transaction.from.toLowerCase() != address.toLowerCase()) {
      throw const WalletTransactionNotSent('authWalletChanged');
    }
    if (transaction.chainId.toString() != chainId) {
      throw const WalletTransactionNotSent('walletTransactionWrongChain');
    }
    final session = modal.session;
    if (session == null ||
        session.getApprovedMethods(namespace: 'eip155')?.contains('eth_sendTransaction') != true ||
        session.getApprovedChains(namespace: 'eip155')?.contains('eip155:$chainId') != true) {
      throw const WalletTransactionNotSent('walletTransactionPermission');
    }
    _sending = true;
    try {
      return await dispatchWalletTransaction(
        () async => modal.request(
          topic: session.topic,
          chainId: 'eip155:$chainId',
          request: SessionRequestParams(
            method: 'eth_sendTransaction',
            params: [transaction.parameters],
          ),
        ),
      );
    } finally {
      _sending = false;
    }
    // A reported hash survives a later account change. The funding journal must
    // retain it under the original wallet, not imply that nothing was sent.
  }

  @override
  Future<void> release() async {
    if (_closed) return;
    _closed = true;
    _expiryTimer?.cancel();
    modal.removeListener(_check);
    await _invalidations.close();
  }

  @override
  Future<void> disconnect() async {
    if (_closed) return;
    await release();
    await _sdkCall(() => modal.disconnect());
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
