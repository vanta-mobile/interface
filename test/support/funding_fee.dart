import 'dart:async';

import 'package:vanta/features/funding/data/funding_fee_json.dart';
import 'package:vanta/features/funding/data/funding_fee_mapper.dart';
import 'package:vanta/features/funding/domain/funding_fee.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';

const fundingFeeQuery = FundingFeeQuery(market: TransferMarket.perp, chainId: 56, asset: 'USDT');
const fundingFeePayload = '''{
  "code":"000000","success":true,"data":{
    "gasCost":0.123456789012345678901234567890123456789,
    "gasUsdValue":0.100000000000000001,
    "tokenPrice":1.12357820,
    "gasLimit":200000,"gasPrice":null
  }
}''';
FundingFeeQuote fundingFeeFixture(FundingFeeQuery query) => mapFundingFee(
  decodeFundingFeeJson(fundingFeePayload),
  query: query,
  receivedAt: DateTime.utc(2026, 11, 3, 12),
);

class TestFundingFeeRepository implements FundingFeeRepository {
  final calls = <FundingFeeQuery>[];
  final gates = <FundingFeeQuery, Completer<FundingFeeQuote>>{};
  Object? failure;
  @override
  Future<FundingFeeQuote> read(FundingFeeQuery query) async {
    calls.add(query);
    if (gates[query] case final gate?) return gate.future;
    if (failure case final error?) throw error;
    return fundingFeeFixture(query);
  }
}
