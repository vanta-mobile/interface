import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_provider.dart';

/// Supplies the native SDK host after the Navigator is mounted. Restoration
/// never opens a wallet picker or asks for a signature.
class WalletSessionHost extends ConsumerStatefulWidget {
  const WalletSessionHost({
    required this.child,
    this.onRestored,
    this.initiallyAttemptedIdentity,
    super.key,
  });
  final Widget child;
  final VoidCallback? onRestored;
  final String? initiallyAttemptedIdentity;

  @override
  ConsumerState<WalletSessionHost> createState() => _WalletSessionHostState();
}

class _WalletSessionHostState extends ConsumerState<WalletSessionHost> with WidgetsBindingObserver {
  String? _attemptedIdentity;
  bool _restoring = false;

  Future<void> _restore() async {
    if (_restoring) return;
    _restoring = true;
    // A return from a wallet/login route belongs to that route's own flow.
    final currentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    try {
      await ref.read(authProvider.notifier).restoreWalletSession(context);
      if (mounted && currentRoute) widget.onRestored?.call();
    } finally {
      _restoring = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _attemptedIdentity = widget.initiallyAttemptedIdentity;
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
      unawaited(_restore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    final identity = session.identity;
    final key = identity == null ? null : '${identity.id}:${identity.walletAddress}';
    if (!session.busy && identity?.needsWalletConnection == true && key != _attemptedIdentity) {
      _attemptedIdentity = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_restore());
      });
    }
    if (identity == null) _attemptedIdentity = null;
    return widget.child;
  }
}
