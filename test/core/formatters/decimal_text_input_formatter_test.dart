import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/formatters/decimal_text_input_formatter.dart';

void main() {
  group('DecimalTextInputFormatter', () {
    test('truncates fractional digits and keeps the cursor in range', () {
      final formatter = DecimalTextInputFormatter(maxFractionDigits: 2);

      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.23'),
        const TextEditingValue(text: '1.234', selection: TextSelection.collapsed(offset: 5)),
      );

      expect(result.text, '1.23');
      expect(result.selection, const TextSelection.collapsed(offset: 4));
    });

    test('rejects malformed decimal edits', () {
      final formatter = DecimalTextInputFormatter(maxFractionDigits: 2);
      const oldValue = TextEditingValue(text: '1.2', selection: TextSelection.collapsed(offset: 3));

      for (final text in ['1.2.3', '1a', '-1']) {
        expect(
          formatter.formatEditUpdate(
            oldValue,
            TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            ),
          ),
          oldValue,
        );
      }
    });

    test('rejects an overflowing insertion that would rewrite digits', () {
      final formatter = DecimalTextInputFormatter(maxFractionDigits: 2);
      const oldValue = TextEditingValue(
        text: '1.23',
        selection: TextSelection.collapsed(offset: 2),
      );

      final result = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(text: '1.923', selection: TextSelection.collapsed(offset: 3)),
      );

      expect(result, oldValue);
    });

    test('rejects an overflowing replacement that would rewrite a suffix', () {
      final formatter = DecimalTextInputFormatter(maxFractionDigits: 2);
      const oldValue = TextEditingValue(
        text: '1.23',
        selection: TextSelection(baseOffset: 2, extentOffset: 3),
      );

      final result = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(text: '1.453', selection: TextSelection.collapsed(offset: 4)),
      );

      expect(result, oldValue);
    });
  });
}
