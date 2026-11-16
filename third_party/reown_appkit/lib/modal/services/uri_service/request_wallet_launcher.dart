import 'dart:async';

import 'package:reown_appkit/modal/services/explorer_service/models/redirect.dart';
import 'package:reown_appkit/modal/utils/platform_utils.dart';

class WalletRequestLaunchException implements Exception {
  const WalletRequestLaunchException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A restored session can retain the peer redirect after the explorer's local
/// listing has disappeared. Keep launching independent of that optional cache.
Future<void> launchWalletRequest({
  required WalletRedirect? cachedRedirect,
  required String? nativeRedirect,
  required String? universalRedirect,
  required String topic,
  required int requestId,
  required PlatformType platform,
  required Future<bool> Function(WalletRedirect redirect, {String? wcURI, PlatformType? pType})
  openRedirect,
  Duration timeout = const Duration(seconds: 5),
}) async {
  String? nonempty(String? value) => value?.trim().isNotEmpty == true ? value!.trim() : null;
  final peerLink = nonempty(nativeRedirect) ?? nonempty(universalRedirect);
  final mobileLink = peerLink ?? nonempty(cachedRedirect?.mobile);
  if (platform == PlatformType.mobile && mobileLink == null ||
      cachedRedirect == null && mobileLink == null) {
    throw const WalletRequestLaunchException(
      'Connected wallet has no app redirect. Reconnect the wallet on this device.',
    );
  }
  // CoreUtils adds /wc when formatting a pending WalletConnect request.
  String removeWcPath(String value) {
    final uri = Uri.parse(value);
    return uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'wc'
        ? uri.replace(pathSegments: uri.pathSegments.skip(1).toList()).toString()
        : value;
  }

  final redirect = (cachedRedirect ?? WalletRedirect()).copyWith(
    mobile: mobileLink == null ? null : removeWcPath(mobileLink),
  );
  final opened =
      await openRedirect(
        redirect,
        pType: platform,
        wcURI: 'requestId=$requestId&sessionTopic=$topic',
      ).timeout(
        timeout,
        onTimeout: () =>
            throw const WalletRequestLaunchException('Opening the connected wallet timed out'),
      );
  if (!opened) {
    throw const WalletRequestLaunchException(
      'The operating system could not open the connected wallet app',
    );
  }
}
