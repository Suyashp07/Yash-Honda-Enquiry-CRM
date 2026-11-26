import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color brand = Color(0xFFCC0000);
  static const Color brandHover = Color(0xFF990000);
  static const Color brandSoft = Color(0xFFFFE5E5);
  static const Color brandBorder = Color(0xFFFCA5A5);

  // Neutrals & Text Hierarchy (WCAG AA compliant on white)
  static const Color ink = Color(0xFF0F172A);
  static const Color body = Color(0xFF475569);
  static const Color secondary = Color(0xFF64748B);
  static const Color disabled = Color(0xFF94A3B8);

  // Surfaces & Borders
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  // Semantic: Success (Booked, Completed, Delivered, Healthy)
  static const Color success = Color(0xFF15803D);
  static const Color successSoft = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFF86EFAC);

  // Semantic: Warning (Quoted, Pending, Due soon, Busy)
  static const Color warning = Color(0xFF92400E);
  static const Color warningAccent = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);

  // Semantic: Danger (Failed, Overdue, Destructive confirmation)
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerSoft = Color(0xFFFEF2F2);
  static const Color dangerBorder = Color(0xFFFCA5A5);

  // Semantic: Info (Active / In progress, Informational)
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoSoft = Color(0xFFEFF6FF);
  static const Color infoBorder = Color(0xFFBFDBFE);

  // Semantic: Neutral status (Closed, Lost, Idle, Inactive)
  static const Color neutralStatus = Color(0xFF475569);
  static const Color neutralSoft = Color(0xFFF1F5F9);
  static const Color neutralBorder = Color(0xFFCBD5E1);

  // Semantic: AI accent
  static const Color aiAccent = Color(0xFF6D28D9);
  static const Color aiSoft = Color(0xFFF5F3FF);
  static const Color aiBorder = Color(0xFFDDD6FE);

  // BigWing dark theme accent
  static const Color bigWingDark = Color(0xFF0F172A);
  static const Color bigWingGold = Color(0xFFF59E0B);

  // Legacy aliases mapped to semantic tokens for clean incremental migration
  static const Color primary = brand;
  static const Color primaryDark = brandHover;
  static const Color primaryLight = brandSoft;
  static const Color textPrimary = ink;
  static const Color textSecondary = body;
  static const Color textMuted = secondary;
  static const Color statusActive = info;
  static const Color statusResolved = warning;
  static const Color statusBought = success;
  static const Color statusClosed = neutralStatus;
  static const Color repIdle = neutralStatus;
  static const Color repBusy = warning;
}
