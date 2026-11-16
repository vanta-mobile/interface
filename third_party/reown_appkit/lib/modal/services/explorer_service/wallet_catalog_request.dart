import 'dart:async';

import 'package:http/http.dart' as http;

/// Bound the directory lookup without closing the shared explorer client.
/// Aborting also stops a stalled response body, not just the caller's wait.
Future<http.Response> fetchWalletCatalog({
  required http.Client client,
  required Uri uri,
  required Map<String, String> headers,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final aborted = Completer<void>();
  final request = http.AbortableRequest('GET', uri, abortTrigger: aborted.future)
    ..headers.addAll(headers);
  try {
    return await (() async {
      final response = await client.send(request);
      return http.Response.fromStream(response);
    })().timeout(
      timeout,
      onTimeout: () {
        if (!aborted.isCompleted) aborted.complete();
        throw TimeoutException('Wallet catalog request timed out');
      },
    );
  } finally {
    if (!aborted.isCompleted) aborted.complete();
  }
}
