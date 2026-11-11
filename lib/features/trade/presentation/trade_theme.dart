import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Semantic tokens from the mobile Futures design, scoped to its workspace.
abstract final class TradeColors {
  static const background = AppColors.authBackground;
  static const card = AppColors.authCard;
  static const control = AppColors.authButton;
  static const text = AppColors.authText;
  static const secondary = AppColors.authSecondary;
  static const muted = PortfolioColors.muted;
  static const line = AppColors.authLine;
  static const accent = AppColors.authAccent;
  static const accentBackground = AppColors.authOnAccent;
  static const positive = PortfolioColors.positive;
  static const negative = AppColors.authError;
  static const transparent = AppColors.transparent;
  static const switchBackground = AppColors.authOverlay;
  static const assetIconBackground = AppColors.authText;
  static const sheet = PortfolioColors.inset;
  static const ratioBuy = Color(0xFF013220);
  static const ratioSell = PortfolioColors.negativeSurface;
}

abstract final class TradeTypography {
  static const heading = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w700,
    color: TradeColors.text,
  );
  static const symbol = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
    color: TradeColors.text,
  );
  static const body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: TradeColors.text,
  );
  static const caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w500,
    color: TradeColors.muted,
  );
  static const option = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
    color: TradeColors.text,
  );
  static const small = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    height: 16 / 10,
    fontWeight: FontWeight.w500,
    color: TradeColors.muted,
  );
}
