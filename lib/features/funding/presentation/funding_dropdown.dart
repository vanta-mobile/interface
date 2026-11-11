import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../portfolio/presentation/portfolio_components.dart';

/// One selectable row of an in-place funding dropdown.
class FundingOption<T> {
  const FundingOption(this.value, this.label, this.icon);
  final T value;
  final String label;
  final Widget icon;
}

/// In-place dropdown below its anchor; tapping outside closes it.
class FundingDropdown<T> extends StatefulWidget {
  const FundingDropdown({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.builder,
  });
  final List<FundingOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final Widget Function(BuildContext context, bool open, VoidCallback? toggle) builder;
  @override
  State<FundingDropdown<T>> createState() => _FundingDropdownState<T>();
}

class _FundingDropdownState<T> extends State<FundingDropdown<T>> {
  final controller = OverlayPortalController(), link = LayerLink(), anchor = GlobalKey();
  final scroll = ScrollController();
  double width = 0;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void _toggle() => setState(controller.isShowing ? controller.hide : controller.show);
  void _select(T value) {
    setState(controller.hide);
    widget.onSelected(value);
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: link,
    child: OverlayPortal(
      controller: controller,
      overlayChildBuilder: (context) {
        final (below, maxHeight) = _space(context);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const Key('funding-dropdown-barrier'),
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
              ),
            ),
            CompositedTransformFollower(
              link: link,
              targetAnchor: below ? Alignment.bottomLeft : Alignment.topLeft,
              followerAnchor: below ? Alignment.topLeft : Alignment.bottomLeft,
              offset: Offset(0, below ? _gap : -_gap),
              showWhenUnlinked: false,
              child: SizedBox(width: width, child: _menu(maxHeight)),
            ),
          ],
        );
      },
      child: LayoutBuilder(
        key: anchor,
        builder: (context, constraints) {
          width = constraints.maxWidth;
          return widget.builder(
            context,
            controller.isShowing,
            widget.options.isEmpty ? null : _toggle,
          );
        },
      ),
    ),
  );

  static const _gap = 8.0, _margin = 16.0;

  /// Opens below the anchor unless the space above is larger; either way the
  /// menu stays inside the safe area and keyboard, scrolling longer lists.
  (bool, double) _space(BuildContext context) {
    final media = MediaQuery.of(context);
    final box = anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return (true, 0);
    final top = box.localToGlobal(Offset.zero).dy, bottom = top + box.size.height;
    final below =
        media.size.height -
        media.viewInsets.bottom -
        media.padding.bottom -
        _margin -
        bottom -
        _gap;
    final above = top - _gap - media.padding.top - _margin;
    final down = below >= 200 || below >= above;
    return (down, (down ? below : above).clamp(0, double.infinity));
  }

  Widget _menu(double maxHeight) => Container(
    constraints: BoxConstraints(maxHeight: maxHeight),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: PortfolioColors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: PortfolioColors.button),
      boxShadow: const [
        BoxShadow(color: PortfolioColors.menuShadow, offset: Offset(0, 8), blurRadius: 20),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Scrollbar(
        controller: scroll,
        child: SingleChildScrollView(
          key: const Key('funding-dropdown-scroll'),
          controller: scroll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, option) in widget.options.indexed) ...[
                if (index > 0) const SizedBox(height: 4),
                Semantics(
                  button: true,
                  selected: option.value == widget.selected,
                  child: InkWell(
                    key: Key('funding-option-${option.value}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _select(option.value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            option.icon,
                            const SizedBox(width: 8),
                            Expanded(child: Text(option.label, style: AccountTypography.body)),
                            if (option.value == widget.selected)
                              const PortfolioIcon('check-circle.svg', size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
