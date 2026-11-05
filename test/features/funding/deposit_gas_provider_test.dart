import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/application/deposit_gas_provider.dart';
import 'package:vanta/features/funding/domain/deposit_transaction.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_gas.dart';
import '../../support/deposit_wallet.dart';
import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestDepositGasRepository repository;
  final query = depositQuery(), time = DateTime.utc(2026, 11, 4, 8);
  late DateTime now;
  ProviderSubscription<AccountSnapshotState<DepositGasQuote>>? listener;
  DepositGasController controller() => container.read(depositGasProvider(query).notifier);
  AccountSnapshotState<DepositGasQuote> state() => container.read(depositGasProvider(query));
  void gasTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      now = time;
      identity = TestIdentityRepository()
        ..restored = const AuthIdentity(
          id: 'public-wallet',
          walletAddress: accountAddress,
          walletKind: WalletKind.external,
        );
      repository = TestDepositGasRepository()..result = gasQuote(query: query, receivedAt: now);
      container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          depositGasRepositoryProvider.overrideWithValue(repository),
          depositGasClockProvider.overrideWithValue(() => now),
        ],
      );
      container.read(authProvider);
      listener = container.listen(depositGasProvider(query), (_, _) {});
      await tester.pump();
      try {
        await body(tester);
      } finally {
        listener?.close();
        listener = null;
        container.dispose();
        await identity.dispose();
      }
    });
  }

  gasTest('explicit estimate uses restored EOA without signing or creating a wallet', (
    tester,
  ) async {
    expect(repository.calls, isEmpty);
    await controller().estimate('1');
    expect(repository.calls.single, (accountAddress, query, '1'));
    expect(state().account!.address, accountAddress);
    expect(identity.wallets, 0);
    expect(container.read(authProvider).identity!.signingAvailable, false);
  });
  gasTest('busy dedup, safe failure preserves stale quote, manual retry succeeds', (tester) async {
    await controller().estimate('1');
    final previous = state().account;
    repository.gate = Completer();
    final pending = controller().estimate('1');
    await controller().estimate('2');
    expect(repository.calls.length, 2);
    repository.failure = const FormatException('private detail');
    repository.gate!.complete();
    await pending;
    expect(state().account, same(previous));
    expect(state().stale, true);
    expect(state().failure!.key, 'depositRpcFailed');
    repository.failure = null;
    await controller().estimate('1');
    expect(state().failure, null);
    expect(state().stale, false);
  });
  for (final source in ['quote', 'wallet', 'block']) {
    gasTest('expiry respects earliest $source deadline without automatic requests', (tester) async {
      repository.result = gasQuote(
        query: query,
        receivedAt: now,
        wallet: depositSnapshot(
          query: query,
          receivedAt: source == 'wallet' ? now.subtract(const Duration(seconds: 29)) : now,
          blockAge: source == 'block' ? const Duration(seconds: 119) : Duration.zero,
        ),
      );
      await controller().estimate('1');
      expect(state().stale, false);
      await tester.pump(Duration(seconds: source == 'quote' ? 30 : 1));
      expect(state().stale, true);
      expect(repository.calls.length, 1);
    });
  }
  for (final issue in [
    'oldQuote',
    'futureQuote',
    'oldWallet',
    'oldBlock',
    'futureBlock',
    'walletAfterQuote',
  ]) {
    gasTest('reject unusable $issue before exposing quote', (tester) async {
      final wallet = depositSnapshot(
        query: query,
        receivedAt: switch (issue) {
          'oldWallet' => now.subtract(const Duration(seconds: 30)),
          'walletAfterQuote' => now.add(const Duration(seconds: 1)),
          _ => now,
        },
        blockAge: switch (issue) {
          'oldBlock' => const Duration(seconds: 120),
          'futureBlock' => const Duration(seconds: -121),
          _ => Duration.zero,
        },
      );
      repository.result = gasQuote(
        query: query,
        wallet: wallet,
        receivedAt: switch (issue) {
          'oldQuote' => now.subtract(const Duration(seconds: 30)),
          'futureQuote' => now.add(const Duration(seconds: 1)),
          _ => now,
        },
      );
      await controller().estimate('1');
      expect(state().account, null);
      expect(state().failure, isA<AccountReadFailure>());
    });
  }
  for (final issue in [
    'wallet',
    'query',
    'amount',
    'from',
    'to',
    'data',
    'value',
    'kind',
    'gas',
    'limit',
    'price',
    'nonce',
    'nativeReserve',
  ]) {
    gasTest('tampered $issue cannot replace previous scoped immutable transaction', (tester) async {
      await controller().estimate('1');
      final previous = state().account;
      final wallet = depositSnapshot(
        query: issue == 'query' ? depositQuery(chain: 1) : query,
        receivedAt: now,
        nativeUnits: issue == 'nativeReserve' ? BigInt.one : null,
        address: issue == 'wallet' ? '0x${'3' * 40}' : accountAddress,
      );
      final base = nextDepositTransaction(wallet, BigInt.parse('1000000000000000000'));
      final tx = DepositTransaction(
        kind: issue == 'kind' ? DepositTransactionKind.approve : base.kind,
        query: base.query,
        from: issue == 'from' ? '0x${'3' * 40}' : base.from,
        to: issue == 'to' ? '0x${'3' * 40}' : base.to,
        data: issue == 'data' ? '0xdeadbeef' : base.data,
        value: issue == 'value' ? BigInt.one : base.value,
        amountUnits: issue == 'amount' ? BigInt.one : base.amountUnits,
      );
      repository.result = gasQuote(
        query: wallet.query,
        wallet: wallet,
        transaction: tx,
        receivedAt: now,
        estimatedGas: issue == 'gas' ? BigInt.zero : null,
        gasLimit: issue == 'limit' ? BigInt.from(25201) : null,
        gasPrice: issue == 'price' ? BigInt.zero : null,
        nonce: issue == 'nonce' ? BigInt.one << 64 : null,
      );
      await controller().estimate('1');
      expect(state().account, same(previous));
      expect(state().stale, true);
      expect(state().failure!.key, 'depositRpcInvalid');
    });
  }
  for (final change in <AuthIdentity?>[
    null,
    const AuthIdentity(
      id: 'other-user',
      walletAddress: accountAddress,
      walletKind: WalletKind.external,
    ),
    const AuthIdentity(
      id: 'public-wallet',
      walletAddress: '0x3333333333333333333333333333333333333333',
      walletKind: WalletKind.external,
    ),
    const AuthIdentity(
      id: 'public-wallet',
      walletAddress: accountAddress,
      walletKind: WalletKind.embedded,
    ),
    const AuthIdentity(
      id: 'public-wallet',
      walletAddress: accountAddress,
      walletKind: WalletKind.external,
      signingAvailable: true,
    ),
  ]) {
    gasTest(
      'scope change clears quote and invalidates pending estimate: ${change?.id}/${change?.walletAddress}/${change?.walletKind}/${change?.signingAvailable}',
      (tester) async {
        await controller().estimate('1');
        repository.gate = Completer();
        final pending = controller().estimate('1');
        identity.events.add(change);
        await tester.pump();
        expect(state().account, null);
        expect(repository.isCurrent!(), false);
        repository.gate!.complete();
        await pending;
        expect(state().account, null);
      },
    );
  }
  gasTest('stop drops late initial result and retains old refresh quote as stale', (tester) async {
    for (final hadQuote in [false, true]) {
      if (hadQuote) await controller().estimate('1');
      final previous = state().account;
      repository.gate = Completer();
      final pending = controller().estimate('1');
      controller().stop();
      expect(repository.isCurrent!(), false);
      repository.gate!.complete();
      await pending;
      expect(state().account, same(previous));
      expect(state().stale, hadQuote);
    }
  });
  gasTest('family disposal releases transport and prevents late result', (tester) async {
    listener!.close();
    container.dispose();
    var closed = 0;
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        depositGasClockProvider.overrideWithValue(() => now),
        depositGasRepositoryProvider.overrideWith((ref) {
          ref.onDispose(() => closed++);
          return repository;
        }),
      ],
    );
    container.read(authProvider);
    listener = container.listen(depositGasProvider(query), (_, _) {});
    await tester.pump();
    repository.gate = Completer();
    final pending = controller().estimate('1');
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 0);
    listener!.close();
    listener = null;
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 1);
    expect(repository.isCurrent!(), false);
    repository.gate!.complete();
    await pending;
    expect(container.exists(depositGasProvider(query)), false);
  });
}
