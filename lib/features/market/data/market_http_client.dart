import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../../core/network/managed_http_client.dart';

/// Wrap injected pool leases as well as standalone clients in a service-local
/// abortable lifetime. Closing a lease never closes the shared connection pool.
http.Client createMarketHttpClient({
  http.Client? client,
  Duration timeout = const Duration(seconds: 12),
}) => ManagedHttpClient(
  client ?? IOClient(HttpClient()..idleTimeout = const Duration(minutes: 2)),
  timeout: timeout,
);
