import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../application/generated_subaccount_provider.dart';
import '../application/subaccount_list_provider.dart';
import '../domain/subaccount_management.dart';
import 'account_components.dart';
import 'account_authorization_page.dart';
import 'subaccount_backup_screen.dart';

class CreateSubaccountScreen extends ConsumerStatefulWidget {
  const CreateSubaccountScreen({super.key});
  @override
  ConsumerState<CreateSubaccountScreen> createState() => _CreateSubaccountScreenState();
}

class _CreateSubaccountScreenState extends ConsumerState<CreateSubaccountScreen> {
  final name = TextEditingController();
  bool authorize = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(generatedAccountProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), state = ref.watch(generatedAccountProvider);
    final identity = ref.watch(authProvider.select((s) => s.identity));
    final count = ref.watch(subaccountListProvider).account?.childCount;
    final enabled = canCreateSubaccount(identity) && count != null && count < 10;
    if (state.wallet != null && !state.busy) {
      return SubaccountBackupScreen(
        wallet: state.wallet!,
        accepted: state.accepted,
        failure: state.failure == null
            ? null
            : apiErrorText(context, state.failure!, state.details),
      );
    }
    if (authorize) {
      return AccountAuthorizationPage(
        heading: l.accountsConfirmCreation,
        summary: l.accountsCreateSummary(name.text.trim()),
        owner: identity?.walletAddress ?? '—',
        notice: l.accountsAuthorizeCreation,
        busy: state.busy,
        onCancel: () => setState(() => authorize = false),
        onOpen: enabled
            ? () => ref.read(generatedAccountProvider.notifier).create(name.text)
            : null,
        failure: state.failure == null
            ? null
            : apiErrorText(context, state.failure!, state.details),
      );
    }
    return AccountsPage(
      title: l.accountsCreate,
      canPop: !state.busy,
      actions: [closeAccountsButton(context, enabled: !state.busy)],
      footer: [
        AccountAction(
          key: const Key('generated-subaccount-create'),
          label: l.accountsContinue,
          busy: state.busy,
          onPressed: enabled && name.text.trim().isNotEmpty
              ? () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() => authorize = true);
                }
              : null,
        ),
        const SizedBox(height: 12),
        AccountAction(
          label: tr(context, 'cancel'),
          primary: false,
          onPressed: state.busy ? null : () => Navigator.pop(context),
        ),
      ],
      children: [
        Text(l.accountsNameHeading, style: PortfolioTypography.heading),
        const SizedBox(height: 16),
        Text(l.accountsNameHint, style: AccountTypography.secondary),
        const SizedBox(height: 36),
        Text(l.accountsName, style: PortfolioTypography.caption),
        const SizedBox(height: 6),
        TextField(
          key: const Key('generated-subaccount-name'),
          controller: name,
          enabled: enabled && !state.busy,
          maxLength: 64,
          style: PortfolioTypography.section,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            counterText: '',
            fillColor: AppColors.authInput,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PortfolioColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PortfolioColors.line),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        PortfolioCard(
          border: false,
          radius: 14,
          child: Column(
            children: [
              AccountValueRow(l.accountsOwner, l.portfolioMainAccount),
              const SizedBox(height: 12),
              AccountValueRow(l.accountsNewAccount, l.accountsNewWallet),
              const SizedBox(height: 12),
              AccountValueRow(l.accountsSlots, count == null ? '—' : l.accountsSlotsUsed(count)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AccountNotice(l.accountsCreateNotice),
        if (!canCreateSubaccount(identity)) AccountNotice(l.subaccountCreateExternalOnly),
        if (state.failure != null)
          Text(
            apiErrorText(context, state.failure!, state.details),
            style: AccountTypography.secondary.copyWith(color: PortfolioColors.negative),
          ),
      ],
    );
  }
}
