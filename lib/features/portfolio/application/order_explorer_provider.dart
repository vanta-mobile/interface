import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Aster Chain explorer page for an order's placement transaction.
Uri orderExplorerUri(String transactionHash) =>
    Uri.https('www.asterdex.com', '/en/explorer/tx/$transactionHash');

final orderExplorerLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
