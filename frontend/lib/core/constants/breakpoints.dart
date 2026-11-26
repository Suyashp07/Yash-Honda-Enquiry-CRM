import 'package:flutter/material.dart';

enum DeviceScreenType { phone, tablet, compactDesktop, desktop }

class Breakpoints {
  Breakpoints._();

  static const double phoneMax = 600.0;
  static const double tabletMax = 1024.0;
  static const double compactDesktopMax = 1280.0;

  static DeviceScreenType getDeviceTypeForWidth(double width) {
    if (width < phoneMax) return DeviceScreenType.phone;
    if (width < tabletMax) return DeviceScreenType.tablet;
    if (width < compactDesktopMax) return DeviceScreenType.compactDesktop;
    return DeviceScreenType.desktop;
  }

  static DeviceScreenType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return getDeviceTypeForWidth(width);
  }

  static bool isPhone(BuildContext context) =>
      getDeviceType(context) == DeviceScreenType.phone;

  static bool isTablet(BuildContext context) =>
      getDeviceType(context) == DeviceScreenType.tablet;

  static bool isCompactDesktop(BuildContext context) =>
      getDeviceType(context) == DeviceScreenType.compactDesktop;

  static bool isDesktop(BuildContext context) {
    final type = getDeviceType(context);
    return type == DeviceScreenType.compactDesktop ||
        type == DeviceScreenType.desktop;
  }

  static bool isFullDesktop(BuildContext context) =>
      getDeviceType(context) == DeviceScreenType.desktop;

  static double gutterFor(BuildContext context) =>
      isFullDesktop(context) ? 24.0 : 16.0;
}

class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;
  final Widget? compactDesktop;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.compactDesktop,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final type = Breakpoints.getDeviceTypeForWidth(constraints.maxWidth);
        switch (type) {
          case DeviceScreenType.phone:
            return phone;
          case DeviceScreenType.tablet:
            return tablet ?? desktop;
          case DeviceScreenType.compactDesktop:
            return compactDesktop ?? desktop;
          case DeviceScreenType.desktop:
            return desktop;
        }
      },
    );
  }
}
