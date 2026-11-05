import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_spot_service.dart';
import '../data/signed_spot_repository.dart';
import '../domain/aster_spot_account.dart';
import 'account_read_provider.dart';
import 'wallet_account_controller.dart';

final asterSpotRepositoryProvider = Provider<AsterSpotAccountRepository>((ref) {
  final service = AsterSpotService();
  ref.onDispose(service.close);
  return SignedSpotRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
  );
});

final spotAccountReadProvider = NotifierProvider<SpotAccountReadController, SpotAccountReadState>(
  SpotAccountReadController.new,
);

class SpotAccountReadController extends WalletAccountController<AsterSpotAccount> {
  @override
  AsterSpotAccountRepository get repository => ref.read(asterSpotRepositoryProvider);
}
