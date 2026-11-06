import '../../../core/network/network_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/application/wallet_account_controller.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../data/signed_subaccount_list_repository.dart';
import '../domain/subaccount_directory.dart';

final subaccountListRepositoryProvider = Provider.autoDispose<SubaccountListRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedSubaccountListRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
  );
});

final subaccountListProvider =
    NotifierProvider.autoDispose<SubaccountListController, SubaccountListState>(
      SubaccountListController.new,
    );

class SubaccountListController extends WalletAccountController<SubaccountDirectory> {
  @override
  SubaccountListState build() {
    // Keep the auto-disposed transport alive for this screen, including while
    // a signed request awaits its response. A read alone does not retain it.
    ref.watch(subaccountListRepositoryProvider);
    return super.build();
  }

  @override
  SubaccountListRepository get repository => ref.read(subaccountListRepositoryProvider);
}
