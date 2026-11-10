import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../subaccounts/application/account_entries_provider.dart';
import '../../subaccounts/presentation/account_components.dart';
import '../application/transfer_history_load_provider.dart';
import '../application/transfer_history_provider.dart';
import '../domain/transfer_history.dart';
import 'transfer_history_components.dart';
import 'transfer_history_feedback.dart';
import 'transfer_record_screen.dart';

void openTransferHistory(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const TransferHistoryScreen()));

class TransferHistoryEntry extends ConsumerWidget {
  const TransferHistoryEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    key: const Key('transfer-history-entry'),
    onPressed: () => openTransferHistory(context),
    icon: const Icon(Icons.swap_vert),
    label: Text(AppLocalizations.of(context).assetHistoryTitle),
  );
}

class TransferHistoryScreen extends ConsumerStatefulWidget {
  const TransferHistoryScreen({super.key});
  @override
  ConsumerState<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends ConsumerState<TransferHistoryScreen> {
  TransferType? _type;
  int _page = 0;
  static const _pageSize = 5;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(transferHistoryLoadProvider);
    ref.listen(authProvider.select((s) => s.identity), (_, _) {
      setState(() {
        _type = null;
        _page = 0;
      });
    });
    final state = ref.watch(transferHistoryProvider);
    final entry = ref.watch(activeAccountEntryProvider);
    final records =
        state.account?.records.where((r) => _type == null || r.type == _type).toList() ?? [];
    final pages = (records.length / _pageSize).ceil().clamp(1, 1000);
    final page = _page.clamp(0, pages - 1);
    return Scaffold(
      backgroundColor: PortfolioColors.background,
      body: SafeArea(
        child: Column(
          children: [
            HistoryHeader(title: l.assetHistoryTitle, close: true),
            Expanded(
              child: RefreshIndicator(
                onRefresh: ref.read(transferHistoryProvider.notifier).refresh,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontal = constraints.maxWidth > 820
                        ? (constraints.maxWidth - 788) / 2
                        : 16.0;
                    return ListView(
                      key: const Key('transfer-history-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal + 8, 32),
                      children: [
                        Text(
                          entry == null ? l.account : accountLabel(l, entry),
                          style: AccountTypography.body,
                        ),
                        const SizedBox(height: 16),
                        HistoryFilters(
                          selected: _type,
                          onChanged: (type) => setState(() {
                            _type = type;
                            _page = 0;
                          }),
                        ),
                        const SizedBox(height: 8),
                        const TransferHistoryFeedback(),
                        HistoryRecordList(
                          records: records,
                          loaded: state.account != null,
                          page: page,
                          pages: pages,
                          onPage: (value) => setState(() => _page = value),
                          onOpen: (record) => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => TransferRecordScreen(
                                recordKey: record.key,
                                ownerAddress: state.account!.address,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
