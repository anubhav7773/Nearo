import 'package:flutter/material.dart';

class AppColors {
  // Primary & Brand Tokens
  static const Color primaryBlue = Color(0xFF1E3A8A);      // Deep Indigo (AppBar, Primary Buttons)
  static const Color primaryHover = Color(0xFF1E40AF);     // Button pressed state
  static const Color accentBlue = Color(0xFF2563EB);       // Links, Active Tabs, Highlights
  
  // Civic SOS & Alert Tokens
  static const Color sosRed = Color(0xFFDC2626);           // SOS Trigger, Emergency Badges
  static const Color sosRedLight = Color(0xFFFEE2E2);      // SOS Background highlight banner
  static const Color sosRedPulse = Color(0x33DC2626);      // Ripple animation ring color

  // Feedback & Trust Tokens
  static const Color verifiedGreen = Color(0xFF16A34A);   // Resident Verification Badge
  static const Color verifiedGreenBg = Color(0xFFDCFCE7); // Badge container background
  static const Color warningOrange = Color(0xFFEA580C);   // Scam alert warnings

  // Neutral & Surface Tokens (Light Theme First)
  static const Color background = Color(0xFFF8FAFC);      // Global Scaffold background (Slate-50)
  static const Color surfaceCard = Color(0xFFFFFFFF);     // Card & Modal surface
  static const Color borderSubtle = Color(0xFFE2E8F0);    // Card 1px borders & dividers
  static const Color borderFocused = Color(0xFF94A3B8);   // Input active borders

  // Typography Tokens
  static const Color textPrimary = Color(0xFF0F172A);     // Headings & post text (Slate-900)
  static const Color textSecondary = Color(0xFF64748B);   // Subtitles, meta-info (Slate-500)
  static const Color textMuted = Color(0xFF94A3B8);       // Placeholders, disabled actions
}
