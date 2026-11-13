import 'dart:async';
import 'dart:collection';

import 'package:app_links/app_links.dart';

import 'wallet_configuration.dart';

/// Native return links can carry the wallet's encrypted response. Opening the
/// app alone does not deliver that response to Reown's pending request.
class WalletRedirectHandler {
  WalletRedirectHandler({Stream<Uri>? links, Future<Uri?> Function()? initialLink})
    : _links = links ?? AppLinks().uriLinkStream,
      _initialLink = initialLink ?? AppLinks().getInitialLink;

  final Stream<Uri> _links;
  final Future<Uri?> Function() _initialLink;
  StreamSubscription<Uri>? _subscription;
  Future<bool> Function(String)? _dispatch;
  final _pending = Queue<Uri>();
  final _handled = <Uri>{};
  bool _closed = false, _draining = false, _drainRequested = false;

  void start() {
    if (_closed || _subscription != null) return;
    _subscription = _links.listen(_receive, onError: (Object _) {});
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    try {
      final uri = await _initialLink();
      if (uri != null) _receive(uri);
    } catch (_) {
      // A missing initial link cannot invalidate a live wallet session.
    }
  }

  void attach(Future<bool> Function(String) dispatch) {
    if (_closed) return;
    _dispatch = dispatch;
    retry();
  }

  void detach() => _dispatch = null;

  void retry() {
    if (_closed) return;
    _drainRequested = true;
    if (!_draining) unawaited(_drain());
  }

  void _receive(Uri uri) {
    if (_closed || !_walletResponse(uri) || _handled.contains(uri) || _pending.contains(uri)) {
      return;
    }
    if (_pending.length == 8) return;
    _pending.add(uri);
    retry();
  }

  Future<void> _drain() async {
    if (_draining || _closed) return;
    _draining = true;
    try {
      while (!_closed && _dispatch != null && _drainRequested) {
        _drainRequested = false;
        final dispatch = _dispatch!;
        // A stale/unhandled response must not block a later valid response.
        for (final uri in _pending.toList(growable: false)) {
          if (_closed || !identical(_dispatch, dispatch)) break;
          try {
            // Only the SDK validates/decrypts a response and resolves its request.
            // Neither the URI nor a return to the app proves financial success.
            final handled = await dispatch(uri.toString());
            if (_closed) return;
            if (!identical(_dispatch, dispatch)) break;
            if (!handled) continue;
            _pending.remove(uri);
            _handled.add(uri);
            if (_handled.length > 32) _handled.remove(_handled.first);
          } catch (_) {
            // Retain the response for the next resume; never log its payload.
          }
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> close() async {
    _closed = true;
    _dispatch = null;
    _pending.clear();
    _handled.clear();
    await _subscription?.cancel();
  }
}

final _redirect = Uri.parse(WalletConfiguration.redirect);

bool _walletResponse(Uri uri) {
  if (uri.scheme != _redirect.scheme ||
      uri.host != _redirect.host ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.path.isNotEmpty && uri.path != '/' ||
      uri.toString().length > 262144) {
    return false;
  }
  try {
    final query = uri.queryParametersAll;
    if (query.values.any((v) => v.length != 1)) return false;
    bool has(String key) => query[key]?.single.isNotEmpty ?? false;
    return has('wc_ev') && has('topic') || has('phantomRequest') || has('solflareRequest');
  } on FormatException {
    return false;
  }
}
