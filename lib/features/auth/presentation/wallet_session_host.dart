import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_provider.dart';

/// Supplies the native SDK host after the Navigator is mounted. Restoration
/// never opens a wallet picker or asks for a signature.
class WalletSessionHost extends ConsumerStatefulWidget {
  const WalletSessionHost({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<WalletSessionHost> createState() => _WalletSessionHostState();
}

class _WalletSessionHostState extends ConsumerState<WalletSessionHost> with WidgetsBindingObserver {
  String? _attemptedIdentity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(authProvider.notifier).restoreWalletSession(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    final identity = session.identity;
    if (!session.busy &&
        identity?.needsWalletConnection == true &&
        identity!.id != _attemptedIdentity) {
      _attemptedIdentity = identity.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(ref.read(authProvider.notifier).restoreWalletSession(context));
      });
    }
    if (identity == null) _attemptedIdentity = null;
    return widget.child;
  }
}
