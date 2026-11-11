/// Only sanitized, user-safe details cross the data boundary.
enum ApiErrorCause { timeout, connection, cancelled, invalidResponse, rateLimit }

class ApiErrorDetails {
  const ApiErrorDetails({this.message, this.status, this.cause, this.endpoint});
  final String? message;
  final int? status;
  final ApiErrorCause? cause;

  /// A fixed API path supplied by the service, never a signed URL or query.
  final String? endpoint;
}

abstract interface class DetailedApiFailure {
  ApiErrorDetails? get details;
}

ApiErrorDetails? errorDetailsOf(Object error) => error is DetailedApiFailure ? error.details : null;
