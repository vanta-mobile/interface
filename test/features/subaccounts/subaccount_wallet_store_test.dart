import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/data/aster_signature_verifier.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_signature.dart';
import 'package:vanta/features/subaccounts/data/subaccount_wallet_store.dart';

import '../../support/aster_account.dart';

void main() {
  late Map<String, String> storage;
  late DeviceSubaccountWalletStore store;
  setUp(() {
    storage = {};
    store = DeviceSubaccountWalletStore(
      read: (key) async => storage[key],
      write: (key, value) async {
        storage[key] = value;
      },
    );
  });
  test('generates independent wallets and persists before returning public metadata', () async {
    final wallet = await store.generate(owner: accountAddress, name: 'Momentum');
    final other = await store.generate(owner: accountAddress, name: 'Trend');
    expect(wallet.address, isNot(accountAddress));
    expect(other.address, isNot(wallet.address));
    expect(wallet.backedUp, false);
    final restored = DeviceSubaccountWalletStore(
      read: (key) async => storage[key],
      write: (key, value) async {
        storage[key] = value;
      },
    );
    expect((await restored.list()).map((w) => w.address), [wallet.address, other.address]);
    expect((await restored.reveal(wallet.address)).length, 64);
  });
  test('signs the exact child EIP-712 body and rejects a different body', () async {
    final wallet = await store.generate(owner: accountAddress, name: '策略');
    final data = asterReadTypedData('subAccountName=x&subSourceAddr=${wallet.address}');
    final signature = await store.sign(wallet.address, data);
    expect(verifyAsterWalletSignature(wallet.address, data, signature), true);
    expect(
      verifyAsterWalletSignature(wallet.address, asterReadTypedData('other'), signature),
      false,
    );
  });
  test('backup acknowledgement is durable and never replaces the private key', () async {
    final wallet = await store.generate(owner: accountAddress, name: 'Desk');
    final before = await store.reveal(wallet.address);
    await store.acknowledgeBackup(wallet.address);
    expect((await store.list()).single.backedUp, true);
    expect(await store.reveal(wallet.address) == before, true);
  });
  test('failed persistence returns a safe error and no generated account', () async {
    final broken = DeviceSubaccountWalletStore(
      read: (_) async => null,
      write: (_, _) async => throw StateError('sensitive native error'),
    );
    await expectLater(
      broken.generate(owner: accountAddress, name: 'Desk'),
      throwsA(
        isA<AccountReadFailure>().having((e) => e.key, 'safe key', 'subaccountSecureStorageFailed'),
      ),
    );
  });
  test('invalid metadata or address/key mismatch blocks access without overwriting', () async {
    await store.generate(owner: accountAddress, name: 'Desk');
    final data = jsonDecode(storage.values.single) as Map<String, dynamic>;
    final wallets = data['wallets'] as List<dynamic>;
    (wallets.single as Map<String, dynamic>)['address'] = accountAddress;
    storage[DeviceSubaccountWalletStore.storageKey] = jsonEncode(data);
    final original = storage.values.single;
    await expectLater(store.list(), throwsA(isA<AccountReadFailure>()));
    await expectLater(
      store.generate(owner: accountAddress, name: 'Other'),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(storage.values.single == original, true);
  });
  test('serialized concurrent writes retain both keys', () async {
    await Future.wait([
      store.generate(owner: accountAddress, name: 'A'),
      store.generate(owner: accountAddress, name: 'B'),
    ]);
    expect((await store.list()).map((w) => w.name), ['A', 'B']);
  });
  test('generated connection signs only while owned and rejects native transaction path', () async {
    final wallet = await store.generate(owner: accountAddress, name: 'Desk');
    final connection = store.connection(wallet), data = asterReadTypedData('scope');
    expect(
      verifyAsterWalletSignature(wallet.address, data, await connection.signTypedData(data)),
      true,
    );
    expect((await connection.signPersonalMessage('SIWE challenge')).length, 132);
    await connection.release();
    expect(connection.isCurrent, false);
    await expectLater(connection.signTypedData(data), throwsA(isA<Exception>()));
  });
  for (final name in ['', ' ', 'x\n', 'a' * 65]) {
    test('invalid account name is rejected before secure write ${name.length}', () async {
      await expectLater(
        store.generate(owner: accountAddress, name: name),
        throwsA(isA<AccountReadFailure>()),
      );
      expect(storage, isEmpty);
    });
  }
}
