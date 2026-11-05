import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/asset_metadata_mapper.dart';
import 'package:vanta/features/portfolio/domain/asset_metadata.dart';

import '../../support/asset_metadata.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4);
  AssetMetadataSnapshot map(Object? p, [AssetMetadataSource source = AssetMetadataSource.names]) =>
      mapAssetMetadata(p, source: source, receivedAt: now);
  test('names and official mixed-case logo code map to original account identifiers without guessing aliases', () {
    final names = map(metadataPayload(AssetMetadataSource.names)),
        logos = map(metadataPayload(AssetMetadataSource.logos), AssetMetadataSource.logos);
    expect(names.forSymbol('USDT')!.displayName(false), 'TetherUS');
    expect(names.forSymbol('USDT')!.displayName(true), '泰达币');
    expect(logos.forSymbol('ASBNB')!.symbol, 'asBNB');
    expect(logos.forSymbol('ASBNB')!.logo, metadataLogo('asbnb'));
    expect(logos.forSymbol('BNB'), null);
    expect(names.forSymbol('USDF'), null);
    expect(() => names.entries.clear(), throwsUnsupportedError);
  });
  test('empty names use available English or symbol fallback and search both languages', () {
    const english = AssetMetadata(symbol: 'BTC', name: 'Bitcoin');
    expect(english.displayName(true), 'Bitcoin');
    expect(english.matches('bitcoin'), true);
    final names = map(metadataPayload(AssetMetadataSource.names));
    expect(names.forSymbol('USDT')!.matches('泰达'), true);
    expect(names.forSymbol('USDT')!.matches('ether'), true);
    expect(names.forSymbol('USDT')!.matches('btc'), false);
  });
  test('non-account protocol labels are omitted without trimming or reinterpreting codes', () {
    final p = metadataPayload(AssetMetadataSource.names);
    (p['data'] as List).addAll([
      {'assetCode': 'PumpBTC Protocol '},
      {'assetCode': 'USDT '},
      {'assetCode': '币安人生', 'assetName': '币安人生'},
    ]);
    final result = map(p);
    expect(result.entries.length, 3);
    expect(result.forSymbol('PumpBTC'), null);
    expect(result.forSymbol('币安人生')!.name, '币安人生');
  });
  test(
    'all finance-like metadata is ignored; name catalog does not change precision or balances',
    () {
      final p = metadataPayload(AssetMetadataSource.names);
      final row = (p['data'] as List).first as Map;
      row['assetDigit'] = 'untrusted';
      row['gas'] = 'NaN';
      row['freeAuditWithdrawAmt'] = 'huge';
      expect(map(p).forSymbol('USDT')!.name, 'TetherUS');
    },
  );
  for (final change in <String, Object?>{
    'code': 'bad',
    'success': false,
    'data': null,
    'message': 'ignored',
  }.entries) {
    if (change.key == 'message') continue;
    test('bad envelope ${change.key} is rejected', () {
      final p = metadataPayload(AssetMetadataSource.names)..[change.key] = change.value;
      expect(() => map(p), throwsFormatException);
    });
  }
  for (final value in [null, 12, '', 'A' * 81, 'bad\nasset']) {
    test('invalid source identifier ${value.hashCode} rejects catalog', () {
      final p = metadataPayload(AssetMetadataSource.names);
      (p['data'] as List).add({'assetCode': value});
      expect(() => map(p), throwsFormatException);
    });
  }
  for (final value in [3, 'x' * 121, 'a\nb', 'a\u202eb']) {
    test('invalid display name ${value.hashCode} is rejected', () {
      final p = metadataPayload(AssetMetadataSource.names);
      ((p['data'] as List).first as Map)['assetName'] = value;
      expect(() => map(p), throwsFormatException);
    });
  }
  test('duplicate symbol after case normalization is ambiguous and rejected', () {
    final p = metadataPayload(AssetMetadataSource.names);
    (p['data'] as List).add({'assetCode': 'usdt'});
    expect(() => map(p), throwsFormatException);
  });
  test('missing or unapproved logo leaves display name usable', () {
    final p = metadataPayload(AssetMetadataSource.names);
    ((p['data'] as List).first as Map)['logoUrl'] = 'https://untrusted.invalid/a.png';
    expect(map(p).forSymbol('USDT')!.logo, null);
    expect(map(p).forSymbol('USDT')!.name, 'TetherUS');
  });
  for (final value in [
    'http://static.astherus.finance/image/admin_mgs_image_upload/a.png',
    'https://static.astherus.finance:443/image/admin_mgs_image_upload/a.png',
    'https://user@static.astherus.finance/image/admin_mgs_image_upload/a.png',
    'https://static.astherus.finance.evil/image/admin_mgs_image_upload/a.png',
    'https://static.astherus.finance/image/admin_mgs_image_upload/a.png?a=1',
    'https://static.astherus.finance/image/admin_mgs_image_upload/a.png#x',
    'https://static.astherus.finance/image/admin_mgs_image_upload/../a.png',
    'https://static.astherus.finance/image/admin_mgs_image_upload/%2fsecret.png',
    'https://static.astherus.finance/other/a.png',
    'https://static.astherus.finance/image/admin_mgs_image_upload/a.svg',
  ]) {
    test('unsafe logo URL ${value.hashCode} is ignored', () => expect(assetLogoUri(value), null));
  }
  test('metadata receipt freshness has bounded age and rollback handling', () {
    final s = map(metadataPayload(AssetMetadataSource.names));
    expect(s.freshAt(now), true);
    expect(s.freshAt(now.add(const Duration(minutes: 15))), false);
    expect(s.freshAt(now.subtract(const Duration(seconds: 31))), false);
  });
}
