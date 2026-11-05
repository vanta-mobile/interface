/// Server timestamps only; local receipt time is not an update sequence.
DateTime? mapAccountUpdateTime(Object? value) {
  if (value == null || value == 0) return null;
  if (value is! int || value < 0 || value > 253402300799999) {
    throw const FormatException();
  }
  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}
