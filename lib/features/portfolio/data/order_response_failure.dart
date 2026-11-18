import '../../../core/errors/api_error_details.dart';
import '../domain/account_snapshot.dart';

/// Only fixed mapper diagnostics become localization keys. Never surface a raw
/// FormatException, payload, client reference or signed URL to the user.
AccountReadFailure orderResponseFailure(FormatException failure, String endpoint) {
  final reason = switch (failure.message) {
    'Strategy identity mismatch' ||
    'Strategy leg identity mismatch' ||
    'Order identity mismatch' => 'orderResponseIdentityMismatch',
    'Invalid strategy status' || 'Invalid order status' => 'orderResponseStatusInvalid',
    _ => 'orderResponseMalformed',
  };
  return AccountReadFailure(
    'accountDataInvalid',
    reasonKey: reason,
    details: ApiErrorDetails(cause: ApiErrorCause.invalidResponse, endpoint: endpoint),
  );
}
