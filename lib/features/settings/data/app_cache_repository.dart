import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Disposable files in the platform cache directory only. Journals, sessions
/// and preferences live in support/secure storage and are never touched here.
class AppCacheRepository {
  AppCacheRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationCacheDirectory;
  final Future<Directory> Function() _directory;

  Future<int> size() async {
    final root = await _directory();
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on FileSystemException {
          // A file removed while listing no longer occupies cache space.
        }
      }
    }
    return total;
  }

  /// Deletes every entry; throws after attempting all entries if any failed.
  Future<void> clear() async {
    final root = await _directory();
    if (!await root.exists()) return;
    FileSystemException? failure;
    await for (final entity in root.list(followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } on FileSystemException catch (error) {
        failure ??= error;
      }
    }
    if (failure != null) throw failure;
  }
}
