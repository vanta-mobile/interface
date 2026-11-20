import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/presentation/scaled_order_embedded.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/scaled_order.dart';
import '../../support/scaled_order_widget.dart';
import '../../support/trade_fixture.dart';

void main() {
  testWidgets('inline Scaled Order names the failing child, previews and confirms', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final repository = TestScaledRepository();
    final container = setup(
      tester,
      width: 390,
      language: const Locale('en'),
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await grantTrading(tester, container);
    await launch(tester, container);
    await container.read(liveOrderProvider.notifier).load('BTCUSDT');
    await container.read(mainOrderCapacityProvider.notifier).load('BTCUSDT');
    final data = container.read(liveOrderProvider).context!;
    Navigator.of(tester.element(find.byType(Navigator).first)).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 202, child: ScaledOrderEmbeddedForm(data: data, enabled: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(ScaledOrderEmbeddedForm)));

    // Preview stays hidden and both directions disabled until a plan exists.
    expect(find.byKey(const Key('scaled-preview')), findsNothing);
    // A child breaking an exchange rule is named with its terms.
    await field(tester, 'scaled-low', '1');
    await field(tester, 'scaled-high', '2');
    await field(tester, 'scaled-count', '2');
    await field(tester, 'scaled-size', '0.003');
    expect(
      tester.widget<Text>(find.byKey(const Key('scaled-error'))).data,
      startsWith('Order 1 (price 1, quantity'),
    );
    expect(find.byKey(const Key('scaled-preview')), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('scaled-review-long'))).onPressed,
      isNull,
    );

    // A highest price outside the exchange's percent band is reported under
    // that field, not as a child-order message.
    await field(tester, 'scaled-low', '79000');
    await field(tester, 'scaled-high', '90000');
    await field(tester, 'scaled-size', '0.002');
    expect(find.byKey(const Key('scaled-error')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('scaled-high-error'))).data,
      l10n.scaledPriceOutOfRange,
    );

    await field(tester, 'scaled-high', '81000');
    expect(find.byKey(const Key('scaled-high-error')), findsNothing);
    expect(find.byKey(const Key('scaled-error')), findsNothing);
    // 0.001 × 79000 + 0.001 × 81000 = 160 USDT at 10× leverage.
    expect(find.textContaining('16.00'), findsNWidgets(2));
    await tap(tester, 'scaled-preview');
    expect(find.byKey(const Key('scaled-preview-sheet')), findsOneWidget);
    expect(find.byKey(const Key('scaled-preview-row-1')), findsOneWidget);
    expect(find.textContaining('80000.000000', findRichText: true), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Above what the account can open: like Aster, only the clicked direction
    // is checked, and the field then reports that direction's maximum.
    await field(tester, 'scaled-size', '1');
    expect(find.byKey(const Key('scaled-error')), findsNothing);
    await tap(tester, 'scaled-review-long');
    expect(find.byKey(const Key('scaled-confirmation')), findsNothing);
    final max = tester.widget<Text>(find.byKey(const Key('scaled-error'))).data!;
    expect(max, startsWith('Maximum qty is'));
    // The long card shows the same maximum the message names.
    expect(
      find.textContaining(
        max.substring('Maximum qty is '.length).split(' ').first,
        findRichText: true,
      ),
      findsWidgets,
    );
    // Editing clears the message until the next click.
    await field(tester, 'scaled-size', '2');
    expect(find.byKey(const Key('scaled-error')), findsNothing);
    await field(tester, 'scaled-size', '0.002');
    await tap(tester, 'scaled-review-long');
    expect(find.byKey(const Key('scaled-confirmation')), findsOneWidget);
    expect(find.text(l10n.orderConfirmTitle), findsOneWidget);
    expect(find.text('0.002 BTC'), findsOneWidget);
    await tap(tester, 'scaled-cancel');
    expect(find.byKey(const Key('scaled-confirmation')), findsNothing);
    expect(repository.posts, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
