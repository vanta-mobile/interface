import '../../../core/errors/api_error_parser.dart';
import '../../../core/network/request_scope.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_message_signer.dart';
import '../../market/data/market_http_client.dart';
import '../domain/event_registration.dart';
import '../domain/points.dart';

class VantaEventRegistrationRepository implements EventRegistrationRepository {
  VantaEventRegistrationRepository({
    required this.points,
    required this.signer,
    http.Client? client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 12),
  }) : _client = createMarketHttpClient(client: client, timeout: timeout),
       now = now ?? DateTime.now;
  final PointsRepository points;
  final WalletMessageSigner Function() signer;
  final http.Client _client;
  final DateTime Function() now;
  final Duration timeout;
  void close() => _client.close();
  @override
  Future<EventRegistrationPhase> register(
    EventRegistrationApproval approval, {
    required bool Function() isCurrent,
    required void Function(EventRegistrationPhase) onStep,
  }) => RequestScope.run(isCurrent, () async {
    final id = approval.event.id, address = approval.identity.walletAddress;
    if (address == null || !isPointsEvmAddress(address) || !approval.identity.signingAvailable) {
      throw const EventRegistrationFailure('pointsWalletRequired');
    }
    Future<bool> check() async {
      if (!isCurrent()) throw const EventRegistrationFailure('eventRegistrationChanged');
      onStep(EventRegistrationPhase.checking);
      final event = (await points.event(id)).value;
      if (!isCurrent()) throw const EventRegistrationFailure('eventRegistrationChanged');
      final participant = (await points.eventParticipant(id, address)).value;
      if (!isCurrent() ||
          event.id != id ||
          participant.eventId != id ||
          pointsAddressKey(participant.address) != pointsAddressKey(address)) {
        throw const EventRegistrationFailure('eventRegistrationChanged');
      }
      if (participant.registered) return true;
      if (!event.canRegister(now().toUtc()) ||
          participant.blockReason != null ||
          registrationTerms(event) != approval.terms) {
        throw const EventRegistrationFailure('eventRegistrationChanged');
      }
      return false;
    }

    if (await check()) return EventRegistrationPhase.verified;
    final timestamp = now().toUtc().millisecondsSinceEpoch;
    final message =
        'Vanta Trading Event Registration\nEvent ID: $id\nAddress: ${address.toLowerCase()}\nTimestamp: $timestamp';
    onStep(EventRegistrationPhase.signing);
    final signature = await signer().signPersonalMessage(
      expectedAddress: address,
      message: message,
    );
    if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) {
      throw const AuthFailure('authWalletSignature');
    }
    if (await check()) return EventRegistrationPhase.verified;
    final age = now().toUtc().millisecondsSinceEpoch - timestamp;
    // Local freshness policy; the public frontend does not specify a server TTL.
    if (!isCurrent() || age < 0 || age > 120000) {
      throw const EventRegistrationFailure('eventRegistrationChanged');
    }
    onStep(EventRegistrationPhase.sending);
    if (!isCurrent()) throw const EventRegistrationFailure('eventRegistrationChanged');
    try {
      final request =
          http.Request('POST', Uri.https('api.vanta.exchange', '/api/trading-events/$id/register'))
            ..followRedirects = false
            ..headers.addAll({'Accept': 'application/json', 'Content-Type': 'application/json'})
            ..body = jsonEncode({
              'address': address.toLowerCase(),
              'timestamp': timestamp,
              'signature': signature,
            });
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw EventRegistrationFailure(
          'eventRegistrationUnknown',
          mayHaveSent: true,
          details: apiErrorDetails(decodeErrorPayload(response.body), status: response.statusCode),
        );
      }
    } on EventRegistrationFailure {
      rethrow;
    } catch (_) {
      throw const EventRegistrationFailure('eventRegistrationUnknown', mayHaveSent: true);
    }
    // A successful POST is an acknowledgement, not proof of registration/reward.
    if (!isCurrent()) return EventRegistrationPhase.acknowledged;
    try {
      final participant = (await points.eventParticipant(id, address)).value;
      if (isCurrent() &&
          participant.eventId == id &&
          pointsAddressKey(participant.address) == pointsAddressKey(address) &&
          participant.registered) {
        return EventRegistrationPhase.verified;
      }
    } catch (_) {
      /* Keep acknowledgement separate from verification. */
    }
    return EventRegistrationPhase.acknowledged;
  });
}
