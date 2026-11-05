import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/assistant_provider.dart';
import 'assistant_composer.dart';
import 'assistant_header.dart';
import 'assistant_message_tile.dart';
import 'assistant_status.dart';

/// A single scroll surface also works with the keyboard, landscape and large
/// text. Stream updates only rebuild the message that consumes them.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});
  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _scroll = ScrollController();
  bool _scrollScheduled = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow() {
    if (_scrollScheduled || !_scroll.hasClients || _scroll.position.extentAfter > 120) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(assistantProvider.select((s) => s.messages.map((m) => m.id).join('\n')));
    ref.listen(
      assistantProvider.select((s) => s.messages.isEmpty ? null : s.messages.last),
      (_, _) => _follow(),
    );
    final messageIds = ids.isEmpty ? <String>[] : ids.split('\n');
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 820 ? (constraints.maxWidth - 788) / 2 : 16.0;
        return CustomScrollView(
          key: const Key('assistant-page'),
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 12),
              sliver: const SliverToBoxAdapter(child: AssistantHeader()),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              sliver: const SliverToBoxAdapter(child: AssistantStatus()),
            ),
            if (messageIds.isEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 24),
                sliver: SliverToBoxAdapter(
                  child: Text(AppLocalizations.of(context).assistantEmpty),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              sliver: SliverList.builder(
                itemCount: messageIds.length,
                itemBuilder: (_, index) =>
                    AssistantMessageTile(key: ValueKey(messageIds[index]), id: messageIds[index]),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
              sliver: const SliverToBoxAdapter(child: AssistantComposer()),
            ),
          ],
        );
      },
    );
  }
}
