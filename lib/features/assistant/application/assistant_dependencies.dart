import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_message_signer.dart';
import '../data/assistant_auth_repository.dart';
import '../data/assistant_auth_service.dart';
import '../data/assistant_chat_repository.dart';
import '../data/assistant_http.dart';
import '../data/assistant_secure_store.dart';
import '../data/assistant_vault.dart';

final assistantClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final assistantIdProvider = Provider<String Function()>(
  (_) => () {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  },
);
final assistantVaultProvider = Provider<AssistantVault>(
  (_) => AssistantVault(NativeAssistantSecureStore()),
);
final assistantHttpProvider = Provider.autoDispose<AssistantHttp>((ref) {
  final service = AssistantHttp(now: ref.watch(assistantClockProvider));
  ref.onDispose(service.close);
  return service;
});
final assistantAuthRepositoryProvider = Provider.autoDispose<AssistantAuthRepository>((ref) {
  final repository = AssistantAuthRepository(
    service: AssistantAuthService(ref.watch(assistantHttpProvider)),
    vault: ref.watch(assistantVaultProvider),
    now: ref.watch(assistantClockProvider),
    signer: () {
      final identity = ref.read(identityRepositoryProvider);
      if (identity is! WalletMessageSigner) throw const AuthFailure('authWalletReconnect');
      return identity as WalletMessageSigner;
    },
  );
  ref.onDispose(repository.close);
  return repository;
});
final assistantChatRepositoryProvider = Provider.autoDispose<AssistantChatRepository>(
  (ref) => AssistantChatRepository(ref.watch(assistantHttpProvider)),
);
final assistantLinkOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
