import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_icons.dart';

class StatusStyle {
  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;

  const StatusStyle({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });
}

class AppStatus {
  AppStatus._();

  static StatusStyle forEnquiryStatus(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return const StatusStyle(
          label: 'Active',
          foreground: AppColors.info,
          background: AppColors.infoSoft,
          border: AppColors.infoBorder,
          icon: AppIcons.info,
        );
      case 'RESOLVED':
      case 'QUOTED':
        return const StatusStyle(
          label: 'Quoted',
          foreground: AppColors.warning,
          background: AppColors.warningSoft,
          border: AppColors.warningBorder,
          icon: AppIcons.warning,
        );
      case 'CUSTOMER_BOUGHT':
      case 'BOOKED':
        return const StatusStyle(
          label: 'Booked',
          foreground: AppColors.success,
          background: AppColors.successSoft,
          border: AppColors.successBorder,
          icon: AppIcons.success,
        );
      case 'CLOSED':
      case 'LOST':
        return const StatusStyle(
          label: 'Closed',
          foreground: AppColors.neutralStatus,
          background: AppColors.neutralSoft,
          border: AppColors.neutralBorder,
          icon: AppIcons.error,
        );
      case 'OTHER DEALER':
        return const StatusStyle(
          label: 'Lost to competitor',
          foreground: AppColors.neutralStatus,
          background: AppColors.neutralSoft,
          border: AppColors.neutralBorder,
          icon: AppIcons.error,
        );
      default:
        return StatusStyle(
          label: status,
          foreground: AppColors.neutralStatus,
          background: AppColors.neutralSoft,
          border: AppColors.neutralBorder,
          icon: AppIcons.info,
        );
    }
  }

  static StatusStyle forRepState(String state) {
    final normalized = state.toLowerCase();
    if (normalized == 'busy') {
      return const StatusStyle(
        label: 'Busy',
        foreground: AppColors.warning,
        background: AppColors.warningSoft,
        border: AppColors.warningBorder,
        icon: AppIcons.warning,
      );
    }
    if (normalized == 'available' || normalized == 'idle') {
      return const StatusStyle(
        label: 'Available',
        foreground: AppColors.neutralStatus,
        background: AppColors.neutralSoft,
        border: AppColors.neutralBorder,
        icon: AppIcons.success,
      );
    }
    return StatusStyle(
      label: state,
      foreground: AppColors.neutralStatus,
      background: AppColors.neutralSoft,
      border: AppColors.neutralBorder,
      icon: AppIcons.info,
    );
  }

  static StatusStyle forDeliveryStatus(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return const StatusStyle(
          label: 'Delivered',
          foreground: AppColors.success,
          background: AppColors.successSoft,
          border: AppColors.successBorder,
          icon: AppIcons.success,
        );
      case 'accepted':
      case 'sent':
        return const StatusStyle(
          label: 'Accepted by provider',
          foreground: AppColors.info,
          background: AppColors.infoSoft,
          border: AppColors.infoBorder,
          icon: AppIcons.info,
        );
      case 'queued':
        return const StatusStyle(
          label: 'Queued',
          foreground: AppColors.warning,
          background: AppColors.warningSoft,
          border: AppColors.warningBorder,
          icon: AppIcons.warning,
        );
      case 'simulated':
        return const StatusStyle(
          label: 'Simulated (not sent)',
          foreground: AppColors.warning,
          background: AppColors.warningSoft,
          border: AppColors.warningBorder,
          icon: AppIcons.warning,
        );
      case 'failed':
        return const StatusStyle(
          label: 'Failed',
          foreground: AppColors.danger,
          background: AppColors.dangerSoft,
          border: AppColors.dangerBorder,
          icon: AppIcons.error,
        );
      default:
        return StatusStyle(
          label: status,
          foreground: AppColors.neutralStatus,
          background: AppColors.neutralSoft,
          border: AppColors.neutralBorder,
          icon: AppIcons.info,
        );
    }
  }

  static StatusStyle forActiveFlag(bool isActive) {
    if (isActive) {
      return const StatusStyle(
        label: 'Active',
        foreground: AppColors.success,
        background: AppColors.successSoft,
        border: AppColors.successBorder,
        icon: AppIcons.success,
      );
    }
    return const StatusStyle(
      label: 'Inactive',
      foreground: AppColors.neutralStatus,
      background: AppColors.neutralSoft,
      border: AppColors.neutralBorder,
      icon: AppIcons.error,
    );
  }
}
