import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/builder_authorization_provider.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/domain/builder_authorization.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_signatures.dart';
import '../../support/builder.dart';
import '../../support/identity_repository.dart';
import '../../support/trading_authorization.dart';

void main() {
  test('a journal refresh preserves the server refusal and never retries approval', () async {
    final identity = TestIdentityRepository()
      ..restored = const AuthIdentity(
        id: 'owner',
        walletAddress: fixtureMaster,
        signingAvailable: true,
      );
    final repository = TestTradingAuthorizationRepository()
      ..failure = const AccountReadFailure(
        'accountReadFailed',
        details: ApiErrorDetails(message: 'Signature check failed', status: 400),
      );
    final journal = MemoryBuilderApprovalJournal();
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        tradingAuthorizationRepositoryProvider.overrideWithValue(repository),
        builderApprovalJournalProvider.overrideWithValue(journal),
        tradingAgentProvider.overrideWith((_) async => null),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.dispose();
    });
    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(tradingAuthorizationProvider.notifier);
    await container.read(builderApprovalProvider.future);
    await controller.enableTrading();
    await journal.save(
      fixtureMaster,
      BuilderApprovalRecord(
        status: BuilderApprovalStatus.rejected,
        maxFeeRate: VantaBuilder.approvalCap,
      ),
    );
    container.invalidate(builderApprovalProvider);
    await container.read(builderApprovalProvider.future);
    final state = container.read(tradingAuthorizationProvider);
    expect(state.result, isNull);
    expect(state.failure, 'accountReadFailed');
    expect(state.errorDetails?.status, 400);
    expect(state.errorDetails?.message, 'Signature check failed');
    expect(repository.enables, 1);
    expect(repository.checks, 0);
  });
}
