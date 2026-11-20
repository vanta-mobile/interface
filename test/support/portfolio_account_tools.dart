import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/aster_account_panel.dart';
import 'package:vanta/features/portfolio/presentation/spot_account_panel.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

/// Component tests exercise the retained account tools on their own route.
/// The app no longer links to them since the portfolio preview was removed.
Future<void> openPortfolioAccountTools(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(Navigator).first)).push<void>(
    MaterialPageRoute(
      builder: (context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            bottom: TabBar(
              tabs: [
                Tab(text: AppLocalizations.of(context).accountPerpetualTab),
                Tab(text: AppLocalizations.of(context).accountSpotTab),
              ],
            ),
          ),
          body: const SafeArea(
            child: TabBarView(
              children: [
                SingleChildScrollView(padding: EdgeInsets.all(16), child: AsterAccountPanel()),
                SingleChildScrollView(padding: EdgeInsets.all(16), child: SpotAccountPanel()),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
