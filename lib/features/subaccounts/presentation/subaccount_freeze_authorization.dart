import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/wallet_operation.dart';
import '../../../core/errors/error_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/account_entries_provider.dart';
import '../application/subaccount_management_provider.dart';
import '../domain/account_entry.dart';
import 'account_authorization_page.dart';

class SubaccountFreezeAuthorization extends ConsumerStatefulWidget {
  const SubaccountFreezeAuthorization({super.key, required this.entry});
  final AccountEntry entry;

  @override
  ConsumerState<SubaccountFreezeAuthorization> createState() => _FreezeAuthorizationState();
}

class _FreezeAuthorizationState extends ConsumerState<SubaccountFreezeAuthorization> {
  bool busy = false;
  String? failure;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), entry = widget.entry;
    ref.watch(accountStatusUpdateProvider);
    final manage = ref.watch(canManageAccountsProvider);
    return AccountAuthorizationPage(
      heading: entry.freezeRequested ? l.accountsConfirmUnfreeze : l.accountsConfirmFreeze,
      summary:
          '${entry.name} · ${entry.freezeRequested ? l.accountsUnfreezeAction : l.accountsFreezeAction}',
      owner: entry.owner,
      notice: entry.freezeRequested ? l.accountsAuthorizeUnfreeze : l.accountsAuthorizeFreeze,
      busy: busy,
      failure: failure,
      showCancel: true,
      onCancel: () => Navigator.pop(context),
      onOpen: manage ? _submit : null,
    );
  }

  Future<void> _submit() async {
    if (busy || !ref.read(canManageAccountsProvider)) return;
    setState(() {
      busy = true;
      failure = null;
    });
    final controller = ref.read(accountStatusUpdateProvider.notifier);
    controller.cancel();
    await controller.prepare(
      widget.entry.freezeRequested
          ? WalletOperationKind.unfreezeSubaccount
          : WalletOperationKind.freezeSubaccount,
      {'child': widget.entry.address},
    );
    if (!mounted) return;
    final review = ref.read(accountStatusUpdateProvider).review;
    if (review != null) await controller.confirm(review);
    if (!mounted) return;
    final state = ref.read(accountStatusUpdateProvider);
    if (state.result != null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      busy = false;
      failure = state.failure == null
          ? AppLocalizations.of(context).authWalletChanged
          : apiErrorText(context, state.failure!, state.errorDetails);
    });
  }
}
