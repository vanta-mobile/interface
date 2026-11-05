import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Keep idle HTTP connections across normal chart-reading pauses. Dart's
/// 15-second default otherwise repeats DNS/TCP/TLS work on the next selection.
http.Client createMarketHttpClient() =>
    IOClient(HttpClient()..idleTimeout = const Duration(minutes: 2));
