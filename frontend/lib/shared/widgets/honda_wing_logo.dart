import 'package:flutter/material.dart';

class HondaWingPainter extends CustomPainter {
  final Color color;
  const HondaWingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final outer = Path()
      ..moveTo(w * 0.06, h * 0.92)
      ..lineTo(w * 0.96, h * 0.92)
      ..lineTo(w * 0.78, h * 0.78)
      ..lineTo(w * 0.14, h * 0.78)
      ..close();
    canvas.drawPath(outer, paint);

    for (int i = 0; i < 4; i++) {
      final yTop = h * (0.10 + i * 0.17);
      final yBot = h * (0.21 + i * 0.17);
      final xStart = w * (0.14 + i * 0.04);
      final xEnd = w * (0.98 - i * 0.06);
      final feather = Path()
        ..moveTo(xStart, h * 0.74)
        ..quadraticBezierTo(xStart + w * 0.18, yTop + h * 0.04, xEnd, yTop)
        ..lineTo(xEnd - w * 0.05, yBot)
        ..quadraticBezierTo(
            xStart + w * 0.22, yBot + h * 0.05, xStart + w * 0.10, h * 0.74)
        ..close();
      canvas.drawPath(feather, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HondaWingPainter oldDelegate) =>
      oldDelegate.color != color;
}

class HondaWingLogo extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final bool showWordmark;

  const HondaWingLogo({
    super.key,
    this.width = 36,
    this.height = 22,
    this.color = const Color(0xFFDC2626),
    this.showWordmark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomPaint(
          size: Size(width, height),
          painter: HondaWingPainter(color: color),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 1.5),
          Text(
            'HONDA',
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1.0,
              height: 1.0,
            ),
          ),
        ],
      ],
    );
  }
}
