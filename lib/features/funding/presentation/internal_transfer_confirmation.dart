import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/internal_transfer_provider.dart';
import '../domain/internal_transfer.dart';
import 'internal_transfer_form.dart';

class InternalTransferConfirmation extends ConsumerWidget {
  const InternalTransferConfirmation({super.key, required this.review});
  final InternalTransferReview review;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context),
        valid = identical(ref.watch(internalTransferProvider).review, review),
        c = review.context;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.internalTransferReview),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.internalTransferRisk),
          SelectableText(c.address),
          Text(internalTransferDirectionLabel(l10n, c.direction)),
          ValueRow(l10n.internalTransferAmount, '${review.amount} ${c.assetName}'),
          ValueRow(l10n.internalTransferMaximum, '${c.maximum} ${c.assetName}'),
          Text(l10n.internalTransferClientId),
          SelectableText(review.clientId),
          Text(l10n.internalTransferReadHint),
          if (!valid) Text(l10n.internalTransferChanged),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('internal-transfer-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('internal-transfer-confirm'),
          onPressed: valid ? () => Navigator.pop(context, true) : null,
          child: Text(l10n.internalTransferConfirm),
        ),
      ],
    );
  }
}
