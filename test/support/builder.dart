import 'package:vanta/features/authorization/domain/builder_authorization.dart';
import 'package:vanta/features/portfolio/domain/account_request_signing.dart';

import 'aster_signatures.dart';

Future<AccountRequestIdentity> builderTestAgent(String owner) async => AccountRequestIdentity(
  address: fixtureChild,
  sign: ({required expectedAddress, required typedData}) async =>
      fixtureSign(typedData, child: true),
);

class MemoryBuilderApprovalJournal implements BuilderApprovalJournal {
  MemoryBuilderApprovalJournal({this.approvedByDefault = false});
  final bool approvedByDefault;
  final records = <String, BuilderApprovalRecord>{};
  Object? failure;
  int writes = 0;
  void Function(BuilderApprovalRecord)? onSaved;
  @override
  Future<BuilderApprovalRecord?> load(String owner) async {
    if (failure case final error?) throw error;
    return records[owner.toLowerCase()] ??
        (approvedByDefault
            ? BuilderApprovalRecord(
                status: BuilderApprovalStatus.approved,
                maxFeeRate: VantaBuilder.approvalCap,
              )
            : null);
  }

  @override
  Future<void> save(String owner, BuilderApprovalRecord record) async {
    if (failure case final error?) throw error;
    writes++;
    records[owner.toLowerCase()] = record;
    onSaved?.call(record);
  }
}
