import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_read_provider.dart';
import 'batch_close_provider.dart';
import 'open_orders_auto_read_provider.dart';
import 'position_risk_provider.dart';

/// Read the shared positions snapshot on trade-page entry so its tab count is
/// current before the tab is opened. Also used by standalone position sections.
final positionRiskAutoReadProvider = Provider.autoDispose<void>((ref) {
  autoReadWalletAccount(
    ref,
    positionRiskProvider,
    blocked: () => ref.read(batchCloseProvider).busy,
    triggers: [batchCloseProvider],
  );
});

/// The visible Positions tab also needs account totals for cross margin and
/// open orders for TP/SL rows. Share the page's read owners to avoid duplicates.
/// Never prompts a wallet, and pauses account reads during a batch close.
final positionsAutoReadProvider = Provider.autoDispose<void>((ref) {
  ref.watch(positionRiskAutoReadProvider);
  ref.watch(openOrdersAutoReadProvider);
  bool closing() => ref.read(batchCloseProvider).busy;
  autoReadWalletAccount(ref, accountReadProvider, blocked: closing, triggers: [batchCloseProvider]);
});
