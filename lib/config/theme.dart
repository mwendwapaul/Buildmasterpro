import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Scheme
  static const Color primaryColor = Color(0xFF2962FF);
  static const Color secondaryColor = Color(0xFF3D5AFE);
  static const Color accentColor = Color(0xFF00B8D4);
  
  // Neutral Colors
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E1E1E);
  
  // Text Colors
  static const Color textPrimaryLight = Color(0xFF1F1F1F);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB3B3B3);
  
  // Status Colors
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFD50000);
  static const Color warning = Color(0xFFFFAB00);
  static const Color info = Color(0xFF2196F3);

  // Border Colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF424242);

  // Font Sizes
  static const double fontSizeHeadingLarge = 32;
  static const double fontSizeHeadingMedium = 24;
  static const double fontSizeHeadingSmall = 20;
  static const double fontSizeBodyLarge = 16;
  static const double fontSizeBodyMedium = 14;
  static const double fontSizeBodySmall = 12;

  // Border Radius
  static const double borderRadiusSmall = 4;
  static const double borderRadiusMedium = 8;
  static const double borderRadiusLarge = 12;
  static const double borderRadiusXLarge = 16;

  // Spacing
  static const double spacingXSmall = 4;
  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;
  static const double spacingXLarge = 32;

  // Elevation
  static const List<BoxShadow> elevation1 = [
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
  ];
  
  static const List<BoxShadow> elevation2 = [
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  static const List<BoxShadow> elevation3 = [
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  // Light Theme
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceLight,
        error: error,
      ),
      
      // Typography
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: const TextStyle(
          fontSize: fontSizeHeadingLarge,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
        ),
        displayMedium: const TextStyle(
          fontSize: fontSizeHeadingMedium,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
        ),
        displaySmall: const TextStyle(
          fontSize: fontSizeHeadingSmall,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
        ),
        bodyLarge: const TextStyle(
          fontSize: fontSizeBodyLarge,
          color: textPrimaryLight,
        ),
        bodyMedium: const TextStyle(
          fontSize: fontSizeBodyMedium,
          color: textPrimaryLight,
        ),
        bodySmall: const TextStyle(
          fontSize: fontSizeBodySmall,
          color: textSecondaryLight,
        ),
      ),
      
      // Component Themes
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimaryLight),
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: fontSizeHeadingSmall,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primaryColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLarge,
            vertical: spacingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLarge,
            vertical: spacingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingMedium,
            vertical: spacingSmall,
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(color: primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMedium,
          vertical: spacingMedium,
        ),
      ),
      
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
          side: const BorderSide(color: borderLight),
        ),
        color: surfaceLight,
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          side: const BorderSide(color: borderLight),
        ),
      ),
      
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: spacingMedium,
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryLight,
        type: BottomNavigationBarType.fixed,
      ),
      
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceDark,
        contentTextStyle: const TextStyle(color: textPrimaryDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Dark Theme
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceDark,
        error: error,
      ),
      
      // Typography
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: const TextStyle(
          fontSize: fontSizeHeadingLarge,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        displayMedium: const TextStyle(
          fontSize: fontSizeHeadingMedium,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        displaySmall: const TextStyle(
          fontSize: fontSizeHeadingSmall,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        bodyLarge: const TextStyle(
          fontSize: fontSizeBodyLarge,
          color: textPrimaryDark,
        ),
        bodyMedium: const TextStyle(
          fontSize: fontSizeBodyMedium,
          color: textPrimaryDark,
        ),
        bodySmall: const TextStyle(
          fontSize: fontSizeBodySmall,
          color: textSecondaryDark,
        ),
      ),
      
      // Component Themes (Dark mode variants)
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimaryDark),
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: fontSizeHeadingSmall,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      // Additional dark mode component themes...
      // (Similar to light theme but with dark colors)
    );
  }
}