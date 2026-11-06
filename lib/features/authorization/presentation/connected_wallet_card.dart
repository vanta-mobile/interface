import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/domain/auth_session.dart';

class ConnectedWalletCard extends StatelessWidget {
  const ConnectedWalletCard({required this.identity, required this.onSwitch, super.key});
  final AuthIdentity? identity;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.authCard, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                child: Center(
                  child: identity?.walletAddress == null
                      ? const SizedBox.square(dimension: 16)
                      : SvgPicture.asset(
                          'assets/auth/check-circle.svg',
                          width: 16,
                          height: 16,
                          excludeFromSemantics: true,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WalletConnectionDetails(identity: identity, onSwitch: onSwitch),
              ),
            ],
          ),
          const Divider(height: 25, color: AppColors.authLine),
          Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  l.enableTradingStep,
                  textAlign: TextAlign.center,
                  style: AuthTypography.caption.copyWith(color: AppColors.authAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.enableTradingTitle, style: AuthTypography.body),
                    const SizedBox(height: 2),
                    Text(
                      identity?.walletKind == WalletKind.external
                          ? l.enableTradingSignHint
                          : l.enableTradingEmbeddedSignHint,
                      style: AuthTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletConnectionDetails extends StatelessWidget {
  const _WalletConnectionDetails({required this.identity, required this.onSwitch});
  final AuthIdentity? identity;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), address = identity?.walletAddress;
    final external = identity?.walletKind == WalletKind.external;
    final name = identity?.walletName?.trim();
    final wallet = external && name != null && name.isNotEmpty
        ? name
        : tr(context, external ? 'externalWallet' : 'embeddedWallet');
    final short = address != null && address.length > 12
        ? '${address.substring(0, 6)}…${address.substring(address.length - 4)}'
        : address;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: tr(context, 'copyAddress'),
          child: Semantics(
            label: address,
            button: address != null,
            child: InkWell(
              key: const Key('enable-trading-wallet'),
              onTap: address == null ? null : () => Clipboard.setData(ClipboardData(text: address)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address == null ? l.enableTradingWalletSetup : l.enableTradingWalletConnected,
                    style: AuthTypography.body,
                  ),
                  const SizedBox(height: 2),
                  Text(short == null ? wallet : '$wallet · $short', style: AuthTypography.caption),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        TextButton(
          key: const Key('enable-trading-switch'),
          onPressed: onSwitch,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.authAccent,
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 18),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            alignment: Alignment.centerLeft,
            textStyle: AuthTypography.caption,
          ),
          child: Text(l.enableTradingUseAnother),
        ),
      ],
    );
  }
}
