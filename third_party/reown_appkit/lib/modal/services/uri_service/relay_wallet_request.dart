import 'dart:async';

import 'package:reown_core/relay_client/i_relay_client.dart';
import 'package:reown_core/relay_client/relay_client_models.dart';

final _walletRequestGuardKey = Object();

/// Keep the adapter's identity/cancellation guard attached across SDK awaits.
/// Different requests/SDK instances never share mutable cancellation state.
Future<T> withWalletRequestGuard<T>({
  required bool Function() isCurrent,
  required Future<T> Function() request,
}) => runZoned(request, zoneValues: {_walletRequestGuardKey: isCurrent});

bool Function() currentWalletRequestGuard() =>
    Zone.current[_walletRequestGuardKey] as bool Function()? ?? () => true;

/// Do not background the dapp before its request has been accepted by the
/// relay. The same topic/correlation ID is used for dispatch and wallet launch.
Future<dynamic> dispatchRelayWalletRequest({
  required IRelayClient relay,
  required String topic,
  required int requestId,
  required Future<dynamic> Function() send,
  required Future<void> Function() launch,
  required bool Function() isCurrent,
  Duration publishTimeout = const Duration(seconds: 10),
}) async {
  final published = Completer<void>();
  void onPublish(RelayPublishEvent? event) {
    if (event?.topic == topic && event?.correlationId == requestId && !published.isCompleted) {
      published.complete();
    }
  }

  void onError(ErrorEvent? event) {
    if (!published.isCompleted) {
      final Object? error = event?.error;
      published.completeError(error ?? StateError('Wallet relay publish failed'));
    }
  }

  void unsubscribe() {
    relay.onRelayClientPublish.unsubscribe(onPublish);
    relay.onRelayClientError.unsubscribe(onError);
  }

  relay.onRelayClientPublish.subscribe(onPublish);
  relay.onRelayClientError.subscribe(onError);
  try {
    // Both futures have handlers before either is awaited; validation failures
    // before publish and immediate wallet replies must also settle this call.
    var settled = false;
    final response = Future<dynamic>.sync(send).then<_EarlyResponse>(
      (value) {
        settled = true;
        return _EarlyResponse(value);
      },
      onError: (Object error, StackTrace stack) {
        settled = true;
        Error.throwWithStackTrace(error, stack);
      },
    );
    final first = await Future.any<Object?>([published.future.then<Object?>((_) => null), response])
        .timeout(
          publishTimeout,
          onTimeout: () =>
              throw TimeoutException('Wallet request was not acknowledged by the relay'),
        );
    // Publish listeners have no role while waiting for the wallet's decision.
    unsubscribe();
    if (first is _EarlyResponse) return first.value;
    if (settled) return (await response).value;
    if (!isCurrent()) throw StateError('Wallet session changed before opening its request');
    await launch();
    return (await response).value;
  } finally {
    unsubscribe();
  }
}

class _EarlyResponse {
  const _EarlyResponse(this.value);
  final dynamic value;
}
