import 'dart:async';

import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

class TestAccountChangeRepository implements AccountChangeRepository {
  int authorizations = 0, cleared = 0, canceled = 0;
  DateTime now = DateTime.utc(2026, 11, 3);
  Completer<void>? gate;
  AccountReadFailure? failure;
  final channels = <StreamController<AccountChangeEvent>>[];
  @override
  Future<DateTime> authorize({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    authorizations++;
    onStep(AccountReadStep.signing);
    await gate?.future;
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    if (failure case final error?) throw error;
    onStep(AccountReadStep.loading);
    return now.add(const Duration(minutes: 60));
  }

  @override
  Stream<AccountChangeEvent> connect() {
    final channel = StreamController<AccountChangeEvent>.broadcast(
      sync: true,
      onCancel: () {
        canceled++;
      },
    );
    channels.add(channel);
    return channel.stream;
  }

  @override
  void clear() {
    cleared++;
  }

  Future<void> dispose() async {
    for (final channel in channels) {
      await channel.close();
    }
  }
}
