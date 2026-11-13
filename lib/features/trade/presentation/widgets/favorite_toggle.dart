import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_text.dart';
import '../../../../core/presentation/app_toast.dart';
import '../../../../core/strings.dart';
import '../../../../core/vanta_api/vanta_api_failure.dart';
import '../../../market/application/selection_providers.dart';

/// Toggles a favorite and shows a failed watchlist write with its API cause.
Future<void> toggleFavorite(BuildContext context, WidgetRef ref, String symbol) async {
  final failure = await ref.read(favoriteSymbolsProvider.notifier).toggle(symbol);
  if (failure != null && context.mounted) showFavoriteFailure(context, failure);
}

void showFavoriteFailure(BuildContext context, Object failure) => AppToast.showFailure(
  context,
  failure is VantaApiFailure
      ? apiErrorText(context, failure.key, failure.details)
      : tr(context, vantaApiRequestFailed),
  persistent: false,
);
