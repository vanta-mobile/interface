import 'dart:async';

import 'package:reown_appkit/modal/services/explorer_service/models/redirect.dart';
import 'package:reown_appkit/modal/services/uri_service/launch_url_exception.dart';
import 'package:reown_appkit/modal/utils/platform_utils.dart';

enum WalletLaunchFailure { unavailable, noRedirect, invalidLink, timeout, refused }

class WalletRequestLaunchException implements Exception {
  const WalletRequestLaunchException(
    this.message, {
    this.failure = WalletLaunchFailure.unavailable,
    this.redirect,
  });
  final String message;
  final WalletLaunchFailure failure;

  /// The wallet link the launch targeted, before the request topic and ID
  /// were appended.
  final Uri? redirect;
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
      failure: WalletLaunchFailure.noRedirect,
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
  final link = Uri.tryParse(redirect.mobile ?? redirect.desktop ?? redirect.web ?? '');
  final bool opened;
  try {
    opened =
        await openRedirect(
          redirect,
          pType: platform,
          wcURI: 'requestId=$requestId&sessionTopic=$topic',
        ).timeout(
          timeout,
          onTimeout: () => throw WalletRequestLaunchException(
            'Opening the connected wallet timed out',
            failure: WalletLaunchFailure.timeout,
            redirect: link,
          ),
        );
  } on LaunchUrlException {
    // UriService reports any refused launch as "App not installed", even when
    // the connected wallet is installed. Report what is actually known.
    throw WalletRequestLaunchException(
      'The operating system could not open the connected wallet app',
      failure: WalletLaunchFailure.refused,
      redirect: link,
    );
  }
  // UriService answers false only when it cannot build a link from the redirect.
  if (!opened) {
    throw WalletRequestLaunchException(
      'The connected wallet app link is invalid',
      failure: WalletLaunchFailure.invalidLink,
      redirect: link,
    );
  }
}
