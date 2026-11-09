import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'aster_account_panel.dart';
import 'spot_account_panel.dart';

/// Retains the existing account tools without adding them to the overview.
class PortfolioAccountDetails extends StatelessWidget {
  const PortfolioAccountDetails({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.account),
          bottom: TabBar(
            tabs: [
              Tab(text: l.accountPerpetualTab),
              Tab(text: l.accountSpotTab),
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
    );
  }
}
