import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import 'account_read_provider.dart';
import 'asset_index_provider.dart';
import 'portfolio_overview_provider.dart';

/// Initial loading only. Retained account/price data stays visible on refresh.
final portfolioLoadingProvider = Provider<({bool account, bool value, bool valuation})>((ref) {
  const idle = (account: false, value: false, valuation: false);
  if (ref.watch(portfolioPreviewProvider) || ref.watch(authProvider).needsWalletConnection) {
    return idle;
  }
  final account = ref.watch(accountReadProvider);
  final accountLoading =
      account.account == null && (account.busy || ref.watch(tradingAgentProvider).isLoading);
  final prices = account.account == null ? null : ref.watch(assetIndexProvider);
  final valuationLoading = prices != null && prices.loading && prices.snapshot == null;
  return (
    account: accountLoading,
    value:
        accountLoading || valuationLoading && ref.watch(portfolioOverviewProvider).totalUsd == null,
    valuation: valuationLoading,
  );
});
