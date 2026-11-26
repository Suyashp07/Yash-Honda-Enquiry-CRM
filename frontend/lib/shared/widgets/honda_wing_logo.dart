import 'package:flutter/material.dart';

class HondaWingPainter extends CustomPainter {
  final Color color;
  const HondaWingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Outer swept wing frame (left-tilted spine + bottom bar + 4 tapered feathers)
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final frame = Path()
      ..moveTo(w * 0.14, h * 0.42)
      ..lineTo(w * 0.06, h * 0.86)
      ..lineTo(w * 0.56, h * 0.86)
      ..lineTo(w * 0.94, h * 0.08)
      ..quadraticBezierTo(w * 0.48, h * 0.28, w * 0.14, h * 0.42)
      ..close();
    canvas.drawPath(frame, outline);

    // 4 inner swept feathers matching the official Honda Wing
    final feathers = <Path>[
      Path()
        ..moveTo(w * 0.18, h * 0.44)
        ..quadraticBezierTo(w * 0.52, h * 0.30, w * 0.88, h * 0.14)
        ..lineTo(w * 0.80, h * 0.28)
        ..quadraticBezierTo(w * 0.48, h * 0.38, w * 0.17, h * 0.50)
        ..close(),
      Path()
        ..moveTo(w * 0.16, h * 0.54)
        ..quadraticBezierTo(w * 0.48, h * 0.44, w * 0.78, h * 0.34)
        ..lineTo(w * 0.71, h * 0.47)
        ..quadraticBezierTo(w * 0.44, h * 0.54, w * 0.14, h * 0.61)
        ..close(),
      Path()
        ..moveTo(w * 0.13, h * 0.65)
        ..quadraticBezierTo(w * 0.42, h * 0.58, w * 0.68, h * 0.52)
        ..lineTo(w * 0.62, h * 0.64)
        ..quadraticBezierTo(w * 0.38, h * 0.68, w * 0.11, h * 0.72)
        ..close(),
      Path()
        ..moveTo(w * 0.10, h * 0.76)
        ..quadraticBezierTo(w * 0.35, h * 0.72, w * 0.59, h * 0.69)
        ..lineTo(w * 0.54, h * 0.80)
        ..lineTo(w * 0.08, h * 0.82)
        ..close(),
    ];
    for (final f in feathers) {
      canvas.drawPath(f, fill);
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
    this.width = 40,
    this.height = 24,
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
          const SizedBox(height: 2),
          Text(
            'HONDA',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1.4,
              height: 1.0,
            ),
          ),
        ],
      ],
    );
  }
}
