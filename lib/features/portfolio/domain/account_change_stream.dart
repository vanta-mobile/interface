import '../../notifications/domain/account_notification.dart';
import 'account_snapshot.dart';
import 'open_order_update.dart';
import 'account_update.dart';
import 'spot_open_orders.dart';

enum AccountChangeKind { account, order, configuration, marginCall, unknown }

/// Validated partial updates never prove a complete signed REST snapshot.
class AccountChangeEvent {
  const AccountChangeEvent.connected()
    : connected = true,
      expired = false,
      kind = null,
      time = null,
      order = null,
      account = null,
      spotOrder = null,
      notification = null;
  const AccountChangeEvent.expired()
    : connected = false,
      expired = true,
      kind = null,
      time = null,
      order = null,
      account = null,
      spotOrder = null,
      notification = null;
  const AccountChangeEvent.changed(
    this.kind,
    this.time, {
    this.order,
    this.account,
    this.notification,
    this.spotOrder,
  }) : connected = false,
       expired = false;
  final bool connected, expired;
  final AccountChangeKind? kind;
  final DateTime? time;
  final OpenOrderUpdate? order;
  final AccountUpdate? account;
  final AccountNotification? notification;
  final SpotOpenOrderUpdate? spotOrder;
}

abstract interface class AccountChangeRepository {
  /// Keys stay inside the repository and are never persisted or shown in UI.
  Future<DateTime> authorize({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  });
  Stream<AccountChangeEvent> connect();
  void clear();
}

enum AccountChangeConnection { stopped, connecting, connected, disconnected, paused, expired }

class AccountChangeState {
  const AccountChangeState({
    this.connection = AccountChangeConnection.stopped,
    this.step = AccountReadStep.idle,
    this.expiresAt,
    this.lastEventAt,
    this.renewalDue = false,
    this.failure,
  });
  final AccountChangeConnection connection;
  final AccountReadStep step;
  final DateTime? expiresAt, lastEventAt;
  final bool renewalDue;
  final AccountReadFailure? failure;
  bool get busy => step != AccountReadStep.idle || connection == AccountChangeConnection.connecting;
}
