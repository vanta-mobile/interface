import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/spot_account_change_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/application/wallet_stream_controller.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';

void main() {
  for (final spot in [false, true]) {
    group(spot ? 'Spot' : 'Futures', () {
      late ProviderContainer c;
      late TestIdentityRepository identity;
      late TestAccountChangeRepository changes;
      late WalletStreamController controller;
      AccountChangeState state() =>
          spot ? c.read(spotAccountChangeProvider) : c.read(accountChangeProvider);
      setUp(() async {
        identity = TestIdentityRepository()..restored = signingIdentity;
        changes = TestAccountChangeRepository();
        c = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            accountChangeRepositoryProvider.overrideWithValue(changes),
            spotAccountChangeRepositoryProvider.overrideWithValue(changes),
            accountChangeClockProvider.overrideWithValue(() => changes.now),
          ],
        );
        c.read(authProvider);
        await Future<void>.delayed(Duration.zero);
        controller = spot
            ? c.read(spotAccountChangeProvider.notifier)
            : c.read(accountChangeProvider.notifier);
        await controller.authorize();
        changes.channels.single.add(const AccountChangeEvent.connected());
      });
      tearDown(() async {
        c.dispose();
        await identity.dispose();
        await changes.dispose();
      });

      test('active order keeps the original socket during wallet switch; release in background pauses it', () async {
        final activity = c.read(symbolSettingsActivityProvider.notifier);
        final lease = activity.acquire(SymbolSetting.order)!;
        final connected = state();
        c.read(quoteUpdatesActiveProvider.notifier).setActive(false);
        expect(state(), same(connected));
        expect(changes.canceled, 0);
        c.read(quoteUpdatesActiveProvider.notifier).setActive(true);
        expect(state(), same(connected));
        expect(changes.channels.length, 1);
        c.read(quoteUpdatesActiveProvider.notifier).setActive(false);
        activity.finish(lease, unresolved: false);
        expect(state().connection, AccountChangeConnection.paused);
        expect(changes.canceled, 1);
        expect(changes.authorizations, 1);
        c.read(quoteUpdatesActiveProvider.notifier).setActive(true);
        expect(changes.channels.length, 2);
        expect(changes.authorizations, 1);
      });

      test('real disconnect and expiry still apply during an active order', () async {
        c.read(symbolSettingsActivityProvider.notifier).acquire(SymbolSetting.order);
        c.read(quoteUpdatesActiveProvider.notifier).setActive(false);
        changes.channels.single.addError(StateError('test disconnect'));
        expect(state().connection, AccountChangeConnection.disconnected);
        expect(changes.canceled, 1);
        controller.reconnect();
        changes.channels.last.add(const AccountChangeEvent.connected());
        changes.channels.last.add(const AccountChangeEvent.expired());
        expect(state().connection, AccountChangeConnection.expired);
        c.read(quoteUpdatesActiveProvider.notifier).setActive(true);
        expect(changes.channels.length, 2);
        expect(changes.authorizations, 1);
      });

      test('idle or non-order background still pauses; identity loss closes immediately', () async {
        final activity = c.read(symbolSettingsActivityProvider.notifier);
        final lease = activity.acquire(SymbolSetting.leverage)!;
        c.read(quoteUpdatesActiveProvider.notifier).setActive(false);
        expect(state().connection, AccountChangeConnection.paused);
        activity.finish(lease, unresolved: false);
        c.read(quoteUpdatesActiveProvider.notifier).setActive(true);
        activity.acquire(SymbolSetting.order);
        identity.events.add(null);
        expect(state().connection, AccountChangeConnection.stopped);
        expect(changes.canceled, 2);
      });
    });
  }
}
