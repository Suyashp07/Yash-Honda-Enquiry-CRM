import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Roboto';

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 35,
    height: 42 / 35,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.5,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    height: 34 / 26,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.3,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    height: 30 / 22,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    letterSpacing: -0.2,
  );

  static const TextStyle section = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 25 / 18,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.5,
    height: 22 / 15.5,
    fontWeight: FontWeight.w400,
    color: AppColors.body,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.5,
    height: 22 / 15.5,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    height: 18 / 13.5,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    height: 17 / 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.secondary,
  );

  static const TextStyle table = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    color: AppColors.body,
  );

  static const TextStyle tableStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle metric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.4,
  );

  static const TextStyle metricMobile = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.3,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w700,
    color: AppColors.secondary,
    letterSpacing: 0.6,
  );
}
