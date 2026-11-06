import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../domain/auth_session.dart';

class AuthActionButton extends StatelessWidget {
  const AuthActionButton({
    required this.label,
    required this.onPressed,
    this.asset,
    this.primary = false,
    this.busy = false,
    this.outlined = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final String? asset;
  final bool primary, busy, outlined;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: primary
          ? AppColors.authAccent
          : outlined
          ? AppColors.authCard
          : AppColors.authButton,
      foregroundColor: primary ? AppColors.authOnAccent : AppColors.authText,
      disabledBackgroundColor: primary
          ? AppColors.authAccent.withValues(alpha: .45)
          : AppColors.authButton,
      disabledForegroundColor: AppColors.authSecondary,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      textStyle: AuthTypography.button,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: outlined ? const BorderSide(color: AppColors.authLine) : null,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.authText),
          )
        else if (asset != null)
          SizedBox.square(
            dimension: 20,
            child: asset == 'assets/auth/wallet.svg'
                ? Center(
                    child: SvgPicture.asset(
                      asset!,
                      width: 18.4667,
                      height: 15.1333,
                      excludeFromSemantics: true,
                    ),
                  )
                : asset!.endsWith('.svg')
                ? SvgPicture.asset(asset!, excludeFromSemantics: true)
                : Image.asset(asset!, excludeFromSemantics: true),
          ),
        if (busy || asset != null) const SizedBox(width: 8),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    ),
  );
}

class AuthFailureText extends StatelessWidget {
  const AuthFailureText(this.failure, {super.key});
  final AuthFailure failure;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      failure.reason ?? tr(context, failure.key),
      key: const Key('auth-error'),
      style: AuthTypography.caption.copyWith(color: AppColors.authError),
    ),
  );
}
