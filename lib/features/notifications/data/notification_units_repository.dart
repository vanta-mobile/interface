import '../../portfolio/data/aster_spot_service.dart';
import '../../portfolio/data/spot_history_mapper.dart';
import '../../portfolio/domain/spot_history.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/domain/aster_account.dart';

abstract interface class NotificationUnitsRepository {
  Future<Map<String, AsterContractUnits>> read();
}

class AsterNotificationUnitsRepository implements NotificationUnitsRepository {
  AsterNotificationUnitsRepository(this.service);
  final AsterAccountService service;
  @override
  Future<Map<String, AsterContractUnits>> read() => service.contractUnits();
}

abstract interface class SpotNotificationUnitsRepository {
  Future<Map<String, SpotSymbolUnits>> read();
}

class AsterSpotNotificationUnitsRepository implements SpotNotificationUnitsRepository {
  AsterSpotNotificationUnitsRepository(this.service);
  final AsterSpotService service;
  @override
  Future<Map<String, SpotSymbolUnits>> read() async =>
      mapSpotSymbolUnits(await service.exchangeInfo());
}
