import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/trading_authorization_provider.dart';
import '../domain/trading_authorization.dart';

void openTradingAuthorization(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const TradingAuthorizationScreen()));

class TradingAuthorizationScreen extends ConsumerStatefulWidget {
  const TradingAuthorizationScreen({super.key});
  @override
  ConsumerState<TradingAuthorizationScreen> createState() => _TradingAuthorizationScreenState();
}

class _TradingAuthorizationScreenState extends ConsumerState<TradingAuthorizationScreen> {
  bool canWithdraw = false;
  final ip = TextEditingController();
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(tradingAuthorizationProvider.notifier).cancel();
    });
  }

  @override
  void dispose() {
    ip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), s = ref.watch(tradingAuthorizationProvider);
    final auth = ref.watch(authProvider),
        controller = ref.read(tradingAuthorizationProvider.notifier);
    ref.listen(
      authProvider.select(
        (s) => (s.identity?.id, s.identity?.walletAddress, s.identity?.walletKind),
      ),
      (a, b) {
        if (a != b) {
          setState(() {
            canWithdraw = false;
            ip.clear();
          });
        }
      },
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.authorizationTitle)),
      body: SafeArea(
        child: ListView(
          key: const Key('authorization-page'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.authorizationScope),
            const SizedBox(height: 12),
            if (auth.identity?.walletAddress case final address?) SelectableText(address),
            const SizedBox(height: 12),
            CheckboxListTile(
              key: const Key('authorization-withdraw-toggle'),
              contentPadding: EdgeInsets.zero,
              value: canWithdraw,
              onChanged: s.busy || s.review != null
                  ? null
                  : (v) => setState(() => canWithdraw = v ?? false),
              title: Text(l.authorizationWithdrawOption),
            ),
            if (canWithdraw) ...[
              Text(l.authorizationWithdrawScope),
              TextField(
                key: const Key('authorization-ip-whitelist'),
                controller: ip,
                enabled: !s.busy && s.review == null,
                autocorrect: false,
                maxLength: 1024,
                decoration: InputDecoration(labelText: l.authorizationIpWhitelist),
              ),
            ],
            FilledButton(
              key: const Key('authorization-prepare'),
              onPressed: s.busy || auth.busy || auth.identity?.walletAddress == null
                  ? null
                  : () => controller.prepare(canWithdraw: canWithdraw, ipWhitelist: ip.text),
              child: Text(l.authorizationEnable),
            ),
            OutlinedButton(
              key: const Key('authorization-check'),
              onPressed: s.busy || auth.busy || auth.identity?.walletAddress == null
                  ? null
                  : controller.check,
              child: Text(l.authorizationCheck),
            ),
            Text(l.authorizationCheckScope),
            if (s.review case final review?) ...[
              const Divider(),
              Text(l.authorizationReview),
              SelectableText(review.identity.walletAddress!),
              Text(review.canWithdraw ? l.authorizationWithdrawGrant : l.authorizationGrant),
              if (review.canWithdraw) SelectableText(review.ipWhitelist),
              SelectableText(review.expiresAt.toLocal().toString()),
              FilledButton(
                key: const Key('authorization-confirm'),
                onPressed: () => controller.confirm(review),
                child: Text(l.authorizationConfirm),
              ),
              TextButton(onPressed: controller.cancel, child: Text(tr(context, 'cancel'))),
            ],
            if (s.busy) ...[
              const LinearProgressIndicator(),
              TextButton(onPressed: controller.stop, child: Text(l.subaccountStopWaiting)),
            ],
            if (s.result case final result?)
              Text(
                result == TradingAuthorizationResult.acknowledged
                    ? l.authorizationAcknowledged
                    : l.authorizationUnknown,
                style: const TextStyle(color: AppColors.warning),
              ),
            if (s.failure case final key?)
              Text(
                apiErrorText(context, key, s.errorDetails),
                style: const TextStyle(color: AppColors.negative),
              ),
            if (s.check case final check?) _AuthorizationAccessCheck(check: check),
          ],
        ),
      ),
    );
  }
}

class _AuthorizationAccessCheck extends StatelessWidget {
  const _AuthorizationAccessCheck({required this.check});
  final TradingAuthorizationCheck check;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        SelectableText(check.checkedAt.toLocal().toString()),
        Text(l.authorizationFuturesRead),
        Text(
          check.futuresReadAccepted
              ? l.authorizationReadAccepted
              : tr(context, check.futuresFailure ?? 'accountReadFailed'),
        ),
        Text(switch (check.futuresCanTrade) {
          true => l.authorizationCanTrade,
          false => l.authorizationCannotTrade,
          null => l.authorizationPermissionUnknown,
        }),
        Text(switch (check.futuresCanWithdraw) {
          true => l.authorizationCanWithdraw,
          false => l.authorizationCannotWithdraw,
          null => l.authorizationWithdrawUnknown,
        }),
        const SizedBox(height: 12),
        Text(l.authorizationSpotRead),
        Text(
          check.spotReadAccepted
              ? l.authorizationReadAccepted
              : tr(context, check.spotFailure ?? 'accountReadFailed'),
        ),
        Text(l.authorizationSpotPermissionUnknown),
      ],
    );
  }
}
