import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_position_adl_repository.dart';
import '../domain/position_adl.dart';
import 'account_read_provider.dart';
import 'wallet_account_controller.dart';

final positionAdlRepositoryProvider = Provider<PositionAdlRepository>((ref) {
  final service = AsterAccountService();
  ref.onDispose(service.close);
  return SignedPositionAdlRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
  );
});

final positionAdlProvider =
    NotifierProvider<PositionAdlController, AccountSnapshotState<PositionAdlSnapshot>>(
      PositionAdlController.new,
    );

class PositionAdlController extends WalletAccountController<PositionAdlSnapshot> {
  @override
  PositionAdlRepository get repository => ref.read(positionAdlRepositoryProvider);
}
