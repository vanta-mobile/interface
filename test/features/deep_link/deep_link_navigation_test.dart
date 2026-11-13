import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/assistant/application/assistant_provider.dart';
import 'package:vanta/features/deep_link/application/deep_link_provider.dart';
import 'package:vanta/features/deep_link/data/app_link_source.dart';
import 'package:vanta/features/deep_link/domain/app_deep_link.dart';
import 'package:vanta/features/deep_link/presentation/deep_link_host.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/market/domain/aster_instrument.dart';
import 'package:vanta/features/market/domain/market_precision.dart';
import 'package:vanta/features/portfolio/application/order_form_prefill_provider.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/order_form_prefill.dart';
import 'package:vanta/features/trade/application/navigation_provider.dart';

class _Assistant extends AssistantController {
  @override
  AssistantViewState build() => AssistantViewState();
  void ready({String draft = ''}) =>
      state = state.copyWith(authenticated: true, historyReady: true, draft: draft);
  @override
  void setDraft(String value) => state = state.copyWith(draft: value);
}

AsterInstrument _instrument(String symbol) => AsterInstrument(
  symbol: symbol,
  base: symbol.replaceAll('USDT', ''),
  ticker: const {},
  precision: const MarketPrecision(priceTick: '0.01', quantityStep: '0.001'),
);

class _Harness {
  _Harness({Future<List<AsterInstrument>>? instruments, Uri? launch}) {
    container = ProviderContainer(
      overrides: [
        appLinkSourceProvider.overrideWithValue(
          AppLinkSource(links: links.stream, initialLink: () async => launch),
        ),
        instrumentsProvider.overrideWith(
          (ref) => instruments ?? Future.value([_instrument('BTCUSDT'), _instrument('ETHUSDT')]),
        ),
        assistantProvider.overrideWith(_Assistant.new),
      ],
    );
    addTearDown(container.dispose);
    // close() only completes once a listener drains the stream.
    addTearDown(() => unawaited(links.close()));
  }

  final links = StreamController<Uri>();
  late final ProviderContainer container;
  DeepLinkNavigator get navigator => container.read(deepLinkNavigatorProvider);
  T read<T>(ProviderListenable<T> provider) => container.read(provider);
}

void main() {
  test('selects page, workspace tab and a catalog-verified market', () async {
    final h = _Harness();
    h.navigator.open(
      const AppDeepLink(
        DeepLinkTarget.futures,
        symbol: 'ETHUSDT',
        futuresTab: DeepLinkFuturesTab.chart,
      ),
    );
    await pumpEventQueue();
    expect(h.read(futuresWorkspaceTabProvider), FuturesWorkspaceTab.chart);
    expect(h.read(symbolProvider), 'ETHUSDT');
    h.navigator.open(
      const AppDeepLink(DeepLinkTarget.futures, panel: DeepLinkFuturesPanel.positions),
    );
    expect(h.read(futuresAccountRequestProvider), FuturesAccountTab.positions);
    h.navigator.open(const AppDeepLink(DeepLinkTarget.points));
    expect(h.read(appDestinationProvider), AppDestination.points);
    expect(h.read(futuresAccountRequestProvider), isNull, reason: 'a newer link replaces it');
    h.navigator.open(const AppDeepLink(DeepLinkTarget.futures, symbol: 'NOPEUSDT'));
    await pumpEventQueue();
    expect(h.read(appDestinationProvider), AppDestination.futures);
    expect(h.read(symbolProvider), 'ETHUSDT', reason: 'unknown markets keep the current one');
  });

  test('a late catalog never overrides a newer link or the user choice', () async {
    final catalog = Completer<List<AsterInstrument>>();
    final h = _Harness(instruments: catalog.future);
    h.navigator.open(const AppDeepLink(DeepLinkTarget.futures, symbol: 'ETHUSDT'));
    h.read(symbolProvider.notifier).select('SOLUSDT');
    catalog.complete([_instrument('ETHUSDT'), _instrument('SOLUSDT')]);
    await pumpEventQueue();
    expect(h.read(symbolProvider), 'SOLUSDT');

    final second = Completer<List<AsterInstrument>>();
    final g = _Harness(instruments: second.future);
    g.navigator.open(const AppDeepLink(DeepLinkTarget.futures, symbol: 'ETHUSDT'));
    g.navigator.open(const AppDeepLink(DeepLinkTarget.portfolio));
    second.complete([_instrument('ETHUSDT')]);
    await pumpEventQueue();
    expect(g.read(symbolProvider), 'BTCUSDT');
  });

  test('suggests order inputs for the verified market, fitted to its increments', () async {
    final h = _Harness();
    h.navigator.open(
      const AppDeepLink(
        DeepLinkTarget.futures,
        symbol: 'ETHUSDT',
        futuresTab: DeepLinkFuturesTab.trade,
        order: DeepLinkOrder(
          type: DeepLinkOrderType.limit,
          price: '3200.123',
          quantity: '0.25',
          unit: DeepLinkSizeUnit.base,
        ),
      ),
    );
    expect(h.read(orderFormPrefillProvider), isNull, reason: 'waits for the catalog');
    await pumpEventQueue();
    final prefill = h.read(orderFormPrefillProvider)!;
    expect(h.read(symbolProvider), 'ETHUSDT');
    expect(
      (prefill.symbol, prefill.type, prefill.price, prefill.size?.unit, prefill.size?.text),
      ('ETHUSDT', OrderPrefillType.limit, null, OrderSizeUnit.base, '0.25'),
      reason: 'a price off the 0.01 tick is dropped, not rounded',
    );

    h.navigator.open(const AppDeepLink(DeepLinkTarget.points));
    expect(h.read(orderFormPrefillProvider), isNull, reason: 'a newer link replaces it');

    h.navigator.open(
      const AppDeepLink(
        DeepLinkTarget.futures,
        symbol: 'NOPEUSDT',
        order: DeepLinkOrder(type: DeepLinkOrderType.market, quantity: '10'),
      ),
    );
    await pumpEventQueue();
    expect(h.read(orderFormPrefillProvider), isNull, reason: 'unknown markets get no terms');
  });

  test('fills an empty AI composer once the conversation is ready, never sends', () async {
    final h = _Harness();
    h.navigator.open(const AppDeepLink(DeepLinkTarget.assistant, prompt: 'Analyze BTC'));
    expect(h.read(appDestinationProvider), AppDestination.assistant);
    expect(h.read(assistantProvider).draft, '');
    (h.container.read(assistantProvider.notifier) as _Assistant).ready();
    expect(h.read(assistantProvider).draft, 'Analyze BTC');
    expect(h.read(assistantProvider).messages, isEmpty);

    final kept = _Harness();
    (kept.container.read(assistantProvider.notifier) as _Assistant).ready(draft: 'mine');
    kept.navigator.open(const AppDeepLink(DeepLinkTarget.assistant, prompt: 'Analyze BTC'));
    expect(kept.read(assistantProvider).draft, 'mine');

    final left = _Harness();
    left.navigator.open(const AppDeepLink(DeepLinkTarget.assistant, prompt: 'Analyze BTC'));
    left.read(appDestinationProvider.notifier).select(AppDestination.futures);
    left.read(appDestinationProvider.notifier).select(AppDestination.assistant);
    (left.container.read(assistantProvider.notifier) as _Assistant).ready();
    expect(left.read(assistantProvider).draft, '', reason: 'leaving the page cancels the prefill');
  });

  Future<_Harness> mount(WidgetTester tester, {Uri? launch}) async {
    final h = _Harness(launch: launch);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: Consumer(
          builder: (context, ref, _) {
            ref.listen(deepLinkInboxProvider, (_, _) {});
            return MaterialApp(
              home: DeepLinkHost(
                child: Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        Text('shell ${ref.watch(appDestinationProvider).name}'),
                        TextButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => const Text('sheet'),
                          ),
                          child: const Text('open sheet'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PopScope(canPop: false, child: Text('signing')),
                            ),
                          ),
                          child: const Text('open signing'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('a launch link opens after the shell mounts', (tester) async {
    await mount(tester, launch: Uri.parse('vantaapp://portfolio'));
    expect(find.text('shell portfolio'), findsOneWidget);
  });

  testWidgets('links close dismissible routes but yield to a protected flow', (tester) async {
    final h = await mount(tester);
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    h.links.add(Uri.parse('vantaapp://points'));
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsNothing);
    expect(find.text('shell points'), findsOneWidget);

    await tester.tap(find.text('open signing'));
    await tester.pumpAndSettle();
    h.links.add(Uri.parse('vantaapp://portfolio'));
    await tester.pumpAndSettle();
    expect(find.text('signing'), findsOneWidget);
    expect(h.read(appDestinationProvider), AppDestination.points);
  });
}
