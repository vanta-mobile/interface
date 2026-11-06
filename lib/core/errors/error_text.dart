import 'package:flutter/widgets.dart';

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
  if (message != null) return uncertain ? '$fallback\n$message' : message;
  final l10n = AppLocalizations.of(context);
  final cause = switch (details?.cause) {
    ApiErrorCause.timeout => l10n.apiRequestTimeout,
    ApiErrorCause.connection => l10n.apiConnectionFailed,
    ApiErrorCause.cancelled => l10n.apiRequestCancelled,
    ApiErrorCause.invalidResponse => l10n.apiInvalidResponse,
    ApiErrorCause.rateLimit => l10n.pointsRateLimited,
    _ => null,
  };
  if (cause != null) return uncertain ? '$fallback\n$cause' : cause;
  return details?.status != null ? '$fallback (HTTP ${details!.status})' : fallback;
}

String accountErrorText(BuildContext context, AccountReadFailure failure) {
  final text = apiErrorText(context, failure.key, failure.details);
  return failure.code == null
      ? text
      : '$text\n${AppLocalizations.of(context).accountErrorCode(failure.code!)}';
}
