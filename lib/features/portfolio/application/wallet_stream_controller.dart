import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../market/application/market_providers.dart' show quoteUpdatesActiveProvider;
import '../domain/account_change_stream.dart';
import '../domain/account_snapshot.dart';
import 'symbol_settings_activity.dart';

/// Explicit, wallet-scoped in-memory user-stream lease. No automatic signatures.
abstract class WalletStreamController extends Notifier<AccountChangeState> {
  int _generation = 0, _socketGeneration = 0;
  String? _authorizedAddress;
  StreamSubscription<AccountChangeEvent>? _subscription;
  Timer? _renewal, _expiry;
  AccountChangeRepository get repository;
  DateTime get now;
  void invalidateSnapshots();
  void applyEvent(String authorizedAddress, AccountChangeEvent event);
  bool get _active => orderSessionActive(
    ref.read(quoteUpdatesActiveProvider),
    ref.read(symbolSettingsActivityProvider),
  );

  @override
  AccountChangeState build() {
    final initialRepository = repository;
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (before, after) {
        if (before != after) stop();
      },
    );
    var wasActive = _active;
    void updateActivity() {
      final active = _active;
      if (wasActive == active) return;
      wasActive = active;
      if (state.expiresAt == null || state.connection == AccountChangeConnection.expired) return;
      if (!active) {
        _closeSocket();
        invalidateSnapshots();
        _replace(AccountChangeConnection.paused);
      } else if (!state.busy) {
        reconnect();
      }
    }

    // Reconcile the inputs directly: an input listener can run before a derived
    // provider invalidates its old cached value. Native pause/resume must take
    // effect before another synchronous intent can use the old stream state.
    ref.listen(quoteUpdatesActiveProvider, (_, _) => updateActivity());
    ref.listen(
      symbolSettingsActivityProvider.select((s) => (s.busy, s.owner)),
      (_, _) => updateActivity(),
    );
    ref.onDispose(() {
      _generation++;
      _closeSocket();
      _renewal?.cancel();
      _expiry?.cancel();
      initialRepository.clear();
    });
    return const AccountChangeState();
  }

  Future<void> authorize() async {
    if (state.busy) return;
    final identity = ref.read(authProvider).identity;
    final address = identity?.walletAddress;
    if (identity == null || address == null) return;
    if (!identity.signingAvailable) {
      state = const AccountChangeState(failure: AccountReadFailure('authWalletReconnect'));
      return;
    }
    _closeSocket();
    _renewal?.cancel();
    _expiry?.cancel();
    invalidateSnapshots();
    final generation = ++_generation;
    final previousEvent = state.lastEventAt;
    bool current() => ref.mounted && generation == _generation;
    state = AccountChangeState(step: AccountReadStep.preparing, lastEventAt: previousEvent);
    try {
      final expiresAt = await repository.authorize(
        address: address,
        isCurrent: current,
        onStep: (step) {
          if (current()) state = AccountChangeState(step: step, lastEventAt: previousEvent);
        },
      );
      if (!current()) return;
      _authorizedAddress = address.toLowerCase();
      state = AccountChangeState(expiresAt: expiresAt, lastEventAt: previousEvent);
      final remaining = expiresAt.difference(now);
      if (remaining <= Duration.zero) {
        _expire();
        return;
      }
      _renewal = Timer(
        remaining > const Duration(minutes: 10)
            ? remaining - const Duration(minutes: 10)
            : Duration.zero,
        () {
          if (current()) _replace(state.connection, renewalDue: true);
        },
      );
      _expiry = Timer(remaining, () {
        if (current()) _expire();
      });
      if (_active) {
        reconnect();
      } else {
        _replace(AccountChangeConnection.paused);
      }
    } catch (error) {
      if (!current()) return;
      state = AccountChangeState(
        lastEventAt: previousEvent,
        failure: error is AccountReadFailure
            ? error
            : const AccountReadFailure('accountReadFailed'),
      );
    }
  }

  /// Reuses only the still-valid in-memory lease. Never prompts a signature.
  void reconnect() {
    if (state.busy ||
        state.expiresAt == null ||
        state.connection == AccountChangeConnection.expired) {
      return;
    }
    if (!now.isBefore(state.expiresAt!)) {
      _expire();
      return;
    }
    if (!_active) return;
    _closeSocket();
    invalidateSnapshots();
    _replace(AccountChangeConnection.connecting);
    final generation = _socketGeneration;
    final address = _authorizedAddress;
    bool current() =>
        ref.mounted &&
        generation == _socketGeneration &&
        address != null &&
        address == ref.read(authProvider).identity?.walletAddress?.toLowerCase();
    _subscription = repository.connect().listen(
      (event) {
        if (!current()) return;
        if (event.expired) {
          _expire();
        } else if (event.connected) {
          _replace(AccountChangeConnection.connected);
        } else {
          invalidateSnapshots();
          try {
            applyEvent(address!, event);
          } on AccountReadFailure catch (failure) {
            _closeSocket();
            _replace(AccountChangeConnection.disconnected, failure: failure);
            return;
          }
          final time = event.time;
          _replace(
            state.connection,
            lastEventAt:
                time != null && (state.lastEventAt == null || time.isAfter(state.lastEventAt!))
                ? time
                : null,
          );
        }
      },
      onError: (Object error) {
        if (!current()) return;
        _closeSocket();
        invalidateSnapshots();
        _replace(
          AccountChangeConnection.disconnected,
          failure: error is AccountReadFailure ? error : const AccountReadFailure('accountNetwork'),
        );
      },
      onDone: () {
        if (!current() || state.connection == AccountChangeConnection.expired) return;
        invalidateSnapshots();
        _replace(AccountChangeConnection.disconnected, failure: state.failure);
      },
    );
  }

  void _replace(
    AccountChangeConnection connection, {
    DateTime? lastEventAt,
    bool? renewalDue,
    AccountReadFailure? failure,
  }) {
    state = AccountChangeState(
      connection: connection,
      step: state.step,
      expiresAt: state.expiresAt,
      lastEventAt: lastEventAt ?? state.lastEventAt,
      renewalDue: renewalDue ?? state.renewalDue,
      failure: failure,
    );
  }

  void _expire() {
    _closeSocket();
    _renewal?.cancel();
    _expiry?.cancel();
    repository.clear();
    invalidateSnapshots();
    _replace(AccountChangeConnection.expired, renewalDue: true);
  }

  void _closeSocket() {
    _socketGeneration++;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  void stop() {
    _authorizedAddress = null;
    _generation++;
    _closeSocket();
    _renewal?.cancel();
    _expiry?.cancel();
    repository.clear();
    invalidateSnapshots();
    state = const AccountChangeState();
  }
}
