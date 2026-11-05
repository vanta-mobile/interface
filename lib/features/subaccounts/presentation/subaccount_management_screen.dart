import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/wallet_operation_provider.dart';
import '../../../core/domain/wallet_operation.dart';
import '../../../core/presentation/wallet_operation_history.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/subaccount_management_provider.dart';
import '../domain/subaccount_management.dart';
import 'subaccount_action_selector.dart';

part 'subaccount_management_review.dart';

void openSubaccountManagement(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const SubaccountManagementScreen()));

class SubaccountManagementScreen extends ConsumerStatefulWidget {
  const SubaccountManagementScreen({super.key});
  @override
  ConsumerState<SubaccountManagementScreen> createState() => _SubaccountManagementScreenState();
}

class _SubaccountManagementScreenState extends ConsumerState<SubaccountManagementScreen> {
  final child = TextEditingController(),
      name = TextEditingController(),
      amount = TextEditingController(),
      asset = TextEditingController(text: 'USDT'),
      switchAddress = TextEditingController(),
      signature = TextEditingController();
  WalletOperationKind kind = WalletOperationKind.createSubaccount;
  String direction = 'FUTURE_FUTURE';
  bool toChild = true;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(subaccountManagementProvider.notifier).cancel();
    });
  }

  @override
  void dispose() {
    for (final c in [child, name, amount, asset, switchAddress, signature]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        s = ref.watch(subaccountManagementProvider),
        auth = ref.watch(authProvider);
    final controller = ref.read(subaccountManagementProvider.notifier);
    ref.listen(
      authProvider.select(
        (a) => (
          a.identity?.id,
          a.identity?.walletAddress,
          a.identity?.walletKind,
          a.identity?.signingAvailable,
        ),
      ),
      (a, b) {
        if (a != b) {
          setState(() {
            for (final c in [child, name, amount, switchAddress, signature]) {
              c.clear();
            }
          });
        }
      },
    );
    final address = auth.identity?.walletAddress;
    final creationAllowed = canCreateSubaccount(auth.identity);
    final creationBlocked = kind == WalletOperationKind.createSubaccount && !creationAllowed;
    final saved = ref
        .watch(walletOperationStorageProvider)
        .records
        .where((r) => r.kind == WalletOperationKind.createSubaccount && r.acknowledged)
        .toList();
    final masters = saved
        .where(
          (r) =>
              r.address.toLowerCase() == address?.toLowerCase() ||
              r.terms['child']!.toLowerCase() == address?.toLowerCase(),
        )
        .map((r) => r.address.toLowerCase())
        .toSet();
    final known = saved.where((r) => masters.contains(r.address.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: Text(l.subaccountActions)),
      body: SafeArea(
        child: ListView(
          key: const Key('subaccount-management-page'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.subaccountActionsScope),
            if (address != null) SelectableText(address),
            const SizedBox(height: 12),
            SubaccountActionSelector(
              selected: kind,
              creationAllowed: creationAllowed,
              busy: s.busy,
              onChanged: (k) {
                controller.cancel();
                setState(() {
                  kind = k;
                  signature.clear();
                });
              },
            ),
            TextField(
              key: const Key('subaccount-child-address'),
              controller: child,
              enabled: !creationBlocked && !s.busy && s.review == null,
              autocorrect: false,
              decoration: InputDecoration(labelText: l.subaccountChildAddress),
            ),
            if (kind == WalletOperationKind.createSubaccount)
              TextField(
                key: const Key('subaccount-name'),
                controller: name,
                enabled: creationAllowed && !s.busy && s.review == null,
                maxLength: 64,
                decoration: InputDecoration(labelText: l.subaccountName),
              ),
            if (kind == WalletOperationKind.subaccountTransfer) ...[
              Text(l.subaccountTransferScope),
              DropdownButtonFormField<bool>(
                initialValue: toChild,
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: true, child: Text(l.subaccountMasterToChild)),
                  DropdownMenuItem(value: false, child: Text(l.subaccountChildToMaster)),
                ],
                onChanged: s.busy || s.review != null ? null : (v) => setState(() => toChild = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: direction,
                isExpanded: true,
                items: [
                  for (final d in ['FUTURE_FUTURE', 'FUTURE_SPOT', 'SPOT_FUTURE', 'SPOT_SPOT'])
                    DropdownMenuItem(
                      value: d,
                      child: Text(walletOperationTermValue(context, 'direction', d)),
                    ),
                ],
                onChanged: s.busy || s.review != null
                    ? null
                    : (v) => setState(() => direction = v!),
              ),
              TextField(
                key: const Key('subaccount-transfer-asset'),
                controller: asset,
                enabled: !s.busy && s.review == null,
                decoration: InputDecoration(labelText: l.internalTransferAsset),
              ),
              TextField(
                key: const Key('subaccount-transfer-amount'),
                controller: amount,
                enabled: !s.busy && s.review == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.internalTransferAmount),
              ),
            ],
            FilledButton(
              key: const Key('subaccount-action-prepare'),
              onPressed:
                  creationBlocked || s.busy || s.review != null || address == null || auth.busy
                  ? null
                  : () => controller.prepare(kind, switch (kind) {
                      WalletOperationKind.createSubaccount => {
                        'child': child.text.trim(),
                        'name': name.text.trim(),
                      },
                      WalletOperationKind.freezeSubaccount ||
                      WalletOperationKind.unfreezeSubaccount => {'child': child.text.trim()},
                      WalletOperationKind.subaccountTransfer => {
                        'from': toChild ? address : child.text.trim(),
                        'to': toChild ? child.text.trim() : address,
                        'asset': asset.text.trim(),
                        'amount': amount.text.trim(),
                        'direction': direction,
                      },
                      _ => {},
                    }),
              child: Text(l.subaccountActionPrepare),
            ),
            if (s.review case final review?
                when review.record.kind != WalletOperationKind.createSubaccount || creationAllowed)
              _SubaccountReview(
                review: review,
                busy: s.busy,
                signature: signature,
                controller: controller,
              ),
            if (s.busy) ...[
              const LinearProgressIndicator(),
              TextButton(onPressed: controller.stop, child: Text(l.subaccountStopWaiting)),
            ],
            if (s.failure case final failure?)
              Text(tr(context, failure), style: const TextStyle(color: AppColors.negative)),
            if (s.result != null) Text(l.walletOperationAcknowledged),
            if (known.isNotEmpty) ...[
              const Divider(),
              Text(l.subaccountKnownAddresses),
              Text(l.subaccountSwitchScope),
              for (final master in masters)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.subaccountParent),
                    SelectableText(master),
                    OutlinedButton(
                      onPressed: s.busy || auth.busy || master == address?.toLowerCase()
                          ? null
                          : () => _switch(master),
                      child: Text(l.subaccountSwitch),
                    ),
                  ],
                ),
              for (final record in known)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectableText(record.terms['name']!),
                    SelectableText(record.terms['child']!),
                    OutlinedButton(
                      onPressed:
                          s.busy ||
                              auth.busy ||
                              record.terms['child']!.toLowerCase() == address?.toLowerCase()
                          ? null
                          : () => _switch(record.terms['child']!),
                      child: Text(l.subaccountSwitch),
                    ),
                  ],
                ),
            ],
            TextField(
              key: const Key('subaccount-switch-address'),
              controller: switchAddress,
              enabled: !s.busy && !auth.busy,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: l.subaccountChildAddress),
            ),
            OutlinedButton(
              key: const Key('subaccount-switch-entered'),
              onPressed: s.busy || auth.busy
                  ? null
                  : () {
                      if (validOperationAddress(switchAddress.text.trim())) {
                        _switch(switchAddress.text.trim());
                      }
                    },
              child: Text(l.subaccountSwitchEntered),
            ),
            const Divider(),
            const WalletOperationHistory(withdrawals: false),
          ],
        ),
      ),
    );
  }

  Future<void> _switch(String target) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.subaccountSwitch),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Text(l.subaccountSwitchScope), SelectableText(target)],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr(c, 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.subaccountSwitch)),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).switchToWallet(context, target);
    }
  }
}
