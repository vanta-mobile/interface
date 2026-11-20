import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/application/transfer_confirmation_provider.dart';
import 'package:vanta/features/funding/presentation/transfer_record_progress.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/transfers.dart';

void main() {
  final hash = '0x${'b' * 64}';
  Future<AppLocalizations> pump(WidgetTester tester, Widget child, List<dynamic> overrides) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides.cast()],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byWidget(child)));
  }

  testWidgets('a completed record shows both steps as done without reading the chain', (
    tester,
  ) async {
    final record = transferRecord(type: 'WITHDRAW', status: 'SUCCESS', hash: hash);
    final l = await pump(tester, TransferRecordProgress(record), const []);
    expect(find.text(l.assetHistoryConfirmed), findsOneWidget);
    expect(find.text(l.assetHistoryConfirmationUnavailable), findsNothing);
    expect(find.text(l.assetHistoryWithdrawCompleted), findsOneWidget);
  });

  testWidgets('a processing deposit with a confirmed receipt shows the chain step done', (
    tester,
  ) async {
    final record = transferRecord(status: 'PROCESSING', hash: hash);
    final l = await pump(tester, TransferRecordProgress(record), [
      transferConfirmationProvider((56, hash)).overrideWith((_) async => true),
    ]);
    expect(find.text(l.assetHistoryConfirmed), findsOneWidget);
    expect(find.text(l.assetHistoryCrediting), findsOneWidget);
  });

  testWidgets('an unconfirmed or unreadable processing record keeps the existing copy', (
    tester,
  ) async {
    final record = transferRecord(type: 'WITHDRAW', status: 'PROCESSING', hash: hash);
    for (final result in <Future<bool> Function()>[
      () async => false,
      () => Future.error(StateError('rpc')),
    ]) {
      final l = await pump(tester, TransferRecordProgress(record), [
        transferConfirmationProvider((56, hash)).overrideWith((_) => result()),
      ]);
      await tester.pump();
      expect(find.text(l.assetHistoryConfirmationUnavailable), findsOneWidget);
      expect(find.text(l.assetHistoryConfirmed), findsNothing);
      expect(find.text(l.assetHistoryWithdrawPending), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('only processing records with a readable hash query the chain', (tester) async {
    expect(transferConfirmationKey(transferRecord(status: 'PROCESSING', hash: hash)), (56, hash));
    expect(transferConfirmationKey(transferRecord(status: 'PROCESSING')), null);
    expect(transferConfirmationKey(transferRecord(status: 'SUCCESS', hash: hash)), null);
    expect(transferConfirmationKey(transferRecord(status: 'FAILED', hash: hash)), null);
  });
}
