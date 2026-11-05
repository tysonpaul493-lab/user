import 'package:flutter/material.dart';

/// A rich, daylight cartographic canvas painted behind the tile layer.
/// Ensures the map always renders realistic street layout, road geometry,
/// parklands, and emergency grid corridors even when network tiles are
/// loading, resolving DNS, or caching.
class CartographicMapBackground extends StatelessWidget {
  const CartographicMapBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _CartographicPainter(),
      ),
    );
  }
}

class _CartographicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base terrain canvas (Daylight cream/ivory)
    final basePaint = Paint()..color = const Color(0xFFF3F0E8);
    canvas.drawRect(Offset.zero & size, basePaint);

    // 2. Park / Green zones
    final parkPaint = Paint()
      ..color = const Color(0xFFE4EFE2)
      ..style = PaintingStyle.fill;

    // Top-left sector park
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.05, size.height * 0.08, size.width * 0.28, size.height * 0.22),
        const Radius.circular(16),
      ),
      parkPaint,
    );

    // Bottom-right hospital campus zone
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.60, size.width * 0.32, size.height * 0.28),
        const Radius.circular(16),
      ),
      parkPaint,
    );

    // 3. Water body / River channel
    final waterPaint = Paint()
      ..color = const Color(0xFFD6E7F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final waterPath = Path();
    waterPath.moveTo(-20, size.height * 0.42);
    waterPath.cubicTo(
      size.width * 0.3,
      size.height * 0.38,
      size.width * 0.6,
      size.height * 0.50,
      size.width + 20,
      size.height * 0.45,
    );
    canvas.drawPath(waterPath, waterPaint);

    // 4. Secondary residential streets (White lines with subtle outline)
    final minorStreetPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final minorOutlinePaint = Paint()
      ..color = const Color(0xFFDDD7CC)
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke;

    // Grid of local streets
    const stepX = 55.0;
    const stepY = 50.0;

    for (double x = 20; x < size.width + 40; x += stepX) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorOutlinePaint);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorStreetPaint);
    }

    for (double y = 20; y < size.height + 40; y += stepY) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorOutlinePaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorStreetPaint);
    }

    // 5. Major Arterial Avenues (Warm daylight highway yellow with grey casings)
    final majorCasingPaint = Paint()
      ..color = const Color(0xFFD4CCBC)
      ..strokeWidth = 9.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final majorRoadPaint = Paint()
      ..color = const Color(0xFFFFE8A3) // Indian highway navigation yellow
      ..strokeWidth = 6.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // Diagonal Primary Corridor
    final arterial1 = Path();
    arterial1.moveTo(-10, size.height * 0.15);
    arterial1.lineTo(size.width + 10, size.height * 0.85);
    canvas.drawPath(arterial1, majorCasingPaint);
    canvas.drawPath(arterial1, majorRoadPaint);

    // Central Crossing Boulevard
    final arterial2 = Path();
    arterial2.moveTo(size.width * 0.48, -10);
    arterial2.lineTo(size.width * 0.52, size.height + 10);
    canvas.drawPath(arterial2, majorCasingPaint);
    canvas.drawPath(arterial2, majorRoadPaint);

    // Horizontal Express Highway
    final arterial3 = Path();
    arterial3.moveTo(-10, size.height * 0.72);
    arterial3.lineTo(size.width + 10, size.height * 0.68);
    canvas.drawPath(arterial3, majorCasingPaint);
    canvas.drawPath(arterial3, majorRoadPaint);

    // 6. Subtle block buildings / urban footprint markings
    final blockPaint = Paint()
      ..color = const Color(0xFFE9E5DC)
      ..style = PaintingStyle.fill;

    for (double x = 28; x < size.width - 20; x += stepX) {
      for (double y = 28; y < size.height - 20; y += stepY) {
        if (x > size.width * 0.40 && x < size.width * 0.60) continue;
        if (y > size.height * 0.38 && y < size.height * 0.52) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 22, 18),
            const Radius.circular(3),
          ),
          blockPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
