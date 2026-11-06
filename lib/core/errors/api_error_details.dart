/// Only sanitized, user-safe details cross the data boundary.
enum ApiErrorCause { timeout, connection, cancelled, invalidResponse, rateLimit }

class ApiErrorDetails {
  const ApiErrorDetails({this.message, this.status, this.cause});
  final String? message;
  final int? status;
  final ApiErrorCause? cause;
}

abstract interface class DetailedApiFailure {
  ApiErrorDetails? get details;
}

ApiErrorDetails? errorDetailsOf(Object error) => error is DetailedApiFailure ? error.details : null;
