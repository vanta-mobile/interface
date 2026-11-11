import 'dart:async';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/presentation/funding_icons.dart';
import 'package:vanta/features/portfolio/application/asset_metadata_provider.dart';
import 'package:vanta/features/portfolio/application/portfolio_overview_provider.dart';
import 'package:vanta/features/portfolio/data/asset_metadata_mapper.dart';
import 'package:vanta/features/portfolio/domain/asset_metadata.dart';
import 'package:vanta/features/portfolio/domain/portfolio_overview.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_asset_details.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_assets.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/asset_metadata.dart';

class _SignedOut extends AuthController {
  @override
  AuthSession build() => const AuthSession();
}

void main() {
  late TestAssetMetadataRepository repository;
  late ProviderContainer container;
  late List<Uri> reads;
  late int retries;

  Future<void> mount(
    WidgetTester t, {
    bool catalogFailure = false,
    bool funding = false,
    FutureOr<Uint8List> Function(Uri)? image,
  }) async {
    repository = TestAssetMetadataRepository();
    repository.snapshots[AssetMetadataSource.logos] = mapAssetMetadata(
      metadataPayload(AssetMetadataSource.logos),
      source: AssetMetadataSource.logos,
      receivedAt: DateTime.now().toUtc(),
    );
    if (catalogFailure) repository.failures[AssetMetadataSource.logos] = StateError('fixture');
    reads = [];
    retries = 0;
    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_SignedOut.new),
        assetMetadataRepositoryProvider.overrideWithValue(repository),
        assetLogoProvider.overrideWith((ref, uri) {
          reads.add(uri);
          return image?.call(uri) ?? metadataPng;
        }),
        assetLogoRetryProvider.overrideWith(
          (ref) => (uri) {
            retries++;
            ref.invalidate(assetLogoProvider(uri));
          },
        ),
      ],
    );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      container.dispose();
      await t.pump();
    });
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                if (funding)
                  const SliverToBoxAdapter(child: Center(child: FundingAssetIcon('USDF'))),
                PortfolioAssetList(
                  overview: PortfolioOverview(
                    performance: PortfolioPerformance(),
                    assets: [
                      for (final symbol in ['USDF', 'BTC', 'UNKNOWN'])
                        PortfolioAsset(symbol: symbol, balance: Decimal.one),
                    ],
                  ),
                  preview: true,
                  hidden: false,
                  hideSmall: false,
                  onHideSmall: (_) {},
                  sliver: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Finder badge(String symbol) =>
      find.byWidgetPredicate((widget) => widget is PortfolioAssetBadge && widget.symbol == symbol);
  Finder badgeImage(String symbol) =>
      find.descendant(of: badge(symbol), matching: find.byType(Image));

  testWidgets('portfolio and deposit share catalog/image requests and preserve their sizes', (
    t,
  ) async {
    final gate = Completer<Uint8List>();
    await mount(
      t,
      funding: true,
      image: (uri) => uri == metadataLogo('usdf') ? gate.future : metadataPng,
    );
    expect(badgeImage('USDF'), findsNothing);
    expect(find.text('USDF'), findsOneWidget);
    gate.complete(metadataPng);
    await t.pumpAndSettle();
    expect(
      (t.widget<Image>(badgeImage('USDF')).image as ResizeImage).imageProvider,
      isA<MemoryImage>().having((image) => image.bytes, 'bytes', metadataPng),
    );
    expect(t.getSize(badgeImage('USDF')), const Size(32, 32));
    final depositImage = find.descendant(
      of: find.byType(FundingAssetIcon),
      matching: find.byType(Image),
    );
    expect(t.getSize(depositImage), const Size(24, 24));
    expect(reads, unorderedEquals([metadataLogo('usdf'), metadataLogo('btc')]));
    expect(repository.calls, [AssetMetadataSource.logos]);
    expect(find.descendant(of: badge('UNKNOWN'), matching: find.text('U')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final corrupt in [false, true]) {
    testWidgets('image ${corrupt ? 'decode' : 'request'} failure keeps balances and fallback', (
      t,
    ) async {
      await mount(
        t,
        image: (_) {
          if (corrupt) return Uint8List.fromList([1, 2, 3]);
          throw StateError('fixture');
        },
      );
      expect(find.text('USDF'), findsOneWidget);
      expect(find.descendant(of: badge('USDF'), matching: find.text('U')), findsOneWidget);
      expect(t.getSize(badge('USDF')), const Size(32, 32));
      expect(reads.length, 2);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('catalog failure keeps asset rows usable without image requests', (t) async {
    await mount(t, catalogFailure: true);
    expect(find.text('USDF'), findsOneWidget);
    expect(find.text('BTC'), findsOneWidget);
    expect(reads, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('page refresh awaits catalog and failed visible image retry', (t) async {
    final imageGate = Completer<Uint8List>();
    var fail = true;
    await mount(
      t,
      image: (uri) {
        if (uri != metadataLogo('usdf')) return metadataPng;
        if (fail) throw StateError('fixture');
        return imageGate.future;
      },
    );
    final catalogGate = Completer<AssetMetadataSnapshot>();
    repository.gates[AssetMetadataSource.logos] = catalogGate;
    fail = false;
    var settled = false;
    final refresh = container.read(portfolioRefreshProvider)().then((_) => settled = true);
    await t.pumpAndSettle();
    expect(settled, isFalse);
    catalogGate.complete(repository.snapshots[AssetMetadataSource.logos]);
    await t.pumpAndSettle();
    expect(retries, 1);
    expect(settled, isFalse);
    imageGate.complete(metadataPng);
    await refresh;
    await t.pumpAndSettle();
    expect(
      (t.widget<Image>(badgeImage('USDF')).image as ResizeImage).imageProvider,
      isA<MemoryImage>().having((image) => image.bytes, 'bytes', metadataPng),
    );
    expect(settled, isTrue);
    expect(reads.where((uri) => uri == metadataLogo('btc')).length, 1);
    expect(t.takeException(), isNull);
  });
}
