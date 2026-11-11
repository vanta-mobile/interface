import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/market/domain/market_precision.dart';
import 'package:vanta/features/market/domain/market_quote.dart';
import 'package:vanta/features/portfolio/application/asset_metadata_provider.dart';
import 'package:vanta/features/portfolio/application/asset_metadata_refresh_provider.dart';
import 'package:vanta/features/portfolio/domain/asset_metadata.dart';
import 'package:vanta/features/trade/presentation/widgets/coin_icon.dart';
import 'package:vanta/features/trade/presentation/widgets/market_list_row.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/asset_metadata.dart';

void main() {
  late ProviderContainer container;
  late TestAssetMetadataRepository repository;
  late List<Uri> images;
  final btc = metadataLogo('btc'), eth = metadataLogo('eth');
  final png = File('test/fixtures/funding_icons/eth.png').readAsBytesSync();

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    FutureOr<Uint8List> Function(Uri)? image,
    bool catalogFails = false,
  }) async {
    images = [];
    repository = TestAssetMetadataRepository();
    repository.snapshots[AssetMetadataSource.logos] = AssetMetadataSnapshot(
      source: AssetMetadataSource.logos,
      receivedAt: DateTime.now().toUtc(),
      entries: {
        'BTC': AssetMetadata(symbol: 'BTC', logo: btc),
        'ETH': AssetMetadata(symbol: 'ETH', logo: eth),
      },
    );
    if (catalogFails) repository.failures[AssetMetadataSource.logos] = StateError('offline');
    container = ProviderContainer(
      overrides: [
        assetMetadataRepositoryProvider.overrideWithValue(repository),
        assetLogoProvider.overrideWith((ref, uri) {
          images.add(uri);
          return image?.call(uri) ?? png;
        }),
      ],
    );
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  }

  testWidgets('market rows and header sizes share one catalog and one image per asset', (t) async {
    var selected = false;
    await mount(
      t,
      Column(
        children: [
          MarketListRow(
            quote: const MarketQuote(symbol: 'BTCUSDT', base: 'BTC', precision: MarketPrecision()),
            onSelect: () => selected = true,
          ),
          MarketListRow(
            quote: const MarketQuote(symbol: 'ETHUSDT', base: 'ETH', precision: MarketPrecision()),
            onSelect: () {},
          ),
          const CoinIcon(base: 'BTC', size: 32),
        ],
      ),
    );
    expect(find.byType(Image), findsNWidgets(3));
    expect(t.widgetList<Image>(find.byType(Image)).map((i) => i.width), [18, 18, 32]);
    expect(repository.calls, [AssetMetadataSource.logos]);
    expect(images, [btc, eth]);
    await t.tap(find.text('BTCUSDT'));
    expect(selected, true);
    await t.tap(find.byKey(const ValueKey('favorite-BTCUSDT')));
    expect(container.read(favoriteSymbolsProvider), contains('BTCUSDT'));
    expect(t.takeException(), isNull);
    await close(t);
  });

  testWidgets('catalog and image failure retain fallbacks and refresh awaits recovery', (t) async {
    var failImage = true;
    final gate = Completer<Uint8List>();
    await mount(
      t,
      const Row(
        children: [
          CoinIcon(),
          CoinIcon(base: 'UNKNOWN'),
        ],
      ),
      catalogFails: true,
      image: (_) => failImage ? Future.error(StateError('offline')) : gate.future,
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('◎'), findsOneWidget);
    expect(images, isEmpty);
    repository.failures.clear();
    await container.read(assetMetadataRefreshProvider)();
    await t.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    failImage = false;
    var done = false;
    final refresh = container.read(assetMetadataRefreshProvider)().then((_) => done = true);
    await t.pump();
    expect(done, false);
    gate.complete(png);
    await refresh;
    await t.pumpAndSettle();
    final image = t.widget<Image>(find.byType(Image));
    await t.runAsync(() => precacheImage(image.image, t.element(find.byType(MaterialApp))));
    await t.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.text('◎'), findsOneWidget);
    expect(t.takeException(), isNull);
    await close(t);
  });

  testWidgets('late prior-token result never replaces the selected token image', (t) async {
    final old = Completer<Uint8List>();
    var base = 'BTC';
    late StateSetter set;
    await mount(
      t,
      StatefulBuilder(
        builder: (_, update) {
          set = update;
          return CoinIcon(base: base);
        },
      ),
      image: (uri) => uri == btc ? old.future : png,
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    set(() => base = 'ETH');
    await t.pumpAndSettle();
    final image = t.widget<Image>(find.byType(Image)).image;
    old.complete(Uint8List(1));
    await t.pumpAndSettle();
    expect(t.widget<Image>(find.byType(Image)).image, image);
    expect(t.takeException(), isNull);
    await close(t);
  });
}
