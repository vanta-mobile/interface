import '../../../core/errors/api_error_parser.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/exact_json.dart';
import '../../market/data/market_http_client.dart';
import '../../portfolio/data/aster_read_service.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/points.dart';
import '../domain/trading_event.dart';
import '../domain/event_engagement.dart';
import 'event_engagement_mapper.dart';
import 'points_mapper.dart';
import 'trading_event_mapper.dart';

/// Public runtime configuration and request wrapper on app.vanta.exchange
/// specify this origin and /api prefix. Never carries Aster/Privy credentials.
class PointsService extends AsterReadService {
  PointsService({http.Client? client, Duration timeout = const Duration(seconds: 12)})
    : this._(createMarketHttpClient(client: client, timeout: timeout), timeout);
  PointsService._(http.Client client, Duration timeout)
    : _taskClient = client,
      super(
        client: client,
        timeout: timeout,
        origin: Uri.https('api.vanta.exchange'),
        decodeResponse: decodeFundingJson,
      );
  final http.Client _taskClient;
  final _taskAborts = <Completer<void>>{};
  bool _closed = false;
  @override
  void close() {
    _closed = true;
    for (final abort in _taskAborts) {
      if (!abort.isCompleted) abort.complete();
    }
    super.close();
  }

  Future<Object?> currentCampaign() => get('/api/campaign/current');
  Future<Object?> campaigns() => get('/api/campaigns');
  Future<Object?> events({TradingEventType type = TradingEventType.retail}) =>
      get('/api/trading-events', query: 'type=${type.api}');
  void _eventId(int id) {
    if (id <= 0) throw const PointsFailure('pointsDataInvalid');
  }

  Future<Object?> event(int id) {
    _eventId(id);
    return get('/api/trading-events/$id');
  }

  Future<Object?> eventLeaderboard(int id, {TradingEventType type = TradingEventType.retail}) {
    _eventId(id);
    return get(
      '/api/trading-events/$id/rankings/${type == TradingEventType.channel ? 'channel' : 'retail'}-volume',
      query: 'limit=${type == TradingEventType.channel ? 10 : 30}',
    );
  }

  Future<Object?> eventParticipant(int id, String address) {
    _eventId(id);
    if (!isPointsEvmAddress(address)) throw const PointsFailure('pointsDataInvalid');
    return get('/api/trading-events/$id/participants/${address.toLowerCase()}');
  }

  Future<Object?> eventTaskProgress(int id, String address) {
    _eventId(id);
    if (!isPointsEvmAddress(address)) throw const PointsFailure('pointsDataInvalid');
    return _taskRead('/api/trading-events/$id/participants/${address.toLowerCase()}/tasks');
  }

  Future<Object?> _taskRead(String path) async {
    if (_closed) throw const PointsFailure('pointsUnavailable');
    final abort = Completer<void>();
    _taskAborts.add(abort);
    try {
      return await (() async {
        final request =
            http.AbortableRequest(
                'GET',
                Uri.https('api.vanta.exchange', path),
                abortTrigger: abort.future,
              )
              ..followRedirects = false
              ..headers['Accept'] = 'application/json';
        final response = await _taskClient.send(request);
        if (response.statusCode != 200 ||
            response.headers['content-type']?.split(';').first.trim().toLowerCase() !=
                'application/json' ||
            (response.contentLength ?? 0) > 2097152) {
          final errorBody = await response.stream.take(64).fold<List<int>>(<int>[], (bytes, chunk) {
            if (bytes.length + chunk.length <= 65536) bytes.addAll(chunk);
            return bytes;
          });
          throw PointsFailure(
            response.statusCode == 429 || response.statusCode == 418
                ? 'pointsRateLimited'
                : response.statusCode == 200
                ? 'pointsDataInvalid'
                : 'pointsUnavailable',
            details: apiErrorDetails(
              decodeErrorPayload(utf8.decode(errorBody, allowMalformed: true)),
              status: response.statusCode,
            ),
          );
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 2097152) throw const PointsFailure('pointsDataInvalid');
          bytes.add(chunk);
        }
        return decodeFundingJson(utf8.decode(bytes.takeBytes()));
      })().timeout(
        timeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw const PointsFailure('pointsNetwork');
        },
      );
    } on PointsFailure {
      rethrow;
    } on FormatException {
      throw const PointsFailure('pointsDataInvalid');
    } catch (_) {
      throw const PointsFailure('pointsNetwork');
    } finally {
      _taskAborts.remove(abort);
    }
  }

  Future<Object?> leaderboard(int? campaign) {
    if (campaign != null && (campaign <= 0 || campaign > 9223372036854775807)) {
      throw const PointsFailure('pointsDataInvalid');
    }
    return get(campaign == null ? '/api/leaderboard/total' : '/api/leaderboard/campaign/$campaign');
  }

  Future<Object?> wallet(String address, {bool history = false}) {
    if (!isPointsEvmAddress(address)) throw const PointsFailure('pointsDataInvalid');
    return get('/api/points/${address.toLowerCase()}${history ? '/campaigns' : ''}');
  }
}

class PublicPointsRepository implements PointsRepository {
  PublicPointsRepository(this.service, {DateTime Function()? now}) : now = now ?? DateTime.now;
  final PointsService service;
  final DateTime Function() now;
  Future<PointsSnapshot<T>> _read<T>(
    Future<Object?> Function() request,
    T Function(Object?) map,
  ) async {
    try {
      final payload = await request();
      return PointsSnapshot(value: map(payload), receivedAt: now().toUtc());
    } on PointsFailure {
      rethrow;
    } on FormatException {
      throw const PointsFailure('pointsDataInvalid');
    } on AccountReadFailure catch (error) {
      throw PointsFailure(switch (error.key) {
        'accountDataInvalid' => 'pointsDataInvalid',
        'accountNetwork' => 'pointsNetwork',
        'accountRateLimited' => 'pointsRateLimited',
        _ => 'pointsUnavailable',
      }, details: error.details);
    }
  }

  @override
  Future<PointsSnapshot<PointsCampaign?>> currentCampaign() =>
      _read(service.currentCampaign, mapCurrentPointsCampaign);
  @override
  Future<PointsSnapshot<List<PointsCampaign>>> campaigns() =>
      _read(service.campaigns, mapPointsCampaigns);
  @override
  Future<PointsSnapshot<PointsLeaderboard>> leaderboard(int? campaign) => _read(
    () => service.leaderboard(campaign),
    (p) => mapPointsLeaderboard(p, campaign: campaign),
  );
  @override
  Future<PointsSnapshot<WalletPoints>> wallet(String address) =>
      _read(() => service.wallet(address), (p) => mapWalletPoints(p, address: address));
  @override
  Future<PointsSnapshot<WalletPointsHistory>> walletHistory(String address) => _read(
    () => service.wallet(address, history: true),
    (p) => mapWalletPointsHistory(p, address: address),
  );
  @override
  Future<PointsSnapshot<List<TradingEvent>>> events({
    TradingEventType type = TradingEventType.retail,
  }) => _read(() => service.events(type: type), (p) => mapTradingEvents(p, type: type));
  @override
  Future<PointsSnapshot<TradingEvent>> event(int id) =>
      _read(() => service.event(id), (p) => mapTradingEvent(p, eventId: id));
  @override
  Future<PointsSnapshot<EventLeaderboard>> eventLeaderboard(
    int id, {
    TradingEventType type = TradingEventType.retail,
  }) => _read(
    () => service.eventLeaderboard(id, type: type),
    (p) => mapEventLeaderboard(p, eventId: id, type: type),
  );
  @override
  Future<PointsSnapshot<EventTaskProgress>> eventTaskProgress(int id, String address) => _read(
    () => service.eventTaskProgress(id, address),
    (p) => mapEventTaskProgress(p, eventId: id, address: address),
  );
  @override
  Future<PointsSnapshot<EventParticipant>> eventParticipant(int id, String address) => _read(
    () => service.eventParticipant(id, address),
    (p) => mapEventParticipant(p, eventId: id, address: address),
  );
}
