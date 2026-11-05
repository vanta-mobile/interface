import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/event_media_provider.dart';
import '../data/event_document_mapper.dart';
import '../domain/trading_event.dart';

class EventMedia extends ConsumerWidget {
  const EventMedia({super.key, required this.uri, this.label});
  final Uri uri;
  final String? label;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), image = ref.watch(eventMediaProvider(uri));
    Widget unavailable() => Semantics(
      label: l10n.eventImageUnavailable,
      child: const SizedBox(height: 72, child: Icon(Icons.broken_image_outlined)),
    );
    return image.when(
      data: (bytes) => Image.memory(
        bytes,
        semanticLabel: label,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => unavailable(),
      ),
      loading: () => const SizedBox(height: 72, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => Column(
        children: [
          unavailable(),
          TextButton(
            onPressed: () => ref.invalidate(eventMediaProvider(uri)),
            child: Text(l10n.pointsRefresh),
          ),
        ],
      ),
    );
  }
}

class EventLinkButton extends ConsumerStatefulWidget {
  const EventLinkButton({super.key, required this.uri, required this.label});
  final Uri uri;
  final String label;
  @override
  ConsumerState<EventLinkButton> createState() => _EventLinkButtonState();
}

class _EventLinkButtonState extends ConsumerState<EventLinkButton> {
  bool busy = false, failed = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    failed = false;
                  });
                  var opened = false;
                  try {
                    if (eventLink(widget.uri.toString()) == widget.uri) {
                      opened = await ref.read(eventLinkLauncherProvider)(widget.uri);
                    }
                  } catch (_) {
                    /* Localized safe failure below. */
                  }
                  if (mounted) {
                    setState(() {
                      busy = false;
                      failed = !opened;
                    });
                  }
                },
          icon: const Icon(Icons.open_in_new),
          label: Text(widget.label),
        ),
        if (failed) Text(l10n.eventLinkFailed),
      ],
    );
  }
}

class EventDocumentView extends StatelessWidget {
  const EventDocumentView({super.key, required this.document});
  final EventDocument document;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final block in document.blocks)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: switch (block.kind) {
            EventBlockKind.heading => SelectableText(
              block.text,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            EventBlockKind.paragraph => SelectableText(block.text),
            EventBlockKind.listItem => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: SelectableText(block.text)),
              ],
            ),
            EventBlockKind.table => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in block.rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [for (final cell in row) SelectableText(cell)],
                    ),
                  ),
              ],
            ),
            EventBlockKind.image => EventMedia(
              uri: block.url!,
              label: block.text.isEmpty ? null : block.text,
            ),
            EventBlockKind.link => EventLinkButton(
              uri: block.url!,
              label: block.text.isEmpty ? block.url.toString() : block.text,
            ),
          },
        ),
    ],
  );
}
