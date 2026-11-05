import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/subaccounts/data/subaccount_list_mapper.dart';

import '../../support/aster_account.dart';
import '../../support/subaccounts.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);
  test(
    'opaque native 64-bit IDs, names and parent flags are immutable, without wallet inference',
    () {
      final payload = subaccountRows();
      final directory = mapSubaccountDirectory(payload, address: accountAddress, receivedAt: now);
      expect(directory.address, accountAddress);
      expect(directory.receivedAt, now);
      expect(directory.childCount, 1);
      expect(directory.accounts.first.accountId.toString(), '9007199254740993');
      expect(directory.accounts.first.name, '交易台 / Desk A');
      expect(directory.accounts.last.isParent, true);
      expect(directory.accounts.last.name, '');
      payload.first['subAccountName'] = 'changed';
      expect(directory.accounts.first.name, '交易台 / Desk A');
      expect(() => directory.accounts.clear(), throwsUnsupportedError);
    },
  );
  test('empty directory and parent-only response do not fabricate children', () {
    expect(mapSubaccountDirectory([], address: accountAddress, receivedAt: now).childCount, 0);
    expect(
      mapSubaccountDirectory(
        [subaccountRows().last],
        address: accountAddress,
        receivedAt: now,
      ).childCount,
      0,
    );
  });
  test('existing records above ten children are retained instead of truncated or rejected', () {
    final rows = List.generate(
      11,
      (i) => {'accountId': i + 1, 'subAccountName': '$i', 'parentAccount': false},
    );
    final directory = mapSubaccountDirectory(rows, address: accountAddress, receivedAt: now);
    expect(directory.childCount, 11);
    expect(directory.accounts.length, 11);
  });
  for (final entry in <(String, Object?)>[
    ('accountId', 0),
    ('accountId', -1),
    ('accountId', '123'),
    ('accountId', 1.5),
    ('subAccountName', null),
    ('subAccountName', 1),
    ('subAccountName', 'a' * 4097),
    ('parentAccount', 'true'),
    ('parentAccount', 1),
    ('parentAccount', null),
  ]) {
    test(
      'rejects malformed ${entry.$1} ${entry.$2.toString().length > 20 ? 'oversized' : entry.$2}',
      () {
        expect(
          () => mapSubaccountDirectory(
            [subaccountRows().first..[entry.$1] = entry.$2],
            address: accountAddress,
            receivedAt: now,
          ),
          throwsFormatException,
        );
      },
    );
  }
  test('rejects invalid envelopes, duplicate IDs, multiple parents and resource overflow', () {
    for (final payload in [
      null,
      <String, Object?>{},
      [null],
      [subaccountRows().first, subaccountRows().first],
      [subaccountRows().last, subaccountRows().last..['accountId'] = 3],
      List.filled(1001, subaccountRows().first),
    ]) {
      expect(
        () => mapSubaccountDirectory(payload, address: accountAddress, receivedAt: now),
        throwsFormatException,
      );
    }
  });
}
