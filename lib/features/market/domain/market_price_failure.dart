import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/errors/api_error_details.dart';
import '../../../core/market_failure.dart';
import '../../portfolio/domain/account_snapshot.dart';

/// Preserve safe API detail while keeping quote/recovery keys independent of text.
AccountReadFailure marketPriceFailure(Object error, String reasonKey, {String? endpoint}) =>
    error is AccountReadFailure
    ? error
    : AccountReadFailure(
        'liveCapacityPriceUnavailable',
        reasonKey: reasonKey,
        details: switch (error) {
          MarketFailure(:final details) when details != null => details,
          TimeoutException() => const ApiErrorDetails(cause: ApiErrorCause.timeout),
          http.RequestAbortedException() => const ApiErrorDetails(cause: ApiErrorCause.cancelled),
          SocketException() ||
          http.ClientException() => const ApiErrorDetails(cause: ApiErrorCause.connection),
          FormatException() => ApiErrorDetails(
            cause: ApiErrorCause.invalidResponse,
            endpoint: endpoint,
          ),
          _ => null,
        },
      );
