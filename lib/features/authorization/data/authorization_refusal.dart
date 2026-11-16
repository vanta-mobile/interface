import '../../portfolio/domain/account_snapshot.dart';

/// An explicit API refusal, classified by HTTP/envelope data, never display text.
/// Timeout/unknown exchange codes remain pending even with a 4xx HTTP status.
bool authorizationWasRefused(AccountReadFailure failure) =>
    {400, 401, 403}.contains(failure.details?.status) &&
    (failure.code != null && failure.code! < 0 ||
        failure.code == null && failure.details?.message != null) &&
    !{-1000, -1001, -1006, -1007}.contains(failure.code);
