import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../application/generated_subaccount_provider.dart';
import '../domain/generated_subaccount.dart';
import 'account_components.dart';
import 'subaccount_backup_card.dart';
import 'account_management_screen.dart';

class SubaccountBackupScreen extends ConsumerStatefulWidget {
  const SubaccountBackupScreen({
    super.key,
    required this.wallet,
    this.accepted = false,
    this.failure,
  });
  final GeneratedSubaccount wallet;
  final bool accepted;
  final String? failure;
  @override
  ConsumerState<SubaccountBackupScreen> createState() => _SubaccountBackupScreenState();
}

class _SubaccountBackupScreenState extends ConsumerState<SubaccountBackupScreen>
    with WidgetsBindingObserver {
  String? _key, _failure;
  bool _saved = false, _busy = false;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _revision++;
    _key = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      _revision++;
      setState(() => _key = null);
    }
  }

  bool get _authorized {
    final identity = ref.read(authProvider).identity;
    return identity?.signingAvailable == true &&
        identity?.walletAddress?.toLowerCase() == widget.wallet.owner.toLowerCase();
  }

  Future<void> _reveal() async {
    if (_key != null) {
      _revision++;
      setState(() => _key = null);
      return;
    }
    if (!_authorized || _busy) return;
    final revision = ++_revision;
    setState(() => _busy = true);
    try {
      final key = await ref.read(subaccountWalletStoreProvider).reveal(widget.wallet.address);
      if (mounted && revision == _revision && _authorized) setState(() => _key = key);
    } catch (e) {
      if (mounted) {
        setState(
          () => _failure = e is AccountReadFailure ? e.key : 'subaccountSecureStorageFailed',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    if (!_authorized || !_saved || _busy) return;
    setState(() {
      _busy = true;
      _key = null;
    });
    try {
      await ref.read(generatedAccountProvider.notifier).saved(widget.wallet);
      if (mounted && _authorized) {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else if (widget.accepted) {
          Navigator.of(context).pushReplacement<void, void>(
            MaterialPageRoute(builder: (_) => const AccountManagementScreen()),
          );
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _failure = e is AccountReadFailure ? e.key : 'subaccountSecureStorageFailed',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Retain the creation lifecycle while acknowledging an interrupted backup.
    ref.watch(generatedAccountProvider);
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (a, b) {
        if (a != b) {
          _revision++;
          setState(() {
            _key = null;
            _saved = false;
          });
        }
      },
    );
    return AccountsPage(
      title: l.accountsBackupTitle,
      canPop: !_authorized,
      actions: const [
        Padding(padding: EdgeInsets.only(right: 20), child: PortfolioIcon('shield.svg')),
      ],
      footer: [
        AccountAction(
          key: const Key('subaccount-backup-continue'),
          label: _saved ? l.accountsDone : l.accountsContinue,
          busy: _busy,
          onPressed: _saved && _authorized ? _continue : null,
        ),
      ],
      children: [
        Text(
          widget.accepted ? l.accountsCreated : l.accountsBackupPending,
          style: PortfolioTypography.heading,
        ),
        const SizedBox(height: 16),
        Text(l.accountsBackupNotice, style: AccountTypography.secondary),
        const SizedBox(height: 36),
        SubaccountBackupCard(
          wallet: widget.wallet,
          accepted: widget.accepted,
          privateKey: _key,
          onReveal: _busy || !_authorized ? null : _reveal,
        ),
        const SizedBox(height: 16),
        AccountNotice(l.accountsKeyWarning, warning: true),
        if (widget.failure != null)
          Text(
            widget.failure!,
            style: PortfolioTypography.caption.copyWith(color: PortfolioColors.negative),
          ),
        if (_failure != null)
          Text(
            apiErrorText(context, _failure!, null),
            style: PortfolioTypography.caption.copyWith(color: PortfolioColors.negative),
          ),
        const SizedBox(height: 16),
        BackupAcknowledgement(
          key: const Key('subaccount-backup-saved'),
          saved: _saved,
          onChanged: _busy || !_authorized ? null : (value) => setState(() => _saved = value),
        ),
      ],
    );
  }
}
