/// Dotted numeric release version, e.g. `1.2.0`. Build metadata after `+` and
/// pre-release tags after `-` are ignored; anything else is rejected.
class AppVersion implements Comparable<AppVersion> {
  AppVersion._(Iterable<int> parts, this.text) : parts = List.unmodifiable(parts);

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

/// Platform-specific release metadata from the public configuration.
class AppRelease {
  AppRelease({
    required this.latest,
    required this.forceUpdate,
    required Map<String, String> releaseNotes,
    this.storeUri,
  }) : releaseNotes = Map.unmodifiable(releaseNotes);
  final AppVersion latest;
  final bool forceUpdate;
  final Uri? storeUri;
  final Map<String, String> releaseNotes;

  String? notesFor(String locale) =>
      releaseNotes[locale] ??
      releaseNotes[locale.split(RegExp('[-_]')).first] ??
      releaseNotes['en'] ??
      releaseNotes['zh'] ??
      releaseNotes.values.firstOrNull;
}

class AppUpdateConfiguration {
  const AppUpdateConfiguration({this.minimum, this.release});
  final AppVersion? minimum;
  final AppRelease? release;
}

class AppUpdateCheck {
  const AppUpdateCheck({required this.current, this.minimum, this.release});
  final AppVersion current;
  final AppVersion? minimum;
  final AppRelease? release;
  bool get updateRequired =>
      minimum != null && current < minimum! ||
      release != null && release!.forceUpdate && current < release!.latest;
  bool get updateAvailable => updateRequired || release != null && current < release!.latest;
  AppVersion? get target => release?.latest ?? minimum;
  bool get hasPublishedVersion => release != null;
}
