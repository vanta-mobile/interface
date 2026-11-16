import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/network/request_scope.dart';
import '../../../core/vanta_api/vanta_api_http.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../data/api_notification_symbols_repository.dart';
import '../domain/api_notification.dart';

final apiNotificationSymbolsRepositoryProvider =
    Provider.autoDispose<ApiNotificationSymbolsRepository?>((ref) {
      final base = ref.watch(vantaApiConfigurationProvider).baseUri;
      if (base == null) return null;
      final repository = ApiNotificationSymbolsRepository(
        VantaApiHttp(baseUri: base, client: ref.watch(backendHttpPoolProvider).lease()),
      );
      ref.onDispose(repository.close);
      return repository;
    });

final apiNotificationUnitsProvider =
    FutureProvider.autoDispose<Map<String, NotificationSymbolUnits>>((ref) async {
      final repository = ref.watch(apiNotificationSymbolsRepositoryProvider);
      if (repository == null) return const {};
      return RequestScope.runOwned(() => ref.mounted, repository.read);
    }, retry: (_, _) => null);
