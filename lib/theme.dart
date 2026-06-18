import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ثيم موحّد للتطبيق مستوحى من ألوان الموقع الأصلي (أحمر/أسود) مع دعم RTL كامل.
class AppTheme {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkRed = Color(0xFF9B0008);
  static const Color background = Color(0xFF0B0C10);
  static const Color surface = Color(0xFF15171F);
  static const Color surfaceVariant = Color(0xFF1E2029);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textMuted = Color(0xFFA5ADBB);

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
    );
    final textTheme = GoogleFonts.cairoTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryRed,
        brightness: Brightness.dark,
        primary: primaryRed,
        surface: surface,
        background: background,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryRed,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        side: BorderSide(color: primaryRed.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
