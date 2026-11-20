import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/presentation/live_order_embedded_controls.dart';
import 'package:vanta/l10n/app_localization_delegates.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/live_order.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('available balance row grows with enlarged $language text instead of clipping', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: vantaTheme(),
          locale: Locale(language),
          localizationsDelegates: appLocalizationDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: EmbeddedAvailableRow(data: liveContext()),
            ),
          ),
        ),
      );
      final row = tester.getRect(find.byKey(const Key('live-order-available')));
      expect(row.height, greaterThanOrEqualTo(embeddedCheckRowHeight));
      final texts = find.descendant(
        of: find.byKey(const Key('live-order-available')),
        matching: find.byType(Text),
      );
      expect(texts, findsNWidgets(2));
      for (final text in texts.evaluate()) {
        // A squeezed paragraph is laid out shorter than its text and clips it.
        final paragraph = text.renderObject! as RenderBox;
        final needed = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
        expect(paragraph.size.height, greaterThanOrEqualTo(needed));
        final rect = tester.getRect(find.byWidget(text.widget));
        expect(row.top <= rect.top && rect.bottom <= row.bottom, isTrue);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
