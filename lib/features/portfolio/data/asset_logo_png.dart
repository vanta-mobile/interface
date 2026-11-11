import 'dart:convert';
import 'dart:typed_data';

const assetLogoMaxBytes = 524288;

/// Bound compressed bytes and pixel dimensions before decoding a thumbnail.
bool isAssetLogoPng(Uint8List bytes) {
  if (bytes.length < 33 || bytes.length > assetLogoMaxBytes) return false;
  final header = ByteData.sublistView(bytes);
  return bytes[0] == 137 &&
      ascii.decode(bytes.sublist(1, 4), allowInvalid: true) == 'PNG' &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10 &&
      header.getUint32(8) == 13 &&
      ascii.decode(bytes.sublist(12, 16), allowInvalid: true) == 'IHDR' &&
      header.getUint32(16) >= 1 &&
      header.getUint32(20) >= 1 &&
      header.getUint32(16) <= 2048 &&
      header.getUint32(20) <= 2048;
}
