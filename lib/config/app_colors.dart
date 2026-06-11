import 'package:flutter/material.dart';

/// Global color scheme matching web version
/// Based on Tailwind CSS slate and blue color palette
class AppColors {
  // Primary Background Colors (Dark Blue Theme)
  static const Color slate900 = Color(0xFF0F172A); // Main dark background
  static const Color slate800 = Color(0xFF1E293B); // Slightly lighter dark
  static const Color blue900 = Color(0xFF1E3A8A);  // Deep blue accent
  static const Color blue800 = Color(0xFF1E40AF);  // Medium blue
  static const Color blue700 = Color(0xFF1D4ED8);  // Between blue800 and blue600
  
  // Primary Blue Colors
  static const Color blue600 = Color(0xFF2563EB); // Primary blue
  static const Color blue500 = Color(0xFF3B82F6); // Lighter blue
  static const Color blue400 = Color(0xFF60A5FA); // Accent blue
  
  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8); // slate-400
  static const Color textMuted = Color(0xFF64748B);     // slate-500
  
  // Semantic Colors
  static const Color success = Color(0xFF10B981);  // green-500
  static const Color warning = Color(0xFFF59E0B);  // amber-500
  static const Color error = Color(0xFFEF4444);    // red-500
  static const Color info = Color(0xFF3B82F6);     // blue-500
  
  // Card & Surface Colors
  static const Color cardBackground = Color(0xFF1E293B);  // slate-800
  static const Color surfaceLight = Color(0xFF334155);    // slate-700
  
  // Border Colors
  static const Color borderLight = Color(0xFF334155);  // slate-700
  static const Color borderDark = Color(0xFF1E293B);   // slate-800
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [slate900, blue900, slate900],
  );
  
  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue500, blue600],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [slate800, Color(0xFF334155)], // slate-800 to slate-700
  );
  
  // Status Badge Colors
  static const Color statusOperational = success;
  static const Color statusWarning = warning;
  static const Color statusError = error;
  
  // Role Badge Colors
  static const Color roleAdmin = Color(0xFF9333EA);    // purple-600
  static const Color roleClient = blue500;
  static const Color roleContractor = Color(0xFF10B981); // green-500
  
  // Shadows
  static BoxShadow blueShadow({double opacity = 0.4}) => BoxShadow(
    color: blue500.withValues(alpha: opacity),
    blurRadius: 20,
    offset: const Offset(0, 10),
  );
  
  static BoxShadow cardShadow({double opacity = 0.1}) => BoxShadow(
    color: Colors.black.withValues(alpha: opacity),
    blurRadius: 10,
    offset: const Offset(0, 4),
  );
}
