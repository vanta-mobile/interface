import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';

class AuthPageHeader extends StatelessWidget {
  const AuthPageHeader({required this.title, required this.onBack, this.onClose, super.key});
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 3),
      child: Row(
        children: [
          IconButton(
            key: const Key('auth-back'),
            tooltip: l10n.authBack,
            onPressed: onBack,
            icon: SvgPicture.asset(
              'assets/auth/back.svg',
              width: 18,
              height: 14,
              excludeFromSemantics: true,
            ),
          ),
          Expanded(child: Text(title, style: AuthTypography.heading)),
          IconButton(
            key: const Key('auth-close'),
            tooltip: l10n.authClose,
            onPressed: onClose ?? () => Navigator.of(context).maybePop(),
            icon: SvgPicture.asset(
              'assets/auth/close.svg',
              width: 24,
              height: 24,
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    );
  }
}
