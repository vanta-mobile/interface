import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'rebalance_screen.dart';

void openRebalance(BuildContext context) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const RebalanceScreen()));

class RebalanceEntry extends StatelessWidget {
  const RebalanceEntry({super.key});
  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: const Key('rebalance-entry'),
    onPressed: () => openRebalance(context),
    child: Text(AppLocalizations.of(context).rebalanceTitle),
  );
}
