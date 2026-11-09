import 'features/funding/application/deposit_submission_provider.dart';
import 'features/funding/data/deposit_submission_journal.dart';
import 'core/application/wallet_operation_provider.dart';
import 'features/portfolio/application/position_margin_storage_provider.dart';
import 'core/data/wallet_operation_journal.dart';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'features/auth/application/auth_provider.dart';
import 'features/trade/application/providers.dart';
import 'features/trade/presentation/trading_screen.dart';

import 'package:path_provider/path_provider.dart';

import 'features/portfolio/data/order_recovery_journal.dart';
import 'features/portfolio/data/rebalance_journal.dart';
import 'features/funding/data/internal_transfer_journal.dart';
import 'features/funding/application/internal_transfer_storage_provider.dart';
import 'features/portfolio/application/rebalance_storage_provider.dart';
import 'features/portfolio/application/order_recovery_provider.dart';
import 'features/funding/data/deposit_approval_journal.dart';
import 'features/funding/application/deposit_approval_provider.dart';
import 'features/notifications/application/push_messaging_provider.dart';
import 'features/notifications/data/firebase_push_messaging_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final pushMessaging = await initializeFirebaseMessaging();
  final recovery = FileOrderRecoveryJournal(getApplicationSupportDirectory);
  final rebalances = FileRebalanceJournal(getApplicationSupportDirectory);
  try {
    await rebalances.reload();
  } catch (_) {
    /* Preserve blocking storage state. */
  }
  final internalTransfers = FileInternalTransferJournal(getApplicationSupportDirectory);
  try {
    await internalTransfers.reload();
  } catch (_) {
    /* Keep blocking storage state. */
  }
  final walletOperations = FileWalletOperationJournal(getApplicationSupportDirectory);
  try {
    await walletOperations.reload();
  } catch (_) {
    /* Block writes on storage failure. */
  }
  final margins = FileWalletOperationJournal(
    getApplicationSupportDirectory,
    filename: 'position-margin-operations-v1.json',
  );
  try {
    await margins.reload();
  } catch (_) {
    /* Preserve blocked margin state. */
  }
  final deposits = FileDepositSubmissionJournal(getApplicationSupportDirectory);
  try {
    await deposits.reload();
  } catch (_) {
    /* Block new deposits on storage failure. */
  }
  final approvals = FileDepositApprovalJournal(getApplicationSupportDirectory);
  try {
    await approvals.reload();
  } catch (_) {
    /* A corrupt funding journal blocks writes. */
  }
  try {
    await recovery.reload();
  } catch (_) {
    // The journal retains a safe blocking error; public/demo use remains available.
  }
  String? saved;
  try {
    saved = await LocalLocalePreferences().read();
  } catch (_) {
    // System locale remains usable if local preferences cannot be read.
  }
  runApp(
    ProviderScope(
      overrides: [
        pushMessagingRepositoryProvider.overrideWithValue(pushMessaging),
        initialLocaleProvider.overrideWithValue(localeFromPreference(saved)),
        orderRecoveryJournalProvider.overrideWithValue(recovery),
        rebalanceJournalProvider.overrideWithValue(rebalances),
        internalTransferJournalProvider.overrideWithValue(internalTransfers),
        depositApprovalJournalProvider.overrideWithValue(approvals),
        depositSubmissionJournalProvider.overrideWithValue(deposits),
        walletOperationJournalProvider.overrideWithValue(walletOperations),
        positionMarginJournalProvider.overrideWithValue(margins),
      ],
      child: const VantaApp(),
    ),
  );
}

class VantaApp extends ConsumerWidget {
  const VantaApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushRegistrationProvider);
    ref.listen(authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress)), (
      previous,
      next,
    ) {
      if (previous != next) ref.read(accountProvider.notifier).disconnect();
    });
    return MaterialApp(
      title: 'Vanta',
      debugShowCheckedModeBanner: false,
      theme: vantaTheme(),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const TradingScreen(),
    );
  }
}

@Preview(name: 'Vanta mobile', size: Size(390, 844))
Widget mobilePreview() => const ProviderScope(child: VantaApp());
