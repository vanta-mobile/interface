import 'package:flutter/material.dart';

abstract final class AppColors {
  static const launchBackground = Color(0xFF121215);
  static const background = Color(0xFF0B0E13);
  static const surface = Color(0xFF11151D);
  static const raised = Color(0xFF1A202B);
  static const input = Color(0xFF1D2430);
  static const line = Color(0xFF252C37);
  static const text = Color(0xFFF3F5F7);
  static const secondary = Color(0xFF939DAE);
  static const muted = Color(0xFF667184);
  static const accent = Color(0xFF00D6AC);
  static const accentSoft = Color(0xFF112E2C);
  static const positive = Color(0xFF00CFA2);
  static const negative = Color(0xFFFF6175);
  static const positiveDepth = Color(0xFF12332F);
  static const negativeDepth = Color(0xFF33202A);
  static const positiveBookDepth = Color(0xFF154139);
  static const negativeBookDepth = Color(0xFF48232E);
  static const warning = Color(0xFFF2B84B);
  static const bitcoin = Color(0xFFF7931A);
  static const onAccent = Color(0xFF042B24);
  static const transparent = Color(0x00000000);
  static const authBackground = Color(0xFF121215);
  static const authText = Color(0xFFFFFFFF);
  static const authSecondary = Color(0xFFE6E8E8);
  static const authInput = Color(0xFF222834);
  static const authLine = Color(0x24FFFFFF);
  static const authButton = Color(0xFF3C4143);
  static const authCard = Color(0xFF232526);
  static const authOverlay = Color(0x80000000);
  static const authAccent = Color(0xFF00E4AB);
  static const authOnAccent = Color(0xFF013220);
  static const authError = Color(0xFFF5464B);
}

abstract final class AuthTypography {
  static const brand = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    color: AppColors.authAccent,
  );
  static const heading = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w700,
    color: AppColors.authText,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: AppColors.authText,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.authSecondary,
  );
  static const button = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w700);
}

ThemeData vantaTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'Inter',
  fontFamilyFallback: const ['NotoSansSC'],
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.negative,
    outline: AppColors.line,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: AppColors.text),
    bodySmall: TextStyle(fontSize: 11, color: AppColors.secondary),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  ),
  dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
  iconTheme: const IconThemeData(color: AppColors.secondary, size: 20),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.onAccent,
      minimumSize: const Size(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.text,
      side: const BorderSide(color: AppColors.line),
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.input,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.accent),
    ),
    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    dragHandleColor: AppColors.muted,
    showDragHandle: true,
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: AppColors.raised,
    contentTextStyle: TextStyle(color: AppColors.text, fontFamilyFallback: ['NotoSansSC']),
    behavior: SnackBarBehavior.floating,
  ),
);

/// Portfolio and primary navigation tokens from the supplied mobile design.
abstract final class PortfolioColors {
  static const transparent = AppColors.transparent;
  static const background = AppColors.authBackground;
  static const card = AppColors.authCard;
  static const button = AppColors.authButton;
  static const text = AppColors.authText;
  static const secondary = AppColors.authSecondary;
  static const muted = Color(0xFF959B9E);
  static const line = AppColors.authLine;
  static const accent = AppColors.authAccent;
  static const onAccent = AppColors.authOnAccent;
  static const negative = AppColors.authError;
  static const positive = Color(0xFF0FB276);
  static const inset = Color(0xFF181A1B);
  static const accountScrim = Color(0x66000000);
  static const menuShadow = Color(0x40000000);
  static const negativeSurface = Color(0xFF4E210F);
  static const assetEstimate = Color(0xFFA1A9B4);
  static const assetDivider = Color(0xFF232526);
}

abstract final class PortfolioTypography {
  static const assetSymbol = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
    color: PortfolioColors.text,
  );
  static const tab = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: PortfolioColors.text,
  );
  static const heading = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w700,
    color: PortfolioColors.text,
  );
  static const section = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
    color: PortfolioColors.text,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: PortfolioColors.secondary,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: PortfolioColors.secondary,
  );
  static const value = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    color: PortfolioColors.text,
  );
  static const metric = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
    color: PortfolioColors.text,
  );
  static const detailValue = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
    color: PortfolioColors.text,
  );
  static const navigation = TextStyle(fontSize: 10, height: 16 / 10, fontWeight: FontWeight.w500);
}

/// Account-management typography from the supplied mobile frames.
abstract final class AccountTypography {
  static const heading = PortfolioTypography.heading;
  static const section = PortfolioTypography.section;
  static const name = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
    color: PortfolioColors.text,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: PortfolioColors.text,
  );
  static const secondary = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: PortfolioColors.secondary,
  );
  static const caption = PortfolioTypography.caption;
  static const fieldLabel = TextStyle(
    fontSize: 12,
    height: 14 / 12,
    fontWeight: FontWeight.w500,
    color: PortfolioColors.secondary,
  );
}

/// Compact status labels in the portfolio transaction design.
abstract final class HistoryTypography {
  static const status = TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500);
}

/// Deposit and withdrawal form typography from the supplied funding frames.
abstract final class FundingTypography {
  static const fieldLabel = TextStyle(
    fontSize: 10,
    height: 14 / 10,
    fontWeight: FontWeight.w500,
    color: PortfolioColors.secondary,
  );
  static const amount = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w500,
    color: PortfolioColors.text,
  );
  static const value = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: PortfolioColors.text,
  );
  static const note = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    color: PortfolioColors.secondary,
  );
  static const tab = TextStyle(fontSize: 12, height: 18 / 12, fontWeight: FontWeight.w500);
}

/// Global toast tokens from the supplied feedback frames.
abstract final class ToastColors {
  static const background = AppColors.authCard;
  static const border = AppColors.authLine;
  static const text = AppColors.authText;
  static const icon = AppColors.authSecondary;
}

abstract final class ToastTypography {
  static const message = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w700,
    color: ToastColors.text,
  );
}

/// Shared load-failure, empty and skeleton state tokens.
abstract final class StatusColors {
  static const title = AppColors.authText;
  static const message = PortfolioColors.muted;
  static const actionBorder = AppColors.authLine;
  static const skeleton = AppColors.authCard;

  /// Placeholder on a card surface, where [skeleton] would match the card.
  static const skeletonOnCard = AppColors.authButton;
}

abstract final class StatusTypography {
  static const title = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
    color: StatusColors.title,
  );
  static const message = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: StatusColors.message,
  );
  // Button text styles replace, rather than merge with, the theme font.
  static const action = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
    color: StatusColors.title,
  );
}

/// Notification center tokens from the supplied mobile frames.
abstract final class NotificationColors {
  static const detailValue = PortfolioColors.text;
  static const background = PortfolioColors.background;
  static const unread = PortfolioColors.card;
  static const divider = PortfolioColors.line;
  static const title = PortfolioColors.secondary;
  static const body = PortfolioColors.secondary;
  static const time = Color(0xFF7B8185);
  static const muted = PortfolioColors.muted;
  static const accent = PortfolioColors.accent;
  static const neutralSurface = PortfolioColors.card;
  static const neutral = PortfolioColors.secondary;
  static const positiveSurface = PortfolioColors.onAccent;
  static const positive = PortfolioColors.positive;
  static const warningSurface = Color(0xFF472909);
  static const warning = Color(0xFFE9A83C);
  static const negativeSurface = PortfolioColors.negativeSurface;
  static const negative = PortfolioColors.negative;
}

abstract final class NotificationTypography {
  static const detailLabel = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: NotificationColors.body,
  );
  static const detailValue = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: NotificationColors.detailValue,
  );
  static const detailSection = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: NotificationColors.detailValue,
  );
  static const detailSummaryLabel = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: NotificationColors.body,
  );
  static const detailSummaryValue = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
    color: NotificationColors.detailValue,
  );
  static const detailStatus = TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500);
  static const heading = PortfolioTypography.heading;
  static const action = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: NotificationColors.accent,
  );
  static const tab = TextStyle(fontSize: 12, height: 18 / 12, fontWeight: FontWeight.w700);
  static const filter = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: NotificationColors.title,
  );
  static const group = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: NotificationColors.muted,
  );
  static const title = TextStyle(
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w700,
    color: NotificationColors.title,
  );
  static const time = TextStyle(
    fontSize: 10,
    height: 16 / 10,
    fontWeight: FontWeight.w500,
    color: NotificationColors.time,
  );
  static const body = TextStyle(
    fontSize: 10,
    height: 16 / 10,
    fontWeight: FontWeight.w500,
    color: NotificationColors.body,
  );
  static const chip = TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w700);
}

/// Primary navigation tokens beyond the shared tab label style.
abstract final class NavigationTypography {
  static const badge = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: AppColors.authSecondary,
  );
  static const selectedPoints = TextStyle(
    fontSize: 10,
    height: 16 / 10,
    fontWeight: FontWeight.w700,
    color: AppColors.authAccent,
  );
}

/// Points page tokens from the supplied mobile frames.
abstract final class PointsColors {
  static const background = AppColors.authBackground;
  static const text = AppColors.authText;
  static const secondary = AppColors.authSecondary;
  static const accent = AppColors.authAccent;
  static const card = AppColors.authCard;
  static const section = PortfolioColors.inset;
  static const divider = AppColors.authLine;
  static const summaryStart = Color(0xFF0E4033);
  static const summaryEnd = Color(0xFF0B1F1B);
  static const rankBadge = Color(0x1AFFFFFF);
  static const leaderPoints = AppColors.authOnAccent;
  static const loadingValue = Color(0x19FFFFFF);
  static const activeTint = Color(0x1A00E4AB);
  static const neutralTint = Color(0x1AE6E8E8);
  static const scrim = Color(0x9E000000);
  static const numeralTop = Color(0xEBE3F2ED);
  static const numeralMiddle = Color(0xA6A8C4BA);
  static const numeralBottom = Color(0x298AA89E);
}

abstract final class PointsTypography {
  static const header = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
    color: PointsColors.text,
  );
  static const heading = PortfolioTypography.heading;
  static const summaryLabel = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    color: PointsColors.accent,
  );
  static const total = PortfolioTypography.value;
  static const section = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: PointsColors.text,
  );
  static const campaign = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
    color: PointsColors.text,
  );
  static const label = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: PointsColors.secondary,
  );
  static const labelPrimary = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: PointsColors.text,
  );
  static const scope = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
    color: PointsColors.secondary,
  );
  static const caption = TextStyle(
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w400,
    color: PointsColors.secondary,
  );
  static const status = TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500);
  static const metric = PortfolioTypography.metric;
  static const option = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    color: PointsColors.text,
  );
  static const rank = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    color: PointsColors.secondary,
  );
  static const address = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    color: PointsColors.text,
  );
  static const points = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    color: PointsColors.text,
  );
  static const podiumPoints = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w700,
    color: PointsColors.text,
  );
  static const unit = TextStyle(
    fontSize: 10,
    height: 16 / 10,
    fontWeight: FontWeight.w400,
    color: PointsColors.secondary,
  );
  static const numeral = TextStyle(fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w700);
  static const emptyTitle = section;
}

/// Vanta AI conversation and wallet-authentication tokens from the AI frames.
abstract final class AssistantColors {
  static const background = AppColors.authBackground;
  static const text = AppColors.authText;
  static const secondary = AppColors.authSecondary;
  static const muted = PortfolioColors.muted;
  static const accent = AppColors.authAccent;
  static const onAccent = AppColors.authOnAccent;
  static const error = AppColors.authError;
  static const card = AppColors.authCard;
  static const line = AppColors.authLine;
  static const input = AppColors.authInput;
  static const inputBorder = AppColors.authCard;
  static const reply = PortfolioColors.inset;
  static const onSend = Color(0xFF121215);
  static const failureSurface = Color(0xFF29171C);
  static const limitSurface = NotificationColors.warningSurface;
}

abstract final class AssistantTypography {
  static const title = PortfolioTypography.heading;
  static const quota = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: AssistantColors.muted,
  );
  static const clear = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    color: AssistantColors.muted,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: AssistantColors.text,
  );
  static const secondary = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: AssistantColors.secondary,
  );
  static const placeholder = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: AssistantColors.muted,
  );
  static const label = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
    color: AssistantColors.text,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: AssistantColors.secondary,
  );
  static const time = TextStyle(
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w400,
    color: AssistantColors.muted,
  );
  static const disclaimer = TextStyle(
    fontSize: 10,
    height: 16 / 10,
    fontWeight: FontWeight.w500,
    color: AssistantColors.secondary,
  );
  static const button = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w700);
}
