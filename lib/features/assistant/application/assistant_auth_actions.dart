part of 'assistant_controller.dart';

extension AssistantAuthActions on AssistantController {
  Future<void> prepare() async {
    final identity = _readyIdentity();
    if (identity == null) return;
    _auth.cancel();
    final generation = _begin(AssistantPhase.preparing);
    try {
      final challenge = await _auth.prepare(
        identity,
        cancellation: _nextToken(),
        isCurrent: () => _current(generation),
      );
      if (!_current(generation)) return;
      _set(_view.copyWith(phase: AssistantPhase.review, challenge: challenge));
      _tick();
    } catch (error) {
      if (_alive(generation)) {
        _set(
          _view.copyWith(phase: AssistantPhase.idle, challenge: null, failureKey: _failure(error)),
        );
      }
    }
  }

  Future<void> confirm(AssistantChallenge challenge) async {
    if (_readyIdentity() == null || !identical(_view.challenge, challenge)) return;
    final generation = _begin(AssistantPhase.signing);
    _allowWalletBackground = true;
    try {
      final session = await _auth.confirm(
        challenge,
        cancellation: _nextToken(),
        isCurrent: () => _current(generation),
        awaitForeground: () async {
          if (!_alive(generation)) throw const AssistantFailure('assistantSessionChanged');
          if (!_view.active) {
            _foreground ??= Completer<void>();
            await _foreground!.future;
          }
          if (!_alive(generation)) throw const AssistantFailure('assistantSessionChanged');
          _allowWalletBackground = false;
          if (!_current(generation)) throw const AssistantFailure('assistantSessionChanged');
        },
      );
      if (!_alive(generation)) return;
      _allowWalletBackground = false;
      if (_current(generation)) await _adoptSession(session, generation);
    } catch (error) {
      if (_alive(generation)) {
        _allowWalletBackground = false;
        _set(
          _view.copyWith(phase: AssistantPhase.idle, challenge: null, failureKey: _failure(error)),
        );
      }
    }
  }

  Future<void> restore() async {
    if (_readyIdentity() == null) return;
    _auth.cancel();
    final generation = _begin(AssistantPhase.restoring);
    try {
      final session = await _auth.restore(
        _scope!,
        cancellation: _nextToken(),
        isCurrent: () => _current(generation),
      );
      if (!_current(generation)) return;
      if (session == null) {
        _set(
          _view.copyWith(
            phase: AssistantPhase.idle,
            challenge: null,
            failureKey: 'assistantNoSavedSession',
          ),
        );
      } else {
        await _adoptSession(session, generation);
      }
    } catch (error) {
      if (_alive(generation)) {
        _set(
          _view.copyWith(phase: AssistantPhase.idle, challenge: null, failureKey: _failure(error)),
        );
      }
    }
  }

  Future<void> _adoptSession(AssistantSession session, int generation) async {
    final keepMemory = _session?.userId == session.userId && _view.historyReady;
    final previous = _view, writer = _writer;
    _writer = null;
    writer?.schedule(_snapshot);
    await writer?.closeAndWait();
    if (!_current(generation)) return;
    _session = session;
    if (keepMemory) {
      _set(
        previous.copyWith(
          phase: AssistantPhase.idle,
          authenticated: true,
          challenge: null,
          failureKey: null,
        ),
      );
      _attachWriter(session);
      _writer?.schedule(_snapshot);
    } else {
      _set(
        _view.copyWith(
          phase: AssistantPhase.loadingHistory,
          authenticated: true,
          historyReady: false,
          messages: const [],
          draft: '',
          challenge: null,
          quota: null,
          quotaReadAt: null,
          quotaStale: true,
          scopeVersion: _view.scopeVersion + 1,
        ),
      );
      await _loadHistory(generation);
    }
  }

  Future<void> readUsage() async {
    if (_readyIdentity() == null || _session == null) return;
    final generation = _begin(AssistantPhase.readingUsage), userId = _session!.userId;
    try {
      final session = await _auth.restore(
        _scope!,
        cancellation: _nextToken(),
        isCurrent: () => _current(generation),
      );
      if (!_current(generation)) return;
      if (session == null || session.userId != userId) {
        throw const AssistantFailure('assistantAuthorization');
      }
      _session = session;
      final quota = await _auth.usage(
        session,
        cancellation: _nextToken(),
        isCurrent: () => _current(generation),
      );
      if (!_current(generation)) return;
      _set(
        _view.copyWith(
          phase: AssistantPhase.idle,
          quota: quota,
          quotaReadAt: _clock().toUtc(),
          quotaStale: false,
        ),
      );
      _tick();
    } catch (error) {
      if (_alive(generation)) {
        _set(
          _view.copyWith(phase: AssistantPhase.idle, quotaStale: true, failureKey: _failure(error)),
        );
      }
    }
  }
}
