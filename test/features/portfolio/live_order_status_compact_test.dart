import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/presentation/live_order_status.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/live_order.dart';

class _Fixed extends LiveOrderController {
  _Fixed(this.value);
  final LiveOrderState value;
  @override
  LiveOrderState build() => value;
}

Widget _app(LiveOrderState state) => ProviderScope(
  overrides: [liveOrderProvider.overrideWith(() => _Fixed(state))],
  child: MaterialApp(
    theme: vantaTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: const LiveOrderStatus())),
  ),
);

void main() {
  final intent = liveIntent();
  final settled = LiveOrderState(
    context: intent.context,
    intent: intent,
    result: LiveOrderResult(orderId: '42', status: 'NEW', executedQuantity: Decimal.zero),
  );

  testWidgets('status hides an order settled by another flow', (tester) async {
    await tester.pumpWidget(_app(settled));
    expect(find.text(intent.clientOrderId), findsNothing);
    expect(find.text('42'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status keeps the unknown-outcome recheck', (tester) async {
    await tester.pumpWidget(
      _app(
        LiveOrderState(context: intent.context, intent: intent, result: const LiveOrderResult()),
      ),
    );
    expect(find.byKey(const Key('live-order-recheck')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
