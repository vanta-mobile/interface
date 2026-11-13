import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/deep_link/data/app_link_source.dart';
import 'package:vanta/features/deep_link/domain/app_deep_link.dart';

AppDeepLink? parse(String link) => AppDeepLink.parse(Uri.parse(link));

void main() {
  test('maps each owned host and ignores links owned by wallet or OAuth', () {
    for (final target in DeepLinkTarget.values) {
      expect(parse('vantaapp://${target.name}')?.target, target);
      expect(parse('vantaapp://${target.name}/')?.target, target);
    }
    for (final link in [
      'vantaapp://wallet?wc_ev=x&topic=y',
      'vanta://wallet?wc_ev=x&topic=y',
      'vanta://futures',
      'https://vanta.exchange/futures',
      'vantaapp://unknown',
      'vantaapp://futures/orders',
      'vantaapp://user@futures',
      'vantaapp://futures:8080',
      'vantaapp://futures?symbol=${'A' * 9000}',
    ]) {
      expect(parse(link), isNull, reason: link);
    }
  });

  test('normalizes market symbols and drops invalid ones without losing the page', () {
    for (final raw in ['ETHUSDT', 'eth-usdt', 'ETH/USDT', 'eth_usdt', 'ETH', ' eth ']) {
      expect(
        parse('vantaapp://futures?symbol=${Uri.encodeQueryComponent(raw)}')?.symbol,
        'ETHUSDT',
      );
    }
    expect(parse('vantaapp://futures?symbol=1000PEPE')?.symbol, '1000PEPEUSDT');
    for (final raw in ['USDT', '', 'ET\$H', '${'A' * 21}USDT']) {
      final link = parse('vantaapp://futures?symbol=${Uri.encodeQueryComponent(raw)}');
      expect(link?.target, DeepLinkTarget.futures, reason: raw);
      expect(link?.symbol, isNull, reason: raw);
    }
    final repeated = parse('vantaapp://futures?symbol=ETH&symbol=BTC&tab=chart');
    expect(repeated?.symbol, isNull);
    expect(repeated?.futuresTab, DeepLinkFuturesTab.chart);
    expect(parse('vantaapp://futures?tab=trade')?.futuresTab, DeepLinkFuturesTab.trade);
    expect(parse('vantaapp://futures?tab=orders')?.futuresTab, isNull);
    for (final panel in DeepLinkFuturesPanel.values) {
      expect(parse('vantaapp://futures?panel=${panel.name}')?.panel, panel);
    }
    expect(parse('vantaapp://futures?panel=history')?.panel, isNull);
    expect(parse('vantaapp://portfolio?panel=positions')?.panel, isNull);
    expect(parse('vantaapp://futures?symbol=%E0%A4%A')?.target, DeepLinkTarget.futures);
  });

  test('keeps AI prompts intact or drops them, and ignores foreign parameters', () {
    final prompt = parse('vantaapp://assistant?prompt=${Uri.encodeQueryComponent(' 分析 BTC 行情 ')}');
    expect(prompt?.prompt, '分析 BTC 行情');
    final long = 'a' * (deepLinkPromptMaxLength + 1);
    expect(parse('vantaapp://assistant?prompt=$long')?.prompt, isNull);
    expect(parse('vantaapp://assistant?prompt=%20')?.prompt, isNull);
    final foreign = parse('vantaapp://portfolio?symbol=ETH&prompt=hi');
    expect((foreign?.symbol, foreign?.prompt), (null, null));
    expect(parse('vantaapp://assistant?symbol=ETH')?.symbol, isNull);
  });

  test('reads order inputs only with a market, and always opens the trade tab', () {
    final link = parse(
      'vantaapp://futures?symbol=eth&tab=chart&type=limit&price=3200.5&qty=100&unit=quote',
    )!;
    expect(link.symbol, 'ETHUSDT');
    expect(link.futuresTab, DeepLinkFuturesTab.trade);
    expect(
      (link.order?.type, link.order?.price, link.order?.quantity, link.order?.unit),
      (DeepLinkOrderType.limit, '3200.5', '100', DeepLinkSizeUnit.quote),
    );
    final base = parse('vantaapp://futures?symbol=BTC&qty=0.01&unit=base')!.order!;
    expect((base.type, base.quantity, base.unit), (null, '0.01', DeepLinkSizeUnit.base));
    expect(parse('vantaapp://futures?symbol=BTC&qty=5')!.order!.unit, DeepLinkSizeUnit.quote);
    expect(parse('vantaapp://futures?symbol=BTC&price=1')!.order!.type, DeepLinkOrderType.limit);
    final market = parse('vantaapp://futures?symbol=BTC&type=market&price=1&qty=5')!.order!;
    expect((market.type, market.price, market.quantity), (DeepLinkOrderType.market, null, '5'));
    // No market: terms must never land on whichever market is selected.
    final bare = parse('vantaapp://futures?type=limit&price=1&qty=5&tab=chart')!;
    expect((bare.order, bare.futuresTab), (null, DeepLinkFuturesTab.chart));
    expect(parse('vantaapp://futures?symbol=BTC&qty=5&unit=lots')!.order, isNull);
    expect(parse('vantaapp://futures?symbol=BTC&type=stopLimit')!.order, isNull);
    for (final amount in ['-1', '0', '0.00', '1e3', '1,000', '.5', '5.', ' ', '1' * 41]) {
      final encoded = Uri.encodeQueryComponent(amount);
      final order = parse('vantaapp://futures?symbol=BTC&type=limit&price=$encoded&qty=$encoded')!;
      expect((order.order?.price, order.order?.quantity), (null, null), reason: amount);
    }
    expect(parse('vantaapp://portfolio?symbol=BTC&qty=5')!.order, isNull);
  });

  test('source opens a launch link once when the stream replays it', () async {
    for (final initialFirst in [true, false]) {
      final links = StreamController<Uri>();
      final initial = Completer<Uri?>();
      final opened = <DeepLinkTarget>[];
      final source = AppLinkSource(links: links.stream, initialLink: () => initial.future)
        ..start((link) => opened.add(link.target));
      final launch = Uri.parse('vantaapp://points');
      if (initialFirst) {
        initial.complete(launch);
        await pumpEventQueue();
        links.add(launch);
      } else {
        links.add(launch);
        await pumpEventQueue();
        initial.complete(launch);
      }
      await pumpEventQueue();
      links
        ..add(Uri.parse('vantaapp://wallet?wc_ev=x&topic=y'))
        ..add(launch)
        ..add(Uri.parse('vantaapp://portfolio'));
      await pumpEventQueue();
      expect(opened, [
        DeepLinkTarget.points,
        DeepLinkTarget.points,
        DeepLinkTarget.portfolio,
      ], reason: 'initialFirst=$initialFirst');
      await source.close();
      links.add(Uri.parse('vantaapp://points'));
      await pumpEventQueue();
      expect(opened, hasLength(3));
      await links.close();
    }
  });

  test('source survives a failing launch lookup and stream errors', () async {
    final links = StreamController<Uri>();
    final opened = <DeepLinkTarget>[];
    final source = AppLinkSource(
      links: links.stream,
      initialLink: () => Future<Uri?>.error(StateError('missing')),
    )..start((link) => opened.add(link.target));
    links
      ..addError(StateError('stream'))
      ..add(Uri.parse('vantaapp://assistant'));
    await pumpEventQueue();
    expect(opened, [DeepLinkTarget.assistant]);
    await source.close();
    await links.close();
  });
}
