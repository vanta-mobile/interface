/// Optional public labels owned by the exchange, independent of prices.
class MarketDescriptor {
  MarketDescriptor({this.name = '', Iterable<String> aliases = const []})
    : aliases = List.unmodifiable(aliases);

  const MarketDescriptor.empty() : name = '', aliases = const [];

  final String name;
  final List<String> aliases;
}
