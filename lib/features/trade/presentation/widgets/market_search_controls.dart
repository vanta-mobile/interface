import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../market/application/market_selection_provider.dart';
import 'market_category_filter.dart';

class MarketSearchControls extends ConsumerStatefulWidget {
  const MarketSearchControls({super.key});
  @override
  ConsumerState<MarketSearchControls> createState() => _MarketSearchControlsState();
}

class _MarketSearchControlsState extends ConsumerState<MarketSearchControls> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(marketSelectionProvider);
    final controller = ref.read(marketSelectionProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('market-search'),
          controller: search,
          onChanged: controller.search,
          decoration: InputDecoration(
            hintText: tr(context, 'search'),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: tr(context, 'clearSearch'),
                    onPressed: () {
                      search.clear();
                      controller.search('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          key: const Key('market-list-filter'),
          segments: [
            ButtonSegment(value: false, label: Text(tr(context, 'allMarkets'))),
            ButtonSegment(value: true, label: Text(tr(context, 'favorites'))),
          ],
          selected: {selection.onlyFavorites},
          onSelectionChanged: (values) => controller.favorites(values.single),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 8),
        const MarketCategoryFilter(),
      ],
    );
  }
}
