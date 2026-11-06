import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/auth_session.dart';

/// Only public identity metadata is persisted here, never tokens or keys.
class WalletPreference {
  const WalletPreference(this.userId, this.kind, this.address, {this.walletName});
  final String userId;
  final WalletKind kind;
  final String? address;
  final String? walletName;
}

abstract interface class WalletPreferenceStore {
  Future<WalletPreference?> read();
  Future<void> write(WalletPreference preference);
}

class LocalWalletPreferenceStore implements WalletPreferenceStore {
  LocalWalletPreferenceStore({SharedPreferencesAsync? preferences})
    : _providedPreferences = preferences;
  final SharedPreferencesAsync? _providedPreferences;
  late final _preferences = _providedPreferences ?? SharedPreferencesAsync();
  static const _key = 'vanta.primaryWallet';

  @override
  Future<WalletPreference?> read() async {
    final raw = await _preferences.getString(_key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['userId'] is! String) return null;
      final kind = WalletKind.values.where((kind) => kind.name == data['kind']).firstOrNull;
      final address = data['address'];
      if (kind == null || (address != null && address is! String)) return null;
      final name = data['walletName'];
      return WalletPreference(
        data['userId'] as String,
        kind,
        address as String?,
        walletName: name is String && name.trim().isNotEmpty ? name.trim() : null,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(WalletPreference preference) => _preferences.setString(
    _key,
    jsonEncode({
      'userId': preference.userId,
      'kind': preference.kind.name,
      'address': preference.address,
      'walletName': preference.walletName,
    }),
  );
}
