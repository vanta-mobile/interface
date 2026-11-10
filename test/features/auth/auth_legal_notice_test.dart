import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/presentation/auth_legal_notice.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final calls = <MethodCall>[];
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);
        return true;
      },
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });

  Future<void> mount(
    WidgetTester tester,
    String language, {
    double width = 360,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: vantaTheme(),
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const AuthLegalNotice(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'zh']) {
    testWidgets('$language legal links open their distinct HTTPS documents externally', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await mount(tester, language);
        final labels = language == 'en' ? ['Terms of Use', 'Privacy Policy'] : ['使用条款', '隐私政策'];
        expect(calls, isEmpty);
        for (final (index, key, path) in [
          (0, 'auth-terms-of-use', 'terms-of-use'),
          (1, 'auth-privacy-policy', 'privacy-policy'),
        ]) {
          final button = find.byKey(Key(key));
          expect(find.text(labels[index]), findsOneWidget);
          expect(tester.getSemantics(button).getSemanticsData().flagsCollection.isLink, true);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(calls.last.method, 'launch');
          final arguments = calls.last.arguments as Map<Object?, Object?>;
          expect(arguments['url'], 'https://app.vanta.exchange/docs/reference/$path');
          expect(arguments['useWebView'], false);
          expect(arguments['useSafariVC'], false);
        }
        expect(calls.length, 2);
        Focus.of(tester.element(find.text(labels.first))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(calls.length, 3);
        expect(
          (calls.last.arguments as Map<Object?, Object?>)['url'],
          'https://app.vanta.exchange/docs/reference/terms-of-use',
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    for (final width in [240.0, 320.0, 768.0]) {
      testWidgets('$language legal links fit width $width at enlarged text', (tester) async {
        await mount(tester, language, width: width, scale: 2);
        expect(find.byKey(const Key('auth-terms-of-use')), findsOneWidget);
        expect(find.byKey(const Key('auth-privacy-policy')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
