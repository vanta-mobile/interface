import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'internal_transfer_screen.dart';

void openInternalTransfer(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const InternalTransferScreen()));

class InternalTransferEntry extends StatelessWidget {
  const InternalTransferEntry({super.key});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('internal-transfer-entry'),
    onPressed: () => openInternalTransfer(context),
    icon: const Icon(Icons.swap_vert),
    label: Text(AppLocalizations.of(context).internalTransferTitle),
  );
}
