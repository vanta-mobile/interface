import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../notifications/application/push_device_provider.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../../trade/presentation/trade_theme.dart';
import '../application/settings_providers.dart';
import 'settings_app_card.dart';
import 'settings_mode_card.dart';

void openSettings(BuildContext context) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const SettingsScreen()));

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      key: const Key('settings-screen'),
      backgroundColor: TradeColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 7, 16, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('settings-back'),
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Navigator.maybePop(context),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 44),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: PortfolioIcon('back.svg', size: 24),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.modeAccountSettings, style: TradeTypography.heading)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => Future.wait([
                  refreshAccountModes(ref, context),
                  ref.read(pushDeviceProvider.notifier).refresh(),
                  ref.read(appCacheProvider.notifier).measure(),
                ]),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: const [SettingsModeCard(), SizedBox(height: 16), SettingsAppCard()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
