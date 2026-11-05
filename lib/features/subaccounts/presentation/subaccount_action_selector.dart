import 'package:flutter/material.dart';

import '../../../core/domain/wallet_operation.dart';
import '../../../core/presentation/wallet_operation_history.dart';
import '../../../l10n/generated/app_localizations.dart';

class SubaccountActionSelector extends StatelessWidget {
  const SubaccountActionSelector({
    super.key,
    required this.selected,
    required this.creationAllowed,
    required this.busy,
    required this.onChanged,
  });
  final WalletOperationKind selected;
  final bool creationAllowed, busy;
  final ValueChanged<WalletOperationKind> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<WalletOperationKind>(
        key: const Key('subaccount-action'),
        initialValue: selected,
        isExpanded: true,
        items: [
          for (final kind in WalletOperationKind.values.where(
            (k) => k != WalletOperationKind.withdrawal && k != WalletOperationKind.isolatedMargin,
          ))
            DropdownMenuItem(
              value: kind,
              enabled: kind != WalletOperationKind.createSubaccount || creationAllowed,
              child: Text(
                walletOperationLabel(context, kind),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: busy
            ? null
            : (kind) {
                if (kind != null &&
                    (kind != WalletOperationKind.createSubaccount || creationAllowed)) {
                  onChanged(kind);
                }
              },
      ),
      if (!creationAllowed)
        Text(
          AppLocalizations.of(context).subaccountCreateExternalOnly,
          key: const Key('subaccount-create-restriction'),
        ),
    ],
  );
}
