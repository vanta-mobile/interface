import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vanta/features/auth/data/wallet_preference_store.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

// Mutable test double for the platform preferences API.
// ignore: must_be_immutable
class _Preferences implements SharedPreferencesAsync {
  final values = <String, String>{};
  String? get value => values['value'];
  set value(String? value) {
    if (value == null) {
      values.remove('value');
    } else {
      values['value'] = value;
    }
  }

  @override
  Future<String?> getString(String key) async => value;
  @override
  Future<void> setString(String key, String value) async => this.value = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('old wallet preferences remain readable without a wallet name', () async {
    final preferences = _Preferences()
      ..value = jsonEncode({
        'userId': 'user',
        'kind': 'external',
        'address': '0x1111111111111111111111111111111111111111',
      });
    final store = LocalWalletPreferenceStore(preferences: preferences);
    final restored = await store.read();
    expect(restored?.userId, 'user');
    expect(restored?.kind, WalletKind.external);
    expect(restored?.walletName, isNull);
  });

  test('wallet name survives a new preference store', () async {
    final preferences = _Preferences();
    final store = LocalWalletPreferenceStore(preferences: preferences);
    await store.write(
      const WalletPreference(
        'user',
        WalletKind.external,
        '0x1111111111111111111111111111111111111111',
        walletName: 'MetaMask',
      ),
    );
    final restored = await LocalWalletPreferenceStore(preferences: preferences).read();
    expect(restored?.walletName, 'MetaMask');
    expect(restored?.address, '0x1111111111111111111111111111111111111111');
  });

  test('invalid optional names do not discard the selected wallet identity', () async {
    for (final name in ['', '   ', 7]) {
      final preferences = _Preferences()
        ..value = jsonEncode({
          'userId': 'user',
          'kind': 'external',
          'address': '0x1111111111111111111111111111111111111111',
          'walletName': name,
        });
      final restored = await LocalWalletPreferenceStore(preferences: preferences).read();
      expect(restored?.userId, 'user');
      expect(restored?.walletName, isNull);
    }
  });
}
