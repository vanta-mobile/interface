import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/data/wallet_redirect_handler.dart';

Uri _response([String value = 'encrypted']) =>
    Uri.parse('vantaapp://wallet?topic=topic&wc_ev=$value');
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late StreamController<Uri> links;
  late WalletRedirectHandler handler;
  final calls = <String>[];

  setUp(() {
    calls.clear();
    links = StreamController<Uri>(sync: true);
    handler = WalletRedirectHandler(links: links.stream, initialLink: () async => null);
  });
  tearDown(() async {
    await handler.close();
    await links.close();
  });
  Future<bool> dispatch(String value) async {
    calls.add(value);
    return true;
  }

  test('buffers warm response until SDK initialization and deduplicates delivery', () async {
    handler.start();
    handler.start();
    links.add(_response());
    links.add(_response());
    expect(calls, isEmpty);
    handler.attach(dispatch);
    await _flush();
    links.add(_response());
    handler.retry();
    await _flush();
    expect(calls, [_response().toString()]);
  });

  test('initial response and event stream share one delivery', () async {
    await handler.close();
    final initial = Completer<Uri?>();
    handler = WalletRedirectHandler(links: links.stream, initialLink: () => initial.future);
    handler.start();
    handler.attach(dispatch);
    links.add(_response());
    await _flush();
    initial.complete(_response());
    await _flush();
    expect(calls, [_response().toString()]);
  });

  test('bare returns, foreign URLs and ambiguous or malformed payloads are ignored', () async {
    handler.start();
    handler.attach(dispatch);
    for (final value in [
      'vantaapp://wallet',
      'https://wallet?topic=t&wc_ev=e',
      // Privy's OAuth scheme and navigation hosts never carry wallet responses.
      'vanta://wallet?topic=t&wc_ev=e',
      'vantaapp://futures?topic=t&wc_ev=e',
      'vantaapp://other?topic=t&wc_ev=e',
      'vantaapp://user@wallet?topic=t&wc_ev=e',
      'vantaapp://wallet:42?topic=t&wc_ev=e',
      'vantaapp://wallet/path?topic=t&wc_ev=e',
      'vantaapp://wallet?topic=t&wc_ev=',
      'vantaapp://wallet?wc_ev=e',
      'vantaapp://wallet?topic=t&wc_ev=e&wc_ev=second',
      'vantaapp://wallet?topic=t&wc_ev=%FF',
      'vantaapp://wallet?topic=t&wc_ev=${'a' * 262144}',
    ]) {
      links.add(Uri.parse(value));
    }
    links.addError(const FormatException());
    await _flush();
    expect(calls, isEmpty);
    links.add(_response());
    await _flush();
    expect(calls, [_response().toString()]);
  });

  test('direct wallet responses are forwarded to SDK without interpretation', () async {
    handler.start();
    handler.attach(dispatch);
    final direct = [
      Uri.parse('vantaapp://wallet/?phantomRequest=encrypted'),
      Uri.parse('vantaapp://wallet?solflareRequest=encrypted'),
    ];
    for (final uri in direct) {
      links.add(uri);
    }
    await _flush();
    expect(calls, direct.map((u) => u.toString()).toList());
  });

  for (final throws in [false, true]) {
    test(
      'unhandled response ${throws ? 'throw' : 'false'} retries without blocking next response',
      () async {
        var ready = false;
        handler.start();
        handler.attach((value) async {
          calls.add(value);
          if (!ready && value == _response('stale').toString()) {
            if (throws) throw StateError('not ready');
            return false;
          }
          return true;
        });
        links.add(_response('stale'));
        await _flush();
        links.add(_response('current'));
        await _flush();
        expect(calls.last, _response('current').toString());
        ready = true;
        handler.retry();
        await _flush();
        expect(calls.last, _response('stale').toString());
        final count = calls.length;
        handler.retry();
        await _flush();
        expect(calls, hasLength(count));
      },
    );
  }

  test('serializes responses and deduplicates while SDK is awaiting a response', () async {
    final gate = Completer<bool>();
    handler.start();
    handler.attach((value) async {
      calls.add(value);
      return calls.length == 1 ? gate.future : true;
    });
    links.add(_response('first'));
    links.add(_response('first'));
    links.add(_response('second'));
    expect(calls, [_response('first').toString()]);
    gate.complete(true);
    await _flush();
    expect(calls, [_response('first').toString(), _response('second').toString()]);
  });

  test('retry while SDK dispatch is pending is honored after it settles', () async {
    final gate = Completer<bool>();
    handler.start();
    handler.attach((value) async {
      calls.add(value);
      return calls.length == 1 ? gate.future : true;
    });
    links.add(_response());
    handler.retry();
    gate.complete(false);
    await _flush();
    expect(calls, hasLength(2));
  });

  test('replacement SDK receives response left in flight on the previous SDK', () async {
    final gate = Completer<bool>();
    handler.start();
    handler.attach((_) => gate.future);
    links.add(_response());
    handler.detach();
    handler.attach(dispatch);
    gate.complete(true);
    await _flush();
    expect(calls, [_response().toString()]);
  });

  test('bounded queue retains accepted callbacks until SDK is ready', () async {
    handler.start();
    for (var i = 0; i < 20; i++) {
      links.add(_response('$i'));
    }
    handler.attach(dispatch);
    await _flush();
    expect(calls, [for (var i = 0; i < 8; i++) _response('$i').toString()]);
  });

  test('close stops delivery, ignores late initial link and in-flight dispatch', () async {
    await handler.close();
    final initial = Completer<Uri?>(), gate = Completer<bool>();
    handler = WalletRedirectHandler(links: links.stream, initialLink: () => initial.future);
    handler.start();
    handler.attach((value) async {
      calls.add(value);
      return gate.future;
    });
    links.add(_response('first'));
    links.add(_response('second'));
    await handler.close();
    expect(links.hasListener, isFalse);
    initial.complete(_response('initial'));
    gate.complete(true);
    links.add(_response('late'));
    handler.attach(dispatch);
    handler.retry();
    await _flush();
    expect(calls, [_response('first').toString()]);
  });
}
