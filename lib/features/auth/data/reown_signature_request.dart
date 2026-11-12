import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../domain/auth_session.dart';
import 'reown_auth_failure.dart';

/// Keep dispatch and wallet launch inside AppKit. Its modal error events and
/// async-void launch errors can arrive without settling `request`, so bridge
/// them into this request's future and release the caller's signing lease.
///
/// A sleeping wallet cannot answer a ping, so liveness is only judged while
/// the request is in flight: a session ping is queued just before the wallet
/// is launched and the wallet answers it once in the foreground. Only an
/// explicit ping error, or no answer for [probeTimeout] while this app holds
/// the foreground, marks the session unresponsive. Time spent in the wallet
/// never counts, so a user reviewing the request is not interrupted.
Future<dynamic> requestReownSignature({
  required ReownAppKitModal modal,
  required String chainId,
  required SessionRequestParams request,
  required bool Function() isCurrent,
  required Stream<void> invalidations,
  required bool Function() needsReconnect,
  required void Function() onUnresponsive,
  Duration relayTimeout = const Duration(seconds: 10),
  Duration probeTimeout = const Duration(seconds: 10),
  Duration responseTimeout = const Duration(seconds: 60),
}) async {
  final result = Completer<dynamic>();
  final topic = modal.session?.topic;
  Timer? responseTimer, probeTimer;
  var answered = false, dispatched = false;
  void current() {
    if (!isCurrent() || topic == null || modal.session?.topic != topic) {
      throw const AuthFailure('authWalletChanged');
    }
  }

  void fail(Object error, StackTrace stack) {
    if (!result.isCompleted) result.completeError(failureFromReown(error), stack);
    // Late SDK callbacks belong to the abandoned request, never a later retry.
  }

  void unresponsive() {
    if (result.isCompleted) return;
    if (!isCurrent()) {
      fail(const AuthFailure('authWalletChanged'), StackTrace.current);
      return;
    }
    // No answer is not proof of disconnection. Require a verified connection
    // before another signing attempt; never replay this one.
    fail(const AuthFailure('authWalletSessionUnverified'), StackTrace.current);
    onUnresponsive();
  }

  void probe() {
    probeTimer?.cancel();
    if (!dispatched || answered || result.isCompleted) return;
    probeTimer = Timer(probeTimeout, unresponsive);
  }

  void onError(ModalError? error) {
    if (error is ErrorOpeningWallet || error is WalletNotInstalled) {
      fail(const AuthFailure('authWalletOpenFailed'), StackTrace.current);
    } else if (error is UserRejectedRequest) {
      fail(const AuthFailure('authWalletRejected'), StackTrace.current);
    } else if (error != null) {
      fail(ReownAppKitModalException(error.message), StackTrace.current);
    }
  }

  void onRelayError(ErrorEvent? event) {
    // AppKit swallows publish failures; the request may never reach the wallet.
    final Object? error = event?.error;
    if (dispatched) fail(error ?? StateError('Relay error'), StackTrace.current);
  }

  void onSessionChanged() {
    try {
      current();
    } catch (error, stack) {
      fail(error, stack);
    }
  }

  final lifecycle = _LifecycleObserver((state) {
    if (state != AppLifecycleState.resumed) {
      probeTimer?.cancel();
      return;
    }
    // The wallet's queued answer arrives once the relay socket is back.
    unawaited(modal.reconnectRelay().catchError((Object _) {}));
    probe();
  });

  current();
  final subscription = invalidations.listen((_) {
    fail(
      AuthFailure(needsReconnect() ? 'authWalletSessionUnverified' : 'authWalletChanged'),
      StackTrace.current,
    );
  });
  final relayErrors = modal.appKit?.core.relayClient.onRelayClientError;
  modal.addListener(onSessionChanged);
  modal.onModalError.subscribe(onError);
  relayErrors?.subscribe(onRelayError);
  WidgetsBinding.instance.addObserver(lifecycle);
  runZonedGuarded(() async {
    try {
      // An unreachable relay is a network failure, not evidence about the wallet.
      await modal.reconnectRelay().timeout(
        relayTimeout,
        onTimeout: () => throw const AuthFailure('authWalletUnavailable'),
      );
      if (result.isCompleted) return;
      current();
      final sdk = modal.appKit;
      if (sdk == null) throw const AuthFailure('authWalletUnavailable');
      dispatched = true;
      // Queue the ping before the request launches the wallet.
      unawaited(
        sdk.ping(topic: topic!).then((_) {
          answered = true;
          probeTimer?.cancel();
        }, onError: (Object _) => unresponsive()),
      );
      responseTimer = Timer(responseTimeout, () {
        if (!answered) return unresponsive();
        fail(const AuthFailure('authWalletResponseTimeout'), StackTrace.current);
      });
      if (WidgetsBinding.instance.lifecycleState case null || AppLifecycleState.resumed) probe();
      final value = await modal.request(topic: topic, chainId: chainId, request: request);
      current();
      if (!result.isCompleted) result.complete(value);
    } catch (error, stack) {
      fail(error, stack);
    }
  }, fail);
  try {
    return await result.future;
  } finally {
    responseTimer?.cancel();
    probeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(lifecycle);
    unawaited(subscription.cancel());
    relayErrors?.unsubscribe(onRelayError);
    modal.onModalError.unsubscribe(onError);
    modal.removeListener(onSessionChanged);
  }
}

class _LifecycleObserver with WidgetsBindingObserver {
  _LifecycleObserver(this.onChange);
  final void Function(AppLifecycleState) onChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onChange(state);
}
