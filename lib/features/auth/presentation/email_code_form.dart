import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_provider.dart';
import '../domain/auth_session.dart';
import 'auth_controls.dart';
import 'verification_code_input.dart';

class EmailCodeForm extends ConsumerStatefulWidget {
  const EmailCodeForm({super.key});
  @override
  ConsumerState<EmailCodeForm> createState() => _EmailCodeFormState();
}

class _EmailCodeFormState extends ConsumerState<EmailCodeForm> {
  final _code = TextEditingController();
  Timer? _timer;
  bool _resending = false;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final deadline = ref.read(authProvider).resendAt;
      if (deadline != null &&
          deadline.isAfter(DateTime.now().subtract(const Duration(seconds: 1)))) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    await ref.read(authProvider.notifier).sendCode(ref.read(authProvider).email);
    if (!mounted) return;
    if (ref.read(authProvider).failure == null) {
      _code.clear();
      _expired = false;
    }
    setState(() => _resending = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    final controller = ref.read(authProvider.notifier);
    final l10n = AppLocalizations.of(context);
    if (session.failure?.key == 'authCodeExpired') _expired = true;
    final seconds = session.resendAt == null
        ? 0
        : (session.resendAt!.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(0, 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.authCheckEmail, style: AuthTypography.heading),
        const SizedBox(height: 4),
        Text(
          l10n.authCodeDelivery,
          style: AuthTypography.body.copyWith(color: AppColors.authSecondary),
        ),
        Row(
          children: [
            Expanded(child: SelectableText(session.email, style: AuthTypography.body)),
            TextButton(
              key: const Key('change-login-email'),
              onPressed: session.busy ? null : controller.changeEmail,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.authAccent,
                textStyle: AuthTypography.caption,
              ),
              child: Text(l10n.changeEmail),
            ),
          ],
        ),
        VerificationCodeInput(
          controller: _code,
          enabled: !session.busy,
          hasError: session.failure != null,
          onSubmitted: _expired ? (_) {} : controller.verifyCode,
        ),
        if (session.failure case final failure?) ...[
          const SizedBox(height: 12),
          AuthFailureText(failure),
        ],
        const SizedBox(height: 12),
        _actions(session, l10n, seconds),
      ],
    );
  }

  Widget _actions(AuthSession session, AppLocalizations l10n, int seconds) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_expired)
        AuthActionButton(
          key: const Key('resend-email-code'),
          label: l10n.resendCode,
          primary: true,
          busy: _resending && session.busy,
          onPressed: session.busy || seconds > 0 ? null : _resend,
        )
      else ...[
        ValueListenableBuilder(
          valueListenable: _code,
          builder: (context, value, _) => AuthActionButton(
            key: const Key('verify-email-code'),
            label: l10n.authVerifyContinue,
            primary: true,
            busy: session.busy && !_resending,
            onPressed: session.busy || value.text.length != 6
                ? null
                : () => ref.read(authProvider.notifier).verifyCode(_code.text),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          key: const Key('resend-email-code'),
          onPressed: session.busy || seconds > 0 ? null : _resend,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.authSecondary,
            disabledForegroundColor: AppColors.authSecondary,
            textStyle: AuthTypography.caption,
          ),
          child: _resending && session.busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.authSecondary),
                )
              : Text(seconds > 0 ? l10n.authResendCountdown(seconds) : l10n.resendCode),
        ),
        const SizedBox(height: 8),
        Text(l10n.authSpamHint, style: AuthTypography.caption),
      ],
    ],
  );
}
