import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/presentation/aster_account_panel.dart';

import '../../support/account_updates.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> open(WidgetTester tester, Widget page) async {
    final context = tester.element(find.byType(Navigator).first);
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'balance event displays absolute wallet value, clears unavailable fields and labels partial history',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final account = TestAsterAccountRepository();
      final container = setup(
        tester,
        language: const Locale('en'),
        identityRepository: identity,
        asterAccountRepository: account,
      );
      addTearDown(identity.dispose);
      await launch(tester, container);
      await container.read(accountReadProvider.notifier).refresh();
      container.read(accountReadProvider.notifier).applyEvent(accountUpdate());
      await open(tester, const Scaffold(body: SingleChildScrollView(child: AsterAccountPanel())));
      expect(find.text('102.000000000000000001 USDT'), findsOneWidget);
      expect(find.text('92.000000000000000001 USDT'), findsOneWidget);
      expect(find.text('89.000000000000000001 USDT'), findsNothing);
      expect(find.textContaining('Last applied account event:'), findsOneWidget);
      expect(find.textContaining('Missing rows do not mean closed positions'), findsOneWidget);
      expect(find.text('99999 USDT'), findsNothing);
      expect(account.calls, 1);
      expect(identity.wallets, 0);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
