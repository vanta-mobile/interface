import '../../portfolio/data/aster_read_service.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/funding_catalog.dart';
import '../domain/funding_fee.dart';
import 'funding_fee_json.dart';
import 'funding_fee_mapper.dart';

class FundingFeeService extends AsterReadService {
  FundingFeeService({super.client, super.timeout})
    : super(origin: Uri.https('www.asterdex.com'), decodeResponse: decodeFundingFeeJson);
  Future<Object?> estimate(FundingFeeQuery query) {
    if (!fundingEvmChainIds.contains(query.chainId) ||
        !RegExp(r'^[\p{L}\p{N}_.-]{1,60}$', unicode: true).hasMatch(query.asset)) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    return get(
      '/bapi/futures/v1/public/future/aster/estimate-withdraw-fee',
      query: Uri(
        queryParameters: {
          'chainId': query.chainId.toString(),
          'network': 'EVM',
          'currency': query.asset,
          'accountType': query.market.name,
        },
      ).query,
    );
  }
}

class AsterFundingFeeRepository implements FundingFeeRepository {
  AsterFundingFeeRepository(this.service, {DateTime Function()? now}) : now = now ?? DateTime.now;
  final FundingFeeService service;
  final DateTime Function() now;
  @override
  Future<FundingFeeQuote> read(FundingFeeQuery query) async =>
      mapFundingFee(await service.estimate(query), query: query, receivedAt: now());
}
