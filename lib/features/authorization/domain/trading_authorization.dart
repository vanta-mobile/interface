import '../../../core/errors/api_error_details.dart';

import 'dart:io';

import '../../auth/domain/auth_session.dart';

/// A server acknowledgement and an accepted signed read are different facts.
class TradingAuthorizationCheck {
  const TradingAuthorizationCheck({
    required this.address,
    required this.checkedAt,
    required this.futuresReadAccepted,
    required this.spotReadAccepted,
    this.futuresCanTrade,
    this.futuresCanWithdraw,
    this.futuresFailure,
    this.spotFailure,
    this.builderReady,
    this.builderFailure,
    this.builderErrorDetails,
    this.agentReady,
    this.agentFailure,
    this.agentErrorDetails,
    this.futuresErrorDetails,
    this.spotErrorDetails,
  });
  final String address;
  final DateTime checkedAt;
  final bool futuresReadAccepted, spotReadAccepted;
  final bool? futuresCanTrade, futuresCanWithdraw;
  final String? futuresFailure, spotFailure;
  final bool? builderReady;
  final String? builderFailure;
  final ApiErrorDetails? builderErrorDetails;
  final bool? agentReady;
  final String? agentFailure;
  final ApiErrorDetails? agentErrorDetails, futuresErrorDetails, spotErrorDetails;

  bool get canResumeBuilder =>
      agentReady == true && agentFailure == null && builderReady == false && builderFailure == null;
}

class TradingAuthorizationReview {
  const TradingAuthorizationReview({
    required this.identity,
    required this.expiresAt,
    required this.preparedAt,
    this.canWithdraw = false,
    this.ipWhitelist = '',
  });
  final AuthIdentity identity;
  final DateTime expiresAt, preparedAt;
  final bool canWithdraw;
  final String ipWhitelist;
}

enum TradingAuthorizationResult { acknowledged, unknown }

/// Request lifecycle, independent of presentation copy and recovery journals.
enum TradingAuthorizationStep { preparing, signing, submitting, confirming }

abstract interface class TradingAuthorizationRepository {
  Future<TradingAuthorizationResult> enable({
    required TradingAuthorizationReview review,
    required bool Function() isCurrent,
    void Function(TradingAuthorizationStep)? onStep,
    bool retryPendingBuilder = false,
  });
  Future<TradingAuthorizationCheck> check({
    required String address,
    required bool Function() isCurrent,
    String? identityId,
  });
}

class TradingAuthorizationState {
  const TradingAuthorizationState({
    this.busy = false,
    this.review,
    this.result,
    this.check,
    this.failure,
    this.errorDetails,
    this.builderAuthorized = false,
    this.step,
  });
  final bool busy;
  final TradingAuthorizationReview? review;
  final TradingAuthorizationResult? result;
  final TradingAuthorizationCheck? check;
  final ApiErrorDetails? errorDetails;
  final String? failure;
  final bool builderAuthorized;
  final TradingAuthorizationStep? step;
}

/// Normalize only documented literal IP/CIDR entries. No hostnames, URLs,
/// ports, zone IDs, wildcards or DNS lookups are accepted.
String? normalizeAgentIpWhitelist(String input) {
  if (input.length > 1024 || input.trim().isEmpty) return null;
  final entries = input.trim().split(RegExp(r'\s+'));
  if (entries.length > 16 || entries.toSet().length != entries.length) return null;
  for (final entry in entries) {
    if (entry.contains('%')) return null;
    final parts = entry.split('/');
    if (parts.length > 2) return null;
    final address = InternetAddress.tryParse(parts[0]);
    if (address == null) return null;
    if (parts.length == 2) {
      final prefix = int.tryParse(parts[1]),
          limit = address.type == InternetAddressType.IPv4 ? 32 : 128;
      if (prefix == null ||
          !RegExp(r'^(0|[1-9]\d*)$').hasMatch(parts[1]) ||
          prefix < 0 ||
          prefix > limit) {
        return null;
      }
    }
  }
  return entries.join(' ');
}
