import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/wallet_signing_preparation.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../data/builder_approval_journal.dart';
import '../data/builder_authorization_repository.dart';
import '../domain/builder_authorization.dart';
import 'trading_agent_provider.dart';

final builderApprovalJournalProvider = Provider<BuilderApprovalJournal>(
  (ref) => DeviceBuilderApprovalJournal(),
);

/// Loading this local public journal never signs or sends a request.
final builderApprovalProvider = FutureProvider<BuilderApprovalRecord?>((ref) async {
  final identity = ref.watch(authProvider.select((s) => s.identity));
  if (identity?.walletAddress == null || !identity!.signingAvailable) return null;
  return ref.watch(builderApprovalJournalProvider).load(identity.walletAddress!);
});

final builderAuthorizationRepositoryProvider = Provider<AsterBuilderAuthorizationRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  final identity = ref.watch(identityRepositoryProvider);
  return AsterBuilderAuthorizationRepository(
    service,
    identity.signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    journal: ref.watch(builderApprovalJournalProvider),
    onChanged: () {
      if (ref.mounted) ref.invalidate(builderApprovalProvider);
    },
    authorization: ref.watch(asterAuthorizationCheckProvider),
    signingPreparation: identity is WalletSigningPreparation
        ? identity as WalletSigningPreparation
        : null,
  );
});
