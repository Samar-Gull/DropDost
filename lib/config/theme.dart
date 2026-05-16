import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF2ECC71);
  static const Color secondaryColor = Color(0xFF3498DB);
  static const Color accentColor = Color(0xFFE74C3C);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF2C3E50);

  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: Colors.white,
    textTheme: GoogleFonts.poppinsTextTheme(),

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: textDark),
      titleTextStyle: GoogleFonts.poppins(
        color: textDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(16),
    ),
  );
}
