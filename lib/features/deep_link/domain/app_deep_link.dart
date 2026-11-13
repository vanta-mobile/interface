/// In-app navigation scheme. Android routes every `vanta://` link to Privy's
/// OAuth redirect activity, so navigation links need a scheme of their own.
/// Wallet returns share it on the `wallet` host, which is not a page.
const deepLinkScheme = 'vantaapp';

/// Longer AI prompts are dropped rather than truncated so meaning never changes.
const deepLinkPromptMaxLength = 2000;

const _maxLinkLength = 8192;

enum DeepLinkTarget { futures, portfolio, points, assistant, notifications }

enum DeepLinkFuturesTab { chart, trade }

enum DeepLinkFuturesPanel { orders, positions, assets }

enum DeepLinkOrderType { limit, market }

enum DeepLinkSizeUnit { base, quote }

/// Order form inputs. They are suggestions for the form only: the user still
/// chooses Long/Short, reviews the confirmation and signs.
class DeepLinkOrder {
  const DeepLinkOrder({this.type, this.price, this.quantity, this.unit = DeepLinkSizeUnit.quote});

  final DeepLinkOrderType? type;
  final String? price;
  final String? quantity;
  final DeepLinkSizeUnit unit;
}

/// A validated navigation intent from outside the app. It can choose a page, a
/// market, order form inputs and an AI draft; it never signs or submits.
class AppDeepLink {
  const AppDeepLink(
    this.target, {
    this.symbol,
    this.futuresTab,
    this.panel,
    this.order,
    this.prompt,
  });

  final DeepLinkTarget target;

  /// Normalized perpetual symbol such as `ETHUSDT`; the catalog still decides
  /// whether it exists.
  final String? symbol;
  final DeepLinkFuturesTab? futuresTab;

  /// Account section below the order form: open orders, positions or assets.
  final DeepLinkFuturesPanel? panel;

  /// Only present with a [symbol], so terms never land on whichever market
  /// happens to be selected.
  final DeepLinkOrder? order;

  /// Draft for Vanta AI. It is placed in the composer and never sent.
  final String? prompt;

  /// Returns null for links this app does not own. Malformed optional
  /// parameters are ignored so the link still opens its page.
  static AppDeepLink? parse(Uri uri) {
    if (uri.scheme != deepLinkScheme ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.path.isNotEmpty && uri.path != '/' ||
        uri.toString().length > _maxLinkLength) {
      return null;
    }
    if (uri.host == 'open') return _openFeature(uri);
    final target = DeepLinkTarget.values.where((t) => t.name == uri.host).firstOrNull;
    if (target == null) return null;
    final Map<String, List<String>> query;
    try {
      query = uri.queryParametersAll;
    } on FormatException {
      return AppDeepLink(target);
    }
    String? single(String key) => query[key]?.length == 1 ? query[key]!.single : null;
    return switch (target) {
      DeepLinkTarget.futures => _futures(single),
      DeepLinkTarget.assistant => AppDeepLink(target, prompt: _prompt(single('prompt'))),
      _ => AppDeepLink(target),
    };
  }
}

/// `vantaapp://open?feature=<id>` is what Google Assistant's OPEN_APP_FEATURE
/// inline inventory produces (shortcut IDs in android/app/src/main/res/xml/shortcuts.xml).
/// A missing or unknown feature opens the app home, like the required fallback intent.
AppDeepLink _openFeature(Uri uri) {
  String? feature;
  try {
    final values = uri.queryParametersAll['feature'];
    if (values != null && values.length == 1) feature = values.single;
  } on FormatException {
    feature = null;
  }
  return _features[feature] ?? const AppDeepLink(DeepLinkTarget.futures);
}

const _features = {
  'futures': AppDeepLink(DeepLinkTarget.futures, futuresTab: DeepLinkFuturesTab.trade),
  'chart': AppDeepLink(DeepLinkTarget.futures, futuresTab: DeepLinkFuturesTab.chart),
  'orders': AppDeepLink(DeepLinkTarget.futures, panel: DeepLinkFuturesPanel.orders),
  'positions': AppDeepLink(DeepLinkTarget.futures, panel: DeepLinkFuturesPanel.positions),
  'portfolio': AppDeepLink(DeepLinkTarget.portfolio),
  'points': AppDeepLink(DeepLinkTarget.points),
  'assistant': AppDeepLink(DeepLinkTarget.assistant),
  'notifications': AppDeepLink(DeepLinkTarget.notifications),
};

AppDeepLink _futures(String? Function(String) single) {
  final symbol = normalizeDeepLinkSymbol(single('symbol'));
  final order = symbol == null ? null : _order(single);
  return AppDeepLink(
    DeepLinkTarget.futures,
    symbol: symbol,
    // The order form lives on the trade tab.
    futuresTab: order != null
        ? DeepLinkFuturesTab.trade
        : DeepLinkFuturesTab.values.where((t) => t.name == single('tab')).firstOrNull,
    panel: DeepLinkFuturesPanel.values.where((p) => p.name == single('panel')).firstOrNull,
    order: order,
  );
}

DeepLinkOrder? _order(String? Function(String) single) {
  final type = DeepLinkOrderType.values.where((t) => t.name == single('type')).firstOrNull;
  // A market order has no limit price; never carry one into a later mode switch.
  final price = type == DeepLinkOrderType.market ? null : _amount(single('price'));
  final rawUnit = single('unit');
  final unit = rawUnit == null
      ? DeepLinkSizeUnit.quote
      : DeepLinkSizeUnit.values.where((u) => u.name == rawUnit).firstOrNull;
  // An unknown unit would change what the number means, so drop the quantity.
  final quantity = unit == null ? null : _amount(single('qty'));
  if (type == null && price == null && quantity == null) return null;
  return DeepLinkOrder(
    type: type ?? (price != null ? DeepLinkOrderType.limit : null),
    price: price,
    quantity: quantity,
    unit: unit ?? DeepLinkSizeUnit.quote,
  );
}

/// Positive plain decimals only: no sign, exponent, comma or spaces inside.
String? _amount(String? raw) {
  final text = raw?.trim();
  if (text == null || text.length > 40 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) {
    return null;
  }
  return RegExp(r'[1-9]').hasMatch(text) ? text : null;
}

/// Accepts `ETHUSDT`, `eth-usdt`, `ETH/USDT` or a bare base asset `ETH`.
String? normalizeDeepLinkSymbol(String? raw) {
  if (raw == null) return null;
  final compact = raw.trim().toUpperCase().replaceAll(RegExp(r'[-/_ ]'), '');
  final symbol = compact.endsWith('USDT') ? compact : '${compact}USDT';
  return RegExp(r'^[A-Z0-9]{1,20}USDT$').hasMatch(symbol) ? symbol : null;
}

String? _prompt(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty || text.length > deepLinkPromptMaxLength) return null;
  return text;
}
