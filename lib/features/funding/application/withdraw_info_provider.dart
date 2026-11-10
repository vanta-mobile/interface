import '../../authorization/application/trading_agent_provider.dart';
import '../../../core/network/network_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../portfolio/application/account_change_provider.dart';
import '../../portfolio/application/spot_account_change_provider.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/application/wallet_account_controller.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../data/signed_withdraw_info_repository.dart';
import '../data/withdraw_info_mapper.dart';
import '../domain/withdraw_info.dart';

final withdrawInfoRepositoryProvider = Provider.autoDispose<WithdrawInfoRepository>((ref) {
  final service = AsterAccountService(
    client: ref.watch(backendHttpPoolProvider).lease(),
    decodeResponse: decodeWithdrawInfoJson,
  );
  ref.onDispose(service.close);
  return SignedWithdrawInfoRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});
final withdrawInfoProvider =
    NotifierProvider.autoDispose<WithdrawInfoController, WithdrawInfoState>(
      WithdrawInfoController.new,
    );

class WithdrawInfoController extends WalletAccountController<WithdrawInfo> {
  @override
  WithdrawInfoState build() {
    ref.watch(withdrawInfoRepositoryProvider);
    ref.listen(accountChangeProvider, (_, _) => markStale());
    ref.listen(spotAccountChangeProvider, (_, _) => markStale());
    return super.build();
  }

  @override
  WithdrawInfoRepository get repository => ref.read(withdrawInfoRepositoryProvider);
}
