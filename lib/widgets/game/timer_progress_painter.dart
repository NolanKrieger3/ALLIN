import 'package:flutter/material.dart';

/// Custom painter for rounded rectangle progress border (used for turn timer)
class RoundedRectProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  RoundedRectProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Calculate path length for the rounded rect
    final perimeter = 2 * (size.width + size.height - strokeWidth * 2);
    final progressLength = perimeter * progress;

    // Create path for rounded rect starting from top-center
    final path = Path();
    // Start from top-center
    path.moveTo(size.width / 2, strokeWidth / 2);
    // Draw to top-right corner
    path.lineTo(size.width - strokeWidth / 2 - 16, strokeWidth / 2);
    path.arcToPoint(
      Offset(size.width - strokeWidth / 2, strokeWidth / 2 + 16),
      radius: const Radius.circular(16),
    );
    // Right side
    path.lineTo(size.width - strokeWidth / 2, size.height - strokeWidth / 2 - 16);
    path.arcToPoint(
      Offset(size.width - strokeWidth / 2 - 16, size.height - strokeWidth / 2),
      radius: const Radius.circular(16),
    );
    // Bottom side
    path.lineTo(strokeWidth / 2 + 16, size.height - strokeWidth / 2);
    path.arcToPoint(
      Offset(strokeWidth / 2, size.height - strokeWidth / 2 - 16),
      radius: const Radius.circular(16),
    );
    // Left side
    path.lineTo(strokeWidth / 2, strokeWidth / 2 + 16);
    path.arcToPoint(
      Offset(strokeWidth / 2 + 16, strokeWidth / 2),
      radius: const Radius.circular(16),
    );
    // Back to start
    path.lineTo(size.width / 2, strokeWidth / 2);

    // Create dash effect based on progress
    final pathMetrics = path.computeMetrics();
    final progressPath = Path();

    for (final metric in pathMetrics) {
      final extractPath = metric.extractPath(0, progressLength);
      progressPath.addPath(extractPath, Offset.zero);
    }

    canvas.drawPath(progressPath, paint);

    // Add glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(progressPath, glowPaint);
  }

  @override
  bool shouldRepaint(RoundedRectProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
