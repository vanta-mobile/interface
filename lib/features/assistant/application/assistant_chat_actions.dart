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

  Future<void> send() async {
    _tick();
    if (_readyIdentity() == null || !_view.canSend || _session == null) return;
    final prompt = _view.draft, userId = _session!.userId;
    final generation = _begin(AssistantPhase.restoring);
    String? replyId;
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
      final requestId = _id(), userMessageId = _id();
      replyId = _id();
      final now = _clock().toUtc();
      final history = <AssistantMessage>[
        ..._view.messages.skip((_view.messages.length - 198).clamp(0, _view.messages.length)),
        AssistantMessage(
          id: userMessageId,
          role: AssistantRole.user,
          content: prompt.trim(),
          createdAt: now,
        ),
      ];
      final pending = AssistantMessage(
        id: replyId,
        role: AssistantRole.assistant,
        content: '',
        createdAt: now,
        delivery: AssistantDelivery.streaming,
      );
      // Flush older coalesced draft data before staging this explicit turn.
      _writer?.invalidatePending();
      await _vault.saveHistory(
        session.scope,
        session.userId,
        AssistantHistory(messages: [...history, pending]),
        isCurrent: () => _current(generation),
      );
      if (!_current(generation)) return;
      _set(
        _view.copyWith(
          phase: AssistantPhase.sending,
          quotaStale: true,
          draft: '',
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
      _set(_view.copyWith(phase: AssistantPhase.idle));
      _writer?.schedule(_snapshot);
      _writer?.flush();
    } catch (error) {
      if (!_alive(generation)) return;
      final quota = error is AssistantFailure ? error.quota : null;
      _set(
        _view.copyWith(
          phase: AssistantPhase.idle,
          errorDetails: error is AssistantFailure ? error.details : null,
          failureKey: _failure(error),
          draft: _view.draft.isEmpty ? prompt : _view.draft,
          messages: _view.messages.map(
            (m) => m.id == replyId && m.delivery == AssistantDelivery.streaming
                ? m.withReply(
                    content: m.content,
                    reasoning: m.reasoning,
                    delivery: AssistantDelivery.failed,
                  )
                : m,
          ),
          quota: quota ?? _view.quota,
          quotaReadAt: quota == null ? _view.quotaReadAt : _clock().toUtc(),
          quotaStale: quota == null ? _view.quotaStale : false,
        ),
      );
      _writer?.schedule(_snapshot);
      _writer?.flush();
      _tick();
    }
  }
}
