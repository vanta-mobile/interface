import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/presentation/no_press_feedback.dart';
import 'package:vanta/core/theme.dart';

void main() {
  const pressed = {WidgetState.pressed};

  test('theme uses a flat #FFFFFF 6% press overlay without ripples', () {
    final theme = vantaTheme();
    expect(AppColors.pressOverlay, const Color(0x0FFFFFFF));
    expect(theme.splashFactory, NoSplash.splashFactory);
    expect(theme.highlightColor, AppColors.pressOverlay);
    for (final style in [
      theme.filledButtonTheme.style,
      theme.outlinedButtonTheme.style,
      theme.textButtonTheme.style,
      theme.iconButtonTheme.style,
    ]) {
      expect(style?.overlayColor?.resolve(pressed), AppColors.pressOverlay);
    }
    expect(theme.checkboxTheme.overlayColor?.resolve(pressed), AppColors.transparent);
    expect(theme.switchTheme.overlayColor?.resolve(pressed), AppColors.transparent);
    expect(theme.tabBarTheme.overlayColor?.resolve(pressed), AppColors.transparent);
  });

  testWidgets('NoPressFeedback removes the pressed highlight beneath it', (tester) async {
    late ThemeData inner;
    await tester.pumpWidget(
      MaterialApp(
        theme: vantaTheme(),
        home: NoPressFeedback(
          child: Builder(
            builder: (context) {
              inner = Theme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(inner.highlightColor, AppColors.transparent);
    expect(inner.splashFactory, NoSplash.splashFactory);
  });
}
