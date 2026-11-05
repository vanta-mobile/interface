import 'assistant.dart';
import 'assistant_session.dart';

enum AssistantPhase {
  idle,
  preparing,
  review,
  signing,
  restoring,
  loadingHistory,
  sending,
  readingUsage,
  clearing,
}

const _keep = Object();

/// Presentation state deliberately contains no access/refresh token.
class AssistantViewState {
  AssistantViewState({
    Iterable<AssistantMessage> messages = const [],
    this.phase = AssistantPhase.idle,
    this.active = true,
    this.authenticated = false,
    this.historyReady = false,
    this.draft = '',
    this.scopeVersion = 0,
    this.challenge,
    this.quota,
    this.quotaReadAt,
    this.quotaStale = true,
    this.failureKey,
    this.storageFailureKey,
  }) : messages = List.unmodifiable(messages);
  final List<AssistantMessage> messages;
  final AssistantPhase phase;
  final bool active, authenticated, historyReady, quotaStale;
  final String draft;
  final int scopeVersion;
  final AssistantChallenge? challenge;
  final AssistantQuota? quota;
  final DateTime? quotaReadAt;
  final String? failureKey, storageFailureKey;
  bool get busy => phase != AssistantPhase.idle && phase != AssistantPhase.review;
  bool get canSend =>
      active &&
      authenticated &&
      historyReady &&
      phase == AssistantPhase.idle &&
      draft.trim().isNotEmpty &&
      draft.length <= 12000 &&
      !(quota?.remaining == 0 && !quotaStale);
  AssistantViewState copyWith({
    Iterable<AssistantMessage>? messages,
    AssistantPhase? phase,
    bool? active,
    bool? authenticated,
    bool? historyReady,
    String? draft,
    int? scopeVersion,
    Object? challenge = _keep,
    Object? quota = _keep,
    Object? quotaReadAt = _keep,
    bool? quotaStale,
    Object? failureKey = _keep,
    Object? storageFailureKey = _keep,
  }) => AssistantViewState(
    messages: messages ?? this.messages,
    phase: phase ?? this.phase,
    active: active ?? this.active,
    authenticated: authenticated ?? this.authenticated,
    historyReady: historyReady ?? this.historyReady,
    draft: draft ?? this.draft,
    scopeVersion: scopeVersion ?? this.scopeVersion,
    challenge: identical(challenge, _keep) ? this.challenge : challenge as AssistantChallenge?,
    quota: identical(quota, _keep) ? this.quota : quota as AssistantQuota?,
    quotaReadAt: identical(quotaReadAt, _keep) ? this.quotaReadAt : quotaReadAt as DateTime?,
    quotaStale: quotaStale ?? this.quotaStale,
    failureKey: identical(failureKey, _keep) ? this.failureKey : failureKey as String?,
    storageFailureKey: identical(storageFailureKey, _keep)
        ? this.storageFailureKey
        : storageFailureKey as String?,
  );
}
