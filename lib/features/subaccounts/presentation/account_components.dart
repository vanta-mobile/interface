import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../domain/account_entry.dart';

String accountLabel(AppLocalizations l, AccountEntry a) => !a.roleKnown
    ? l.account
    : a.main
    ? l.portfolioMainAccount
    : a.name;
String shortAccountAddress(String address) => address.length < 14
    ? address
    : '${address.substring(0, 6)}…${address.substring(address.length - 4)}';

class AccountsPage extends StatelessWidget {
  const AccountsPage({
    super.key,
    required this.title,
    required this.children,
    this.footer = const [],
    this.actions,
    this.onRefresh,
    this.onBack,
    this.canPop = true,
    this.showBack = true,
  });
  final String title;
  final List<Widget> children, footer;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onBack;
  final bool canPop;

  /// Pages closed from an action button can stay poppable without a back icon.
  final bool showBack;
  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context), back = canPop && showBack;
    final titleLayout =
        TextPainter(
          text: TextSpan(
            text: title,
            style: Theme.of(context).textTheme.titleLarge?.merge(AccountTypography.heading),
          ),
          textDirection: direction,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 2,
        )..layout(
          maxWidth:
              (MediaQuery.sizeOf(context).width -
                      (back ? 48 : 16) -
                      (actions?.length ?? 0) * 48 -
                      16)
                  .clamp(80, 600),
        );
    final toolbarHeight = (titleLayout.height + 16).clamp(56.0, double.infinity);
    titleLayout.dispose();
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 7, 24, 16),
          sliver: SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
    return PopScope(
      canPop: canPop && onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canPop) onBack?.call();
      },
      child: Scaffold(
        backgroundColor: PortfolioColors.background,
        appBar: AppBar(
          toolbarHeight: toolbarHeight,
          backgroundColor: PortfolioColors.background,
          surfaceTintColor: PortfolioColors.transparent,
          centerTitle: false,
          titleSpacing: 0,
          title: Text(title, style: AccountTypography.heading, maxLines: 2),
          automaticallyImplyLeading: back,
          leading: back
              ? IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack ?? () => Navigator.maybePop(context),
                  icon: const PortfolioIcon('back.svg', size: 24),
                )
              : const SizedBox(width: 16),
          leadingWidth: back ? 48 : 16,
          actions: actions,
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Expanded(
                    child: onRefresh == null
                        ? scroll
                        : RefreshIndicator(onRefresh: onRefresh!, child: scroll),
                  ),
                  if (footer.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: footer,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountAction extends StatelessWidget {
  const AccountAction({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.primary = true,
    this.danger = false,
    this.outlined = false,
    this.fadeDisabled = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy, primary, danger, outlined;

  /// Funding frames keep a disabled primary in its own colors at 40% opacity.
  final bool fadeDisabled;
  @override
  Widget build(BuildContext context) {
    final faded = fadeDisabled && primary && !danger && (busy || onPressed == null);
    final button = FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: danger && primary
            ? PortfolioColors.negative
            : primary
            ? PortfolioColors.accent
            : PortfolioColors.card,
        foregroundColor: danger && !primary
            ? PortfolioColors.negative
            : primary && !danger
            ? PortfolioColors.onAccent
            : PortfolioColors.text,
        side: danger && !primary || outlined ? const BorderSide(color: PortfolioColors.line) : null,
        disabledBackgroundColor: faded ? PortfolioColors.accent : PortfolioColors.card,
        disabledForegroundColor: faded ? PortfolioColors.onAccent : PortfolioColors.secondary,
        textStyle: Theme.of(context).textTheme.labelLarge?.merge(PortfolioTypography.section),
      ),
      child: busy
          ? Semantics(
              label: label,
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: faded ? PortfolioColors.onAccent : null,
                ),
              ),
            )
          : Text(label, textAlign: TextAlign.center),
    );
    return faded ? Opacity(opacity: 0.4, child: button) : button;
  }
}

class AccountNotice extends StatelessWidget {
  const AccountNotice(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: PortfolioIcon(
            'info.svg',
            size: 16,
            color: warning ? AppColors.warning : PortfolioColors.muted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: PortfolioTypography.caption)),
      ],
    ),
  );
}

class AccountValueRow extends StatelessWidget {
  const AccountValueRow(this.label, this.value, {super.key, this.copyable = false, this.color});
  final String label, value;
  final bool copyable;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Text(label, style: PortfolioTypography.caption)),
      const SizedBox(width: 12),
      Flexible(
        fit: FlexFit.tight,
        child: copyable
            ? SelectableText(
                value,
                textAlign: TextAlign.right,
                style: PortfolioTypography.caption.copyWith(color: color ?? PortfolioColors.text),
              )
            : Text(
                value,
                textAlign: TextAlign.right,
                style: PortfolioTypography.caption.copyWith(color: color ?? PortfolioColors.text),
              ),
      ),
    ],
  );
}

/// Keeps the designed compact row while allowing the full identifier to be copied.
class AccountAddressRow extends StatelessWidget {
  const AccountAddressRow(this.label, this.address, {super.key, this.showCopyButton = false});
  final String label, address;
  final bool showCopyButton;
  @override
  Widget build(BuildContext context) {
    final row = AccountValueRow(label, shortAccountAddress(address));
    if (showCopyButton) {
      return Semantics(
        button: true,
        label: tr(context, 'copyAddress'),
        child: InkWell(
          onTap: () => copyAccountAddress(address),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Expanded(child: row),
                const SizedBox(width: 8),
                const PortfolioIcon('copy.svg', size: 16),
              ],
            ),
          ),
        ),
      );
    }
    return Semantics(
      onLongPress: () => copyAccountAddress(address),
      child: GestureDetector(
        onLongPress: () => copyAccountAddress(address),
        behavior: HitTestBehavior.opaque,
        child: row,
      ),
    );
  }
}

void copyAccountAddress(String address) => Clipboard.setData(ClipboardData(text: address));
Widget closeAccountsButton(BuildContext context, {bool enabled = true}) => IconButton(
  key: const Key('accounts-close'),
  tooltip: tr(context, 'close'),
  onPressed: enabled ? () => Navigator.maybePop(context) : null,
  icon: const PortfolioIcon('close.svg', size: 24),
);

class AccountContext extends StatelessWidget {
  const AccountContext(this.address, {super.key});
  final String address;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        children: [
          const PortfolioIcon('account.svg', color: PortfolioColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${AppLocalizations.of(context).portfolioMainAccount} · ${shortAccountAddress(address)}',
              style: PortfolioTypography.caption,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget copyAccountButton(BuildContext context, String address) => IconButton(
  tooltip: tr(context, 'copyAddress'),
  onPressed: () => copyAccountAddress(address),
  icon: const PortfolioIcon('copy.svg'),
);
