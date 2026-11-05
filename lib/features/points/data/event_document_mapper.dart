import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../domain/trading_event.dart';
import 'points_mapper.dart';

Uri? eventLink(Object? raw, {bool image = false}) {
  if (raw == null || raw == '') return null;
  if (raw is! String || raw.length > 4096 || RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(raw)) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  final resolved = Uri.https('app.vanta.exchange').resolveUri(uri);
  if (resolved.scheme != 'https' ||
      resolved.host.isEmpty ||
      resolved.userInfo.isNotEmpty ||
      (resolved.hasPort && resolved.port != 443)) {
    return null;
  }
  if (image &&
      (resolved.host != 'nltkngcwiuydkpmqrili.supabase.co' ||
          !resolved.path.startsWith('/storage/v1/object/public/trading-event-content/'))) {
    return null;
  }
  return resolved;
}

/// Render published rich text as native content, never executable HTML or CSS.
/// Text, table structure, links and approved raster media survive sanitization.
EventDocument mapEventDocument(Object? raw) {
  final source = pointsText(raw ?? '', max: 131072, empty: true);
  final fragment = html.parseFragment(source);
  var nodeCount = 0;
  void bound(dom.Node node, int depth) {
    if (++nodeCount > 10000 || depth > 64) throw const FormatException();
    for (final child in node.nodes) {
      bound(child, depth + 1);
    }
  }

  bound(fragment, 0);
  for (final node in fragment.querySelectorAll(
    'script,style,iframe,object,embed,template,form,input,button,svg,math,noscript',
  )) {
    node.remove();
  }
  final blocks = <EventBlock>[];
  void add(EventBlock block) {
    if (blocks.length >= 1000) throw const FormatException();
    blocks.add(block);
  }

  String content(dom.Node node) {
    if (node is dom.Text) return node.data;
    if (node is dom.Element && node.localName == 'br') return '\n';
    final value = node.nodes.map(content).join();
    return node is dom.Element &&
            const {
              'p',
              'div',
              'li',
              'tr',
              'h1',
              'h2',
              'h3',
              'h4',
              'h5',
              'h6',
            }.contains(node.localName)
        ? '\n$value\n'
        : value;
  }

  String text(dom.Node node) =>
      pointsText(content(node).replaceAll(RegExp(r'\s+'), ' ').trim(), max: 32768, empty: true);
  void reference(dom.Element element) {
    final image = element.localName == 'img';
    final uri = eventLink(element.attributes[image ? 'src' : 'href'], image: image);
    if (uri != null) {
      add(
        EventBlock(
          image ? EventBlockKind.image : EventBlockKind.link,
          text: image
              ? pointsText(element.attributes['alt'] ?? '', max: 1024, empty: true)
              : text(element),
          url: uri,
        ),
      );
    }
  }

  void visit(dom.Node node) {
    if (node is dom.Element) {
      final tag = node.localName;
      if (tag == 'img' || tag == 'a') {
        reference(node);
        return;
      }
      if (tag == 'table') {
        final rows = <List<String>>[];
        for (final tr in node.querySelectorAll('tr')) {
          final cells = tr.children
              .where((e) => e.localName == 'td' || e.localName == 'th')
              .map(text)
              .toList();
          if (cells.length > 20 || rows.length >= 200) throw const FormatException();
          if (cells.isNotEmpty) rows.add(cells);
        }
        if (rows.isNotEmpty) add(EventBlock(EventBlockKind.table, rows: rows));
        for (final e in node.querySelectorAll('a,img')) {
          reference(e);
        }
        return;
      }
      if (const {
        'p',
        'li',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'blockquote',
        'pre',
      }.contains(tag)) {
        final value = text(node);
        if (value.isNotEmpty) {
          add(
            EventBlock(
              tag == 'li'
                  ? EventBlockKind.listItem
                  : tag!.startsWith('h')
                  ? EventBlockKind.heading
                  : EventBlockKind.paragraph,
              text: value,
            ),
          );
        }
        for (final e in node.querySelectorAll('a,img')) {
          reference(e);
        }
        return;
      }
    } else if (node is dom.Text && text(node).isNotEmpty) {
      add(EventBlock(EventBlockKind.paragraph, text: text(node)));
      return;
    }
    for (final child in node.nodes) {
      visit(child);
    }
  }

  visit(fragment);
  return EventDocument(blocks);
}
