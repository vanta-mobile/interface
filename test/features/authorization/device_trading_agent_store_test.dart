import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/data/aster_signature_verifier.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_signatures.dart';
import '../../support/trading_agents.dart';

void main() {
  late MemoryTradingAgentStorage storage;
  late DateTime now;
  setUp(() {
    storage = MemoryTradingAgentStorage();
    now = DateTime.utc(2026, 11, 10);
  });

  test('device agent survives restart and signs for the owner with its own identity', () async {
    final store = storage.store(() => now);
    final agent = await store.prepare('login', fixtureMaster, now.add(const Duration(days: 30)));
    expect(agent.address, isNot(fixtureMaster.toLowerCase()));
    await store.setStatus(agent, TradingAgentStatus.unknown);
    await store.setStatus(agent, TradingAgentStatus.active);
    final restored = storage.store(() => now);
    final signing = await restored.resolve('login', fixtureMaster);
    final query = Uri(
      queryParameters: {'user': fixtureMaster, 'signer': agent.address, 'nonce': '123'},
    ).query;
    final data = asterReadTypedData(query);
    final signature = await signing.sign(expectedAddress: agent.address, typedData: data);
    expect(verifyAsterWalletSignature(agent.address, data, signature), true);
    expect(verifyAsterWalletSignature(fixtureMaster, data, signature), false);
    expect((await restored.load('login', fixtureMaster))?.status, TradingAgentStatus.active);
  });

  test(
    'unknown grant survives restart, blocks replay and only permits explicit read checks',
    () async {
      final store = storage.store(() => now);
      final agent = await store.prepare('login', fixtureMaster, now.add(const Duration(days: 30)));
      await store.setStatus(agent, TradingAgentStatus.unknown);
      final restored = storage.store(() => now);
      await expectLater(
        restored.resolve('login', fixtureMaster),
        throwsA(isA<AccountReadFailure>()),
      );
      await expectLater(
        restored.prepare('login', fixtureMaster, agent.expiresAt),
        throwsA(isA<AccountReadFailure>()),
      );
      expect(
        (await restored.resolve('login', fixtureMaster, allowUnknown: true)).address,
        agent.address,
      );
      expect(storage.writes, 2);
    },
  );

  test('login identities and owner wallets cannot use each other\'s agent', () async {
    final store = storage.store(() => now);
    final agent = await store.prepare('login', fixtureMaster, now.add(const Duration(days: 30)));
    await store.setStatus(agent, TradingAgentStatus.unknown);
    await store.setStatus(agent, TradingAgentStatus.active);
    for (final scope in [('other-login', fixtureMaster), ('login', fixtureChild)]) {
      expect(await store.load(scope.$1, scope.$2), null);
      await expectLater(store.resolve(scope.$1, scope.$2), throwsA(isA<AccountReadFailure>()));
    }
    final signing = await store.resolve('login', fixtureMaster);
    for (final addresses in [(fixtureChild, agent.address), (fixtureMaster, fixtureChild)]) {
      await expectLater(
        signing.sign(
          expectedAddress: agent.address,
          typedData: asterReadTypedData(
            Uri(queryParameters: {'user': addresses.$1, 'signer': addresses.$2, 'nonce': '1'})
                .query,
          ),
        ),
        throwsA(isA<AccountReadFailure>()),
      );
    }
  });

  test('expiry is checked again by previously resolved signers', () async {
    final store = storage.store(() => now);
    final agent = await store.prepare('login', fixtureMaster, now.add(const Duration(days: 30)));
    await store.setStatus(agent, TradingAgentStatus.unknown);
    await store.setStatus(agent, TradingAgentStatus.active);
    final signing = await store.resolve('login', fixtureMaster);
    now = agent.expiresAt;
    await expectLater(
      signing.sign(
        expectedAddress: agent.address,
        typedData: asterReadTypedData('user=$fixtureMaster&signer=${agent.address}&nonce=1'),
      ),
      throwsA(isA<AccountReadFailure>()),
    );
    final replacement = await store.prepare(
      'login',
      fixtureMaster,
      now.add(const Duration(days: 30)),
    );
    expect(replacement.address, isNot(agent.address));
    expect(replacement.status, TradingAgentStatus.prepared);
  });

  test('rejected grants cannot sign and require a new explicit authorization', () async {
    final store = storage.store(() => now);
    final agent = await store.prepare('login', fixtureMaster, now.add(const Duration(days: 30)));
    await store.setStatus(agent, TradingAgentStatus.unknown);
    await store.setStatus(agent, TradingAgentStatus.active);
    await store.setStatus(agent, TradingAgentStatus.rejected);
    await expectLater(store.resolve('login', fixtureMaster), throwsA(isA<AccountReadFailure>()));
    final replacement = await store.prepare('login', fixtureMaster, agent.expiresAt);
    expect(replacement.address, isNot(agent.address));
  });

  test('storage failure prevents key use; corrupt keys are never replaced silently', () async {
    final store = storage.store(() => now);
    storage.writeFailure = StateError('fixture failure');
    await expectLater(
      store.prepare('login', fixtureMaster, now.add(const Duration(days: 30))),
      throwsA(
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'authorizationSecureStorageFailed'),
      ),
    );
    storage.writeFailure = null;
    await store.prepare('login', fixtureMaster, now.add(const Duration(days: 30)));
    final key = storage.values.keys.single;
    final record = jsonDecode(storage.values[key]!) as Map<String, dynamic>;
    record['address'] = fixtureChild.toLowerCase();
    storage.values[key] = jsonEncode(record);
    final writes = storage.writes;
    await expectLater(store.load('login', fixtureMaster), throwsA(isA<AccountReadFailure>()));
    await expectLater(
      store.prepare('login', fixtureMaster, now.add(const Duration(days: 30))),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(storage.writes, writes);
  });
}
