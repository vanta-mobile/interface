import 'package:flutter/widgets.dart';

import '../../features/auth/domain/auth_session.dart';
import '../../features/portfolio/domain/account_snapshot.dart';
import '../../l10n/generated/app_localizations.dart';
import '../strings.dart';
import 'api_error_details.dart';

String apiErrorText(
  BuildContext context,
  String key,
  ApiErrorDetails? details, {
  String? fallbackText,
}) {
  final fallback = fallbackText ?? tr(context, key);
  final message = details?.message;
  // Unknown-outcome and recovery wording must remain visible even when the
  // backend supplied a reason for the transport/reconciliation failure.
  final uncertain = RegExp(
    r'unknown|unverified|unresolved|recovery|pending',
    caseSensitive: false,
  ).hasMatch(key);
  if (message != null) {
    // A wallet's own rejection must read as the wallet's answer, not an app fault.
    final text = key.startsWith('authWallet')
        ? AppLocalizations.of(context).walletResponseReason(message)
        : message;
    return uncertain ? '$fallback\n$text' : text;
  }
  final l10n = AppLocalizations.of(context);
  final cause = switch (details?.cause) {
    ApiErrorCause.timeout => l10n.apiRequestTimeout,
    ApiErrorCause.connection => l10n.apiConnectionFailed,
    ApiErrorCause.cancelled => l10n.apiRequestCancelled,
    ApiErrorCause.invalidResponse when fallbackText != null =>
      details?.endpoint == null ? fallback : '$fallback (${details!.endpoint})',
    ApiErrorCause.invalidResponse =>
      details?.endpoint == null
          ? l10n.apiInvalidResponse
          : l10n.apiInvalidResponseAt(details!.endpoint!),
    ApiErrorCause.rateLimit => l10n.pointsRateLimited,
    _ => null,
  };
  if (cause != null) return uncertain ? '$fallback\n$cause' : cause;
  return details?.status != null ? '$fallback (HTTP ${details!.status})' : fallback;
}

/// Wallet/identity failures use the same wording rules as API failures.
String authFailureText(BuildContext context, AuthFailure failure) =>
    apiErrorText(context, failure.key, failure.details);

String accountErrorText(BuildContext context, AccountReadFailure failure) {
  final text = apiErrorText(
    context,
    failure.key,
    failure.details,
    fallbackText: failure.reasonKey == null ? null : tr(context, failure.reasonKey!),
  );
  return failure.code == null
      ? text
      : '$text\n${AppLocalizations.of(context).accountErrorCode(failure.code!)}';
}
