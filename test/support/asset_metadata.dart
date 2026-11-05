import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vanta/features/portfolio/domain/asset_metadata.dart';

final metadataPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jVHYAAAAASUVORK5CYII=',
);
Uri metadataLogo([String asset = 'usdt']) =>
    Uri.parse('https://static.astherus.finance/image/admin_mgs_image_upload/20251010/$asset.png');
Map<String, Object?> metadataPayload(AssetMetadataSource source) => {
  'code': '000000',
  'success': true,
  'data': <Object?>[
    if (source == AssetMetadataSource.names) ...[
      {
        'assetCode': 'USDT',
        'assetName': 'TetherUS',
        'chineseName': '泰达币',
        'logoUrl': metadataLogo().toString(),
        'assetDigit': 8,
      },
      {
        'assetCode': 'BTC',
        'assetName': 'Bitcoin',
        'chineseName': '比特币',
        'logoUrl': metadataLogo('btc').toString(),
      },
    ] else ...[
      for (final symbol in ['BTC', 'USDT', 'USDF', 'asBNB'])
        {'assetCode': symbol, 'logoUrl': metadataLogo(symbol.toLowerCase()).toString()},
    ],
  ],
};

class TestAssetMetadataRepository implements AssetMetadataRepository {
  TestAssetMetadataRepository({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  final calls = <AssetMetadataSource>[];
  final gates = <AssetMetadataSource, Completer<AssetMetadataSnapshot>>{};
  final failures = <AssetMetadataSource, Object>{};
  final snapshots = <AssetMetadataSource, AssetMetadataSnapshot>{};
  @override
  Future<AssetMetadataSnapshot> read(AssetMetadataSource source) async {
    calls.add(source);
    if (gates[source] case final gate?) return gate.future;
    if (failures[source] case final error?) throw error;
    return snapshots[source] ??
        AssetMetadataSnapshot(source: source, receivedAt: now(), entries: const {});
  }
}

Uint8List metadataImage(int width, int height) {
  final bytes = Uint8List.fromList(metadataPng), header = ByteData.sublistView(bytes);
  header.setUint32(16, width);
  header.setUint32(20, height);
  return bytes;
}
