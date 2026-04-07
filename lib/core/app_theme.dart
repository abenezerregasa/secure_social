import 'package:flutter/material.dart';

class AppColors {
  // 1. Deepened the Navy for a "Serious" Corporate feel
  static const Color primary = Color(0xFF1E293B); 
  // 2. Used a more vibrant, but professional Blue for accents
  static const Color accent = Color(0xFF3B82F6);  
  
  static const Color background = Color(0xFFF8FAFC); // Off-white/Grey-blue tint
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFEF4444);   

  // 3. CRITICAL: Visual Hierarchy in Text
  static const Color textMain = Color(0xFF0F172A);   // Almost black
  static const Color textMuted = Color(0xFF64748B);  // Slate grey for subtitles
  static const Color textOnPrimary = Colors.white;
}

class AppStyles {
  // 4. "Soft UI" - 8-12px is the sweet spot for modern apps
  static const double borderRadius = 10.0;
  
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0);

  // 5. Added Subtle Elevation/Shadows
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(borderRadius),
  );
}