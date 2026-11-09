import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../subaccounts/presentation/subaccount_list_screen.dart';
import '../../portfolio/application/portfolio_overview_provider.dart';
import '../application/navigation_provider.dart';
import 'widgets/account_sheet.dart';

/// Existing destinations remain reachable after adopting the four design tabs.
class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    void select(AppDestination destination) =>
        ref.read(appDestinationProvider.notifier).select(destination);
    return ListView(
      key: const Key('explore-page'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.exploreNavigation, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        ListTile(
          key: const Key('portfolio-preview-entry'),
          leading: const Icon(Icons.preview_outlined),
          title: Text(l.portfolioPreviewAccount),
          onTap: () {
            ref.read(portfolioPreviewProvider.notifier).select(true);
            select(AppDestination.portfolio);
          },
        ),
        ListTile(
          key: const Key('explore-assistant'),
          leading: const Icon(Icons.auto_awesome_outlined),
          title: Text(l.assistantNavigation),
          onTap: () => select(AppDestination.assistant),
        ),
        ListTile(
          key: const Key('explore-points'),
          leading: const Icon(Icons.diamond_outlined),
          title: Text(l.points),
          onTap: () => select(AppDestination.points),
        ),
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: Text(l.subaccountManagement),
          onTap: () => openSubaccountList(context),
        ),
        ListTile(
          key: const Key('portfolio-connect-demo'),
          leading: const Icon(Icons.science_outlined),
          title: Text(l.demo),
          onTap: () => showDemoAccountSheet(context),
        ),
      ],
    );
  }
}
