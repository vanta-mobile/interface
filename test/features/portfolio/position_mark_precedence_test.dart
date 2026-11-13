import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/mark_price_mapper.dart';
import 'package:vanta/features/market/domain/mark_prices.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/presentation/position_valuation_rows.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/mark_prices.dart';
import '../../support/position_risk.dart';
import '../../support/trade_fixture.dart';

void main() {
  testWidgets('a newer signed position snapshot takes precedence over retained public marks', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final risk = TestPositionRiskRepository();
    final quote = mapMarkPrice(markPayload(price: '1'), receivedAt: DateTime.utc(2026, 1));
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      positionRiskRepository: risk,
      markPricesStream: Stream.value(MarkPrices(quotes: {'BTCUSDT': quote}, fresh: {'BTCUSDT'})),
    );
    addTearDown(identity.dispose);
    await launch(tester, container);
    await container.read(positionRiskProvider.notifier).refresh();
    final context = tester.element(find.byType(Navigator).first);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Consumer(
            builder: (_, ref, _) {
              final (quote, _) = watchPositionMark(ref, risk.result.positions.first);
              return Text(quote == null ? 'snapshot' : 'public');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('snapshot'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
