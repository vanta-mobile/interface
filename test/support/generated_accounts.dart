import 'package:vanta/features/authorization/application/trading_agent_provider.dart';

import 'trading_agents.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/application/wallet_operation_provider.dart';
import 'package:vanta/core/data/wallet_operation_journal.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/subaccounts/application/generated_subaccount_provider.dart';
import 'package:vanta/features/subaccounts/application/subaccount_list_provider.dart';
import 'package:vanta/features/subaccounts/application/subaccount_management_provider.dart';
import 'package:vanta/features/subaccounts/data/subaccount_wallet_store.dart';
import 'package:vanta/features/subaccounts/domain/subaccount_management.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import 'account_operations.dart';
import 'account_switch_authorization.dart';
import 'aster_account.dart';
import 'identity_repository.dart';
import 'subaccounts.dart';
import 'subaccount_balances.dart';

import 'package:vanta/features/subaccounts/application/account_balances_provider.dart';

const generatedChildAddress = '0x3333333333333333333333333333333333333333';
WalletOperationRecord createdSubaccountRecord({
  String address = generatedChildAddress,
  int nonce = 1,
}) => WalletOperationRecord(
  kind: WalletOperationKind.createSubaccount,
  address: accountAddress,
  nonce: nonce,
  preparedAt: DateTime.utc(2026, 11, 9),
  terms: {'child': address, 'name': 'Momentum'},
  acknowledged: true,
);

class JournalSubaccountRepository extends TestSubaccountManagementRepository {
  JournalSubaccountRepository(this.journal);
  final MemoryWalletOperationJournal journal;
  @override
  Future<WalletOperationRecord> submit(
    SubaccountManagementReview review, {
    String childSignature = '',
    required bool Function() isCurrent,
  }) async {
    final record = await super.submit(review, childSignature: childSignature, isCurrent: isCurrent);
    if (isCurrent()) {
      await journal.prepare(review.record);
      await journal.report(record.key);
    }
    return record;
  }
}

class GeneratedAccountsFixture {
  GeneratedAccountsFixture(
    WidgetTester t, {
    List<WalletOperationRecord> records = const [],
    WalletConnector? switchConnector,
  }) {
    journal = MemoryWalletOperationJournal(records: records);
    repository = JournalSubaccountRepository(journal);
    wallets = DeviceSubaccountWalletStore(
      read: (k) async => storage[k],
      write: (k, v) async {
        storage[k] = v;
      },
    );
    container = ProviderContainer(
      overrides: [
        tradingAgentStoreProvider.overrideWithValue(
          MemoryTradingAgentStorage().store(DateTime.now),
        ),
        identityRepositoryProvider.overrideWithValue(identity),
        accountSwitchAuthorizationProvider.overrideWithValue(TestAccountSwitchAuthorization()),
        if (switchConnector != null)
          walletSwitchConnectorFactoryProvider.overrideWithValue(() => switchConnector),
        walletOperationJournalProvider.overrideWithValue(journal),
        subaccountWalletStoreProvider.overrideWithValue(wallets),
        subaccountBalanceRepositoryProvider.overrideWithValue(balances),
        subaccountManagementRepositoryProvider.overrideWithValue(repository),
        subaccountListRepositoryProvider.overrideWithValue(directory),
        asterAccountRepositoryProvider.overrideWithValue(account),
      ],
    );
    addTearDown(() {
      if (!_closed) container.dispose();
    });
    addTearDown(identity.dispose);
    addTearDown(journal.close);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
  }
  bool _closed = false;
  Future<void> close(WidgetTester t) async {
    if (_closed) return;
    await t.pumpWidget(const SizedBox());
    container.dispose();
    _closed = true;
    await t.pump();
  }

  final identity = TestIdentityRepository()..restored = signingIdentity;
  final directory = TestSubaccountListRepository();
  final balances = TestSubaccountBalanceReader();
  final account = TestAsterAccountRepository();
  final storage = <String, String>{};
  late final MemoryWalletOperationJournal journal;
  late final JournalSubaccountRepository repository;
  late final DeviceSubaccountWalletStore wallets;
  late final ProviderContainer container;
  Future<void> mount(
    WidgetTester t,
    Widget screen, {
    Size size = const Size(393, 818),
    String locale = 'en',
    double scale = 1,
    EdgeInsets? safeInsets,
    Key? captureKey,
  }) async {
    t.view.physicalSize = size;
    container.read(authProvider);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => RepaintBoundary(
            key: captureKey,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: safeInsets,
                viewPadding: safeInsets,
              ),
              child: child!,
            ),
          ),
          home: screen,
        ),
      ),
    );
    await t.pumpAndSettle();
  }
}

Future<void> tapAccountControl(WidgetTester t, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      finder,
      180,
      scrollable: find
          .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .last,
    );
  }
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}
