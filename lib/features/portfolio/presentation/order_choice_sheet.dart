import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import 'portfolio_components.dart';

/// Shared header and spacing for order-type and time-in-force choices.
class OrderChoiceSheet extends StatelessWidget {
  const OrderChoiceSheet({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: TradeTypography.heading)),
              SizedBox(
                width: 24,
                height: 44,
                child: OverflowBox(
                  maxWidth: 44,
                  child: IconButton(
                    tooltip: l.close,
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    icon: const PortfolioIcon('policy-close.svg', size: 24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SvgPicture.asset('assets/trade/policy-divider.svg', height: 1, fit: BoxFit.fill),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
