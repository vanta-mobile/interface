import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';
import 'package:vanta/features/portfolio/presentation/batch_close_controls.dart';
import 'package:vanta/features/portfolio/presentation/futures_asset_mode_screen.dart';
import 'package:vanta/features/portfolio/presentation/futures_position_mode_screen.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/features/portfolio/presentation/position_leverage_screen.dart';
import 'package:vanta/features/portfolio/presentation/position_margin_mode_screen.dart';
import 'package:vanta/features/portfolio/presentation/position_tpsl_screen.dart';
import 'package:vanta/features/portfolio/presentation/scaled_order_screen.dart';
import 'package:vanta/features/trade/presentation/widgets/trading_header.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/order_recovery.dart';
import '../../support/position_risk.dart';
import '../../support/trade_fixture.dart';

void main() {
  for (final language in ['en', 'zh']) {
    for (final storage in ['pending', 'loading', 'failure']) {
      testWidgets('no recovery UI on trading/settings pages, $storage $language', (tester) async {
        final record = OrderRecoveryRecord(
          query: OrderQuery.capture(liveIntent()),
          createdAt: liveOrderClock,
        );
        final journal = MemoryOrderRecoveryJournal(records: [record]);
        addTearDown(journal.close);
        if (storage != 'pending') {
          journal.publish(
            OrderRecoverySnapshot(
              records: [record],
              ready: storage != 'loading',
              failure: storage == 'failure'
                  ? const AccountReadFailure('orderRecoveryStorage')
                  : null,
            ),
          );
        }
        final identity = TestIdentityRepository()..restored = signingIdentity;
        addTearDown(identity.dispose);
        final repository = TestOrderRecoveryRepository(journal);
        final container = setup(
          tester,
          width: 600,
          language: Locale(language),
          identityRepository: identity,
          recoveryJournal: journal,
          recoveryRepository: repository,
        );
        await launch(tester, container);
        final pages = <Widget>[
          PositionTpSlScreen(position: positionRiskFixture().positions.first),
          const PositionLeverageScreen(symbol: 'BTCUSDT'),
          const PositionMarginModeScreen(symbol: 'BTCUSDT'),
          const FuturesPositionModeScreen(),
          const FuturesAssetModeScreen(),
          const ScaledOrderScreen(symbol: 'BTCUSDT'),
          const Scaffold(body: BatchCloseControls()),
          const LiveOrderScreen(symbol: 'BTCUSDT'),
          Scaffold(body: TradingHeader(onLanguage: () {})),
        ];
        for (final page in pages) {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: vantaTheme(),
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(tester.element(find.byWidget(page)));
          expect(find.text(l10n.orderRecoveryTitle), findsNothing, reason: '${page.runtimeType}');
          expect(find.text(l10n.orderRecoveryPending), findsNothing, reason: '${page.runtimeType}');
          expect(find.byKey(const Key('order-recovery-entry')), findsNothing);
          expect(repository.calls, 0);
          expect(journal.snapshot.records.single.key, record.key);
          expect(tester.takeException(), null, reason: '${page.runtimeType}');
        }
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      });
    }
  }
}
