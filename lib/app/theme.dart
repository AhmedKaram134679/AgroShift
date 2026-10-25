import 'package:flutter/material.dart';

/// Design system tokens tailored for an Egyptian agricultural application.
/// Incorporates Nile fertile silt (deep earth), vegetative forest greens, and desert sun accents.
class AgroTheme {
  AgroTheme._();

  // Primary Palette: Fertile Green & Nile River Depth
  static const Color primaryGreen = Color(0xFF1B5E20); // Nile Delta Green
  static const Color primaryLight = Color(0xFF4C8C4A);
  static const Color primaryDark = Color(0xFF003300);

  // Secondary Palette: Silt / Earth / Clay Soil
  static const Color soilBrown = Color(0xFF5D4037); // Egyptian Silt
  static const Color soilLight = Color(0xFF8B6B61);

  // Accent & Alerts
  static const Color sunAmber = Color(0xFFF57F17); // Heat warning
  static const Color severeRed = Color(0xFFC62828); // Critical threshold
  static const Color waterBlue = Color(0xFF0277BD); // Irrigation water
  static const Color cardSurfaceLight = Color(
    0xFFF9FBF7,
  ); // Clean parchment tone

  // Material 3 ThemeData with Arabic font fallbacks and crisp RTL readability
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: soilBrown,
        tertiary: waterBlue,
        error: severeRed,
        surface: cardSurfaceLight,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F6F2),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E7DF), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F5E9),
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: Color(0xFF616161),
            fontWeight: FontWeight.normal,
            fontSize: 12,
          );
        }),
      ),
    );
  }
}
