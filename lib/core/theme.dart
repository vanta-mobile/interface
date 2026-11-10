import 'package:flutter/material.dart';

abstract final class AppColors {
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
}

abstract final class PortfolioTypography {
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
