import 'package:flutter/material.dart';

import '../../trade/presentation/trade_theme.dart';

/// Order-direction summary card with its action button laid over the card's
/// bottom edge. The card's 1px inside stroke covers only the top and sides,
/// which continue [overlap] px behind the button; the button keeps all four
/// 12px corners and is never clipped by the card.
class DirectionActionCard extends StatelessWidget {
  const DirectionActionCard({super.key, required this.rows, required this.button});
  final List<Widget> rows;
  final Widget button;

  /// Card bottom padding hidden behind the button (design: 16 padding, 8 overlap).
  static const overlap = 8.0;

  /// Shape shared by the direction buttons laid over this card.
  static const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: -overlap,
            child: IgnorePointer(child: CustomPaint(painter: _OpenBottomBorderPainter())),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16 - overlap),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
          ),
        ],
      ),
      // Painted after the card, so it sits above the stroke's lower part.
      button,
    ],
  );
}

class _OpenBottomBorderPainter extends CustomPainter {
  const _OpenBottomBorderPainter();
  static const _radius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Inside stroke: the 1px line is centred half a pixel within the bounds.
    const inset = .5, r = _radius - inset;
    final path = Path()
      ..moveTo(inset, size.height)
      ..lineTo(inset, _radius)
      ..arcToPoint(const Offset(_radius, inset), radius: const Radius.circular(r))
      ..lineTo(size.width - _radius, inset)
      ..arcToPoint(Offset(size.width - inset, _radius), radius: const Radius.circular(r))
      ..lineTo(size.width - inset, size.height);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = TradeColors.card,
    );
  }

  @override
  bool shouldRepaint(_OpenBottomBorderPainter oldDelegate) => false;
}
