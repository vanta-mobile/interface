import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../domain/auth_session.dart';
import '../domain/wallet_connection.dart';
import '../domain/wallet_transaction.dart';
import 'evm_account_address.dart';
import 'wallet_transaction_dispatch.dart';
import 'wallet_configuration.dart';

abstract interface class WalletConnector {
  Future<WalletConnection> connect(BuildContext context);
  Future<void> dispose();
}

typedef WalletModalFactory = ReownAppKitModal Function(BuildContext context);

/// BuildContext is used only to host the SDK's native wallet-selection UI.
/// SDK clients, sessions, and signature payloads stay behind this adapter.
class ReownWalletConnector implements WalletConnector {
  ReownWalletConnector(this.configuration, {this.createModal});
  final WalletConfiguration configuration;
  final WalletModalFactory? createModal;
  ReownAppKitModal? _modal;
  Future<WalletConnection>? _pending;
  bool _disposed = false;

  @override
  Future<WalletConnection> connect(BuildContext context) => _pending ??= _sdkCall(() async {
    if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
    if (!configuration.isConfigured) throw const AuthFailure('authWalletConfiguration');
    final previous = _modal;
    if (previous != null && previous.modalContext == null) {
      await previous.dispose();
      _modal = null;
    }
    if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
    // Keep the host alive after the account sheet closes, so subsequent
    // signatures can still launch the connected wallet app.
    final host = Navigator.of(context).context;
    final modal = _modal ??= createModal?.call(host) ?? _createModal(host);
    await modal.init();
    if (_disposed || !context.mounted) throw const AuthFailure('authWalletCancelled');
    if (!modal.isConnected) {
      if (modal.isOpen) throw const AuthFailure('authWalletUnavailable');
      await modal.openModalView();
    }
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

  ReownAppKitModal _createModal(BuildContext context) => ReownAppKitModal(
    context: context,
    projectId: configuration.projectId.trim(),
    metadata: PairingMetadata(
      name: 'Vanta',
      description: 'Vanta wallet sign-in',
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
    if (modal != null) await _sdkCall(modal.dispose);
  }
}

class ReownWalletConnection implements WalletConnection {
  ReownWalletConnection(this.modal, this.address, this.chainId) {
    modal.addListener(_check);
  }
  final ReownAppKitModal modal;
  @override
  final String address;
  @override
  final String chainId;
  final _invalidations = StreamController<void>.broadcast(sync: true);
  bool _invalid = false, _closed = false;

  @override
  bool get isCurrent =>
      !_invalid &&
      !_closed &&
      modal.isConnected &&
      modal.session?.getAddress('eip155')?.toLowerCase() == address.toLowerCase() &&
      modal.selectedChain?.chainId == 'eip155:$chainId';

  void _check() {
    if (!_invalid && !_closed && !isCurrent) {
      _invalid = true;
      _invalidations.add(null);
    }
  }

  @override
  Stream<void> get invalidations => _invalidations.stream;

  Future<String> _request(String method, List<Object?> parameters) => _sdkCall(() async {
    if (!isCurrent) throw const AuthFailure('authWalletChanged');
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
    if (_sending) throw const WalletTransactionNotSent('walletTransactionBusy');
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
    final message = error.toString().toLowerCase();
    result.completeError(
      error is AuthFailure
          ? error
          : AuthFailure(
              message.contains('4001') || message.contains('reject')
                  ? 'authWalletRejected'
                  : 'authWalletUnavailable',
            ),
      stack,
    );
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
