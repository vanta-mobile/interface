import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/core/vanta_api/vanta_api_http.dart';
import 'package:vanta/features/notifications/data/api_notification_mapper.dart';
import 'package:vanta/features/notifications/data/api_notification_symbols_repository.dart';
import 'package:vanta/features/notifications/domain/api_notification.dart';
import 'package:vanta/features/notifications/presentation/api_notification_details.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/api_notifications.dart';
import '../../support/vanta_api.dart';

void main() {
  test('notification additions retain nullable facts and decimal precision', () {
    final payload = mapApiNotification(
      inboxItem(
        payload: {
          'order_type': 'MARKET',
          'orig_type': 'STOP_MARKET',
          'avg_price': '1.123456789123456789',
          'fee_asset': 'BNB',
          'network': '56',
        },
      ),
    ).payload;
    expect(payload.orderType, 'MARKET');
    expect(payload.originalType, 'STOP_MARKET');
    expect(payload.network, '56');
    expect(payload.feeAsset, 'BNB');
    expect(payload.numbers[NotificationNumber.averagePrice], Decimal.parse('1.123456789123456789'));
    final empty = mapApiNotification(inboxItem(payload: {'order_type': null, 'avg_price': null}))
        .payload;
    expect(empty.orderType, isNull);
    expect(empty.numbers, isEmpty);
    for (final bad in ['NaN', true, 1.5]) {
      expect(
        () => mapApiNotification(inboxItem(payload: {'avg_price': bad})),
        throwsFormatException,
      );
    }
  });

  test('symbol metadata validates duplicates and never derives units from symbol text', () async {
    final backend = Backend();
    final repository = ApiNotificationSymbolsRepository(
      VantaApiHttp(baseUri: Uri.https('api.vanta.test'), client: backend.client),
    );
    addTearDown(repository.close);
    backend.routes['GET /v1/symbols'] = (_) => json({
      'items': [
        {'aster_symbol': 'BTCUSDT', 'base_asset': 'BTC', 'quote_asset': 'USDT'},
        {'aster_symbol': 'AAPLUSDT', 'base_asset': null, 'quote_asset': null},
      ],
    });
    final units = await repository.read();
    expect(units['BTCUSDT']!.base, 'BTC');
    expect(units['AAPLUSDT']!.quote, isNull);
    expect(() => units.clear(), throwsUnsupportedError);
    backend.routes['GET /v1/symbols'] = (_) => json({
      'items': [
        {'aster_symbol': 'BTCUSDT', 'base_asset': 'BTC'},
        {'aster_symbol': 'BTCUSDT', 'base_asset': 'ETH'},
      ],
    });
    await expectLater(repository.read(), throwsA(isA<VantaApiFailure>()));
  });

  for (final locale in ['en', 'zh']) {
    testWidgets('new facts use symbol units and refresh waits for metadata: $locale', (t) async {
      late ApiNotificationSymbolsRepository symbols;
      final f = InboxFixture(loadApiUnits: () => symbols.read());
      addTearDown(f.dispose);
      symbols = ApiNotificationSymbolsRepository(
        VantaApiHttp(baseUri: Uri.https('api.vanta.test'), client: f.backend.client),
      );
      Completer<void>? gate;
      f.backend.routes['GET /v1/symbols'] = (_) async {
        await gate?.future;
        return json({
          'items': [
            {'aster_symbol': 'BTCUSDT', 'base_asset': 'BTC', 'quote_asset': 'USDT'},
          ],
        });
      };
      addTearDown(symbols.close);
      f.items.add(
        inboxItem(
          payload: {
            'order_type': 'MARKET',
            'orig_type': 'STOP_MARKET',
            'avg_price': '70000.123456789123456789',
            'qty': '0.001',
            'fee': '-0.01',
            'fee_asset': 'BNB',
            'network': '56',
          },
        ),
      );
      await f.mount(t, language: locale, size: const Size(320, 844), scale: 1.5);
      await t.tap(find.byKey(const ValueKey('notification-event:1')));
      await t.pumpAndSettle();
      final l = AppLocalizations.of(t.element(find.byType(ApiNotificationDetails)));
      expect(find.text('70,000.123456789123456789 USDT'), findsOneWidget);
      expect(find.text('0.001 BTC'), findsOneWidget);
      expect(find.text('-0.01 BNB'), findsOneWidget);
      expect(find.text(l.notificationOrderType('STOP_MARKET')), findsOneWidget);
      expect(find.text('56'), findsOneWidget);
      gate = Completer<void>();
      var settled = false;
      final refresh = t.widget<RefreshIndicator>(find.byType(RefreshIndicator).last).onRefresh()
        ..then((_) => settled = true);
      await t.pump();
      expect(settled, isFalse);
      expect(find.text('0.001 BTC'), findsOneWidget);
      gate.complete();
      await t.pumpAndSettle();
      await refresh;
      expect(settled, isTrue);
      expect(t.takeException(), isNull);
    });
  }
}
