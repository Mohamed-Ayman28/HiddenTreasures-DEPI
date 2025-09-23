import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors (let’s keep Khaki as Main for now)
  static const Color primary = Color(0xFFA79885); // Khaki
  static const Color primaryAccent = Color(0xFFA4193D); // Crimson Red
  static const Color primaryLight = Color(0xFFF5DEB3); // Golden Creme

  // Secondary Colors
  static const Color secondary = Color(0xFF8C0605); // Dark Red
  static const Color secondaryAccent = Color(0xFFA4193D); // Crimson Red
  static const Color secondaryLight = Color(0xFFFFDFB9); // Peach

  // Background Colors
  static const Color background = Color(0xFFFFFFFF); // White
  static const Color backgroundSecondary = Color(0xFFF5DEB3); // Golden Creme
  static const Color backgroundDark = Color(0xFFA79885); // Khaki

  // Text Colors
  static const Color textPrimary = Color(0xFFA79885); // Khaki
  static const Color textSecondary = Color(0xFFA4193D); // Crimson Red
  static const Color textLight = Color(0xFFF5DEB3); // Golden Creme
  static const Color textWhite = Color(0xFFFFFFFF); // White

  // Accent Colors
  static const Color accent = Color(0xFFA4193D); // Crimson Red
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color warning = Color(0xFF8C0605); // Dark Red
  static const Color error = Color(0xFF8C0605); // Dark Red
  static const Color info = Color(0xFFF5DEB3); // Golden Creme

  // Rating Colors
  static const Color star = Color(0xFFA4193D); // Crimson Red
  static const Color starUnfilled = Color(0xFFE0E0E0); // Light Grey

  // Favorite Colors
  static const Color favorite = Color(0xFF8C0605); // Dark Red
  static const Color favoriteUnfilled = Color(0xFFA79885); // Khaki

  // Shadow Colors
  static const Color shadowLight = Color(0x1A000000); // 10% Black
  static const Color shadowMedium = Color(0x33000000); // 20% Black
  static const Color shadowDark = Color(0x4D000000); // 30% Black

  // Border Colors
  static const Color borderLight = Color(0xFFF5DEB3); // Golden Creme
  static const Color borderMedium = Color(0xFFA79885); // Khaki
  static const Color borderDark = Color(0xFFA4193D); // Crimson Red

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA79885), Color(0xFFA4193D)], // Khaki → Crimson
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA4193D), Color(0xFF8C0605)], // Crimson → Dark Red
  );

  static const LinearGradient goldenPeachGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5DEB3), Color(0xFFFFDFB9)], // Golden Creme → Peach
  );

  static const LinearGradient overlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xB3F5DEB3)], // Transparent → Golden Creme (70%)
  );

  // Brand Gradients
  static const LinearGradient visaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1F71), Color(0xFF1434CB), Color(0xFFFDBB2D)], // Navy → Blue → Gold
  );

  // Card Colors
  static const Color cardBackground = Color(0xFFF5DEB3); // Golden Creme
  static const Color cardShadow = Color(0x1A000000); // 10% Black

  // Button Colors
  static const Color buttonPrimary = Color(0xFFA79885); // Khaki
  static const Color buttonSecondary = Color(0xFFA4193D); // Crimson Red
  static const Color buttonDisabled = Color(0xFFE0E0E0); // Light Grey

  // Status Colors
  static const Color online = Color(0xFF4CAF50); // Green
  static const Color offline = Color(0xFFA79885); // Khaki
  static const Color busy = Color(0xFF8C0605); // Dark Red
}
