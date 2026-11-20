import 'package:material_ui/material_ui.dart';
import 'package:qr/qr.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import 'funding_components.dart';

String fundingWalletName(AppLocalizations l, WalletKind? kind) =>
    kind == WalletKind.external ? l.fundingEoaWallet : l.fundingPrivyWallet;

/// From wallet → Deposit to account, with the arrow badge over the gap.
class DepositRoute extends StatelessWidget {
  const DepositRoute({super.key, required this.from, required this.to});
  final String from, to;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FundingField(
                  key: const Key('funding-deposit-from'),
                  label: l.fundingFrom,
                  value: from,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FundingField(
                  label: l.fundingDepositTo,
                  value: to,
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: PortfolioColors.card,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(BorderSide(color: PortfolioColors.line)),
          ),
          child: const PortfolioIcon('funding-arrow.svg', size: 14),
        ),
      ],
    );
  }
}

/// Footer notice that the deposit cannot proceed, with its top-up action.
class DepositAlert extends StatelessWidget {
  const DepositAlert({super.key, required this.text, required this.action, required this.onAction});
  final String text, action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('funding-deposit-alert'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: PortfolioColors.card, borderRadius: BorderRadius.circular(8)),
    child: Row(
      children: [
        const PortfolioIcon('funding-warning.svg', size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AccountTypography.body.copyWith(color: PortfolioColors.negative),
          ),
        ),
        const SizedBox(width: 20),
        OutlinedButton(
          key: const Key('funding-deposit-alert-action'),
          onPressed: onAction,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 27),
            tapTargetSize: MaterialTapTargetSize.padded,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: PortfolioColors.text,
            side: const BorderSide(color: PortfolioColors.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: Theme.of(context).textTheme.labelLarge?.merge(FundingTypography.value),
          ).copyWith(overlayColor: PressFeedback.overlay),
          child: Text(action),
        ),
      ],
    ),
  );
}

/// The wallet address as a QR code, light modules on the sheet surface.
class DepositAddressQr extends StatelessWidget {
  const DepositAddressQr(this.address, {super.key});
  final String address;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: AppLocalizations.of(context).fundingDepositAddressQr,
    child: Container(
      key: const Key('funding-deposit-qr'),
      width: 176,
      height: 176,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: PortfolioColors.inset,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _QrPainter(
          QrImage(QrCode.fromData(data: address, errorCorrectLevel: QrErrorCorrectLevel.M)),
        ),
      ),
    ),
  );
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);
  final QrImage image;
  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount, cell = size.shortestSide / count;
    final paint = Paint()..color = PortfolioColors.text;
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (image.isDark(row, col)) {
          // A hairline overlap keeps adjacent modules from showing seams.
          canvas.drawRect(Rect.fromLTWH(col * cell, row * cell, cell + 0.3, cell + 0.3), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}
