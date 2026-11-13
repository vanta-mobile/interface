import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/presentation/notification_screen.dart';
import '../application/deep_link_provider.dart';
import '../domain/app_deep_link.dart';

/// Opens navigation links once the home shell is visible.
class DeepLinkHost extends ConsumerStatefulWidget {
  const DeepLinkHost({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<DeepLinkHost> createState() => _DeepLinkHostState();
}

class _DeepLinkHostState extends ConsumerState<DeepLinkHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _take());
  }

  void _take() {
    if (!mounted) return;
    final link = ref.read(deepLinkInboxProvider.notifier).take();
    if (link == null || !_returnToShell()) return;
    ref.read(deepLinkNavigatorProvider).open(link);
    if (link.target == DeepLinkTarget.notifications) openNotifications(context);
  }

  /// Closes sheets and pages above the shell. A route that refuses to close,
  /// such as a pending signature, keeps priority and the link is dropped.
  bool _returnToShell() {
    final navigator = Navigator.of(context);
    while (true) {
      Route<dynamic>? top;
      navigator.popUntil((route) {
        top = route;
        return true;
      });
      if (top == null || top!.isFirst) return true;
      if (top!.popDisposition != RoutePopDisposition.pop) return false;
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(deepLinkInboxProvider, (_, next) {
      if (next != null) _take();
    });
    return widget.child;
  }
}
