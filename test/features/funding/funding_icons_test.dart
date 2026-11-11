import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta/features/funding/application/funding_icon_provider.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/presentation/funding_icons.dart';

import '../../support/asset_metadata.dart';
import '../../support/funding_info.dart';
import '../../support/funding_screen.dart';

Finder _memoryImages(Finder parent) => find.descendant(
  of: parent,
  matching: find.byWidgetPredicate(
    (w) => w is Image && (w.image is MemoryImage || w.image is ResizeImage),
  ),
);

void main() {
  for (final operation in FundingOperation.values) {
    testWidgets('${operation.name} uses catalog token logos and distinct chain icons', (t) async {
      final h = FundingHarness();
      h.catalog.rows = [
        fundingAssetRow(asset: 'BNB', native: true),
        fundingAssetRow(),
        fundingAssetRow(asset: 'ETH', chain: 1, native: true),
        fundingAssetRow(asset: 'ETH', chain: 42161, native: true),
      ];
      await h.open(t, operation: operation);
      expect(_memoryImages(find.byType(FundingAssetIcon)), findsOneWidget);
      expect(_memoryImages(find.byType(FundingNetworkIcon)), findsOneWidget);
      expect(h.icons.requests.where((r) => r.url == h.icons.catalog).length, 1);

      await t.tap(find.byKey(const Key('funding-asset-selector')));
      await t.pumpAndSettle();
      final usdt = find.byKey(const Key('funding-option-USDT'));
      expect(_memoryImages(usdt), findsOneWidget);
      await t.tap(usdt);
      await t.pumpAndSettle();
      expect(h.icons.requests.where((r) => r.url == h.icons.urls['usdt']).length, 1);

      await t.tap(find.byKey(const Key('funding-network')));
      await t.pumpAndSettle();
      for (final id in [1, 56, 42161]) {
        expect(_memoryImages(find.byKey(Key('funding-option-$id'))), findsOneWidget);
        expect(h.icons.requests.where((r) => r.url == h.icons.urls['network-$id']).length, 1);
      }
      await t.tap(find.byKey(const Key('funding-option-42161')));
      await t.pumpAndSettle();
      final network = t.widget<FundingNetworkIcon>(find.byType(FundingNetworkIcon));
      expect(network.chainId, 42161);
      expect(_memoryImages(find.byType(FundingAssetIcon)), findsOneWidget);
      // Opening dropdowns and switching selections reuse the single catalog read.
      expect(h.icons.requests.where((r) => r.url == h.icons.catalog).length, 1);
      expect(t.takeException(), isNull);
      await h.close(t);
    });
  }

  testWidgets('image failures retain input; refresh awaits and retries visible images', (t) async {
    final h = FundingHarness();
    final network = h.icons.urls['network-56']!, token = h.icons.urls['bnb']!;
    h.icons.failures.addAll([network, token]);
    await h.open(t);
    await t.enterText(find.byKey(const Key('funding-amount')), '0.1');
    expect(find.byIcon(Icons.public), findsOneWidget);
    expect(_memoryImages(find.byType(FundingAssetIcon)), findsNothing);

    h.icons.failures.clear();
    final gate = Completer<http.Response>();
    h.icons.gates[network] = gate;
    var done = false;
    final refresh = h.container.read(fundingIconRefreshProvider)().then((_) => done = true);
    await t.pump();
    expect(done, false);
    gate.complete(http.Response.bytes(metadataPng, 200, headers: {'content-type': 'image/png'}));
    await refresh;
    await t.pumpAndSettle();
    expect(_memoryImages(find.byType(FundingAssetIcon)), findsOneWidget);
    expect(_memoryImages(find.byType(FundingNetworkIcon)), findsOneWidget);
    expect(find.text('0.1'), findsOneWidget);
    expect(h.icons.requests.where((r) => r.url == network).length, 2);
    expect(h.icons.requests.where((r) => r.url == token).length, 2);
    expect(t.takeException(), isNull);
    await h.close(t);
  });

  testWidgets('failed or missing catalog keeps usable fallback without per-token requests', (
    t,
  ) async {
    final h = FundingHarness();
    h.icons.failures.add(h.icons.catalog);
    await h.open(t);
    await t.enterText(find.byKey(const Key('funding-amount')), '0.2');
    expect(_memoryImages(find.byType(FundingAssetIcon)), findsNothing);
    expect(find.byKey(const Key('funding-deposit-submit')), findsOneWidget);
    expect(h.icons.requests.where((r) => r.url == h.icons.urls['bnb']), isEmpty);
    await t.tap(find.byKey(const Key('funding-asset-selector')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('funding-option-USDT')));
    await t.pumpAndSettle();
    expect(h.icons.requests.where((r) => r.url == h.icons.catalog).length, 1);
    expect(t.takeException(), isNull);
    await h.close(t);
  });
}
