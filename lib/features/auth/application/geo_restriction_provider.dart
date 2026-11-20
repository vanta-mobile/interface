import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/vanta_api/vanta_api_http.dart';
import 'vanta_api_session_provider.dart';

class GeoRestriction {
  const GeoRestriction({required this.blocked, this.restrictedAreas = const []});
  final bool blocked;
  final List<String> restrictedAreas;
}

final geoRestrictionProvider = AsyncNotifierProvider<GeoRestrictionController, GeoRestriction>(
  GeoRestrictionController.new,
);

class GeoRestrictionController extends AsyncNotifier<GeoRestriction> {
  @override
  Future<GeoRestriction> build() async {
    final base = ref.watch(vantaApiConfigurationProvider).baseUri;
    if (base == null) return const GeoRestriction(blocked: false);
    final client = ref.watch(backendHttpPoolProvider).lease();
    final http = VantaApiHttp(baseUri: base, client: client);
    ref.onDispose(http.close);
    final data = await http.get('/v1/config/geo');
    final decision = data['decision'];
    final blocked = decision is Map && decision['blocked'] == true;
    final rules = data['rules'];
    final areas = rules is Map ? rules['restricted_areas'] : null;
    final names = areas is List
        ? areas.whereType<Map<String, Object?>>().map((e) => e['name']).whereType<String>().toList()
        : const <String>[];
    return GeoRestriction(blocked: blocked, restrictedAreas: names);
  }
}
