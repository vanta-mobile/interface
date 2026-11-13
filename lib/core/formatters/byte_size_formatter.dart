/// Storage sizes in binary units with at most one fractional digit.
abstract final class ByteSizeFormatter {
  static const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

  static String format(int bytes) {
    if (bytes < 0) throw ArgumentError.value(bytes, 'bytes', 'Must not be negative');
    var unit = 0;
    var value = bytes.toDouble();
    while (value >= 1024 && unit < _units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = unit == 0 ? '$bytes' : value.toStringAsFixed(1);
    return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text} ${_units[unit]}';
  }
}
