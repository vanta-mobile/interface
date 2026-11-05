import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../market/application/market_providers.dart';

import '../domain/points.dart';
import '../domain/trading_event.dart';
import '../domain/event_engagement.dart';
import 'points_provider.dart';

final eventTimeProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = ref.watch(pointsClockProvider), active = ref.watch(quoteUpdatesActiveProvider);
  return Stream<DateTime>.multi((output) {
    output.add(clock().toUtc());
    final timer = active
        ? Timer.periodic(const Duration(seconds: 1), (_) => output.add(clock().toUtc()))
        : null;
    output.onCancel = () {
      timer?.cancel();
    };
  });
});
DateTime eventNow(WidgetRef ref) =>
    ref.watch(eventTimeProvider).asData?.value ?? ref.read(pointsClockProvider)().toUtc();

final tradingEventsProvider =
    NotifierProvider.autoDispose<TradingEventsController, PointsLoadState<List<TradingEvent>>>(
      TradingEventsController.new,
    );
final tradingEventProvider = NotifierProvider.autoDispose
    .family<TradingEventController, PointsLoadState<TradingEvent>, int>(TradingEventController.new);
final eventLeaderboardProvider = NotifierProvider.autoDispose
    .family<EventLeaderboardController, PointsLoadState<EventLeaderboard>, int>(
      EventLeaderboardController.new,
    );
final eventParticipantProvider = NotifierProvider.autoDispose
    .family<EventParticipantController, PointsLoadState<EventParticipant>, int>(
      EventParticipantController.new,
    );

final channelEventsProvider =
    NotifierProvider.autoDispose<ChannelEventsController, PointsLoadState<List<TradingEvent>>>(
      ChannelEventsController.new,
    );
final channelEventLeaderboardProvider = NotifierProvider.autoDispose
    .family<EventLeaderboardController, PointsLoadState<EventLeaderboard>, int>(
      (id) => EventLeaderboardController(id, type: TradingEventType.channel),
    );
final eventTaskProgressProvider = NotifierProvider.autoDispose
    .family<EventTaskProgressController, PointsLoadState<EventTaskProgress>, int>(
      EventTaskProgressController.new,
    );

class ChannelEventsController extends PointsLoadController<List<TradingEvent>> {
  @override
  Future<PointsSnapshot<List<TradingEvent>>> read(
    PointsRepository repository,
    String? address,
  ) async {
    final result = await repository.events(type: TradingEventType.channel);
    if (result.value.any((e) => e.type != TradingEventType.channel)) {
      throw const PointsFailure('pointsDataInvalid');
    }
    return result;
  }
}

class EventTaskProgressController extends PointsLoadController<EventTaskProgress> {
  EventTaskProgressController(this.id);
  final int id;
  @override
  bool get walletScoped => true;
  @override
  Future<PointsSnapshot<EventTaskProgress>> read(
    PointsRepository repository,
    String? address,
  ) async {
    final result = await repository.eventTaskProgress(id, address!);
    if (result.value.eventId != id || result.value.address.toLowerCase() != address) {
      throw const PointsFailure('pointsDataInvalid');
    }
    return result;
  }
}

class TradingEventsController extends PointsLoadController<List<TradingEvent>> {
  @override
  Future<PointsSnapshot<List<TradingEvent>>> read(PointsRepository repository, String? address) =>
      repository.events();
}

class TradingEventController extends PointsLoadController<TradingEvent> {
  TradingEventController(this.id);
  final int id;
  @override
  Future<PointsSnapshot<TradingEvent>> read(PointsRepository repository, String? address) async {
    final result = await repository.event(id);
    if (result.value.id != id) throw const PointsFailure('pointsDataInvalid');
    return result;
  }
}

class EventLeaderboardController extends PointsLoadController<EventLeaderboard> {
  EventLeaderboardController(this.id, {this.type = TradingEventType.retail});
  final int id;
  final TradingEventType type;
  @override
  Future<PointsSnapshot<EventLeaderboard>> read(
    PointsRepository repository,
    String? address,
  ) async {
    final result = await repository.eventLeaderboard(id, type: type);
    if (result.value.eventId != id || result.value.type != type) {
      throw const PointsFailure('pointsDataInvalid');
    }
    return result;
  }
}

class EventParticipantController extends PointsLoadController<EventParticipant> {
  EventParticipantController(this.id);
  final int id;
  @override
  bool get walletScoped => true;
  @override
  Future<PointsSnapshot<EventParticipant>> read(
    PointsRepository repository,
    String? address,
  ) async {
    final result = await repository.eventParticipant(id, address!);
    if (result.value.eventId != id || pointsAddressKey(result.value.address) != address) {
      throw const PointsFailure('pointsDataInvalid');
    }
    return result;
  }
}
