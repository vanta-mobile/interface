import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/data/wallet_operation_journal.dart';
import 'package:vanta/core/domain/wallet_operation.dart';

import '../../support/position_margin_adjustment.dart';

void main() {
  late Directory dir;
  late FileWalletOperationJournal journal;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vanta-margin-');
    journal = FileWalletOperationJournal(
      () async => dir,
      filename: 'position-margin-operations-v1.json',
    );
    await journal.reload();
  });
  tearDown(() async {
    await journal.close();
    await dir.delete(recursive: true);
  });
  test('flush before return and recover original pending intent after restart', () async {
    await journal.prepare(marginRecord());
    final text = await File('${dir.path}/position-margin-operations-v1.json').readAsString();
    expect(text, contains(marginReference));
    final recovered = FileWalletOperationJournal(
      () async => dir,
      filename: 'position-margin-operations-v1.json',
    );
    await recovered.reload();
    expect(recovered.snapshot.records.single.acknowledged, false);
    expect(recovered.snapshot.records.single.terms, marginRecord().terms);
    await recovered.close();
    expect(await File('${dir.path}/wallet-operations-v1.json').exists(), false);
  });
  test('exact verified outcome persists; unresolved record cannot be superseded', () async {
    final record = marginRecord();
    await journal.prepare(record);
    await expectLater(journal.prepare(record), throwsA(isA<WalletOperationPending>()));
    await journal.report(record.key, marginReference);
    final stored = decodeWalletOperations(
      await File('${dir.path}/position-margin-operations-v1.json').readAsString(),
    ).single;
    expect(stored.acknowledged, true);
    expect(stored.reference, marginReference);
  });
  test('corruption is preserved and blocks further writes', () async {
    await File('${dir.path}/position-margin-operations-v1.json').writeAsString('{corrupt');
    await expectLater(journal.reload(), throwsA(isA<WalletOperationStorageFailure>()));
    expect(journal.snapshot.failed, true);
    await expectLater(
      journal.prepare(marginRecord()),
      throwsA(isA<WalletOperationStorageFailure>()),
    );
    expect(await File('${dir.path}/position-margin-operations-v1.json').readAsString(), '{corrupt');
  });
}
