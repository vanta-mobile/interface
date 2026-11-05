import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/assistant_view_state.dart';
import 'assistant_controller.dart';

export '../domain/assistant_view_state.dart';
export 'assistant_controller.dart';
export 'assistant_dependencies.dart';

final assistantProvider = NotifierProvider.autoDispose<AssistantController, AssistantViewState>(
  AssistantController.new,
);
