import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/futures_asset_mode_provider.dart';
import 'package:vanta/features/trade/presentation/trade_theme.dart';
import 'package:vanta/features/portfolio/application/futures_position_mode_provider.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';
import 'package:vanta/features/portfolio/presentation/futures_asset_mode_sheet.dart';
import 'package:vanta/features/portfolio/presentation/futures_position_mode_sheet.dart';
import 'package:vanta/features/portfolio/presentation/mode_settings_sheet.dart';
import 'package:vanta/features/portfolio/presentation/multi_asset_activation_sheet.dart';

import '../../support/aster_account.dart';
import '../../support/futures_asset_mode.dart';
import '../../support/futures_position_mode.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

void main() {
  for (final name in ['asset', 'position', 'blocked', 'resolving', 'ready']) {
    testWidgets('mode settings design $name', (t) async {
      final font = FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      await font.load();
      final identity = TestIdentityRepository()..restored = signingIdentity;
      addTearDown(identity.dispose);
      final r = TestFuturesAssetModeRepository();
      if (['blocked', 'resolving', 'ready'].contains(name)) {
        r.context = FuturesAssetModeContext(
          address: accountAddress,
          current: FuturesAssetMode.single,
          isolatedSymbols: name == 'blocked' ? ['ETHUSDT'] : [],
          markets: [
            AssetModeMarket(
              symbol: 'ETHUSDT',
              marginMode: PositionMarginMode.isolated,
              hasPosition: name == 'blocked',
              hasCollateral: false,
            ),
          ],
          receivedAt: assetModeClock,
        );
      }
      final c = setup(
        t,
        width: 393,
        identityRepository: identity,
        futuresAssetModeRepository: r,
        assetModeClock: () => assetModeClock,
        futuresPositionModeRepository: TestFuturesPositionModeRepository(),
        positionModeClock: () => positionModeClock,
        language: const Locale('en'),
      );
      t.view.physicalSize = const Size(393, 852);
      await launch(t, c);
      await c.read(futuresAssetModeProvider.notifier).load();
      await c.read(futuresPositionModeProvider.notifier).load();
      final widget = switch (name) {
        'asset' => const FuturesAssetModeSheet(),
        'position' => const FuturesPositionModeSheet(),
        _ => const MultiAssetActivationSheet(),
      };
      showModeSettingsSheet<void>(
        t.element(find.byType(Navigator).first),
        RepaintBoundary(
          key: const Key('mode-design-capture'),
          child: Material(color: TradeColors.sheet, child: widget),
        ),
      );
      await t.pumpAndSettle();
      if (name == 'ready') {
        r.context = FuturesAssetModeContext(
          address: accountAddress,
          current: FuturesAssetMode.single,
          isolatedSymbols: const [],
          markets: const [
            AssetModeMarket(
              symbol: 'ETHUSDT',
              marginMode: PositionMarginMode.cross,
              hasPosition: false,
              hasCollateral: false,
            ),
          ],
          receivedAt: assetModeClock,
        );
        await c.read(futuresAssetModeProvider.notifier).load();
        await t.pumpAndSettle();
      }
      await expectLater(
        find.byKey(const Key('mode-design-capture')),
        matchesGoldenFile('goldens/modes-$name.png'),
      );
      expect(t.takeException(), null);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
