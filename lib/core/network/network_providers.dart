import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend_http_pool.dart';

final backendHttpPoolProvider = Provider<BackendHttpPool>((ref) {
  final pool = BackendHttpPool();
  ref.onDispose(pool.close);
  return pool;
});
