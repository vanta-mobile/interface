/// Optional public labels owned by the exchange, independent of prices.
class MarketDescriptor {
  MarketDescriptor({
    this.name = '',
    Iterable<String> aliases = const [],
    Iterable<String> categories = const [],
  }) : aliases = List.unmodifiable(aliases),
       categories = Set.unmodifiable(categories);

  const MarketDescriptor.empty() : name = '', aliases = const [], categories = const {};

  final String name;
  final List<String> aliases;
  final Set<String> categories;
}

enum MarketCategory {
  all(null),
  top('Top'),
  rwa('USD1-RWA'),
  meme('Meme'),
  ai('AI'),
  preLaunch('pre-launch'),
  stocks('STOCK'),
  etf('ETF'),
  commodities('Commodities'),
  semiconductors('Semiconductor');

  const MarketCategory(this.tag);
  final String? tag;
}
