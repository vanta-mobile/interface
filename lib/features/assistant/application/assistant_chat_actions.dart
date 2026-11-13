part of 'assistant_controller.dart';

extension AssistantChatActions on AssistantController {
  void stop() {
    _cancel();
    final messages = _view.messages.map(
      (m) => m.delivery == AssistantDelivery.streaming
          ? m.withReply(
              content: m.content,
              reasoning: m.reasoning,
              delivery: AssistantDelivery.interrupted,
            )
          : m,
    );
    _set(_view.copyWith(phase: AssistantPhase.idle, messages: messages, challenge: null));
    _writer?.schedule(_snapshot);
    _writer?.flush();
    if (_view.active) _tick();
  }

  /// Sends the draft, or a suggested [prompt] without replacing the draft.
  Future<void> send({String? prompt}) async {
    _tick();
    final text = (prompt ?? _view.draft).trim();
    final ready = prompt == null
        ? _view.canSend
        : _view.copyWith(draft: text).canSend && text.isNotEmpty;
    if (_readyIdentity() == null || !ready || _session == null) return;
    final now = _clock().toUtc();
    final history = <AssistantMessage>[
      ..._view.messages.skip((_view.messages.length - 198).clamp(0, _view.messages.length)),
      AssistantMessage(id: _id(), role: AssistantRole.user, content: text, createdAt: now),
    ];
    await _exchange(history: history, requestId: _id(), replyId: _id(), draft: prompt == null);
  }

  /// Retries the failed reply to the same question with its original request
  /// ID, replacing that reply instead of adding another question.
  Future<void> retry(String replyId) async {
    _tick();
    final index = _view.messages.indexWhere((m) => m.id == replyId);
    if (_readyIdentity() == null ||
        _session == null ||
        _view.phase != AssistantPhase.idle ||
        !_view.authenticated ||
        !_view.historyReady ||
        _view.limitReached ||
        index < 1 ||
        index != _view.messages.length - 1 ||
        _view.messages[index].delivery != AssistantDelivery.failed ||
        _view.messages[index - 1].role != AssistantRole.user) {
      return;
    }
    await _exchange(
      history: _view.messages.sublist(0, index),
      requestId: _requestIds[replyId] ?? _id(),
      replyId: replyId,
      draft: false,
    );
  }

  Future<void> _exchange({
    required List<AssistantMessage> history,
    required String requestId,
    required String replyId,
    required bool draft,
  }) async {
    final userId = _session!.userId, previous = _view.messages, prompt = history.last.content;
    final generation = _begin(AssistantPhase.restoring);
    _requestIds[replyId] = requestId;
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
      final pending = AssistantMessage(
        id: replyId,
        role: AssistantRole.assistant,
        content: '',
        createdAt: _clock().toUtc(),
        delivery: AssistantDelivery.streaming,
      );
      // Flush older coalesced draft data before staging this explicit turn.
      _writer?.invalidatePending();
      await _vault.saveHistory(
        session.scope,
        session.userId,
        AssistantHistory(messages: [...history, pending], draft: draft ? '' : _view.draft),
        isCurrent: () => _current(generation),
      );
      if (!_current(generation)) return;
      _set(
        _view.copyWith(
          phase: AssistantPhase.sending,
          quotaStale: true,
          draft: draft ? '' : null,
          messages: [...history, pending],
          storageFailureKey: null,
        ),
      );
      await for (final update in _chat.answer(
        accessToken: session.credentials.accessToken,
        userId: session.userId,
        requestId: requestId,
        history: history,
        cancellation: _nextToken(),
      )) {
        if (!_current(generation)) return;
        _set(
          _view.copyWith(
            messages: _view.messages.map(
              (m) => m.id == replyId
                  ? m.withReply(
                      content: update.content,
                      reasoning: update.reasoning,
                      delivery: update.delivery,
                    )
                  : m,
            ),
          ),
        );
        _writer?.schedule(_snapshot);
      }
      if (!_current(generation)) return;
      _requestIds.remove(replyId);
      _set(_view.copyWith(phase: AssistantPhase.idle));
      _writer?.schedule(_snapshot);
      _writer?.flush();
      await readUsage();
    } catch (error) {
      if (!_alive(generation)) return;
      final key = _failure(error), quota = error is AssistantFailure ? error.quota : null;
      final restoreDraft = draft && _view.draft.isEmpty;
      if (key == 'assistantQuotaExceeded') {
        // The question was refused before it reached the model: drop the
        // staged turn, keep the input, and show the daily-limit notice.
        final limit = quota?.limit ?? _view.dailyLimit;
        final now = _clock().toUtc();
        _requestIds.remove(replyId);
        _set(
          _view.copyWith(
            phase: AssistantPhase.idle,
            messages: previous,
            draft: restoreDraft ? prompt : null,
            dailyLimit: limit,
            quota: AssistantQuota(
              day: quota?.day ?? now.toIso8601String().substring(0, 10),
              used: quota?.used ?? limit,
              limit: limit,
              remaining: 0,
              resetAt: quota?.resetAt,
            ),
            quotaReadAt: now,
            quotaStale: false,
            limitReachedAt: now,
            failureKey: null,
          ),
        );
      } else {
        final expired = key == 'assistantAuthorization';
        _set(
          _view.copyWith(
            phase: AssistantPhase.idle,
            errorDetails: error is AssistantFailure ? error.details : null,
            failureKey: key,
            authenticated: expired ? false : null,
            sessionExpired: expired ? true : null,
            messages: _view.messages.map(
              (m) => m.id == replyId && m.delivery == AssistantDelivery.streaming
                  ? m.withReply(
                      content: m.content,
                      reasoning: m.reasoning,
                      delivery: AssistantDelivery.failed,
                    )
                  : m,
            ),
          ),
        );
      }
      _writer?.schedule(_snapshot);
      _writer?.flush();
      _tick();
    }
  }
}
