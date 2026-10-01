import 'package:flutter/material.dart';

/// Design tokens for VINII POS, sourced from the 36 reference screens at
/// v1/ (2026-09-15) — see Q02 in docs/DECISIONS-AND-QUESTIONS.txt.
///
/// Values marked "sampled" were read directly from reference PNG pixels
/// (scripts/results are not kept in the repo, but the brand green in
/// particular was cross-checked against the earlier authenticated Figma
/// capture in docs/FIGMA-DESIGN-CONTEXT.md and matches exactly:
/// #76EC00). Values marked "approximated" have no flat/solid reference
/// pixel available (thin borders, small glyphs) and are a close,
/// conventional match to the sampled pale tint they pair with — call
/// this out if you find the real value, don't silently assume this is
/// exact.
class ViniiColors {
  const ViniiColors._();

  // Brand — sampled, exact.
  static const brandGreen = Color(0xFF76EC00);
  static const emeraldText = Color(0xFF027A48);
  static const successPillBg = Color(0xFFD1FADF);
  static const successPillText = Color(0xFF027A48);

  // Light theme surfaces — sampled.
  static const lightBg = Color(0xFFFFFFFF);
  static const lightGreenTint =
      Color(0xFFEFFDF4); // active-row / selected-pill tint
  // Sampled from v1/POS-DINE-IN-V3.png's content area (not pure white —
  // a warm light gray that the white table/sidebar cards sit on top of).
  static const lightPageBg = Color(0xFFF7F7F5);
  static const sidebarDark = Color(0xFF0A0A0A);
  static const sidebarSelectedTint = Color(0xFF16241A); // dark-green tinted row

  // Dark theme surfaces — sampled.
  static const darkTopbarBg = Color(0xFF13131E);
  static const darkCardBg = Color(0xFF0F0F1A);
  static const darkPageBg = Color(0xFF0A0A0A);
  // Approximated — thin dark borders had no flat sample; a conventional
  // "barely visible on near-black" tone.
  static const darkBorder = Color(0xFF1F2029);
  static const lightBorder = Color(
      0xFFE3E5EB); // reused from FIGMA-DESIGN-CONTEXT.md (same brand, sampled there)

  // Status pale tints — sampled (badge/pill backgrounds, card-border tints).
  static const blueTint = Color(0xFFEFF6FF); // occupied / new / info
  static const amberTint = Color(0xFFFFFBEB); // preparing / reserved / pending
  static const greenTint =
      Color(0xFFEFFDF4); // available / ready / success (same as brand tint)
  static const redTint =
      Color(0xFFFEF2F2); // delayed / urgent / cancelled / unavailable
  static const grayTint = Color(0xFFF4F4F5); // cleaning / completed / neutral

  // Status solid tones — approximated (conventional pairing for the
  // sampled tints above; no flat reference pixel available for thin
  // border strokes or small glyph text).
  static const blueSolid = Color(0xFF2563EB);
  static const amberSolid = Color(0xFFD97706);
  static const greenSolid = Color(0xFF16A34A);
  static const redSolid = Color(0xFFDC2626);
  static const purpleSolid = Color(0xFF7C3AED); // payment pending
  static const purpleTint =
      Color(0xFFF5F3FF); // approximated pair for purpleSolid
  static const graySolid = Color(0xFF6B7280);

  // Text — sampled from FIGMA-DESIGN-CONTEXT.md (same brand, same token set).
  static const textPrimaryLight = Color(0xFF111115);
  static const textSecondaryLight = Color(0xFF555560);
  static const textMutedLight = Color(0xFF94969E);
}

ThemeData viniiLightTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: ViniiColors.lightBg,
    colorScheme: ColorScheme.fromSeed(
        seedColor: ViniiColors.brandGreen, brightness: Brightness.light),
    fontFamily: 'Inter',
    dividerColor: ViniiColors.lightBorder);

ThemeData viniiDarkTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ViniiColors.darkPageBg,
    colorScheme: ColorScheme.fromSeed(
        seedColor: ViniiColors.brandGreen, brightness: Brightness.dark),
    fontFamily: 'Inter',
    dividerColor: ViniiColors.darkBorder);
