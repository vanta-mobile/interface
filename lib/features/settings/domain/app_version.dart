/// Dotted numeric release version, e.g. `1.2.0`. Build metadata after `+` and
/// pre-release tags after `-` are ignored; anything else is rejected.
class AppVersion implements Comparable<AppVersion> {
  AppVersion._(this.parts, this.text);

  static AppVersion? tryParse(String? value) {
    final text = value?.trim().split('+').first.split('-').first;
    if (text == null || !RegExp(r'^\d{1,6}(?:\.\d{1,6}){0,3}$').hasMatch(text)) return null;
    return AppVersion._(text.split('.').map(int.parse).toList(growable: false), text);
  }

  final List<int> parts;
  final String text;

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < parts.length || i < other.parts.length; i++) {
      final a = i < parts.length ? parts[i] : 0, b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  String toString() => text;
}

/// Result of comparing the installed build with the backend's minimum.
class AppUpdateCheck {
  const AppUpdateCheck({required this.current, this.minimum});
  final AppVersion current;

  /// Null when the backend publishes no minimum supported version.
  final AppVersion? minimum;
  bool get updateRequired => minimum != null && current < minimum!;
}
