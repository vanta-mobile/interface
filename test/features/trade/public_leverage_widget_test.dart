import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/market/application/public_leverage_provider.dart';
import 'package:vanta/features/market/domain/public_leverage.dart';
import 'package:vanta/features/trade/presentation/widgets/trade_account_settings.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('public default follows symbol without wallet and missing market stays unknown', (
    t,
  ) async {
    Future<void> show(String symbol) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            publicLeverageProvider.overrideWith(
              (ref) async => {
                'BTCUSDT': PublicLeverage([(1, 200)]),
                'SUSHIUSDT': PublicLeverage([(1, 5)]),
              },
            ),
          ],
          child: MaterialApp(
            theme: vantaTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TradeAccountSettings(symbol: symbol, data: null, enabled: false)),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    await show('BTCUSDT');
    expect(find.text('20×'), findsOneWidget);
    final l = AppLocalizations.of(t.element(find.byType(TradeAccountSettings)));
    expect(find.text(l.cross), findsOneWidget);
    expect(find.text(l.assetModeMulti), findsOneWidget);
    await show('SUSHIUSDT');
    expect(find.text('5×'), findsOneWidget);
    expect(find.text('20×'), findsNothing);
    await show('UNKNOWNUSDT');
    expect(find.text('—'), findsOneWidget);
    expect(find.text(l.cross), findsOneWidget);
    expect(find.text(l.assetModeMulti), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
