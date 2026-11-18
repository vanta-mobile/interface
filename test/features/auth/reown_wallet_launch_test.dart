import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/modal/services/explorer_service/models/redirect.dart';
import 'package:reown_appkit/modal/services/uri_service/launch_url_exception.dart';
import 'package:reown_appkit/modal/services/uri_service/request_wallet_launcher.dart';
import 'package:reown_appkit/modal/utils/core_utils.dart';
import 'package:reown_appkit/modal/utils/platform_utils.dart';

void main() {
  test('restored MetaMask launches from peer redirect without an explorer wallet entry', () async {
    Uri? opened;
    var launches = 0;
    await launchWalletRequest(
      cachedRedirect: null,
      nativeRedirect: 'metamask://wc',
      universalRedirect: 'https://metamask.app.link',
      topic: 'fixture-topic',
      requestId: 42,
      platform: PlatformType.mobile,
      openRedirect: (redirect, {wcURI, pType}) async {
        launches++;
        expect(pType, PlatformType.mobile);
        opened = CoreUtils.formatCustomSchemeUri(redirect.mobile, wcURI);
        return true;
      },
    );
    expect(launches, 1);
    expect(opened.toString(), 'metamask://wc?requestId=42&sessionTopic=fixture-topic');
  });

  for (final useCache in [false, true]) {
    test(
      'missing native metadata uses ${useCache ? 'cached mobile' : 'peer universal'} redirect',
      () async {
        String? mobile;
        await launchWalletRequest(
          cachedRedirect: useCache ? WalletRedirect(mobile: 'metamask://') : null,
          nativeRedirect: ' ',
          universalRedirect: useCache ? null : 'https://metamask.app.link',
          topic: 'fixture-topic',
          requestId: 1,
          platform: PlatformType.mobile,
          openRedirect: (redirect, {wcURI, pType}) async {
            mobile = redirect.mobile;
            return true;
          },
        );
        expect(mobile, useCache ? 'metamask://' : 'https://metamask.app.link');
      },
    );
  }

  test(
    'missing wallet redirect fails immediately instead of awaiting an invisible request',
    () async {
      var launches = 0;
      await expectLater(
        launchWalletRequest(
          cachedRedirect: null,
          nativeRedirect: null,
          universalRedirect: null,
          topic: 'fixture-topic',
          requestId: 1,
          platform: PlatformType.mobile,
          openRedirect: (redirect, {wcURI, pType}) async {
            launches++;
            return true;
          },
        ),
        throwsA(
          isA<WalletRequestLaunchException>().having(
            (e) => e.message,
            'reason',
            contains('Reconnect'),
          ),
        ),
      );
      expect(launches, 0);
    },
  );

  for (final failure in ['false', 'throw', 'timeout']) {
    test('OS launch $failure settles promptly and never attempts a second launch', () async {
      final gate = Completer<bool>();
      var launches = 0;
      await expectLater(
        launchWalletRequest(
          cachedRedirect: null,
          nativeRedirect: 'metamask://',
          universalRedirect: null,
          topic: 'fixture-topic',
          requestId: 1,
          platform: PlatformType.mobile,
          timeout: const Duration(milliseconds: 10),
          openRedirect: (redirect, {wcURI, pType}) async {
            launches++;
            if (failure == 'throw') throw StateError('OS refused wallet launch');
            return failure == 'timeout' ? gate.future : false;
          },
        ),
        throwsA(failure == 'throw' ? isA<StateError>() : isA<WalletRequestLaunchException>()),
      );
      gate.complete(true);
      await pumpEventQueue();
      expect(launches, 1);
    });
  }

  test('refused OS launch reports a concrete cause instead of "App not installed"', () async {
    await expectLater(
      launchWalletRequest(
        cachedRedirect: null,
        nativeRedirect: 'bnc://',
        universalRedirect: null,
        topic: 'fixture-topic',
        requestId: 1,
        platform: PlatformType.mobile,
        openRedirect: (redirect, {wcURI, pType}) async => throw CanNotLaunchUrl(),
      ),
      throwsA(
        isA<WalletRequestLaunchException>().having(
          (e) => e.toString(),
          'reason',
          'The operating system could not open the connected wallet app',
        ),
      ),
    );
    expect(CanNotLaunchUrl().toString(), 'App not installed');
  });

  test('launch failures carry their kind and the targeted wallet link', () async {
    Future<WalletRequestLaunchException> launchFailure(
      Future<bool> Function() open, {
      String? native = 'bnc://app.binance.com/cedefi',
    }) async {
      try {
        await launchWalletRequest(
          cachedRedirect: null,
          nativeRedirect: native,
          universalRedirect: null,
          topic: 'fixture-topic',
          requestId: 7,
          platform: PlatformType.mobile,
          timeout: const Duration(milliseconds: 10),
          openRedirect: (redirect, {wcURI, pType}) => open(),
        );
      } on WalletRequestLaunchException catch (error) {
        return error;
      }
      throw TestFailure('launch unexpectedly succeeded');
    }

    final refused = await launchFailure(() async => throw CanNotLaunchUrl());
    expect(refused.failure, WalletLaunchFailure.refused);
    expect(refused.redirect.toString(), 'bnc://app.binance.com/cedefi');
    expect(refused.redirect.toString(), isNot(contains('fixture-topic')));
    expect((await launchFailure(() async => false)).failure, WalletLaunchFailure.invalidLink);
    expect(
      (await launchFailure(() => Completer<bool>().future)).failure,
      WalletLaunchFailure.timeout,
    );
    final missing = await launchFailure(() async => true, native: null);
    expect(missing.failure, WalletLaunchFailure.noRedirect);
    expect(missing.redirect, isNull);
  });
}
