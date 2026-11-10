import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/presentation/account_read_controls.dart';
import '../../portfolio/presentation/account_snapshot_status.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/subaccount_list_provider.dart';
import '../domain/subaccount_directory.dart';
import 'subaccount_management_screen.dart';
import 'account_management_screen.dart';
import '../../../core/presentation/status_view.dart';

void openSubaccountList(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const AccountManagementScreen()));

class SubaccountListScreen extends ConsumerWidget {
  const SubaccountListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(subaccountListProvider);
    final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    final controller = ref.read(subaccountListProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.subaccountManagement)),
      body: SafeArea(
        child: ListView(
          key: const Key('subaccount-list-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.subaccountListScope),
            OutlinedButton(
              key: const Key('subaccount-management-entry'),
              onPressed: () => openSubaccountManagement(context),
              child: Text(l10n.subaccountActions),
            ),
            if (address != null) ...[
              const SizedBox(height: 12),
              Text(l10n.subaccountConnectedWallet),
              SelectableText(address, key: const Key('subaccount-connected-wallet')),
            ],
            const SizedBox(height: 12),
            AccountReadControls(
              failureView: true,
              state: state,
              onRead: controller.refresh,
              buttonKey: const Key('subaccount-list-refresh'),
              initialLabel: l10n.subaccountRead,
              refreshLabel: l10n.subaccountRefresh,
            ),
            if (state.busy)
              TextButton(
                key: const Key('subaccount-list-stop'),
                onPressed: controller.stopRead,
                child: Text(l10n.subaccountStopWaiting),
              ),
            AccountSnapshotStatus(
              state: state,
              timeKey: const Key('subaccount-list-time'),
              staleKey: const Key('subaccount-list-stale'),
            ),
            if (state.account case final directory?) ...[
              const SizedBox(height: 16),
              _DirectoryView(key: ValueKey(directory.address.toLowerCase()), directory: directory),
            ],
          ],
        ),
      ),
    );
  }
}

class _DirectoryView extends StatefulWidget {
  const _DirectoryView({super.key, required this.directory});
  final SubaccountDirectory directory;
  @override
  State<_DirectoryView> createState() => _DirectoryViewState();
}

class _DirectoryViewState extends State<_DirectoryView> with AutomaticKeepAliveClientMixin {
  String query = '';
  final search = TextEditingController();
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context), directory = widget.directory;
    final accounts = directory.accounts.where(
      (a) => a.name.toLowerCase().contains(query) || a.accountId.toString().contains(query),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.subaccountCount(directory.childCount)),
        if (directory.childCount == 0) StatusEmptyView(message: l10n.subaccountNoChildren),
        Text(l10n.subaccountListBoundaries, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        TextField(
          key: const Key('subaccount-list-search'),
          controller: search,
          decoration: InputDecoration(
            labelText: l10n.subaccountSearch,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => query = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),
        if (accounts.isEmpty && directory.accounts.isNotEmpty) Text(l10n.subaccountNoMatches),
        for (final account in accounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SubaccountCard(account: account),
          ),
      ],
    );
  }
}

class _SubaccountCard extends StatelessWidget {
  const _SubaccountCard({required this.account});
  final AsterSubaccount account;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            account.isParent ? l10n.subaccountParent : l10n.subaccountChild,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SelectableText(
            account.name.trim().isEmpty ? l10n.subaccountUnnamed : account.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(l10n.subaccountId),
          Row(
            children: [
              Expanded(child: SelectableText(account.accountId.toString())),
              IconButton(
                key: Key('subaccount-copy-${account.accountId}'),
                tooltip: l10n.subaccountCopyId,
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: account.accountId.toString())),
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
