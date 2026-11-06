import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/data/wallet_preference_store.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_connection.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';

class MemoryWalletPreferences implements WalletPreferenceStore {
  WalletPreference? value;
  @override
  Future<WalletPreference?> read() async => value;
  @override
  Future<void> write(WalletPreference preference) async => value = preference;
}

class TestWalletConnection implements WalletConnection {
  @override
  final String address;
  @override
  final String chainId;
  @override
  final String? walletName;
  TestWalletConnection({
    this.address = '0x2222222222222222222222222222222222222222',
    this.chainId = '56',
    this.walletName,
  });
  bool current = true;
  int disconnected = 0, personalSigns = 0, typedSigns = 0;
  String? personalMessage;
  Map<String, Object?>? typedData;
  AuthFailure? failure;
  Completer<void>? signGate;
  final events = StreamController<void>.broadcast(sync: true);
  static final signature = '0x${List.filled(65, '11').join()}';
  @override
  bool get isCurrent => current;
  @override
  Stream<void> get invalidations => events.stream;
  @override
  Future<String> signPersonalMessage(String message) async {
    personalSigns++;
    personalMessage = message;
    await signGate?.future;
    if (failure case final error?) throw error;
    return signature;
  }

  @override
  Future<String> signTypedData(Map<String, Object?> data) async {
    typedSigns++;
    typedData = data;
    await signGate?.future;
    if (failure case final error?) throw error;
    return signature;
  }

  final transactions = <EvmWalletTransaction>[];
  WalletTransactionResult transactionResult = WalletTransactionResult.fromResponse('0x${'a' * 64}');
  Object? transactionFailure;
  Completer<void>? transactionGate;
  @override
  Future<WalletTransactionResult> sendTransaction({
    required EvmWalletTransaction transaction,
    required bool Function() isCurrent,
  }) async {
    if (!this.isCurrent || !isCurrent()) throw const WalletTransactionNotSent('authWalletChanged');
    if (transaction.chainId.toString() != chainId) {
      throw const WalletTransactionNotSent('walletTransactionWrongChain');
    }
    if (transactionFailure case final WalletTransactionNotSent error) throw error;
    transactions.add(transaction);
    await transactionGate?.future;
    if (transactionFailure case final error?) throw error;
    return transactionResult;
  }

  @override
  Future<void> disconnect() async {
    disconnected++;
    current = false;
  }

  @override
  Future<void> release() async => current = false;

  void invalidate() {
    current = false;
    events.add(null);
  }

  Future<void> dispose() async {
    if (transactionGate case final gate? when !gate.isCompleted) gate.complete();
    if (signGate case final gate? when !gate.isCompleted) gate.complete();
    await events.close();
  }
}

class TestWalletConnector implements WalletConnector {
  TestWalletConnector(this.connection);
  final TestWalletConnection connection;
  int connects = 0;
  AuthFailure? failure;
  Completer<void>? gate;
  @override
  Future<TestWalletConnection> connect(BuildContext context) async {
    connects++;
    await gate?.future;
    if (failure case final error?) throw error;
    return connection;
  }

  @override
  Future<void> dispose() async {}
}
