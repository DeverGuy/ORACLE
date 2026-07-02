import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// ORACLE Design System — App Theme
// ============================================================

class AppColors {
  // Background layers
  static const Color bg0 = Color(0xFF080C14); // Deepest background
  static const Color bg1 = Color(0xFF0D1117); // Primary background
  static const Color bg2 = Color(0xFF131A24); // Card background base
  static const Color bg3 = Color(0xFF1A2333); // Elevated surfaces

  // Pastel accent blobs (for glassmorphism backgrounds)
  static const Color blobCoral    = Color(0xFFFF6B6B);
  static const Color blobLavender = Color(0xFFB57BEE);
  static const Color blobSky      = Color(0xFF4ECDC4);
  static const Color blobGold     = Color(0xFFFFD93D);
  static const Color blobMint     = Color(0xFF6BCB77);

  // Glass surfaces
  static const Color glassFill    = Color(0x14FFFFFF); // white 8%
  static const Color glassBorder  = Color(0x26FFFFFF); // white 15%
  static const Color glassHighlight = Color(0x33FFFFFF); // white 20%

  // Semantic colours
  static const Color success  = Color(0xFF6BCB77);
  static const Color warning  = Color(0xFFFFD93D);
  static const Color error    = Color(0xFFFF6B6B);
  static const Color pending  = Color(0xFF4ECDC4);
  static const Color info     = Color(0xFF74B9FF);

  // Text
  static const Color textPrimary   = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF8A94A6);
  static const Color textMuted     = Color(0xFF4A5568);

  // Category chart colours
  static const List<Color> chartPalette = [
    Color(0xFF4ECDC4), // Tuition   — teal
    Color(0xFFB57BEE), // Transport — lavender
    Color(0xFFFFD93D), // Lab       — gold
    Color(0xFFFF6B6B), // Late fees — coral
    Color(0xFF6BCB77), // Sports    — mint
  ];
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
      displayLarge:  GoogleFonts.outfit(fontSize: 57, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      displayMedium: GoogleFonts.outfit(fontSize: 45, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      headlineLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineMedium:GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      headlineSmall: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleLarge:    GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleMedium:   GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      titleSmall:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      bodyLarge:     GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
      bodyMedium:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      bodySmall:     GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted),
      labelLarge:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg0,
      colorScheme: ColorScheme.dark(
        primary:   AppColors.blobSky,
        secondary: AppColors.blobLavender,
        surface:   AppColors.bg2,
        error:     AppColors.error,
        onPrimary: AppColors.bg0,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: AppColors.bg2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.blobSky, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium,
        hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blobSky,
          foregroundColor: AppColors.bg0,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 1,
      ),
    );
  }
}

// ============================================================
// Gradient presets
// ============================================================
class AppGradients {
  static const LinearGradient heroBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF080C14), Color(0xFF0D1117), Color(0xFF131A24)],
  );

  static const LinearGradient successCard = LinearGradient(
    colors: [Color(0xFF6BCB77), Color(0xFF4ECDC4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningCard = LinearGradient(
    colors: [Color(0xFFFFD93D), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentCard = LinearGradient(
    colors: [Color(0xFFB57BEE), Color(0xFF4ECDC4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
