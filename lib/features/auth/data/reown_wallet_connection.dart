part of 'reown_wallet_connector.dart';

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
  bool Function()? _signingOwner;
  bool get _signing => _signingOwner?.call() ?? false;
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
    final scope = RequestScope.current;
    bool owner() => isCurrent && (scope?.active ?? true);
    if (!owner()) throw const AuthFailure('authWalletChanged');
    _signingOwner = owner;
    try {
      final result = await modal.request(
        topic: modal.session!.topic,
        chainId: 'eip155:$chainId',
        request: SessionRequestParams(method: method, params: parameters),
      );
      if (!owner()) throw const AuthFailure('authWalletChanged');
      if (result is! String || !RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(result)) {
        throw const AuthFailure('authWalletSignature');
      }
      return result;
    } finally {
      if (identical(_signingOwner, owner)) _signingOwner = null;
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

  bool Function()? _sendingOwner;
  bool get _sending => _sendingOwner?.call() ?? false;
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
    final owner = isCurrent;
    _sendingOwner = owner;
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
      if (identical(_sendingOwner, owner)) _sendingOwner = null;
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
