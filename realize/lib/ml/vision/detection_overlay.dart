import 'package:flutter/material.dart';
import 'vision_processor.dart';

class DetectionOverlay extends StatelessWidget {
  final List<Detection> detections;
  final Size previewSize;
  final Size screenSize;

  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.previewSize,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: screenSize,
      painter: DetectionPainter(
        detections: detections,
        previewSize: previewSize,
        screenSize: screenSize,
      ),
    );
  }
}

class DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size previewSize;
  final Size screenSize;

  DetectionPainter({
    required this.detections,
    required this.previewSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    final textStyle = TextStyle(
      color: Colors.white,
      backgroundColor: Colors.green.withValues(alpha: 0.7),
      fontSize: 16,
    );

    for (final detection in detections) {
      // Scale the bounding box to match the screen size
      final scaledRect = _scaleRect(detection.boundingBox);
      
      // Draw the bounding box
      canvas.drawRect(scaledRect, paint);
      
      // Draw the label
      final textSpan = TextSpan(
        text: detection.label,
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // Position the text above the bounding box
      textPainter.paint(
        canvas,
        Offset(
          scaledRect.left,
          scaledRect.top - textPainter.height,
        ),
      );
    }
  }

  Rect _scaleRect(Rect rect) {
    final double scaleX = screenSize.width / previewSize.width;
    final double scaleY = screenSize.height / previewSize.height;

    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) {
    return true;
  }
}
