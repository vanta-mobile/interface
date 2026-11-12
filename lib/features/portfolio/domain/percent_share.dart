import 'package:decimal/decimal.dart';

/// Amount shown for a percentage stop. Above one unit, partial stops are whole
/// units so the field never shows long fractions; 100% is always the exact
/// maximum. Maxima of one unit or less keep their fractional share.
Decimal percentShare(Decimal maximum, int percent) {
  if (percent >= 100) return maximum;
  final share = maximum * Decimal.fromInt(percent) * Decimal.parse('0.01');
  return maximum > Decimal.one ? share.floor() : share;
}

/// Amount at a continuous slider [position] (0–1) of [maximum] in the shown
/// unit. Above one unit it moves in whole units; otherwise it floors to
/// [fine]. Only the end of the track is the exact maximum.
Decimal sliderAmount(Decimal maximum, double position, Decimal fine) {
  if (position >= 1) return maximum;
  if (position <= 0 || !position.isFinite) return Decimal.zero;
  final raw = maximum * Decimal.parse(position.toStringAsFixed(6));
  if (maximum > Decimal.one) return raw.floor();
  return Decimal.fromBigInt((raw / fine).floor()) * fine;
}
