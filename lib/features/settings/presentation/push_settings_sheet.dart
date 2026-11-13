import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/decimal_text_input_formatter.dart';
import '../../../core/presentation/status_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../../notifications/application/push_device_provider.dart';
import '../../notifications/domain/push_device.dart';
import '../../notifications/presentation/notification_api_error.dart';
import '../../portfolio/presentation/mode_settings_sheet.dart';
import '../../trade/presentation/trade_theme.dart';
import 'quiet_time_picker.dart';
import 'settings_components.dart';

Future<void> openPushSettings(BuildContext context) =>
    showModeSettingsSheet<void>(context, const PushSettingsSheet());

class PushSettingsSheet extends ConsumerStatefulWidget {
  const PushSettingsSheet({super.key});
  @override
  ConsumerState<PushSettingsSheet> createState() => _PushSettingsSheetState();
}

class _PushSettingsSheetState extends ConsumerState<PushSettingsSheet> {
  final _minimum = TextEditingController();
  final _minimumFocus = FocusNode();

  /// Quiet hours chosen locally before both ends exist on the server.
  bool _quietDraft = false;
  String? _draftStart, _draftEnd, _localError;
  Decimal? _submittedMinimum;

  /// Controls with a write in flight; only these show a spinner and lock.
  final _pending = <String>{};

  @override
  void initState() {
    super.initState();
    _minimum.text = _minimumText(_preferences?.minNotional);
    _minimumFocus.addListener(() {
      if (!_minimumFocus.hasFocus) _submitMinimum();
    });
  }

  @override
  void dispose() {
    _minimum.dispose();
    _minimumFocus.dispose();
    super.dispose();
  }

  PushPreferences? get _preferences => ref.read(pushDeviceProvider).status?.preferences;

  /// An absent or zero threshold is the default and shows as the placeholder.
  static String _minimumText(Decimal? value) =>
      value == null || value == Decimal.zero ? '' : value.toString();

  Future<void> _update(String control, PushPreferencesUpdate update) {
    setState(() {
      _localError = null;
      _pending.add(control);
    });
    return ref.read(pushDeviceProvider.notifier).updatePreferences(update).whenComplete(() {
      if (mounted) setState(() => _pending.remove(control));
    });
  }

  void _submitMinimum() {
    final text = _minimum.text.trim(), current = _preferences?.minNotional ?? Decimal.zero;
    // Clearing the field restores the default of 0.
    final value = text.isEmpty ? Decimal.zero : Decimal.tryParse(text);
    if (value == null) {
      _minimum.text = _minimumText(current);
      return;
    }
    // Done and the following blur both submit; send each new value once.
    if (value == current || value == _submittedMinimum) return;
    _submittedMinimum = value;
    unawaited(
      _update(
        'minimum',
        PushPreferencesUpdate(minNotional: value),
      ).whenComplete(() => _submittedMinimum = null),
    );
  }

  /// Picking a time turns quiet hours on; switching them off clears both times.
  void _toggleQuiet(bool enabled) {
    final prefs = _preferences, l = AppLocalizations.of(context);
    if (!enabled) {
      setState(() {
        _quietDraft = false;
        _draftStart = _draftEnd = null;
      });
      if (prefs?.quietStart != null) {
        unawaited(_update('quiet', PushPreferencesUpdate(clearQuietHours: true)));
      }
      return;
    }
    setState(() => _quietDraft = true);
    final start = _draftStart ?? prefs?.quietStart, end = _draftEnd ?? prefs?.quietEnd;
    if (start == null || end == null) return;
    if (_minutes(start) == _minutes(end)) {
      setState(() => _localError = l.pushQuietSameTime);
      return;
    }
    unawaited(_update('quiet', PushPreferencesUpdate(quietStart: start, quietEnd: end)));
  }

  Future<void> _pickTime(bool start) async {
    final l = AppLocalizations.of(context), prefs = _preferences;
    final currentStart = _draftStart ?? prefs?.quietStart;
    final currentEnd = _draftEnd ?? prefs?.quietEnd;
    final picked = await showQuietTimePicker(
      context,
      title: start ? l.pushStartTime : l.pushEndTime,
      initial: start ? currentStart : currentEnd,
    );
    if (picked == null || !mounted) return;
    final nextStart = start ? picked : currentStart, nextEnd = start ? currentEnd : picked;
    setState(() {
      _localError = null;
      _quietDraft = true;
      start ? _draftStart = picked : _draftEnd = picked;
    });
    if (nextStart == null || nextEnd == null) return;
    if (_minutes(nextStart) == _minutes(nextEnd)) {
      setState(() => _localError = l.pushQuietSameTime);
      return;
    }
    unawaited(_update('quiet', PushPreferencesUpdate(quietStart: nextStart, quietEnd: nextEnd)));
  }

  bool get _quietOn => _quietDraft || _preferences?.quietStart != null;

  static String _minutes(String time) => time.substring(0, 5);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final device = ref.watch(pushDeviceProvider);
    final session = ref.watch(vantaApiSessionProvider);
    final prefs = device.status?.preferences;
    ref.listen(pushDeviceProvider.select((s) => s.status?.preferences.minNotional), (_, next) {
      if (!_minimumFocus.hasFocus) _minimum.text = _minimumText(next);
    });
    // Device binding work and other writes queue in the controller, so a
    // pending write locks only its own control instead of the whole sheet.
    final enabled = prefs != null;
    final quietOn = _quietOn, quietBusy = _pending.contains('quiet');
    final error =
        _localError ??
        (device.error == null ? null : notificationApiErrorText(context, device.error!));
    return ModeSheetBody(
      key: const Key('push-settings-sheet'),
      title: l.settingsPushNotifications,
      onRefresh: () => ref.read(pushDeviceProvider.notifier).refresh(),
      children: [
        if (prefs == null && !session.ready && !session.pending)
          const NotificationApiAccess()
        else if (prefs == null && error == null)
          const _PushSkeleton()
        else ...[
          _SwitchRow(
            key: const Key('push-quiet-hours'),
            label: l.pushQuietHours,
            value: quietOn,
            busy: quietBusy,
            onChanged: enabled ? _toggleQuiet : null,
          ),
          const SizedBox(height: 12),
          _Row(
            label: l.pushNotificationTime,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TimeBox(
                  key: const Key('push-quiet-start'),
                  value: _draftStart ?? prefs?.quietStart,
                  onTap: enabled && !quietBusy ? () => _pickTime(true) : null,
                ),
                const SizedBox(width: 8),
                const SettingsIcon('time-separator', width: 12, height: 2),
                const SizedBox(width: 8),
                _TimeBox(
                  key: const Key('push-quiet-end'),
                  value: _draftEnd ?? prefs?.quietEnd,
                  onTap: enabled && !quietBusy ? () => _pickTime(false) : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Row(
            label: l.pushMinimumTradeValue,
            trailing: _MinimumField(
              controller: _minimum,
              focusNode: _minimumFocus,
              enabled: enabled,
              busy: _pending.contains('minimum'),
              onSubmitted: _submitMinimum,
            ),
          ),
          const SettingsDivider(),
          for (final (index, category) in PushCategory.values.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            _SwitchRow(
              key: Key('push-category-${category.name}'),
              label: _categoryLabel(l, category),
              value: prefs?.categories[category] ?? false,
              busy: _pending.contains(category.name),
              onChanged: enabled
                  ? (value) => unawaited(
                      _update(category.name, PushPreferencesUpdate(categories: {category: value})),
                    )
                  : null,
            ),
          ],
        ],
        if (error != null) ModeError(error),
      ],
    );
  }
}

String _categoryLabel(AppLocalizations l, PushCategory category) => switch (category) {
  PushCategory.fills => l.pushTradeExecutions,
  PushCategory.triggers => l.pushConditionalTriggers,
  PushCategory.orders => l.pushOrderUpdates,
  PushCategory.funding => l.pushFundingFees,
  PushCategory.transfers => l.pushTransfers,
  PushCategory.announcements => l.pushAnnouncements,
};

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing});
  final String label;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 40),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TradeTypography.option.copyWith(color: TradeColors.secondary)),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.label,
    required this.value,
    this.busy = false,
    this.onChanged,
  });
  final String label;
  final bool value, busy;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => _Row(
    label: label,
    trailing: SettingsSwitch(value: value, label: label, busy: busy, onChanged: onChanged),
  );
}

BoxDecoration _fieldDecoration() => BoxDecoration(
  color: TradeColors.input,
  border: Border.all(color: TradeColors.line),
  borderRadius: BorderRadius.circular(12),
);

const _fieldText = TextStyle(
  fontFamily: 'Inter',
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  color: TradeColors.text,
);

class _TimeBox extends StatelessWidget {
  const _TimeBox({super.key, required this.value, this.onTap});
  final String? value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: _fieldDecoration(),
          child: Text(
            value == null ? '00:00' : value!.substring(0, 5),
            style: _fieldText.copyWith(color: value == null ? TradeColors.muted : TradeColors.text),
          ),
        ),
      ),
    ),
  );
}

class _MinimumField extends StatelessWidget {
  const _MinimumField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.busy,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled, busy;
  final VoidCallback onSubmitted;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: focusNode,
    // The whole box, including the $ prefix, is the field; it alone shows focus.
    builder: (context, child) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled && !busy ? focusNode.requestFocus : null,
      child: Container(
        key: const Key('push-minimum-notional'),
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: _fieldDecoration().copyWith(
          border: Border.all(color: focusNode.hasFocus ? TradeColors.accent : TradeColors.line),
        ),
        child: child,
      ),
    ),
    child: Row(
      children: [
        // The submitted value stays visible; the prefix turns into a spinner.
        if (busy)
          const SettingsSpinner()
        else
          Text('\$', style: _fieldText.copyWith(color: TradeColors.secondary)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            readOnly: busy,
            textAlign: TextAlign.end,
            style: _fieldText,
            cursorColor: TradeColors.accent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [DecimalTextInputFormatter(maxFractionDigits: 2)],
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: '0',
              hintStyle: _fieldText.copyWith(color: TradeColors.muted),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PushSkeleton extends StatelessWidget {
  const _PushSkeleton();
  @override
  Widget build(BuildContext context) => Column(
    key: const Key('push-settings-skeleton'),
    children: [
      for (var i = 0; i < 6; i++)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: SkeletonBox(height: 24)),
              SizedBox(width: 48),
              SkeletonBox(width: 46, height: 26, radius: 13),
            ],
          ),
        ),
    ],
  );
}
