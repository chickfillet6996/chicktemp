import 'dart:math' as math;

import 'package:flutter/material.dart';

class SplashBackground extends StatefulWidget {
  const SplashBackground({super.key, required this.child});

  final Widget child;

  @override
  State<SplashBackground> createState() => _SplashBackgroundState();
}

class _SplashBackgroundState extends State<SplashBackground>
    with SingleTickerProviderStateMixin {
  static const Color _mistGreen = Color(0xFFDDF1DE);
  static const Color _lineGreen = Color(0xFFCAE6CD);

  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ambientController,
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        final ambient = Curves.easeInOut.transform(_ambientController.value);
        final floatY = math.sin(ambient * math.pi * 2) * 12;
        final floatX = math.cos(ambient * math.pi * 2) * 8;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEAF8EC), Color(0xFFF7FCF8), Color(0xFFFFFFFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -90 + (floatY * 0.35),
                left: -90 - (floatX * 0.45),
                child: _Blob(
                  color: _mistGreen.withOpacity(0.85),
                  size: 330,
                ),
              ),
              Positioned(
                top: 120 + (floatY * 0.3),
                right: -70 + (floatX * 0.45),
                child: _Blob(
                  color: const Color(0xFFEAF5E8).withOpacity(0.95),
                  size: 200,
                ),
              ),
              Positioned(
                bottom: 110 - (floatY * 0.2),
                right: -65 + (floatX * 0.35),
                child: _Blob(
                  color: const Color(0xFFE5F2E3).withOpacity(0.92),
                  size: 235,
                ),
              ),
              Positioned(
                bottom: -18 - (floatY * 0.15),
                left: -28 + (floatX * 0.25),
                child: _Blob(
                  color: const Color(0xFFE9F5E9).withOpacity(0.9),
                  size: 215,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BackgroundLinePainter(
                      color: _lineGreen.withOpacity(0.48 + (ambient * 0.08)),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.42),
                          Colors.white.withOpacity(0.0),
                        ],
                        stops: const [0.18, 0.52, 0.88],
                        begin: const Alignment(-0.35, -1.0),
                        end: const Alignment(0.15, 1.0),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -34 + (floatY * 0.22),
                left: -34 - (floatX * 0.15),
                child: IgnorePointer(
                  child: CustomPaint(
                    size: const Size(300, 300),
                    painter: _ChickenSilhouettePainter(
                      color: _lineGreen.withOpacity(0.48 + (ambient * 0.05)),
                    ),
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _BackgroundLinePainter extends CustomPainter {
  const _BackgroundLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final topCurve = Path()
      ..moveTo(size.width * 0.96, size.height * 0.09)
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.15,
        size.width * 0.56,
        size.height * 0.12,
        size.width * 0.40,
        size.height * 0.19,
      )
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.26,
        size.width * 0.18,
        size.height * 0.34,
        size.width * 0.30,
        size.height * 0.44,
      )
      ..cubicTo(
        size.width * 0.48,
        size.height * 0.54,
        size.width * 0.67,
        size.height * 0.43,
        size.width * 0.72,
        size.height * 0.22,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.14,
        size.width * 0.84,
        size.height * 0.10,
        size.width * 0.96,
        size.height * 0.09,
      );

    final middleLoop = Path()
      ..moveTo(size.width * 0.53, size.height * 0.20)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.30,
        size.width * 0.34,
        size.height * 0.46,
        size.width * 0.46,
        size.height * 0.57,
      )
      ..cubicTo(
        size.width * 0.57,
        size.height * 0.67,
        size.width * 0.72,
        size.height * 0.57,
        size.width * 0.72,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.28,
        size.width * 0.64,
        size.height * 0.18,
        size.width * 0.53,
        size.height * 0.20,
      );

    canvas.drawPath(topCurve, paint);
    canvas.drawPath(middleLoop, paint);
  }

  @override
  bool shouldRepaint(covariant _BackgroundLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ChickenSilhouettePainter extends CustomPainter {
  const _ChickenSilhouettePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;

    final path = Path()
      ..moveTo(width * 0.12, height * 0.95)
      ..cubicTo(
        width * 0.12,
        height * 0.72,
        width * 0.25,
        height * 0.60,
        width * 0.35,
        height * 0.55,
      )
      ..cubicTo(
        width * 0.38,
        height * 0.40,
        width * 0.48,
        height * 0.30,
        width * 0.65,
        height * 0.33,
      )
      ..cubicTo(
        width * 0.80,
        height * 0.33,
        width * 0.90,
        height * 0.45,
        width * 0.92,
        height * 0.62,
      )
      ..cubicTo(
        width * 0.93,
        height * 0.72,
        width * 0.85,
        height * 0.82,
        width * 0.72,
        height * 0.92,
      )
      ..cubicTo(
        width * 0.60,
        height * 0.96,
        width * 0.35,
        height * 0.96,
        width * 0.12,
        height * 0.95,
      )
      ..close()
      ..moveTo(width * 0.52, height * 0.32)
      ..quadraticBezierTo(
        width * 0.48,
        height * 0.18,
        width * 0.58,
        height * 0.10,
      )
      ..quadraticBezierTo(
        width * 0.70,
        height * 0.02,
        width * 0.80,
        height * 0.10,
      )
      ..quadraticBezierTo(
        width * 0.92,
        height * 0.18,
        width * 0.84,
        height * 0.34,
      );

    final wingPath = Path()
      ..moveTo(width * 0.37, height * 0.61)
      ..cubicTo(
        width * 0.46,
        height * 0.49,
        width * 0.61,
        height * 0.49,
        width * 0.67,
        height * 0.62,
      )
      ..cubicTo(
        width * 0.60,
        height * 0.67,
        width * 0.46,
        height * 0.69,
        width * 0.37,
        height * 0.61,
      )
      ..close();

    final beakPath = Path()
      ..moveTo(width * 0.90, height * 0.42)
      ..lineTo(width * 1.0, height * 0.39)
      ..lineTo(width * 0.92, height * 0.49)
      ..close();

    final legOne = Path()
      ..moveTo(width * 0.42, height * 0.90)
      ..lineTo(width * 0.39, height * 1.0)
      ..moveTo(width * 0.39, height * 1.0)
      ..lineTo(width * 0.35, height * 0.98)
      ..moveTo(width * 0.39, height * 1.0)
      ..lineTo(width * 0.43, height * 0.98);

    final legTwo = Path()
      ..moveTo(width * 0.60, height * 0.89)
      ..lineTo(width * 0.59, height * 0.99)
      ..moveTo(width * 0.59, height * 0.99)
      ..lineTo(width * 0.55, height * 0.97)
      ..moveTo(width * 0.59, height * 0.99)
      ..lineTo(width * 0.63, height * 0.97);

    canvas.drawPath(path, outlinePaint);
    canvas.drawPath(wingPath, fillPaint);
    canvas.drawPath(beakPath, fillPaint);
    canvas.drawPath(legOne, outlinePaint);
    canvas.drawPath(legTwo, outlinePaint);

    canvas.drawCircle(
      Offset(width * 0.77, height * 0.25),
      width * 0.012,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChickenSilhouettePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
