import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/modal/services/uri_service/request_wallet_launcher.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vanta/core/monitoring/error_event_filter.dart';
import 'package:vanta/features/auth/data/wallet_launch_report.dart';

void main() {
  test('wallet launch report keeps kind, wallet and link scheme/host only', () {
    final error = WalletRequestLaunchException(
      'The operating system could not open the connected wallet app',
      failure: WalletLaunchFailure.refused,
      redirect: Uri.parse('bnc://app.binance.com/cedefi?appId=private-app'),
    );
    final tags = walletLaunchTags(error, walletName: 'Binance Wallet');
    expect(tags, {
      'wallet.launch': 'refused',
      'wallet.name': 'binance_wallet',
      'wallet.scheme': 'bnc',
      'wallet.host': 'app.binance.com',
    });
    final clean = sanitizeErrorEvent(
      SentryEvent(
        throwable: error,
        tags: {...tags, 'wallet.link': 'bnc://app.binance.com/wc?sessionTopic=private-topic'},
        exceptions: [SentryException(type: 'WalletRequestLaunchException', value: '$error')],
      ),
    );
    expect(clean.tags, tags);
    expect(clean.exceptions!.single.value, '[redacted]');
    expect(
      walletLaunchTags(
        const WalletRequestLaunchException('Connected wallet session is unavailable'),
      ),
      {'wallet.launch': 'unavailable'},
    );
  });
}
