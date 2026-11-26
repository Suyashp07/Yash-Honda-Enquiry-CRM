import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // 8 px spacing rhythm with allowed exceptions
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;

  // Gutters & Padding
  static const double gutterDesktop = 24.0;
  static const double gutterCompact = 16.0;
  static const double cardPadding = 16.0;
  static const double cardPaddingSpacious = 20.0;

  // Radii
  static const double radiusControl = 8.0;
  static const double radiusCard = 12.0;
  static const double radiusDialog = 16.0;
  static const double radiusSheet = 24.0;
  static const double radiusPill = 999.0;

  // Accessibility & Control Constraints
  static const double minTouchTarget = 48.0;
  static const double minControlHeight = 48.0;

  // Elevation & Restrained Shadows
  static const List<BoxShadow> shadowSubtle = [
    BoxShadow(
      color: Color(0x0D000000), // 5%
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: Color(0x14000000), // 8%
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}
