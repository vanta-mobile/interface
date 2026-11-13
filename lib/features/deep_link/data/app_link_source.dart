import 'dart:async';

import 'package:app_links/app_links.dart';

import '../domain/app_deep_link.dart';

/// Delivers `vantaapp://` navigation links from launch and while running.
/// Wallet and OAuth returns on `vanta://` stay with their own handlers.
class AppLinkSource {
  AppLinkSource({Stream<Uri>? links, Future<Uri?> Function()? initialLink})
    : _links = links ?? AppLinks().uriLinkStream,
      _initialLink = initialLink ?? AppLinks().getInitialLink;

  final Stream<Uri> _links;
  final Future<Uri?> Function() _initialLink;
  StreamSubscription<Uri>? _subscription;
  void Function(AppDeepLink)? _onLink;
  bool _closed = false, _streamStarted = false, _initialLoaded = false;
  Uri? _firstStreamLink, _launchLink;

  void start(void Function(AppDeepLink) onLink) {
    if (_closed || _subscription != null) return;
    _onLink = onLink;
    _subscription = _links.listen(_receiveStream, onError: (Object _) {});
    unawaited(_loadInitial());
  }

  // app_links replays the launch link on the stream to its first listener, and
  // getInitialLink returns it too; open it once.
  void _receiveStream(Uri uri) {
    if (!_streamStarted) {
      _streamStarted = true;
      _firstStreamLink = uri;
      if (_initialLoaded && uri == _launchLink) return;
    }
    _deliver(uri);
  }

  Future<void> _loadInitial() async {
    Uri? uri;
    try {
      uri = await _initialLink();
    } catch (_) {
      // Without a launch link the app opens its default page.
    }
    _initialLoaded = true;
    _launchLink = uri;
    if (uri == null || _streamStarted && _firstStreamLink == uri) return;
    _deliver(uri);
  }

  void _deliver(Uri uri) {
    if (_closed) return;
    final link = AppDeepLink.parse(uri);
    if (link != null) _onLink?.call(link);
  }

  Future<void> close() async {
    _closed = true;
    _onLink = null;
    await _subscription?.cancel();
  }
}
