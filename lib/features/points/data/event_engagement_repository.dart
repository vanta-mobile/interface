import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_message_signer.dart';
import '../../market/data/market_http_client.dart';
import '../domain/event_engagement.dart';
import '../domain/event_registration.dart';
import '../domain/points.dart';
import 'event_engagement_journal.dart';

class VantaEventEngagementRepository implements EventEngagementRepository {
  VantaEventEngagementRepository({
    required this.points,
    required this.signer,
    required this.journal,
    http.Client? client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? createMarketHttpClient(),
       now = now ?? DateTime.now;
  final PointsRepository points;
  final WalletMessageSigner Function() signer;
  final EventEngagementJournal journal;
  final http.Client _client;
  final DateTime Function() now;
  final Duration timeout;
  bool _busy = false, _closed = false;
  Completer<void>? _abort;
  void close() {
    _closed = true;
    if (_abort?.isCompleted == false) _abort!.complete();
    _client.close();
  }

  @override
  Future<EventRegistrationPhase> submit(
    EventEngagementApproval approval, {
    required bool Function() isCurrent,
    required void Function(EventRegistrationPhase) onStep,
  }) async {
    if (_busy || _closed) throw const EventRegistrationFailure('eventEngagementBusy');
    _busy = true;
    try {
      return await _submit(approval, isCurrent: isCurrent, onStep: onStep);
    } finally {
      _busy = false;
    }
  }

  Future<EventRegistrationPhase> _submit(
    EventEngagementApproval approval, {
    required bool Function() isCurrent,
    required void Function(EventRegistrationPhase) onStep,
  }) async {
    final address = approval.identity.walletAddress, id = approval.event.id;
    if (address == null || !isPointsEvmAddress(address) || !approval.identity.signingAvailable) {
      throw const AuthFailure('authWalletReconnect');
    }
    int? signedAt;
    void guard() {
      final time = now().toUtc(),
          age = signedAt == null ? null : now().toUtc().millisecondsSinceEpoch - signedAt;
      if (_closed ||
          !isCurrent() ||
          !approval.event.activeAt(time) ||
          eventUtcDay(time) != approval.day ||
          (age != null && (age < 0 || age > 120000))) {
        throw const EventRegistrationFailure('eventRegistrationChanged');
      }
    }

    guard();
    List<PendingEventEngagement> pending;
    try {
      pending = await journal.read();
    } catch (_) {
      throw const EventRegistrationFailure('eventEngagementStorage');
    }
    guard();
    if (pending.any((e) => e.eventId == id && e.address.toLowerCase() == address.toLowerCase())) {
      throw const EventRegistrationFailure('eventEngagementUnknown', mayHaveSent: true);
    }
    Future<bool> check() async {
      guard();
      onStep(EventRegistrationPhase.checking);
      final event = await points.event(id);
      guard();
      final participant = await points.eventParticipant(id, address);
      guard();
      final progress = await points.eventTaskProgress(id, address);
      guard();
      final time = now().toUtc();
      if ([event.receivedAt, participant.receivedAt, progress.receivedAt].any(
            (t) =>
                t.isAfter(time.add(const Duration(seconds: 30))) ||
                !time.isBefore(t.add(const Duration(minutes: 5))),
          ) ||
          event.value.id != id ||
          participant.value.eventId != id ||
          progress.value.eventId != id ||
          pointsAddressKey(participant.value.address) != address.toLowerCase() ||
          pointsAddressKey(progress.value.address) != address.toLowerCase() ||
          registrationTerms(event.value) != approval.terms) {
        throw const EventRegistrationFailure('eventRegistrationChanged');
      }
      if (engagementCompleted(progress.value, approval.action, approval.day)) return true;
      if (!engagementEligible(
        event.value,
        participant.value,
        progress.value,
        approval.action,
        time,
      )) {
        throw const EventRegistrationFailure('eventEngagementIneligible');
      }
      return false;
    }

    if (await check()) return EventRegistrationPhase.verified;
    final timestamp = now().toUtc().millisecondsSinceEpoch;
    signedAt = timestamp;
    final message = [
      approval.action == EventEngagementAction.checkIn
          ? 'Vanta Trading Event Check-In'
          : 'Vanta Trading Event Wallet Connect',
      'Event ID: $id',
      'Address: ${address.toLowerCase()}',
      if (approval.action == EventEngagementAction.checkIn) 'Date: ${approval.day}',
      'Timestamp: $timestamp',
    ].join('\n');
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
    if (age < 0 || age > 120000) throw const EventRegistrationFailure('eventRegistrationChanged');
    guard();
    final entry = PendingEventEngagement(
      eventId: id,
      address: address.toLowerCase(),
      action: approval.action,
      day: approval.day,
    );
    try {
      await journal.add(entry);
    } catch (_) {
      throw const EventRegistrationFailure('eventEngagementStorage');
    }
    // Once written, keep the intent even if scope changes or transport never
    // returns. Reconcile only authoritative completion; never automatically retry.
    try {
      guard();
    } on EventRegistrationFailure {
      try {
        await journal.remove(entry.key);
      } catch (_) {
        throw const EventRegistrationFailure('eventEngagementUnknown', mayHaveSent: true);
      }
      rethrow;
    }
    onStep(EventRegistrationPhase.sending);
    final abort = Completer<void>();
    _abort = abort;
    try {
      guard();
      final request =
          http.AbortableRequest(
              'POST',
              Uri.https('api.vanta.exchange', '/api/trading-events/$id/${approval.action.path}'),
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers.addAll({'Accept': 'application/json', 'Content-Type': 'application/json'})
            ..body = jsonEncode({
              'address': address.toLowerCase(),
              'timestamp': timestamp,
              'signature': signature,
            });
      final status =
          await (() async {
            final response = await _client.send(request);
            await response.stream.listen(null).cancel();
            return response.statusCode;
          })().timeout(
            timeout,
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw const EventRegistrationFailure('eventEngagementUnknown', mayHaveSent: true);
            },
          );
      if (status < 200 || status >= 300) {
        throw const EventRegistrationFailure('eventEngagementUnknown', mayHaveSent: true);
      }
    } catch (_) {
      throw const EventRegistrationFailure('eventEngagementUnknown', mayHaveSent: true);
    } finally {
      _abort = null;
    }
    if (!isCurrent() || _closed) return EventRegistrationPhase.acknowledged;
    try {
      if (await reconcile(eventId: id, address: address)) return EventRegistrationPhase.verified;
    } catch (_) {}
    return EventRegistrationPhase.acknowledged;
  }

  @override
  Future<bool> reconcile({required int eventId, required String address}) async {
    if (_closed || !isPointsEvmAddress(address)) {
      throw const EventRegistrationFailure('eventRegistrationChanged');
    }
    final entries = (await journal.read())
        .where((e) => e.eventId == eventId && e.address.toLowerCase() == address.toLowerCase())
        .toList();
    if (entries.isEmpty) return true;
    final progress = await points.eventTaskProgress(eventId, address), time = now().toUtc();
    if (progress.value.eventId != eventId ||
        progress.value.address.toLowerCase() != address.toLowerCase() ||
        progress.receivedAt.isAfter(time.add(const Duration(seconds: 30))) ||
        !time.isBefore(progress.receivedAt.add(const Duration(minutes: 5)))) {
      throw const PointsFailure('pointsDataInvalid');
    }
    for (final entry in entries) {
      final complete = entry.action == EventEngagementAction.walletConnect
          ? progress.value.newUser?.walletCompleted == true
          : progress.value.daily?.dates.contains(entry.day) == true;
      if (!complete) return false;
      await journal.remove(entry.key);
    }
    return true;
  }
}
