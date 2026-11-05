import '../../portfolio/data/aster_read_service.dart';
import '../domain/funding_catalog.dart';
import 'funding_catalog_mapper.dart';

class FundingCatalogService extends AsterReadService {
  FundingCatalogService({super.client, super.timeout})
    : super(origin: Uri.https('www.asterdex.com'), decodeResponse: decodeFundingCatalogJson);
  Future<Object?> catalog(FundingCatalogQuery query) => get(
    '/bapi/futures/v1/public/future/aster/${query.operation.name}/assets',
    query: Uri(
      queryParameters: {
        'chainIds': fundingEvmChainIds.join(','),
        'networks': 'EVM',
        'accountType': query.market.name,
      },
    ).query,
  );
}

class AsterFundingCatalogRepository implements FundingCatalogRepository {
  AsterFundingCatalogRepository(this.service, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final FundingCatalogService service;
  final DateTime Function() now;
  @override
  Future<FundingCatalog> read(FundingCatalogQuery query) async =>
      mapFundingCatalog(await service.catalog(query), query: query, receivedAt: now());
}
