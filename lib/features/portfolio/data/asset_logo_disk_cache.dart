import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:web3dart/web3dart.dart' as crypto;

import 'asset_logo_png.dart';

/// Disposable public images only. Cache failures must never fail an image read.
/// One Riverpod-owned instance serializes file operations across image services.
class AssetLogoDiskCache {
  AssetLogoDiskCache({
    Future<Directory> Function()? directory,
    DateTime Function()? now,
    this.maxAge = const Duration(days: 30),
    this.maxBytes = 32 * 1024 * 1024,
    this.maxEntries = 512,
  }) : _directory = directory ?? _applicationDirectory,
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _now;
  final Duration maxAge;
  final int maxBytes, maxEntries;
  Directory? _resolvedDirectory;
  bool _initialized = false;
  Future<void> _tail = Future.value();

  static Future<Directory> _applicationDirectory() async {
    final root = await getApplicationCacheDirectory();
    return Directory('${root.path}/public-asset-icons-v1');
  }

  String _key(Uri uri) => crypto.bytesToHex(crypto.keccakUtf8(uri.toString()));

  Future<T?> _serial<T>(Future<T?> Function() action) {
    final task = _tail.then((_) async {
      try {
        return await action();
      } catch (_) {
        // Unavailable/full cache storage falls back to the existing transport.
        return null;
      }
    });
    _tail = task.then<void>((_) {});
    return task;
  }

  Future<Directory> _root() async {
    final root = _resolvedDirectory ??= await _directory();
    await root.create(recursive: true);
    if (!_initialized) {
      await _prune(root);
      _initialized = true;
    }
    return root;
  }

  bool _expired(FileStat stat) {
    final age = _now().toUtc().difference(stat.modified.toUtc());
    return age.isNegative || age >= maxAge;
  }

  Future<Uint8List?> read(Uri uri) => _serial(() async {
    final root = await _root();
    final file = File('${root.path}/${_key(uri)}.png');
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return null;
    if (_expired(stat) || stat.size > assetLogoMaxBytes) {
      await file.delete();
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, assetLogoMaxBytes + 1)) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (!isAssetLogoPng(bytes)) {
      await file.delete();
      return null;
    }
    // Access order survives process restarts; age still uses the write time.
    await file.setLastAccessed(_now().toUtc());
    return bytes;
  });

  Future<void> write(Uri uri, Uint8List bytes) async {
    if (!isAssetLogoPng(bytes) || bytes.length > maxBytes || maxEntries < 1) return;
    await _serial<void>(() async {
      final root = await _root();
      final file = File('${root.path}/${_key(uri)}.png');
      final temp = File('${file.path}.tmp');
      try {
        await temp.writeAsBytes(bytes, flush: true);
        await temp.rename(file.path);
        await file.setLastModified(_now().toUtc());
        await file.setLastAccessed(_now().toUtc());
        await _prune(root);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    });
  }

  Future<void> remove(Uri uri) async {
    await _serial<void>(() async {
      final root = await _root();
      final file = File('${root.path}/${_key(uri)}.png');
      if (await file.exists()) await file.delete();
    });
  }

  Future<void> _prune(Directory root) async {
    final entries = <({File file, FileStat stat})>[];
    var bytes = 0;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! File) continue;
      if (entry.path.endsWith('.tmp')) {
        await entry.delete();
        continue;
      }
      if (!entry.path.endsWith('.png')) continue;
      final stat = await entry.stat();
      if (_expired(stat) || stat.size > assetLogoMaxBytes) {
        await entry.delete();
        continue;
      }
      entries.add((file: entry, stat: stat));
      bytes += stat.size;
    }
    entries.sort((a, b) => a.stat.accessed.compareTo(b.stat.accessed));
    var count = entries.length;
    for (final entry in entries) {
      if (count <= maxEntries && bytes <= maxBytes) break;
      await entry.file.delete();
      bytes -= entry.stat.size;
      count--;
    }
  }
}
