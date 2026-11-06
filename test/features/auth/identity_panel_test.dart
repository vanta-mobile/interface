import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/presentation/identity_panel.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

void main() {
  testWidgets('email login shows failures, keeps entered code, and isolates demo funds', (
    tester,
  ) async {
    final repository = TestIdentityRepository();
    addTearDown(repository.dispose);
    final container = setup(tester, identityRepository: repository);
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('account-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), 'test@example.com');
    await tester.ensureVisible(find.byKey(const Key('send-email-code')));
    await tester.tap(find.byKey(const Key('send-email-code')));
    await tester.pumpAndSettle();
    expect(find.text('test@example.com'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login-code')), '123456');
    await tester.pump();
    repository.verifyFailure = const AuthFailure('authInvalidCode', reason: 'Code expired');
    await tester.tap(find.byKey(const Key('verify-email-code')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Code expired'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('login-code'))).controller?.text,
      '123456',
    );
    repository.verifyFailure = null;
    await tester.tap(find.byKey(const Key('verify-email-code')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(IdentityPanel),
        matching: find.text(identityWithWallet.walletAddress!),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('trading-authorization-entry')), findsOneWidget);
    expect(container.read(accountProvider).connected, false);
    expect(container.read(accountProvider).balance.toString(), '10000');
    await tester.tap(find.byKey(const Key('logout-identity')));
    await tester.pumpAndSettle();
    expect(container.read(authProvider).identity, null);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });

  for (final spec in [(360.0, 1.0), (390.0, 1.5), (844.0, 1.5)]) {
    testWidgets('login form stays accessible with keyboard at ${spec.$1}, scale ${spec.$2}', (
      tester,
    ) async {
      final repository = TestIdentityRepository();
      addTearDown(repository.dispose);
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$2,
        identityRepository: repository,
      );
      if (spec.$1 == 844) tester.view.physicalSize = const Size(844, 390);
      await launch(tester, container);
      await tester.tap(find.byKey(const Key('account-button')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('login-email')));
      await tester.enterText(find.byKey(const Key('login-email')), 'test@example.com');
      await tester.ensureVisible(find.byKey(const Key('send-email-code')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-email-code')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('login-code')));
      expect(find.byKey(const Key('login-code')), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
