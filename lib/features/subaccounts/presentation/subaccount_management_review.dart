part of 'subaccount_management_screen.dart';

class _SubaccountReview extends StatelessWidget {
  const _SubaccountReview({
    required this.review,
    required this.busy,
    required this.signature,
    required this.controller,
  });
  final SubaccountManagementReview review;
  final bool busy;
  final TextEditingController signature;
  final SubaccountManagementController controller;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(l.subaccountActionReview),
        Text(walletOperationLabel(context, review.record.kind)),
        for (final t in review.record.terms.entries)
          SelectableText(
            '${tr(context, switch (t.key) {
              'child' => 'subaccountChildAddress',
              'name' => 'subaccountName',
              'from' => 'subaccountFrom',
              'to' => 'subaccountTo',
              'asset' => 'internalTransferAsset',
              'amount' => 'internalTransferAmount',
              'direction' => 'subaccountTransferDirection',
              _ => 'subaccountId',
            })}: ${walletOperationTermValue(context, t.key, t.value)}',
          ),
        Text(l.subaccountReviewExpires),
        if (review.record.kind == WalletOperationKind.createSubaccount) ...[
          Text(l.subaccountChildSignatureInstructions),
          OutlinedButton(
            key: const Key('subaccount-copy-child-challenge'),
            onPressed: busy
                ? null
                : () => Clipboard.setData(ClipboardData(text: jsonEncode(review.childTypedData))),
            child: Text(l.subaccountCopyChallenge),
          ),
          TextField(
            key: const Key('subaccount-child-signature'),
            controller: signature,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !busy,
            decoration: InputDecoration(labelText: l.subaccountChildSignature),
          ),
        ],
        FilledButton(
          key: const Key('subaccount-action-confirm'),
          onPressed: busy
              ? null
              : () => controller.confirm(review, childSignature: signature.text.trim()),
          child: Text(l.subaccountActionConfirm),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () {
                  signature.clear();
                  controller.cancel();
                },
          child: Text(tr(context, 'cancel')),
        ),
      ],
    );
  }
}
