import '../../../core/exact_json.dart';
import '../domain/account_snapshot.dart';
import '../domain/asset_yield.dart';
import 'aster_read_service.dart';
import 'asset_yield_mapper.dart';

class AsterYieldService extends AsterReadService {
  AsterYieldService({super.client, super.timeout})
    : super(origin: Uri.https('www.asterdex.com'), decodeResponse: decodeFundingJson);
  Future<Object?> usdf() => get('/bapi/futures/v1/public/future/aster/usdf/info', query: 'day=7');
}

class ListaYieldService extends AsterReadService {
  ListaYieldService({super.client, super.timeout})
    : super(origin: Uri.https('api.lista.org'), decodeResponse: decodeFundingJson);
  Future<Object?> asbnb() => get('/v1/stakes/latest-apr');
}

class PublicAssetYieldRepository implements AssetYieldRepository {
  PublicAssetYieldRepository(this.aster, this.lista, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final AsterYieldService aster;
  final ListaYieldService lista;
  final DateTime Function() now;
  @override
  Future<AssetYieldQuote> read(YieldAsset asset) async {
    final payload = await (asset == YieldAsset.usdf ? aster.usdf() : lista.asbnb());
    try {
      return mapAssetYield(payload, asset: asset, receivedAt: now());
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }
}
