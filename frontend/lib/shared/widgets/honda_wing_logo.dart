import 'package:flutter/material.dart';

class HondaWingLogo extends StatelessWidget {
  final double width;
  final double height;

  const HondaWingLogo({
    super.key,
    this.width = 40,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/honda_wing_logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
