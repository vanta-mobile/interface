import 'dart:convert';

import '../domain/assistant.dart';

class AssistantConfiguration {
  const AssistantConfiguration._(this.origin, this.publicKey);
  static final runtimeUri = Uri.https('app.vanta.exchange', '/config.js');
  static final trustedOrigin = Uri.https('nltkngcwiuydkpmqrili.supabase.co');
  final Uri origin;
  final String publicKey;

  /// Read JSON data only. Never evaluate the website's JavaScript.
  factory AssistantConfiguration.fromRuntime(String source) {
    const prefix = 'window.__RUNTIME_CONFIG__';
    final match = RegExp(r'^\s*window\.__RUNTIME_CONFIG__\s*=\s*(\{[\s\S]*\})\s*;?\s*$')
        .firstMatch(source);
    if (source.length > 65536 || !source.trimLeft().startsWith(prefix) || match == null) {
      throw const AssistantFailure('assistantConfiguration');
    }
    try {
      final value = jsonDecode(match[1]!);
      if (value is! Map<String, Object?> || value['VITE_SUPABASE_URL'] != trustedOrigin.origin) {
        throw const AssistantFailure('assistantConfiguration');
      }
      final key = value['VITE_SUPABASE_ANON_KEY'];
      if (key is! String || key.length > 4096 || key.contains(RegExp(r'\s'))) {
        throw const AssistantFailure('assistantConfiguration');
      }
      // The anonymous browser key is public, but a service-role key must never
      // be accepted even if a future runtime configuration accidentally exposes one.
      final parts = key.split('.');
      if (parts.length != 3 || parts.any((p) => !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(p))) {
        throw const AssistantFailure('assistantConfiguration');
      }
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (claims is! Map ||
          claims['role'] != 'anon' ||
          claims['ref'] != trustedOrigin.host.split('.').first) {
        throw const AssistantFailure('assistantConfiguration');
      }
      return AssistantConfiguration._(trustedOrigin, key);
    } on AssistantFailure {
      rethrow;
    } catch (_) {
      throw const AssistantFailure('assistantConfiguration');
    }
  }

  @override
  String toString() => 'AssistantConfiguration(${origin.host})';
}
