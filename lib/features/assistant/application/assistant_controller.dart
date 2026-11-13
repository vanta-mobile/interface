import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../market/application/market_providers.dart';
import '../data/assistant_auth_repository.dart';
import '../data/assistant_chat_repository.dart';
import '../data/assistant_vault.dart';
import '../domain/assistant.dart';
import '../domain/assistant_history.dart';
import '../domain/assistant_session.dart';
import '../domain/assistant_view_state.dart';
import 'assistant_dependencies.dart';
import 'assistant_history_writer.dart';

part 'assistant_auth_actions.dart';
part 'assistant_chat_actions.dart';

class AssistantController extends Notifier<AssistantViewState> {
  late AssistantAuthRepository _auth;
  late AssistantChatRepository _chat;
  late AssistantVault _vault;
  late DateTime Function() _clock;
  late String Function() _id;
  AssistantSession? _session;
  AssistantWalletScope? _scope;
  AssistantHistoryWriter? _writer;
  AssistantHistory _snapshot = AssistantHistory();
  AssistantCancellation? _token;
  // Request IDs of failed replies in this session; a retry reuses the original.
  final _requestIds = <String, String>{};
  Completer<void>? _foreground;
  Timer? _tickTimer;
  int _generation = 0;

  /// Advances when the wallet identity changes and the state is reset.
  int _identityEpoch = 0;
  bool _allowWalletBackground = false;
  AssistantViewState get _view => state;
  bool get _mounted => ref.mounted;
  AuthIdentity? get _identity => ref.read(authProvider).identity;
  @override
  AssistantViewState build() {
    _auth = ref.watch(assistantAuthRepositoryProvider);
    _chat = ref.watch(assistantChatRepositoryProvider);
    _vault = ref.watch(assistantVaultProvider);
    _clock = ref.watch(assistantClockProvider);
    _id = ref.watch(assistantIdProvider);
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress?.toLowerCase(),
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (_, _) {
        _cancel();
        _closeWriter();
        _identityEpoch++;
        _requestIds.clear();
        _session = null;
        _scope = null;
        _snapshot = AssistantHistory();
        _set(
          AssistantViewState(
            active: ref.read(quoteUpdatesActiveProvider),
            scopeVersion: state.scopeVersion + 1,
          ),
        );
      },
    );
    ref.listen(quoteUpdatesActiveProvider, (_, active) {
      _set(_view.copyWith(active: active));
      if (active) {
        if (_foreground?.isCompleted == false) _foreground!.complete();
        _foreground = null;
        _tick();
      } else {
        _tickTimer?.cancel();
        if (!(_view.phase == AssistantPhase.signing && _allowWalletBackground)) stop();
      }
    });
    ref.onDispose(() {
      _cancel();
      _closeWriter();
    });
    return AssistantViewState(active: ref.read(quoteUpdatesActiveProvider));
  }

  void _set(AssistantViewState value) {
    state = value;
    if (value.authenticated && value.historyReady) {
      _snapshot = AssistantHistory(messages: value.messages, draft: value.draft);
    }
  }

  bool _alive(int generation) =>
      ref.mounted && generation == _generation && (_scope?.matches(_identity) ?? false);
  bool _current(int generation) => _alive(generation) && (_view.active || _allowWalletBackground);
  void _cancel() {
    _generation++;
    _token?.cancel();
    _token = null;
    _auth.cancel();
    _allowWalletBackground = false;
    _tickTimer?.cancel();
    if (_foreground?.isCompleted == false) _foreground!.complete();
    _foreground = null;
  }

  int _begin(AssistantPhase phase) {
    _token?.cancel();
    _token = null;
    final generation = ++_generation;
    _set(_view.copyWith(phase: phase, failureKey: null));
    return generation;
  }

  AssistantCancellation _nextToken() => _token = AssistantCancellation();
  AuthIdentity? _readyIdentity() {
    if (!_view.active || _view.busy) return null;
    final identity = _identity;
    try {
      if (identity == null) throw const AssistantFailure('assistantWalletRequired');
      _scope = AssistantWalletScope.fromIdentity(identity);
      return identity;
    } catch (_) {
      _set(_view.copyWith(failureKey: 'assistantWalletRequired'));
      return null;
    }
  }

  String _failure(Object error) => switch (error) {
    AuthFailure(:final key) => key,
    AssistantFailure(:final key) => key,
    _ => 'assistantUnavailable',
  };
  void _closeWriter() {
    _writer?.schedule(_snapshot);
    _writer?.close();
    _writer = null;
  }

  void _attachWriter(AssistantSession session) {
    _writer?.close();
    _writer = AssistantHistoryWriter(_vault, session, (key) {
      if (ref.mounted && _session?.userId == session.userId && session.scope.matches(_identity)) {
        _set(_view.copyWith(storageFailureKey: key));
      }
    });
  }

  void setDraft(String value) {
    if (!_view.authenticated ||
        !_view.historyReady ||
        (_view.phase != AssistantPhase.idle && _view.phase != AssistantPhase.sending)) {
      return;
    }
    _set(
      _view.copyWith(
        draft: value,
        failureKey: value.length > 12000 ? 'assistantInvalidInput' : null,
      ),
    );
    _writer?.schedule(_snapshot);
  }

  void retrySave() {
    _writer?.schedule(_snapshot);
    _writer?.flush();
  }

  void _tick() {
    _tickTimer?.cancel();
    if (!ref.mounted || !_view.active) return;
    final now = _clock().toUtc();
    final day = now.toIso8601String().substring(0, 10);
    if (_view.phase == AssistantPhase.review && _view.challenge?.freshAt(now) == false) {
      _auth.cancel();
      _set(
        _view.copyWith(
          phase: AssistantPhase.idle,
          challenge: null,
          failureKey: 'assistantChallengeExpired',
        ),
      );
    }
    final received = _view.quotaReadAt;
    if (_view.quota != null && _view.quota!.day != day) {
      // A new UTC day resets the allowance; never keep yesterday's limit.
      _set(_view.copyWith(quota: null, quotaReadAt: null, quotaStale: true, limitReachedAt: null));
    } else if (_view.quota != null &&
        (received == null ||
            now.isBefore(received) ||
            now.difference(received) >= const Duration(minutes: 5))) {
      _set(_view.copyWith(quotaStale: true));
    }
    if (_view.quota != null || _view.challenge != null) {
      final midnight = DateTime.utc(now.year, now.month, now.day + 1).difference(now);
      _tickTimer = Timer(
        midnight < const Duration(seconds: 30) ? midnight : const Duration(seconds: 30),
        _tick,
      );
    }
  }

  Future<void> _loadHistory(int generation) async {
    final session = _session!;
    try {
      final history = await _vault.history(session.scope, session.userId);
      if (!_current(generation)) return;
      _set(
        _view.copyWith(
          phase: AssistantPhase.idle,
          messages: history.messages,
          draft: history.draft,
          historyReady: true,
          storageFailureKey: null,
        ),
      );
      _attachWriter(session);
    } catch (error) {
      if (_alive(generation)) {
        _set(
          _view.copyWith(
            phase: AssistantPhase.idle,
            historyReady: false,
            storageFailureKey: _failure(error),
          ),
        );
      }
    }
  }

  Future<void> retryHistory() async {
    if (_readyIdentity() == null || _session == null) return;
    await _loadHistory(_begin(AssistantPhase.loadingHistory));
  }

  Future<void> clearHistory(int scopeVersion) async {
    if (_readyIdentity() == null || _session == null || scopeVersion != _view.scopeVersion) return;
    final previous = _view, session = _session!;
    final generation = _begin(AssistantPhase.clearing);
    _writer?.invalidatePending();
    _snapshot = AssistantHistory();
    _set(_view.copyWith(messages: const [], draft: '', historyReady: false));
    try {
      await _vault.clearHistory(session.scope, session.userId);
      if (!_current(generation)) return;
      _snapshot = AssistantHistory();
      _set(
        _view.copyWith(
          messages: const [],
          draft: '',
          historyReady: true,
          phase: AssistantPhase.idle,
          storageFailureKey: null,
          failureKey: null,
        ),
      );
      _attachWriter(session);
    } catch (_) {
      if (_alive(generation)) {
        _set(previous.copyWith(phase: AssistantPhase.idle, failureKey: 'assistantClearFailed'));
      }
    }
  }

  Future<void> forgetSession(int scopeVersion) async {
    if (_readyIdentity() == null || _scope == null || scopeVersion != _view.scopeVersion) return;
    final generation = _begin(AssistantPhase.clearing), scope = _scope!;
    _auth.cancel();
    _closeWriter();
    try {
      await _vault.forgetCredentials(scope);
      if (!_current(generation)) return;
      _session = null;
      _snapshot = AssistantHistory();
      _set(
        AssistantViewState(
          active: _view.active,
          sessionChecked: true,
          scopeVersion: scopeVersion + 1,
        ),
      );
    } catch (error) {
      if (_alive(generation)) {
        _set(
          _view.copyWith(
            phase: AssistantPhase.idle,
            errorDetails: error is AssistantFailure ? error.details : null,
            failureKey: _failure(error),
          ),
        );
        if (_session != null && _view.historyReady) _attachWriter(_session!);
      }
    }
  }

  Future<void> openLink(String? href) async {
    final uri = href == null || href.length > 2048 ? null : Uri.tryParse(href);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      _set(_view.copyWith(failureKey: 'assistantLinkUnavailable'));
      return;
    }
    final version = _view.scopeVersion;
    try {
      if (!await ref.read(assistantLinkOpenerProvider)(uri) &&
          ref.mounted &&
          version == _view.scopeVersion) {
        _set(_view.copyWith(failureKey: 'assistantLinkUnavailable'));
      }
    } catch (_) {
      if (ref.mounted && version == _view.scopeVersion) {
        _set(_view.copyWith(failureKey: 'assistantLinkUnavailable'));
      }
    }
  }
}
