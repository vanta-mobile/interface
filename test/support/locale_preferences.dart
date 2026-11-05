import 'package:vanta/core/localization/locale_provider.dart';

class MemoryLocalePreferences implements LocalePreferences {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? language) async {
    if (fail) throw StateError('Unavailable');
    value = language;
  }
}
