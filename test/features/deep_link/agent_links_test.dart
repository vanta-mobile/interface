import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/deep_link/domain/app_deep_link.dart';

AppDeepLink parse(String link) => AppDeepLink.parse(Uri.parse(link))!;

const _shortcuts = 'android/app/src/main/res/xml/shortcuts.xml';

void main() {
  group('Gemini AppFunctions links', () {
    // Literal links asserted by android/app/src/test/.../VantaLinksTest.kt.
    test('futures links reach the requested market, view and section', () {
      final link = parse('vantaapp://futures?symbol=ETH&tab=chart&panel=positions');
      expect(
        (link.target, link.symbol, link.futuresTab, link.panel),
        (
          DeepLinkTarget.futures,
          'ETHUSDT',
          DeepLinkFuturesTab.chart,
          DeepLinkFuturesPanel.positions,
        ),
      );
      expect(parse('vantaapp://futures').target, DeepLinkTarget.futures);
      expect(parse('vantaapp://portfolio').target, DeepLinkTarget.portfolio);
    });

    test('order links prefill the form only', () {
      final limit = parse(
        'vantaapp://futures?symbol=BTCUSDT&type=limit&price=3200.5&qty=100&unit=quote',
      );
      expect(
        (limit.order?.type, limit.order?.price, limit.order?.quantity, limit.order?.unit),
        (DeepLinkOrderType.limit, '3200.5', '100', DeepLinkSizeUnit.quote),
      );
      expect(limit.futuresTab, DeepLinkFuturesTab.trade);
      final market = parse('vantaapp://futures?symbol=BTC&type=market&qty=0.01&unit=base');
      expect(
        (market.symbol, market.order?.type, market.order?.price, market.order?.unit),
        ('BTCUSDT', DeepLinkOrderType.market, null, DeepLinkSizeUnit.base),
      );
      expect(
        parse('vantaapp://futures?symbol=ETH&type=limit').order?.type,
        DeepLinkOrderType.limit,
      );
    });

    test('UTF-8 prompts decode to the original question', () {
      final link = parse(
        'vantaapp://assistant?prompt=%E5%88%86%E6%9E%90%20BTC%20%E8%A1%8C%E6%83%85%20%26%20%E9%A3%8E%E9%99%A9%3F',
      );
      expect(link.prompt, '分析 BTC 行情 & 风险?');
      expect(parse('vantaapp://assistant').prompt, isNull);
    });
  });

  group('Google Assistant App Actions links', () {
    test('every OPEN_APP_FEATURE shortcut opens its feature; anything else opens home', () {
      final ids = RegExp(r'android:shortcutId="([^"]+)"')
          .allMatches(File(_shortcuts).readAsStringSync())
          .map((m) => m.group(1)!)
          .toList();
      expect(ids, [
        'futures',
        'chart',
        'orders',
        'positions',
        'portfolio',
        'points',
        'assistant',
        'notifications',
      ]);
      final expected = {
        'futures': (DeepLinkTarget.futures, DeepLinkFuturesTab.trade, null),
        'chart': (DeepLinkTarget.futures, DeepLinkFuturesTab.chart, null),
        'orders': (DeepLinkTarget.futures, null, DeepLinkFuturesPanel.orders),
        'positions': (DeepLinkTarget.futures, null, DeepLinkFuturesPanel.positions),
        'portfolio': (DeepLinkTarget.portfolio, null, null),
        'points': (DeepLinkTarget.points, null, null),
        'assistant': (DeepLinkTarget.assistant, null, null),
        'notifications': (DeepLinkTarget.notifications, null, null),
      };
      for (final id in ids) {
        final link = parse('vantaapp://open?feature=$id');
        expect((link.target, link.futuresTab, link.panel), expected[id], reason: id);
      }
      for (final fallback in [
        'vantaapp://open',
        'vantaapp://open?feature=history',
        'vantaapp://open?feature=orders&feature=points',
        'vantaapp://open?feature=%E0%A4%A',
      ]) {
        final link = parse(fallback);
        expect(
          (link.target, link.futuresTab, link.panel, link.symbol),
          (DeepLinkTarget.futures, null, null, null),
          reason: fallback,
        );
      }
    });

    test('GET_THING market names go through the catalog-checked symbol path', () {
      expect(parse('vantaapp://futures?symbol=ETH').symbol, 'ETHUSDT');
      expect(parse('vantaapp://futures?symbol=Bitcoin%20Cash').symbol, 'BITCOINCASHUSDT');
      expect(parse('vantaapp://futures').symbol, isNull);
    });

    test('iOS App Intents use the same feature IDs and option values', () {
      final swift = File('ios/Runner/VantaAppIntents.swift').readAsStringSync();
      List<String> cases(String type) =>
          RegExp('enum $type: String, AppEnum \\{\\s*case ([a-z, ]+)')
              .firstMatch(swift)!
              .group(1)!
              .split(',')
              .map((c) => c.trim())
              .toList();
      final shortcuts = RegExp(r'android:shortcutId="([^"]+)"')
          .allMatches(File(_shortcuts).readAsStringSync())
          .map((m) => m.group(1)!)
          .toList();
      expect(cases('VantaPage'), shortcuts);
      expect(cases('VantaSection'), DeepLinkFuturesPanel.values.map((p) => p.name));
      expect(cases('VantaMarketView'), DeepLinkFuturesTab.values.reversed.map((t) => t.name));
      expect(cases('VantaOrderType'), DeepLinkOrderType.values.map((t) => t.name));
      expect(cases('VantaSizeUnit'), DeepLinkSizeUnit.values.reversed.map((u) => u.name));
      for (final key in ['symbol', 'tab', 'panel', 'type', 'price', 'qty', 'unit', 'prompt']) {
        expect(swift, contains('("$key", '), reason: 'query key $key');
      }
      final phrases = File('ios/Runner/zh-Hans.lproj/AppShortcuts.strings').readAsStringSync();
      for (final phrase in RegExp(
        r'^"([^"]+)" = "([^"]+)";',
        multiLine: true,
      ).allMatches(phrases)) {
        final english = phrase.group(1)!.replaceAll(RegExp(r'\$\{(\w+)\}'), '');
        expect(phrase.group(2), contains(r'${applicationName}'), reason: phrase.group(1));
        expect(
          swift.replaceAll(RegExp(r'\\\(\\?\.\$?\w+\)'), ''),
          contains('"$english"'),
          reason: 'zh phrase without a Swift phrase: ${phrase.group(1)}',
        );
      }
    });

    test('every synonym list exists in English and Chinese', () {
      final arrays = RegExp(r'@array/(\w+)')
          .allMatches(File(_shortcuts).readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
      expect(arrays, hasLength(8));
      for (final locale in ['values', 'values-zh']) {
        final resources = File('android/app/src/main/res/$locale/assistant_actions.xml')
            .readAsStringSync();
        for (final name in arrays) {
          final list = RegExp(
            '<string-array name="$name">(.*?)</string-array>',
            dotAll: true,
          ).firstMatch(resources);
          expect(list, isNotNull, reason: '$locale/$name');
          final items = '<item>'.allMatches(list!.group(1)!).length;
          expect(items, inInclusiveRange(1, 20), reason: '$locale/$name synonym limit');
        }
      }
    });
  });
}
