import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Adaptive color palette – resolves to light or dark based on context.
class AppColors {
  final Brightness brightness;

  const AppColors._(this.brightness);

  static AppColors of(BuildContext context) {
    return AppColors._(Theme.of(context).brightness);
  }

  // ─── Primary palette (shared) ───────────────────────────
  static const Color primary = Color(0xFF00BFA6);
  static const Color primaryDark = Color(0xFF00897B);
  static const Color primaryLight = Color(0xFF64FFDA);
  static const Color accent = Color(0xFF7C4DFF);
  static const Color accentLight = Color(0xFFB388FF);

  // ─── Status (shared) ────────────────────────────────────
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // ─── Gradients (shared) ─────────────────────────────────
  static const List<Color> primaryGradient = [Color(0xFF00BFA6), Color(0xFF00E5FF)];
  static const List<Color> accentGradient = [Color(0xFF7C4DFF), Color(0xFFE040FB)];
  static const List<Color> warmGradient = [Color(0xFFFF6E40), Color(0xFFFFAB40)];
  static const List<Color> coolGradient = [Color(0xFF42A5F5), Color(0xFF26C6DA)];

  // ─── Adaptive surface / background ──────────────────────
  Color get background => brightness == Brightness.dark
      ? const Color(0xFF0F1923)
      : const Color(0xFFF5F7FA);

  Color get surface => brightness == Brightness.dark
      ? const Color(0xFF1A2733)
      : Colors.white;

  Color get surfaceLight => brightness == Brightness.dark
      ? const Color(0xFF243447)
      : const Color(0xFFEEF1F5);

  Color get surfaceCard => brightness == Brightness.dark
      ? const Color(0xFF1E2D3D)
      : Colors.white;

  // ─── Adaptive text ──────────────────────────────────────
  Color get textPrimary => brightness == Brightness.dark
      ? const Color(0xFFECEFF1)
      : const Color(0xFF1A2733);

  Color get textSecondary => brightness == Brightness.dark
      ? const Color(0xFF90A4AE)
      : const Color(0xFF64748B);

  Color get textHint => brightness == Brightness.dark
      ? const Color(0xFF546E7A)
      : const Color(0xFF94A3B8);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: Colors.white,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1A2733),
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1A2733)),
        iconTheme: const IconThemeData(color: Color(0xFF1A2733)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: _inputDecoration(fillColor: const Color(0xFFEEF1F5), hintColor: const Color(0xFF94A3B8)),
      elevatedButtonTheme: _elevatedButtonTheme(),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 4),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: const Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFEEF1F5), thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A2733),
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F1923),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: Color(0xFF1A2733),
        error: AppColors.error,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: Color(0xFFECEFF1),
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F1923),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFFECEFF1)),
        iconTheme: const IconThemeData(color: Color(0xFFECEFF1)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E2D3D),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: _inputDecoration(fillColor: const Color(0xFF243447), hintColor: const Color(0xFF546E7A)),
      elevatedButtonTheme: _elevatedButtonTheme(),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.primary, foregroundColor: Colors.black, elevation: 4),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1A2733),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: const Color(0xFF546E7A),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF243447), thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF243447),
        contentTextStyle: GoogleFonts.inter(color: const Color(0xFFECEFF1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color primary = isDark ? const Color(0xFFECEFF1) : const Color(0xFF1A2733);
    final Color secondary = isDark ? const Color(0xFF90A4AE) : const Color(0xFF64748B);
    final base = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    return GoogleFonts.interTextTheme(base).copyWith(
      headlineLarge: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: primary),
      titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: primary),
      titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: primary),
      bodyLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: primary),
      bodyMedium: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: secondary),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
    );
  }

  static InputDecorationTheme _inputDecoration({required Color fillColor, required Color hintColor}) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      hintStyle: GoogleFonts.inter(color: hintColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
