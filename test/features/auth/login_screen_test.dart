import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/presentation/auth_controls.dart';

import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';
import '../../support/wallet_login_route.dart';

void main() {
  testWidgets('expired code preserves digits and failed resend, then accepts a new code', (
    tester,
  ) async {
    final repository = TestIdentityRepository()
      ..verifyFailure = const AuthFailure('authCodeExpired');
    addTearDown(repository.dispose);
    final container = setup(tester, identityRepository: repository, language: const Locale('en'));
    await launch(tester, container);
    await openWalletLogin(tester);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Vanta'), findsOneWidget);
    expect(find.byKey(const Key('enter-demo')), findsNothing);
    await tester.enterText(find.byKey(const Key('login-email')), 'alex@example.com');
    await tester.tap(find.byKey(const Key('send-email-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-code')), '482619');
    await tester.pump();
    await tester.tap(find.byKey(const Key('verify-email-code')));
    await tester.pumpAndSettle();
    expect(find.text('Code expired. Request a new code.'), findsOneWidget);
    expect(find.byKey(const Key('verify-email-code')), findsNothing);
    final input = find.byKey(const Key('login-code'));
    expect(tester.widget<TextField>(input).controller!.text, '482619');
    for (var i = 0; i < 6; i++) {
      final cell = tester.widget<Container>(find.byKey(Key('code-cell-$i')));
      expect((cell.decoration! as BoxDecoration).border, Border.all(color: AppColors.authError));
    }
    repository.sendGate = Completer<void>();
    repository.sendFailure = const AuthFailure('authNetwork', reason: 'Connection timed out');
    final resend = find.byKey(const Key('resend-email-code'));
    await tester.tap(resend);
    await tester.pump();
    expect(tester.widget<AuthActionButton>(resend).busy, true);
    expect(repository.sent, 2);
    repository.sendGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Connection timed out'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller!.text, '482619');
    expect(find.byKey(const Key('verify-email-code')), findsNothing);
    repository.sendFailure = null;
    await tester.tap(resend);
    await tester.pumpAndSettle();
    expect(repository.sent, 3);
    expect(tester.widget<TextField>(input).controller!.text, '');
    expect(find.byKey(const Key('verify-email-code')), findsOneWidget);
    expect(container.read(authProvider).resendAt, isNotNull);
    await closeWalletLogin(tester, container);
  });

  testWidgets('code uses a single autofill field and back preserves the email', (tester) async {
    final repository = TestIdentityRepository();
    addTearDown(repository.dispose);
    final container = setup(tester, identityRepository: repository);
    await launch(tester, container);
    await openWalletLogin(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), 'alex@example.com');
    await tester.tap(find.byKey(const Key('send-email-code')));
    await tester.pumpAndSettle();
    final input = find.byKey(const Key('login-code'));
    expect(find.text('验证并继续'), findsOneWidget);
    expect(find.text('如果未收到邮件，请检查垃圾邮件文件夹。'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('resend-email-code'))).onPressed, null);
    expect(tester.widget<TextField>(input).autofillHints, [AutofillHints.oneTimeCode]);
    await tester.enterText(input, '48a2619');
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, '482619');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: '123456', selection: TextSelection.collapsed(offset: 6)),
    );
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, '123456');
    await tester.tap(find.byKey(const Key('auth-back')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('login-email'))).controller!.text,
      'alex@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsNothing);
    expect(repository.verified, 0);
    await closeWalletLogin(tester, container);
  });

  for (final provider in SocialLoginProvider.values) {
    testWidgets('$provider button spins during login and preserves email on failure', (
      tester,
    ) async {
      final repository = TestIdentityRepository()
        ..socialGate = Completer<void>()
        ..socialFailure = const AuthFailure('authNetwork', reason: 'Connection timed out');
      addTearDown(repository.dispose);
      final container = setup(tester, identityRepository: repository);
      await launch(tester, container);
      await openWalletLogin(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('login-email')), 'alex@example.com');
      final button = find.byKey(
        Key(provider == SocialLoginProvider.google ? 'login-google' : 'login-x'),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(repository.socialProvider, provider);
      expect(tester.widget<AuthActionButton>(button).busy, true);
      repository.socialGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Connection timed out'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('login-email'))).controller!.text,
        'alex@example.com',
      );
      expect(tester.takeException(), null);
      await closeWalletLogin(tester, container);
    });
  }
}
