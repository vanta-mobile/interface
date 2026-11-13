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

/// A slider selection: a percentage stop, or a plain [amount] in the shown unit.
typedef SliderChoice = ({int? percent, Decimal? amount});

/// Trade-workspace slider rules. Without a known [maximum] the thumb snaps to
/// the five stops; with one, only the end of the track is 100% (the exact
/// maximum), the start is 0%, and anything between is a [sliderAmount].
SliderChoice sliderChoice(double position, {required Decimal? maximum, required Decimal fine}) {
  if (maximum == null || maximum <= Decimal.zero) {
    return (percent: (position * 4).round() * 25, amount: null);
  }
  if (position >= 1) return (percent: 100, amount: null);
  final amount = sliderAmount(maximum, position, fine);
  return amount <= Decimal.zero ? (percent: 0, amount: null) : (percent: null, amount: amount);
}

/// Thumb position (0–1) of a selected [percent] stop, or else of a typed
/// [amount] as a share of [maximum].
double sliderPosition({int? percent, Decimal? amount, Decimal? maximum}) {
  if (percent != null) return percent / 100;
  if (amount == null || maximum == null || maximum <= Decimal.zero || amount <= Decimal.zero) {
    return 0;
  }
  return (amount / maximum).toDouble().clamp(0.0, 1.0);
}
