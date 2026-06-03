import 'package:flutter/material.dart';

import '../../../../core/theme/itch_colors.dart';

/// График скорости на фоне активной строки (как `DownloadsPage/Chart.tsx`).
class DownloadSpeedChart extends StatelessWidget {
  const DownloadSpeedChart({required this.samples, super.key});

  final List<double> samples;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SpeedAreaPainter(samples),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SpeedAreaPainter extends CustomPainter {
  _SpeedAreaPainter(this.samples);

  final List<double> samples;

  static const _fillTop = Color.fromRGBO(158, 150, 131, 0.2);
  static const _fillBottom = Color.fromRGBO(158, 150, 131, 0.1);

  @override
  void paint(Canvas canvas, Size size) {
    final data = samples.isEmpty
        ? List<double>.filled(16, 0.12)
        : samples.map((v) => v.isFinite ? v.clamp(0.05, 1.0) : 0.12).toList();

    var max = 10.0;
    for (final v in data) {
      if (v > max) {
        max = v;
      }
    }
    max *= 1.1;

    final xs = size.width / (data.length - 1).clamp(1, 999);
    final ys = size.height / max;

    final path = Path()..moveTo(0, size.height);
    for (var i = 0; i < data.length; i++) {
      path.lineTo(i * xs, size.height - data[i] * ys);
    }
    path
      ..lineTo(data.length * xs, size.height)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_fillTop, _fillTop, _fillBottom],
        stops: const [0, 0.5, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);

    final linePaint = Paint()
      ..color = ItchColors.zambezi.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final line = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i * xs;
      final y = size.height - data[i] * ys;
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    canvas.drawPath(line, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeedAreaPainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}
