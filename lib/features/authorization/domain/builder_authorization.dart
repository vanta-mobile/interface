import 'package:decimal/decimal.dart';

/// Public attribution configuration. No Builder signing credential is used by
/// the client. These are total trading-fee budgets, not additional Builder fees.
class VantaBuilder {
  static const address = '0x8e56a61FAF72a8BaD21585a89a3004f8a01D8AAA';
  static const name = 'Vanta';
  static final makerTotal = Decimal.parse('0.00015');
  static final takerTotal = Decimal.parse('0.0005');
  static final approvalCap = takerTotal;
}

class BuilderAuthorization {
  const BuilderAuthorization({required this.owner, required this.maxFeeRate});
  final String owner;
  final Decimal? maxFeeRate;
  bool get bound => maxFeeRate != null;
  bool get sufficient => maxFeeRate != null && maxFeeRate! >= VantaBuilder.approvalCap;
}

enum BuilderApprovalStatus { unknown, approved, rejected }

class BuilderApprovalRecord {
  const BuilderApprovalRecord({required this.status, required this.maxFeeRate});
  final BuilderApprovalStatus status;
  final Decimal maxFeeRate;
}

abstract interface class BuilderApprovalJournal {
  Future<BuilderApprovalRecord?> load(String owner);
  Future<void> save(String owner, BuilderApprovalRecord record);
}
