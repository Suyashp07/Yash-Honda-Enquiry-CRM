import 'package:flutter/material.dart';

enum DeviceScreenType { phone, tablet, desktop }

class Breakpoints {
  static const double phoneMax = 600.0;
  static const double tabletMax = 1100.0;

  static DeviceScreenType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < phoneMax) return DeviceScreenType.phone;
    if (width < tabletMax) return DeviceScreenType.tablet;
    return DeviceScreenType.desktop;
  }

  static bool isPhone(BuildContext context) => getDeviceType(context) == DeviceScreenType.phone;
  static bool isTablet(BuildContext context) => getDeviceType(context) == DeviceScreenType.tablet;
  static bool isDesktop(BuildContext context) => getDeviceType(context) == DeviceScreenType.desktop;
}

class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < Breakpoints.phoneMax) {
          return phone;
        } else if (constraints.maxWidth < Breakpoints.tabletMax) {
          return tablet ?? desktop;
        } else {
          return desktop;
        }
      },
    );
  }
}
