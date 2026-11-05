import '../domain/account_snapshot.dart';
import '../domain/asset_metadata.dart';
import 'asset_metadata_mapper.dart';
import 'asset_metadata_service.dart';

class PublicAssetMetadataRepository implements AssetMetadataRepository {
  PublicAssetMetadataRepository(this.service, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final AssetMetadataService service;
  final DateTime Function() now;
  @override
  Future<AssetMetadataSnapshot> read(AssetMetadataSource source) async {
    final data = await service.catalog(source);
    try {
      return mapAssetMetadata(data, source: source, receivedAt: now());
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }
}
