import 'package:flutter/material.dart';

class HondaWingLogo extends StatelessWidget {
  final double width;
  final double height;
  final bool showWordmark;

  const HondaWingLogo({
    super.key,
    this.width = 40,
    this.height = 28,
    this.showWordmark = false,
  });

  @override
  Widget build(BuildContext context) {
    final wing = Image.asset(
      'assets/honda_wing_logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (!showWordmark) return wing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        wing,
        const SizedBox(height: 1),
        const Text(
          'HONDA',
          style: TextStyle(
            color: Color(0xFFCC0000),
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
