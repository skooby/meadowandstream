import 'package:flutter/material.dart';
import '../constants.dart';

class AppTheme {
  static ThemeData buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primary;
    final backgroundColor =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    return ThemeData(
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accent.withOpacity(0.4),
        selectionHandleColor: AppColors.accent,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: brightness,
        primary: primaryColor,
        background: backgroundColor,
        surface: cardColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        actionsIconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          color: primaryColor,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          fontFamily: AppFonts.head,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.chipDark : AppColors.chipLight,
        selectedColor: primaryColor,
        secondarySelectedColor: primaryColor,
        labelStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          fontFamily: AppFonts.main,
        ),
        secondaryLabelStyle: TextStyle(
          color: isDark ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          fontFamily: AppFonts.main,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.chipBorderRadius),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        ),
        elevation: isDark ? 2 : 4,
        shadowColor: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.black,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryColor,
            fontFamily: AppFonts.head),
        titleMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryColor,
            fontFamily: AppFonts.main),
        titleSmall: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryColor,
            fontFamily: AppFonts.main),
        bodyMedium: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            fontFamily: AppFonts.main,
            fontWeight: FontWeight.w400),
        bodySmall: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[600],
            fontFamily: AppFonts.main,
            fontWeight: FontWeight.w400),
      ),
    );
  }
}
