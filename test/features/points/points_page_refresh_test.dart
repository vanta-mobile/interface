import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/points/application/points_provider.dart';
import 'package:vanta/features/points/domain/points.dart';

import '../../support/identity_repository.dart';
import '../../support/points.dart';

void main() {
  test(
    'page refresh waits for all public sections and failure details stay section-scoped',
    () async {
      final now = DateTime.utc(2026, 11, 6, 12);
      final repository = TestPointsRepository(now: () => now), identity = TestIdentityRepository();
      final container = ProviderContainer(
        overrides: [
          pointsRepositoryProvider.overrideWithValue(repository),
          pointsClockProvider.overrideWithValue(() => now),
          identityRepositoryProvider.overrideWithValue(identity),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.dispose();
      });
      final listeners = [
        container.listen(currentPointsCampaignProvider, (_, _) {}),
        container.listen(pointsCampaignsProvider, (_, _) {}),
        container.listen(pointsLeaderboardProvider(null), (_, _) {}),
        container.listen(walletPointsProvider, (_, _) {}),
        container.listen(pointsPageRefreshProvider, (_, _) {}),
      ];
      addTearDown(() {
        for (final listener in listeners) {
          listener.close();
        }
      });
      await Future<void>.delayed(Duration.zero);
      final old = container.read(currentPointsCampaignProvider).snapshot;
      repository.calls.clear();
      for (final key in ['current', 'cycles', 'board:total']) {
        repository.gates[key] = Completer<void>();
      }
      repository.failures['current'] = const PointsFailure(
        'pointsUnavailable',
        details: ApiErrorDetails(message: 'Campaign is temporarily unavailable.', status: 503),
      );
      var done = false;
      final refresh = container.read(pointsPageRefreshProvider)()..then((_) => done = true);
      final duplicate = container.read(pointsPageRefreshProvider)();
      expect(identical(refresh, duplicate), isTrue);
      repository.gates['current']!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      expect(container.read(currentPointsCampaignProvider).snapshot, same(old));
      expect(
        container.read(currentPointsCampaignProvider).errorDetails?.message,
        'Campaign is temporarily unavailable.',
      );
      expect(container.read(pointsCampaignsProvider).errorDetails, isNull);
      repository.gates['cycles']!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      repository.gates['board:total']!.complete();
      await refresh;
      expect(done, isTrue);
      // Signed out: the default period board but no wallet reads.
      expect(repository.calls, unorderedEquals(['current', 'cycles', 'board:total', 'board:17']));
      expect(identity.wallets, 0);
    },
  );
}
