import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import 'mode_settings_sheet.dart';

class ModeReadAction extends ConsumerWidget {
  const ModeReadAction({
    super.key,
    required this.onRead,
    required this.busy,
    this.blocked = false,
    this.recheck = false,
  });
  final Future<void> Function() onRead;
  final bool busy, blocked, recheck;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider), l = AppLocalizations.of(context);
    final identity = auth.identity;
    return ModeAction(
      busy: busy,
      label: recheck
          ? l.leverageRecheck
          : identity == null
          ? l.accountSignInToRead
          : identity.walletAddress == null
          ? l.createWallet
          : !identity.signingAvailable
          ? l.reconnectExternalWallet
          : l.modeRefresh,
      onPressed: blocked || auth.busy
          ? null
          : identity?.signingAvailable == true && identity?.walletAddress != null
          ? onRead
          : () => showAccountSheet(context),
    );
  }
}
