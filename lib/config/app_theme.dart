import 'package:flutter/material.dart';

class AppTheme {
  // Colors matching your Next.js frontend
  static const Color primaryColor = Color(0xFF2563EB); // Blue-600
  static const Color secondaryColor = Color(0xFF10B981); // Green-500
  static const Color errorColor = Color(0xFFEF4444); // Red-500
  static const Color warningColor = Color(0xFFF59E0B); // Amber-500
  static const Color successColor = Color(0xFF10B981); // Green-500
  
  static const Color backgroundColor = Color(0xFFF9FAFB); // Gray-50
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;
  
  static const Color textPrimaryColor = Color(0xFF111827); // Gray-900
  static const Color textSecondaryColor = Color(0xFF6B7280); // Gray-500
  static const Color borderColor = Color(0xFFE5E7EB); // Gray-200
  
  // Risk score colors
  static const Color riskLowColor = Color(0xFF10B981); // Green
  static const Color riskMediumColor = Color(0xFFF59E0B); // Amber
  static const Color riskHighColor = Color(0xFFEF4444); // Red
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto', // Explicitly set font family
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: surfaceColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimaryColor),
      ),
      
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
          letterSpacing: -0.25,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
          letterSpacing: -0.25,
          height: 1.3,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimaryColor,
          letterSpacing: 0.15,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textPrimaryColor,
          letterSpacing: 0.25,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textSecondaryColor,
          letterSpacing: 0.4,
          height: 1.4,
        ),
      ),
    );
  }
  
  // Helper method to get risk color based on score
  static Color getRiskColor(double riskScore) {
    if (riskScore >= 70) {
      return riskHighColor;
    } else if (riskScore >= 40) {
      return riskMediumColor;
    } else {
      return riskLowColor;
    }
  }
  
  // Helper method to get risk label
  static String getRiskLabel(double riskScore) {
    if (riskScore >= 70) {
      return 'HIGH';
    } else if (riskScore >= 40) {
      return 'MEDIUM';
    } else {
      return 'LOW';
    }
  }
}
