import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:reown_appkit/modal/services/uri_service/relay_wallet_request.dart';
import 'package:reown_appkit/modal/services/uri_service/request_wallet_launcher.dart';

import '../domain/auth_session.dart';
import 'reown_auth_failure.dart';
import 'wallet_error_message.dart';
import 'wallet_launch_report.dart';

/// Keep dispatch and wallet launch inside AppKit. Its modal error events and
/// async-void launch errors can arrive without settling `request`, so bridge
/// them into this request's future and release the caller's signing/network lease.
///
/// A sleeping wallet cannot answer a ping, so liveness is only judged while
/// the request is in flight: a session ping is queued just before the wallet
/// is launched and the wallet answers it once in the foreground. Only an
/// explicit ping error, or no answer for [probeTimeout] while this app holds
/// the foreground, marks the session unresponsive. Time spent in the wallet
/// never counts, so a user reviewing the request is not interrupted.
///
/// [responseTimeout] only ends a request while this app is in the foreground:
/// if it passes while the user is in the wallet, the wallet's answer still
/// wins when they return, and the timeout applies only if none arrives
/// within [probeTimeout] of returning.
Future<dynamic> requestReownWallet({
  required ReownAppKitModal modal,
  required String chainId,
  required SessionRequestParams request,
  String? switchToChainId,
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
  final relay = modal.appKit?.core.relayClient;
  Timer? responseTimer, probeTimer, graceTimer;
  var answered = false, dispatched = false, deadlinePassed = false;
  var probeRevision = 0, awaitingRelay = false;
  void current() {
    if (!isCurrent() || topic == null || modal.session?.topic != topic) {
      throw const AuthFailure('authWalletChanged');
    }
  }

  void fail(Object error, StackTrace stack) {
    // Preserve JSON-RPC codes until the operation-specific caller handles them
    // (network approval may add BNB only for explicit 4902). The connection
    // boundary maps any remaining error to a safe AuthFailure.
    if (!result.isCompleted) result.completeError(error, stack);
    // Late SDK callbacks belong to the abandoned request, never a later retry.
  }

  void unresponsive([Object? error]) {
    if (result.isCompleted) return;
    if (!isCurrent()) {
      fail(const AuthFailure('authWalletChanged'), StackTrace.current);
      return;
    }
    // No answer is not proof of disconnection. Require a verified connection
    // before another signing attempt; never replay this one.
    fail(
      AuthFailure(
        'authWalletSessionUnverified',
        reason: error == null ? null : failureFromReown(error).reason,
      ),
      StackTrace.current,
    );
    onUnresponsive();
  }

  void probe() {
    probeTimer?.cancel();
    if (!dispatched || answered || result.isCompleted) return;
    probeTimer = Timer(probeTimeout, () {
      if (relay?.isConnected != true) {
        fail(const AuthFailure('authNetwork'), StackTrace.current);
      } else {
        unresponsive();
      }
    });
  }

  bool foreground() => switch (WidgetsBinding.instance.lifecycleState) {
    null || AppLifecycleState.resumed => true,
    _ => false,
  };

  void expire() {
    if (result.isCompleted) return;
    if (relay?.isConnected != true) {
      return fail(const AuthFailure('authNetwork'), StackTrace.current);
    }
    if (!answered) return unresponsive();
    fail(const AuthFailure('authWalletResponseTimeout'), StackTrace.current);
  }

  void pingPeer() {
    if (!dispatched || result.isCompleted) return;
    final revision = ++probeRevision;
    answered = false;
    awaitingRelay = relay?.isConnected != true;
    if (awaitingRelay) return;
    unawaited(
      modal.appKit!
          .ping(topic: topic!)
          .then(
            (_) {
              if (revision != probeRevision || result.isCompleted) return;
              answered = true;
              probeTimer?.cancel();
            },
            onError: (Object error) {
              if (revision != probeRevision || result.isCompleted) return;
              if (relay?.isConnected != true) {
                fail(const AuthFailure('authNetwork'), StackTrace.current);
              } else {
                unresponsive(error);
              }
            },
          ),
    );
  }

  void onRelayConnect(EventArgs? _) {
    if (awaitingRelay && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      pingPeer();
      probe();
    }
  }

  void onError(ModalError? error) {
    if (error is ErrorOpeningWallet || error is WalletNotInstalled) {
      fail(
        AuthFailure('authWalletOpenFailed', reason: walletReason(error!.description)),
        StackTrace.current,
      );
    } else if (error is UserRejectedRequest) {
      fail(const AuthFailure('authWalletRejected'), StackTrace.current);
    } else if (error != null) {
      fail(ReownAppKitModalException(error.message), StackTrace.current);
    }
  }

  void onRelayError(ErrorEvent? event) {
    // AppKit swallows publish failures; the request may never reach the wallet.
    final Object? error = event?.error;
    fail(error ?? const AuthFailure('authWalletUnavailable'), StackTrace.current);
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
      graceTimer?.cancel();
      return;
    }
    // AppKit owns reconnection. Recheck a pending request's peer: its previous
    // pong does not prove that the wallet kept the session while backgrounded.
    pingPeer();
    probe();
    // The deadline passed in the wallet: give its answer time to arrive.
    if (deadlinePassed && dispatched && !result.isCompleted) {
      graceTimer?.cancel();
      graceTimer = Timer(probeTimeout, expire);
    }
  });

  current();
  final subscription = invalidations.listen((_) {
    fail(
      AuthFailure(needsReconnect() ? 'authWalletSessionUnverified' : 'authWalletChanged'),
      StackTrace.current,
    );
  });
  final relayErrors = relay?.onRelayClientError;
  modal.addListener(onSessionChanged);
  modal.onModalError.subscribe(onError);
  relayErrors?.subscribe(onRelayError);
  relay?.onRelayClientConnect.subscribe(onRelayConnect);
  WidgetsBinding.instance.addObserver(lifecycle);
  runZonedGuarded(() async {
    try {
      // An unreachable relay is a network failure, not evidence about the wallet.
      await modal.reconnectRelay().timeout(
        relayTimeout,
        onTimeout: () => throw const AuthFailure('authWalletConnectionTimeout'),
      );
      if (result.isCompleted) return;
      current();
      final sdk = modal.appKit;
      if (sdk == null) throw const AuthFailure('authWalletUnavailable');
      if (relay?.isConnected != true) throw const AuthFailure('authNetwork');
      dispatched = true;
      // Queue the ping before the request launches the wallet.
      pingPeer();
      responseTimer = Timer(responseTimeout, () {
        deadlinePassed = true;
        // In the wallet, wait for the user to return before judging.
        if (foreground()) expire();
      });
      if (foreground()) probe();
      final value = await withWalletRequestGuard(
        isCurrent: () => !result.isCompleted && isCurrent(),
        request: () => modal.request(
          topic: topic,
          chainId: chainId,
          request: request,
          switchToChainId: switchToChainId,
        ),
      );
      current();
      if (!result.isCompleted) result.complete(value);
    } catch (error, stack) {
      // The modal error event already settled this request; the launch error
      // itself arrives here with its kind and target link.
      if (error is WalletRequestLaunchException) {
        reportWalletLaunchFailure(error, stack, walletName: modal.session?.peer?.metadata.name);
      }
      // MetaMask answers code 1 "Invalid Id" when its WalletConnect manager no
      // longer holds this session topic. Its SDK still answers pings, so only
      // this reply reveals the orphaned session: require a reconnection.
      if (_orphanedWalletSession(error)) return unresponsive(error);
      fail(error, stack);
    }
  }, fail);
  try {
    return await result.future;
  } finally {
    responseTimer?.cancel();
    probeTimer?.cancel();
    graceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(lifecycle);
    unawaited(subscription.cancel());
    relayErrors?.unsubscribe(onRelayError);
    relay?.onRelayClientConnect.unsubscribe(onRelayConnect);
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

bool _orphanedWalletSession(Object error) =>
    error is JsonRpcError && error.code == 1 && error.message == 'Invalid Id';
