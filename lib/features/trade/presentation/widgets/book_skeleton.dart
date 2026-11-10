import 'package:flutter/material.dart';

import '../../../../core/presentation/status_view.dart';

/// Order book and trade row placeholders from the design's loading overlays.
class BookSkeleton extends StatelessWidget {
  const BookSkeleton({
    super.key,
    required this.columns,
    required this.rows,
    required this.rowExtent,
    required this.widths,
    this.alignLastColumnEnd = false,
  });

  /// Two-column compact book beside the order form.
  const BookSkeleton.compact({super.key})
    : columns = 2,
      rows = 14,
      rowExtent = 30,
      widths = const [
        [54, 40, 48, 56, 40, 48],
        [48, 42, 49, 42, 49, 42],
      ],
      alignLastColumnEnd = true;

  /// Bids and asks side by side on the chart page.
  const BookSkeleton.split({super.key})
    : columns = 4,
      rows = 11,
      rowExtent = 24,
      widths = const [
        [62.25, 58.25, 54.25],
      ],
      alignLastColumnEnd = false;

  /// Recent trades on the chart page.
  const BookSkeleton.trades({super.key})
    : columns = 3,
      rows = 9,
      rowExtent = 30,
      widths = const [
        [92.33, 88.33, 84.33],
      ],
      alignLastColumnEnd = false;

  final int columns, rows;
  final double rowExtent;

  /// Per-column width cycles; a single cycle applies to every column.
  final List<List<double>> widths;
  final bool alignLastColumnEnd;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      children: [
        for (var row = 0; row < rows; row++)
          SizedBox(
            height: rowExtent,
            child: Row(
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: alignLastColumnEnd && column == columns - 1
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: SkeletonBox(width: _width(column, row), height: 8),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );

  double _width(int column, int row) {
    final cycle = widths[column % widths.length];
    return cycle[row % cycle.length];
  }
}
