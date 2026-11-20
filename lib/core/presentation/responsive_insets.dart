/// Symmetric horizontal inset used across full-width page layouts.
///
/// Three tiers:
/// • Phone / narrow  (≤ 592dp) — 16dp screen-edge padding.
/// • Foldable / mid-range tablet (593–820dp) — centers a 560dp content
///   column.  At exactly 592dp the value equals 16dp, so there is no visual
///   jump at the phone→foldable boundary.
/// • Large tablet / ultra-wide (> 820dp) — centers a 788dp content column.
double responsiveHorizontalInset(double maxWidth) {
  if (maxWidth > 820) return (maxWidth - 788) / 2;
  if (maxWidth > 592) return (maxWidth - 560) / 2;
  return 16.0;
}
