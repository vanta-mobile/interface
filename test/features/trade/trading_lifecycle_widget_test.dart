import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';

import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('page observer preserves active order across wallet pause/resume $language', (
      tester,
    ) async {
      final f = NavigationFixture(tester, language: language, width: 320, scale: 1.5);
      await launch(tester, f.container);
      await f.container.read(liveOrderProvider.notifier).load('BTCUSDT');
      final activity = f.container.read(symbolSettingsActivityProvider.notifier);
      final lease = activity.acquire(SymbolSetting.order)!;
      final auth = f.container.read(authProvider);
      final initializations = f.identity.initializations;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(f.container.read(quoteUpdatesActiveProvider), false);
      expect(f.container.read(liveOrderProvider).stale, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(f.identity.initializations, initializations);
      expect(f.container.read(authProvider), same(auth));
      expect(f.container.read(liveOrderProvider).stale, false);
      activity.finish(lease, unresolved: false);
      await tester.pumpAndSettle();
      expect(f.identity.initializations, initializations + 1);
      expect(f.container.read(authProvider), same(auth));
      expect(f.container.read(liveOrderProvider).stale, false);
      expect(f.identity.wallets, 0);
      expect(tester.takeException(), isNull);
      await f.close(tester);
    });
  }
}
