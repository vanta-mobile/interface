import 'dart:ui' as ui;

import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/portfolio_stats_mapper.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_history_chart.dart';

Map<String, Object?> curve({Object? gaps}) => {
  'metric': 'value',
  'points': [
    for (final day in [1, 2, 5, 6])
      {'bucket': '2026-11-0${day}T00:00:00Z', 'equity_close_usd': '${100 + day}'},
  ],
  'equity_gaps': ?gaps,
};

class _RecordingCanvas implements Canvas {
  final paths = <ui.Path>[];
  @override
  void drawPath(ui.Path path, ui.Paint paint) => paths.add(ui.Path.from(path));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('reported UTC gaps break segments without adding zero-equity points', () {
    final result = mapValueCurve(
      curve(
        gaps: [
          {'from': '2026-11-03', 'to': '2026-11-04', 'days': 2},
        ],
      ),
    );
    expect(result.points.map((p) => p.bucket.day), [1, 2, 5, 6]);
    expect(result.breakBefore, {2});
    expect(result.gaps.single.days, 2);
    expect(mapValueCurve(curve()).breakBefore, isEmpty);
    expect(() => result.gaps.clear(), throwsUnsupportedError);
  });
  test('gaps crossing weekly buckets also break the interpolated segment', () {
    final result = mapValueCurve({
      'metric': 'value',
      'points': [
        for (final day in [1, 8, 15])
          {
            'bucket': '2026-11-${day.toString().padLeft(2, '0')}T00:00:00Z',
            'equity_close_usd': '100',
          },
      ],
      'equity_gaps': [
        {'from': '2026-11-04', 'to': '2026-11-05', 'days': 2},
      ],
    });
    expect(result.breakBefore, {1});
  });
  test('invalid gap dates, counts, overlaps and types reject the response', () {
    for (final gaps in [
      'bad',
      [null],
      [
        {'from': '2026-11-04', 'to': '2026-11-03', 'days': 2},
      ],
      [
        {'from': '2026-11-03', 'to': '2026-11-04', 'days': 1},
      ],
      [
        {'from': '2026-02-30', 'to': '2026-03-02', 'days': 1},
      ],
      [
        {'from': '2026-11-03', 'to': '2026-11-04', 'days': 2.0},
      ],
      [
        for (var i = 0; i < 2; i++) {'from': '2026-11-03', 'to': '2026-11-04', 'days': 2},
      ],
    ]) {
      expect(() => mapValueCurve(curve(gaps: gaps)), throwsFormatException);
    }
  });
  for (final compact in [false, true]) {
    test('chart line and fill never bridge the gap, compact=$compact', () {
      final result = mapValueCurve(
        curve(
          gaps: [
            {'from': '2026-11-03', 'to': '2026-11-04', 'days': 2},
          ],
        ),
      );
      final painter = PortfolioHistoryPainter(
        result.points.map((p) => p.value).toList(),
        compact: compact,
        buckets: result.points.map((p) => p.bucket).toList(),
        breakBefore: result.breakBefore,
      );
      final canvas = _RecordingCanvas();
      painter.paint(canvas, const Size(100, 100));
      expect(canvas.paths, hasLength(4)); // separate area + line for each side
      expect(canvas.paths[0].getBounds().right, 20);
      expect(canvas.paths[1].getBounds().right, 20);
      expect(canvas.paths[2].getBounds().left, 80);
      expect(canvas.paths[3].getBounds().left, 80);
      expect(
        painter.shouldRepaint(
          PortfolioHistoryPainter(List.filled(4, Decimal.one), compact: compact),
        ),
        isTrue,
      );
    });
  }
}
