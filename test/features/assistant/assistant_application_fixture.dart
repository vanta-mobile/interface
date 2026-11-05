import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vanta/features/assistant/application/assistant_provider.dart';
import 'package:vanta/features/assistant/data/assistant_chat_repository.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';

import '../../support/identity_repository.dart';
import 'assistant_session_fixture.dart';

class AssistantTestChat extends AssistantChatRepository {
  AssistantTestChat(super.http);
  int calls = 0;
  List<AssistantMessage>? sentHistory;
  final requestIds = <String>[];
  Stream<AssistantReplyUpdate> Function(AssistantCancellation token)? respond;
  @override
  Stream<AssistantReplyUpdate> answer({
    required String accessToken,
    required String userId,
    required String requestId,
    required List<AssistantMessage> history,
    required AssistantCancellation cancellation,
  }) async* {
    calls++;
    sentHistory = history;
    requestIds.add(requestId);
    if (respond != null) {
      yield* respond!(cancellation);
    } else {
      yield const AssistantReplyUpdate(
        content: 'A useful answer',
        reasoning: 'Explanation',
        delivery: AssistantDelivery.complete,
      );
    }
  }
}

class AssistantApplicationHarness {
  AssistantApplicationHarness({bool connected = true}) {
    identity.restored = connected ? assistantIdentity() : null;
    chat = AssistantTestChat(auth.httpService);
    var sequence = 0;
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        assistantAuthRepositoryProvider.overrideWithValue(auth.repository),
        assistantChatRepositoryProvider.overrideWithValue(chat),
        assistantVaultProvider.overrideWithValue(auth.vault),
        assistantClockProvider.overrideWithValue(() => auth.time),
        assistantIdProvider.overrideWithValue(
          () => '12345678-1234-4234-8234-${(++sequence).toString().padLeft(12, '0')}',
        ),
        assistantLinkOpenerProvider.overrideWithValue((uri) async {
          links.add(uri);
          return true;
        }),
      ],
    );
    subscription = container.listen(assistantProvider, (_, _) {});
  }
  final auth = AssistantAuthHarness();
  final identity = TestIdentityRepository();
  final links = <Uri>[];
  late final AssistantTestChat chat;
  late final ProviderContainer container;
  late final ProviderSubscription<AssistantViewState> subscription;
  AssistantController get controller => container.read(assistantProvider.notifier);
  AssistantViewState get state => container.read(assistantProvider);
  Future<void> ready() async {
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> login() async {
    await controller.prepare();
    await controller.confirm(state.challenge!);
  }

  bool _closed = false;
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    subscription.close();
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    auth.close();
    await identity.dispose();
  }
}
