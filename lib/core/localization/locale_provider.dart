import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalePreferences {
  Future<String?> read();
  Future<void> write(String? language);
}

class LocalLocalePreferences implements LocalePreferences {
  late final _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read() => _preferences.getString('vanta.language');
  @override
  Future<void> write(String? language) => language == null
      ? _preferences.remove('vanta.language')
      : _preferences.setString('vanta.language', language);
}

Locale? localeFromPreference(String? code) => switch (code) {
  'zh' => const Locale('zh'),
  'en' => const Locale('en'),
  _ => null,
};

final localePreferencesProvider = Provider<LocalePreferences>((_) => LocalLocalePreferences());
final initialLocaleProvider = Provider<Locale?>((_) => null);
final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);
final localeSaveErrorProvider = NotifierProvider<LocaleSaveError, bool>(LocaleSaveError.new);

class LocaleSaveError extends Notifier<bool> {
  @override
  bool build() => false;
  void setFailed(bool failed) => state = failed;
}

class LocaleController extends Notifier<Locale?> {
  Future<void> _writes = Future.value();
  int _revision = 0;
  @override
  Locale? build() => ref.watch(initialLocaleProvider);

  Future<void> select(String? code) {
    if (code != null && code != 'zh' && code != 'en') return Future.value();
    state = localeFromPreference(code);
    ref.read(localeSaveErrorProvider.notifier).setFailed(false);
    final revision = ++_revision;
    final store = ref.read(localePreferencesProvider);
    // Serialize disk writes so fast language changes cannot restore an older
    // choice after restart. Changing language keeps the current navigation.
    _writes = _writes.then((_) async {
      try {
        await store.write(code);
        if (ref.mounted && revision == _revision) {
          ref.read(localeSaveErrorProvider.notifier).setFailed(false);
        }
      } catch (_) {
        if (ref.mounted && revision == _revision) {
          ref.read(localeSaveErrorProvider.notifier).setFailed(true);
        }
      }
    });
    return _writes;
  }
}
