import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/modal/services/uri_service/relay_wallet_request.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/data/wallet_transaction_dispatch.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';

import '../../support/reown_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestRelayClient relay;
  late Completer<dynamic> response;
  var sends = 0, launches = 0;
  var current = true;
  setUp(() {
    relay = TestRelayClient();
    response = Completer<dynamic>();
    sends = launches = 0;
    current = true;
  });

  Future<dynamic> dispatch({Duration timeout = const Duration(seconds: 1)}) =>
      dispatchRelayWalletRequest(
        relay: relay,
        topic: 'fixture-session',
        requestId: 42,
        isCurrent: () => current,
        publishTimeout: timeout,
        send: () {
          sends++;
          return response.future;
        },
        launch: () async => launches++,
      );
  void acknowledge({String topic = 'fixture-session', int id = 42}) =>
      relay.onRelayClientPublish.broadcast(RelayPublishEvent(topic: topic, correlationId: id));

  test('one request opens the wallet only after its own relay acknowledgement', () async {
    final pending = dispatch();
    await pumpEventQueue();
    expect(sends, 1);
    expect(launches, 0);
    acknowledge(topic: 'another-session');
    acknowledge(id: 43); // A ping / another request must not unlock this one.
    await pumpEventQueue();
    expect(launches, 0);
    acknowledge();
    await pumpEventQueue();
    expect(launches, 1);
    expect(relay.onRelayClientPublish.subscriberCount, 0);
    expect(relay.onRelayClientError.subscriberCount, 0);
    response.complete('signature');
    expect(await pending, 'signature');
    expect(sends, 1);
  });

  for (final failure in ['validation', 'relay']) {
    test('$failure Invalid Id is preserved and never opens a wallet with no request', () async {
      final pending = expectLater(
        dispatch(),
        throwsA(isA<JsonRpcError>().having((e) => e.message, 'reason', 'Invalid Id')),
      );
      await pumpEventQueue();
      final error = JsonRpcError(code: -32600, message: 'Invalid Id');
      if (failure == 'validation') {
        response.completeError(error);
      } else {
        relay.onRelayClientError.broadcast(ErrorEvent(error));
      }
      await pending;
      acknowledge();
      if (!response.isCompleted) response.complete('late signature');
      await pumpEventQueue();
      expect(launches, 0);
      expect(sends, 1);
    });
  }

  test('publish timeout ignores late acknowledgements and never resends', () async {
    await expectLater(
      dispatch(timeout: const Duration(milliseconds: 10)),
      throwsA(isA<TimeoutException>().having((e) => e.message, 'reason', contains('relay'))),
    );
    acknowledge();
    response.complete('late signature');
    await pumpEventQueue();
    expect(launches, 0);
    expect(sends, 1);
  });

  test(
    'a financial request with no publish confirmation stays unknown and is never replayed',
    () async {
      final result = await dispatchWalletTransaction(
        () => dispatch(timeout: const Duration(milliseconds: 10)),
      );
      expect(result.status, WalletTransactionStatus.unknown);
      acknowledge();
      response.complete('0x${'1' * 64}');
      await pumpEventQueue();
      expect(launches, 0);
      expect(sends, 1);
      expect(result.status, WalletTransactionStatus.unknown);
    },
  );

  test('an identity change before publishing cannot open the previous wallet', () async {
    final pending = expectLater(dispatch(), throwsA(isA<StateError>()));
    await pumpEventQueue();
    current = false;
    acknowledge();
    await pending;
    response.complete('late signature');
    await pumpEventQueue();
    expect(launches, 0);
    expect(sends, 1);
  });

  test('a response already received before publish needs no second app launch', () async {
    final pending = dispatch();
    response.complete('already answered');
    expect(await pending, 'already answered');
    acknowledge();
    expect(launches, 0);
    expect(sends, 1);
  });

  test('a cancelled signing lease prevents launch after a late relay acknowledgement', () async {
    final modal = TestReownModal();
    final connection = ReownWalletConnection(modal, modal.address, '56');
    addTearDown(connection.release);
    addTearDown(modal.dispose);
    modal.onRequest = (_) => dispatchRelayWalletRequest(
      relay: relay,
      topic: 'fixture-session',
      requestId: 42,
      send: () => response.future,
      launch: () async => launches++,
      isCurrent: currentWalletRequestGuard(),
    );
    final pending = expectLater(
      connection.signPersonalMessage('Sign in'),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    await pumpEventQueue();
    await connection.release();
    await pending;
    acknowledge();
    response.complete('late signature');
    await pumpEventQueue();
    expect(launches, 0);
    expect(modal.requests, hasLength(1));
  });

  test('overlapping request guards remain isolated across asynchronous SDK work', () async {
    final otherResponse = Completer<dynamic>();
    final otherGate = Completer<void>();
    var otherLaunches = 0;
    final first = withWalletRequestGuard(
      isCurrent: () => current,
      request: () async {
        final guard = currentWalletRequestGuard();
        return dispatchRelayWalletRequest(
          relay: relay,
          topic: 'fixture-session',
          requestId: 42,
          send: () => response.future,
          launch: () async => launches++,
          isCurrent: guard,
        );
      },
    );
    final rejected = expectLater(first, throwsA(isA<StateError>()));
    final other = withWalletRequestGuard(
      isCurrent: () => true,
      request: () async {
        await otherGate.future;
        return dispatchRelayWalletRequest(
          relay: relay,
          topic: 'fixture-session',
          requestId: 43,
          send: () => otherResponse.future,
          launch: () async => otherLaunches++,
          isCurrent: currentWalletRequestGuard(),
        );
      },
    );
    current = false;
    otherGate.complete();
    await pumpEventQueue();
    acknowledge();
    acknowledge(id: 43);
    await rejected;
    await pumpEventQueue();
    expect(launches, 0);
    expect(otherLaunches, 1);
    response.complete('late signature');
    otherResponse.complete('other signature');
    expect(await other, 'other signature');
  });
}
