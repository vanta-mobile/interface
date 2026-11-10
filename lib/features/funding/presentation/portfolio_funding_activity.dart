import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/presentation/app_toast.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/funding_activity_poll_provider.dart';
import '../application/funding_activity_provider.dart';
import '../domain/funding_activity.dart';
import '../domain/transfer_history.dart';
import 'funding_status_screens.dart';
import 'transfer_record_screen.dart';

/// The portfolio owns visible progress polling and terminal feedback; domain
/// progress remains in Riverpod across navigation and is cleared per identity.
class PortfolioFundingActivity extends ConsumerStatefulWidget {
  const PortfolioFundingActivity({super.key, required this.hidden});
  final bool hidden;
  @override
  ConsumerState<PortfolioFundingActivity> createState() => _PortfolioFundingActivityState();
}

class _PortfolioFundingActivityState extends ConsumerState<PortfolioFundingActivity>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Timer? _toastTimer;
  bool _scheduled = false;
  bool get _visible =>
      mounted &&
      (ModalRoute.isCurrentOf(context) ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_toastTimer != null) AppToast.dismiss();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _scheduleToast() {
    if (_scheduled || _toastTimer != null || !_visible) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_visible) return;
      final completion = ref.read(fundingActivityProvider).completions.firstOrNull;
      if (completion == null) return;
      final l = AppLocalizations.of(context);
      final message = l.transferTitle(completion.activity.type.name, completion.status.name);
      ref.read(fundingActivityProvider.notifier).acknowledgeCompletion(completion.activity.key);
      if (completion.status == TransferStatus.success) {
        AppToast.showSuccess(context, message);
      } else {
        AppToast.showFailure(context, message);
      }
      _toastTimer = Timer(AppToast.autoDismissDuration, () {
        _toastTimer = null;
        if (mounted) setState(() {});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final visible = _visible;
    ref.watch(fundingActivityPollProvider(visible));
    ref.listen(authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress)), (_, _) {
      if (_toastTimer != null) AppToast.dismiss();
      _toastTimer?.cancel();
      _toastTimer = null;
    });
    final activity = ref.watch(fundingActivityProvider);
    if (activity.completions.isNotEmpty) _scheduleToast();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in activity.pending)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _ProcessingCard(row, hidden: widget.hidden),
          ),
      ],
    );
  }
}

class _ProcessingCard extends ConsumerWidget {
  const _ProcessingCard(this.activity, {required this.hidden});
  final FundingActivity activity;
  final bool hidden;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), a = activity;
    final owner = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    return Material(
      color: PortfolioColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('portfolio-funding-${a.key}'),
        borderRadius: BorderRadius.circular(14),
        onTap: owner == null
            ? null
            : () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => a.deposit != null
                      ? DepositProcessingScreen(record: a.deposit!)
                      : a.withdrawal != null
                      ? WithdrawalStatusScreen(record: a.withdrawal!)
                      : TransferRecordScreen(
                          recordKey: a.transfer!.key,
                          ownerAddress: owner,
                          initialRecord: a.transfer,
                        ),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const _ProcessingIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.transferTitle(a.type.name, 'processing'), style: AccountTypography.body),
                    const SizedBox(height: 2),
                    Text(
                      l.portfolioFundingPending(
                        hidden ? '••••' : '${a.amount} ${a.asset}',
                        a.type.name,
                      ),
                      style: PortfolioTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox.square(
                dimension: 16,
                child: Center(child: SvgPicture.asset('assets/portfolio/processing-chevron.svg')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessingIcon extends StatelessWidget {
  const _ProcessingIcon();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    height: 32,
    child: Center(
      child: SizedBox.square(
        dimension: 20,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset('assets/portfolio/processing-clock-clip.svg'),
            SvgPicture.asset('assets/portfolio/processing-clock.svg'),
          ],
        ),
      ),
    ),
  );
}
