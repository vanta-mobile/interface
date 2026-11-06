import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';

import '../../support/identity_repository.dart';

import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/errors/error_text.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/presentation/account_read_controls.dart';
import 'package:vanta/features/assistant/domain/assistant_view_state.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

void main() {
  for (final locale in ['en', 'zh']) {
    testWidgets('safe server reason reaches existing account error UI: $locale', (tester) async {
      final identity = TestIdentityRepository();
      addTearDown(identity.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [identityRepositoryProvider.overrideWithValue(identity)],
          child: MaterialApp(
            locale: Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: AccountReadControls(
                state: const AccountSnapshotState(
                  failure: AccountReadFailure(
                    'accountReadFailed',
                    code: -2019,
                    details: ApiErrorDetails(message: 'Margin is insufficient.', status: 400),
                  ),
                ),
                onRead: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Margin is insufficient.'), findsOneWidget);
      expect(find.textContaining('-2019'), findsOneWidget);
    });
  }
  testWidgets('unknown financial outcome stays visible with server detail and timeout', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final text = apiErrorText(
      context,
      'liveOrderOutcomeUnknown',
      const ApiErrorDetails(message: 'Connection closed.', status: 503),
      fallbackText: AppLocalizations.of(context).liveOrderOutcomeUnknown,
    );
    expect(text, contains('Connection closed.'));
    expect(text, contains(AppLocalizations.of(context).liveOrderOutcomeUnknown));
    final timeout = apiErrorText(
      context,
      'liveOrderOutcomeUnknown',
      const ApiErrorDetails(cause: ApiErrorCause.timeout),
      fallbackText: AppLocalizations.of(context).liveOrderOutcomeUnknown,
    );
    expect(timeout, contains(AppLocalizations.of(context).liveOrderOutcomeUnknown));
    expect(timeout, contains(AppLocalizations.of(context).apiRequestTimeout));
    expect(
      apiErrorText(context, 'accountNetwork', const ApiErrorDetails(cause: ApiErrorCause.timeout)),
      AppLocalizations.of(context).apiRequestTimeout,
    );
  });
  test('changing the assistant error key clears previous server details', () {
    final state = AssistantViewState(
      failureKey: 'assistantUnavailable',
      errorDetails: const ApiErrorDetails(message: 'old message'),
    );
    expect(state.copyWith(draft: 'new input').errorDetails?.message, 'old message');
    expect(state.copyWith(failureKey: null).errorDetails, isNull);
    expect(state.copyWith(failureKey: 'assistantAuthorization').errorDetails, isNull);
  });
}
