import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/event_media_service.dart';

final eventMediaServiceProvider = Provider.autoDispose<EventMediaService>((ref) {
  final service = EventMediaService();
  ref.onDispose(service.close);
  return service;
});
final eventMediaProvider = FutureProvider.autoDispose.family<Uint8List, Uri>(
  (ref, uri) => ref.watch(eventMediaServiceProvider).read(uri),
  retry: (_, _) => null,
);
final eventLinkLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
