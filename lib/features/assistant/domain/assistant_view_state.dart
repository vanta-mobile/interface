import '../../../core/errors/api_error_details.dart';
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

/// The website's default daily allowance until the server reports its limit.
const assistantDefaultDailyLimit = 5;

/// Presentation state deliberately contains no access/refresh token.
class AssistantViewState {
  AssistantViewState({
    Iterable<AssistantMessage> messages = const [],
    this.phase = AssistantPhase.idle,
    this.active = true,
    this.authenticated = false,
    this.historyReady = false,
    this.sessionChecked = false,
    this.draft = '',
    this.scopeVersion = 0,
    this.challenge,
    this.quota,
    this.quotaReadAt,
    this.quotaStale = true,
    this.failureKey,
    this.errorDetails,
    this.storageFailureKey,
    this.sessionExpired = false,
    this.dailyLimit = assistantDefaultDailyLimit,
    this.limitReachedAt,
    this.authFailureKey,
    this.authErrorDetails,
  }) : messages = List.unmodifiable(messages);
  final List<AssistantMessage> messages;
  final AssistantPhase phase;
  final bool active, authenticated, historyReady, quotaStale;

  /// Entry has looked for this wallet's stored AI session; until then the
  /// page cannot tell whether to show the conversation or authentication.
  final bool sessionChecked;
  final String draft;
  final int scopeVersion;
  final AssistantChallenge? challenge;
  final AssistantQuota? quota;
  final DateTime? quotaReadAt;
  final ApiErrorDetails? errorDetails;
  final String? failureKey, storageFailureKey;

  /// A stored or active AI session was rejected and must be authenticated again.
  final bool sessionExpired;
  final int dailyLimit;

  /// When the server last refused a request because today's quota was used.
  final DateTime? limitReachedAt;

  /// The latest wallet-authentication failure, kept apart from chat errors.
  final String? authFailureKey;
  final ApiErrorDetails? authErrorDetails;
  int? get remaining {
    final quota = this.quota;
    if (quota == null) return null;
    final limit = quota.limit ?? dailyLimit;
    return quota.remaining ?? (quota.used == null ? null : (limit - quota.used!).clamp(0, limit));
  }

  bool get limitReached => remaining == 0;
  bool get busy => phase != AssistantPhase.idle && phase != AssistantPhase.review;
  bool get canSend =>
      active &&
      authenticated &&
      historyReady &&
      phase == AssistantPhase.idle &&
      draft.trim().isNotEmpty &&
      draft.length <= 12000 &&
      !limitReached;
  AssistantViewState copyWith({
    Iterable<AssistantMessage>? messages,
    AssistantPhase? phase,
    bool? active,
    bool? authenticated,
    bool? historyReady,
    bool? sessionChecked,
    String? draft,
    int? scopeVersion,
    Object? challenge = _keep,
    Object? quota = _keep,
    Object? quotaReadAt = _keep,
    bool? quotaStale,
    Object? failureKey = _keep,
    Object? errorDetails = _keep,
    Object? storageFailureKey = _keep,
    bool? sessionExpired,
    int? dailyLimit,
    Object? limitReachedAt = _keep,
    Object? authFailureKey = _keep,
    Object? authErrorDetails = _keep,
  }) => AssistantViewState(
    messages: messages ?? this.messages,
    phase: phase ?? this.phase,
    active: active ?? this.active,
    authenticated: authenticated ?? this.authenticated,
    historyReady: historyReady ?? this.historyReady,
    sessionChecked: sessionChecked ?? this.sessionChecked,
    draft: draft ?? this.draft,
    scopeVersion: scopeVersion ?? this.scopeVersion,
    challenge: identical(challenge, _keep) ? this.challenge : challenge as AssistantChallenge?,
    quota: identical(quota, _keep) ? this.quota : quota as AssistantQuota?,
    quotaReadAt: identical(quotaReadAt, _keep) ? this.quotaReadAt : quotaReadAt as DateTime?,
    quotaStale: quotaStale ?? this.quotaStale,
    failureKey: identical(failureKey, _keep) ? this.failureKey : failureKey as String?,
    errorDetails: identical(errorDetails, _keep)
        ? (identical(failureKey, _keep) ? this.errorDetails : null)
        : errorDetails as ApiErrorDetails?,
    storageFailureKey: identical(storageFailureKey, _keep)
        ? this.storageFailureKey
        : storageFailureKey as String?,
    sessionExpired: sessionExpired ?? this.sessionExpired,
    dailyLimit: dailyLimit ?? this.dailyLimit,
    limitReachedAt: identical(limitReachedAt, _keep)
        ? this.limitReachedAt
        : limitReachedAt as DateTime?,
    authFailureKey: identical(authFailureKey, _keep)
        ? this.authFailureKey
        : authFailureKey as String?,
    authErrorDetails: identical(authErrorDetails, _keep)
        ? (identical(authFailureKey, _keep) ? this.authErrorDetails : null)
        : authErrorDetails as ApiErrorDetails?,
  );
}
