import 'dart:async';

import 'package:reown_appkit/modal/services/uri_service/request_wallet_launcher.dart';

import '../../../core/monitoring/failure_reporter.dart';

/// Opening the wallet is this device's operation, so its failure is reported
/// even though the UI already shows it. Only the failure kind, wallet name and
/// the link's scheme/host are sent: the launched URL carries the session topic
/// and request ID and is never included.
void reportWalletLaunchFailure(
  WalletRequestLaunchException error,
  StackTrace stackTrace, {
  String? walletName,
}) => unawaited(
  reportHandledFailure(
    error,
    stackTrace,
    operation: 'wallet.launch',
    tags: walletLaunchTags(error, walletName: walletName),
  ),
);

Map<String, String> walletLaunchTags(WalletRequestLaunchException error, {String? walletName}) {
  String? slug(String? value) {
    final text = value?.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9.-]+'), '_');
    if (text == null || text.isEmpty) return null;
    return text.length > 60 ? text.substring(0, 60) : text;
  }

  return {
    'wallet.launch': error.failure.name,
    'wallet.name': ?slug(walletName),
    'wallet.scheme': ?slug(error.redirect?.scheme),
    'wallet.host': ?slug(error.redirect?.host),
  };
}
