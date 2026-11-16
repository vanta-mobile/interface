import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/core/errors/api_error_details.dart';

import '../../support/identity_repository.dart';
import '../../support/trading_authorization.dart';

const _identity = AuthIdentity(
  id: 'signed-user',
  walletAddress: '0x1111111111111111111111111111111111111111',
  signingAvailable: true,
);

void main() {
  late TestIdentityRepository identity;
  late TestTradingAuthorizationRepository repository;
  late ProviderContainer container;
  late TradingAuthorizationController controller;
  setUp(() async {
    identity = TestIdentityRepository()..restored = _identity;
    repository = TestTradingAuthorizationRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        tradingAuthorizationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
    controller = container.read(tradingAuthorizationProvider.notifier);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });

  test('wallet switch invalidates an in-flight grant and ignores its late result', () async {
    repository.enableGate = Completer<void>();
    final pending = controller.enableTrading();
    expect(repository.isCurrent!(), true);
    identity.events.add(
      const AuthIdentity(
        id: 'other-user',
        walletAddress: '0x2222222222222222222222222222222222222222',
        signingAvailable: true,
      ),
    );
    expect(repository.isCurrent!(), false);
    repository.enableGate!.complete();
    await pending;
    expect(container.read(tradingAuthorizationProvider).result, isNull);
    expect(container.read(tradingAuthorizationProvider).busy, false);
    expect(repository.enables, 1);
  });

  test('logout invalidates signing and a late acknowledgement cannot restore it', () async {
    repository.enableGate = Completer<void>();
    final pending = controller.enableTrading();
    await container.read(authProvider.notifier).logout();
    expect(repository.isCurrent!(), false);
    repository.enableGate!.complete();
    await pending;
    expect(container.read(authProvider).identity, isNull);
    expect(container.read(tradingAuthorizationProvider).result, isNull);
  });

  test('disposing the owner invalidates the request guard', () async {
    repository.enableGate = Completer<void>();
    final pending = controller.enableTrading();
    container.dispose();
    expect(repository.isCurrent!(), false);
    repository.enableGate!.complete();
    await pending;
  });

  test('stopping an in-flight grant retains uncertainty and blocks resubmission', () async {
    repository.enableGate = Completer<void>();
    final pending = controller.enableTrading();
    controller.stop();
    expect(repository.isCurrent!(), false);
    repository.enableGate!.complete();
    await pending;
    controller.cancel();
    controller.prepare();
    await controller.enableTrading();
    expect(container.read(tradingAuthorizationProvider).result, TradingAuthorizationResult.unknown);
    expect(repository.enables, 1);
  });

  test('pending Builder recovery requires a successful live missing-binding check', () async {
    repository.result = TradingAuthorizationResult.unknown;
    await controller.enableTrading();
    await controller.enableTrading(retryPendingBuilder: true);
    expect(repository.enables, 1);
    repository.checked = TradingAuthorizationCheck(
      address: _identity.walletAddress!,
      checkedAt: DateTime.now(),
      futuresReadAccepted: true,
      spotReadAccepted: true,
      agentReady: true,
      builderReady: false,
    );
    await controller.check();
    expect(container.read(tradingAuthorizationProvider).result, TradingAuthorizationResult.unknown);
    repository.result = TradingAuthorizationResult.acknowledged;
    await controller.enableTrading(retryPendingBuilder: true);
    expect(repository.enables, 2);
    expect(repository.retriedPendingBuilder, true);
    expect(
      container.read(tradingAuthorizationProvider).result,
      TradingAuthorizationResult.acknowledged,
    );
  });

  test('a failed Builder read never permits pending approval signing', () async {
    repository.result = TradingAuthorizationResult.unknown;
    await controller.enableTrading();
    repository.checked = TradingAuthorizationCheck(
      address: _identity.walletAddress!,
      checkedAt: DateTime.now(),
      futuresReadAccepted: true,
      spotReadAccepted: true,
      agentReady: true,
      builderFailure: 'accountNetwork',
    );
    await controller.check();
    await controller.enableTrading(retryPendingBuilder: true);
    expect(repository.enables, 1);
    expect(container.read(tradingAuthorizationProvider).failure, 'accountNetwork');
  });

  test('stopping before a wallet signature is returned does not invent a pending write', () async {
    repository.initialStep = TradingAuthorizationStep.signing;
    repository.enableGate = Completer<void>();
    final pending = controller.enableTrading();
    expect(container.read(tradingAuthorizationProvider).step, TradingAuthorizationStep.signing);
    controller.stop();
    await pending;
    expect(container.read(tradingAuthorizationProvider).result, isNull);
    expect(container.read(tradingAuthorizationProvider).busy, false);
    repository.enableGate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(tradingAuthorizationProvider).result, isNull);
  });

  test(
    'wallet refusal before dispatch retains its actual reason and allows explicit retry',
    () async {
      repository.initialStep = TradingAuthorizationStep.signing;
      repository.failure = const AccountReadFailure(
        'authWalletRejected',
        details: ApiErrorDetails(message: 'User declined signature'),
      );
      await controller.enableTrading();
      final failed = container.read(tradingAuthorizationProvider);
      expect(failed.result, isNull);
      expect(failed.step, TradingAuthorizationStep.signing);
      expect(failed.failure, 'authWalletRejected');
      expect(failed.errorDetails?.message, 'User declined signature');
      expect(repository.enables, 1);
      repository.failure = null;
      await controller.enableTrading();
      expect(repository.enables, 2);
      expect(
        container.read(tradingAuthorizationProvider).result,
        TradingAuthorizationResult.acknowledged,
      );
    },
  );

  test('signer reconnection for the same wallet preserves an unknown grant', () async {
    repository.result = TradingAuthorizationResult.unknown;
    await controller.enableTrading();
    identity.events.add(
      AuthIdentity(
        id: _identity.id,
        walletAddress: _identity.walletAddress,
        signingAvailable: false,
      ),
    );
    await controller.check();
    expect(container.read(tradingAuthorizationProvider).result, TradingAuthorizationResult.unknown);
    identity.events.add(_identity);
    expect(container.read(tradingAuthorizationProvider).result, TradingAuthorizationResult.unknown);
    await controller.enableTrading();
    expect(repository.enables, 1);
  });

  test('known acknowledgement prevents another onboarding grant', () async {
    await controller.enableTrading();
    await controller.enableTrading();
    expect(repository.enables, 1);
    expect(
      container.read(tradingAuthorizationProvider).result,
      TradingAuthorizationResult.acknowledged,
    );
  });

  test('changing wallets releases the old wait before its callback returns', () async {
    final oldGate = repository.enableGate = Completer<void>();
    final old = controller.enableTrading();
    final oldCurrent = repository.isCurrent!;
    identity.events.add(
      const AuthIdentity(
        id: 'other-user',
        walletAddress: '0x2222222222222222222222222222222222222222',
        signingAvailable: true,
      ),
    );
    final newGate = repository.enableGate = Completer<void>();
    final next = controller.enableTrading();
    expect(repository.enables, 2);
    expect(container.read(tradingAuthorizationProvider).busy, true);
    expect(oldCurrent(), false);
    oldGate.complete();
    await old;
    expect(container.read(tradingAuthorizationProvider).busy, true);
    await controller.enableTrading();
    expect(repository.enables, 2);
    newGate.complete();
    await next;
    expect(container.read(tradingAuthorizationProvider).busy, false);
    expect(
      container.read(tradingAuthorizationProvider).result,
      TradingAuthorizationResult.acknowledged,
    );
  });

  test('stopped wait settles and permits a read-only check without the old response', () async {
    final gate = repository.enableGate = Completer<void>();
    final pending = controller.enableTrading();
    controller.stop();
    await pending;
    await controller.check();
    expect(repository.checks, 1);
    expect(repository.enables, 1);
    expect(container.read(tradingAuthorizationProvider).result, TradingAuthorizationResult.unknown);
    gate.complete();
    await Future<void>.delayed(Duration.zero);
  });

  test('repository replacement interrupts its pending wait and permits checking', () async {
    final gate = repository.enableGate = Completer<void>();
    final pending = controller.enableTrading();
    final replacement = TestTradingAuthorizationRepository();
    container.updateOverrides([
      identityRepositoryProvider.overrideWithValue(identity),
      tradingAuthorizationRepositoryProvider.overrideWithValue(replacement),
    ]);
    container.read(tradingAuthorizationProvider);
    await controller.check();
    expect(replacement.checks, 1);
    expect(container.read(tradingAuthorizationProvider).busy, false);
    gate.complete();
    await pending;
  });
}
