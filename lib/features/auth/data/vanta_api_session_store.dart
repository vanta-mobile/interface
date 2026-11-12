import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Contract `Issued` tokens for one wallet. Never shown, logged or shared with
/// another identity; the refresh token rotates on every use.
class VantaApiCredentials {
  const VantaApiCredentials({
    required this.address,
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
  });
  final String address, accessToken, refreshToken;
  final DateTime accessExpiresAt;

  bool usableAt(DateTime now) =>
      accessExpiresAt.isAfter(now.toUtc().add(const Duration(seconds: 30)));

  /// Maps `Issued`; [address] is the signed wallet, checked against `user.wallet`.
  static VantaApiCredentials fromIssued(
    Map<String, Object?> json, {
    required String address,
    required DateTime receivedAt,
  }) {
    final access = json['access_token'], refresh = json['refresh_token'];
    final expiresIn = json['expires_in'], user = json['user'];
    final wallet = user is Map ? user['wallet'] : null;
    if (access is! String ||
        access.isEmpty ||
        access.length > 8192 ||
        refresh is! String ||
        refresh.isEmpty ||
        refresh.length > 8192 ||
        expiresIn is! int ||
        expiresIn <= 0 ||
        (wallet != null && (wallet is! String || wallet.toLowerCase() != address.toLowerCase()))) {
      throw const FormatException('Invalid session');
    }
    return VantaApiCredentials(
      address: address.toLowerCase(),
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: receivedAt.toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  String encode() => jsonEncode({
    'address': address,
    'access': accessToken,
    'refresh': refreshToken,
    'expires': accessExpiresAt.toUtc().toIso8601String(),
  });

  static VantaApiCredentials? decode(String? source) {
    if (source == null) return null;
    try {
      final value = jsonDecode(source);
      if (value case {
        'address': final String address,
        'access': final String access,
        'refresh': final String refresh,
        'expires': final String expires,
      }) {
        return VantaApiCredentials(
          address: address,
          accessToken: access,
          refreshToken: refresh,
          accessExpiresAt: DateTime.parse(expires).toUtc(),
        );
      }
    } on FormatException {
      // A corrupt record is discarded; the user signs in again.
    }
    return null;
  }
}

abstract interface class VantaApiSessionStore {
  Future<VantaApiCredentials?> read();
  Future<void> write(VantaApiCredentials credentials);
  Future<void> clear();
}

class NativeVantaApiSessionStore implements VantaApiSessionStore {
  NativeVantaApiSessionStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'vanta_api_v1', resetOnError: false),
            iOptions: IOSOptions(
              accountName: 'vanta_api_v1',
              accessibility: KeychainAccessibility.unlocked_this_device,
              synchronizable: false,
            ),
          );
  static const _key = 'session';
  final FlutterSecureStorage _storage;
  @override
  Future<VantaApiCredentials?> read() async =>
      VantaApiCredentials.decode(await _storage.read(key: _key));
  @override
  Future<void> write(VantaApiCredentials credentials) =>
      _storage.write(key: _key, value: credentials.encode());
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
