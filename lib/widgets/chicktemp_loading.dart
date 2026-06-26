import 'dart:math' as math;

import 'package:flutter/material.dart';

class ChickTempLoading extends StatefulWidget {
  final String? text;
  final double size;
  final Color color;
  final bool compact;

  const ChickTempLoading({
    super.key,
    this.text,
    this.size = 58,
    this.color = const Color(0xFF0BB13F),
    this.compact = false,
  });

  const ChickTempLoading.compact({
    super.key,
    this.text,
    this.size = 22,
    this.color = Colors.white,
  }) : compact = true;

  @override
  State<ChickTempLoading> createState() => _ChickTempLoadingState();
}

class _ChickTempLoadingState extends State<ChickTempLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loader = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.92 + (math.sin(_controller.value * math.pi * 2) * 0.08);
        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _controller.value * math.pi * 2,
                  child: CustomPaint(
                    size: Size.square(widget.size),
                    painter: _LoadingRingPainter(color: widget.color),
                  ),
                ),
                Container(
                  width: widget.size * 0.68,
                  height: widget.size * 0.68,
                  padding: EdgeInsets.all(widget.size * 0.14),
                  decoration: BoxDecoration(
                    color: widget.compact
                        ? widget.color.withOpacity(0.12)
                        : Colors.white.withOpacity(0.95),
                    shape: BoxShape.circle,
                    boxShadow: widget.compact
                        ? null
                        : [
                            BoxShadow(
                              color: widget.color.withOpacity(0.16),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Image.asset(
                    'assets/images/chicklogo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.egg_alt_rounded,
                      color: widget.color,
                      size: widget.size * 0.32,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (widget.compact) {
      return RepaintBoundary(child: loader);
    }

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          loader,
          if (widget.text != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.text!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF52627D).withOpacity(0.92),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingRingPainter extends CustomPainter {
  final Color color;

  const _LoadingRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = math.max(2.0, size.width * 0.07);
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.32),
          color,
        ],
        stops: const [0.05, 0.55, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -math.pi / 2,
      math.pi * 1.45,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoadingRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
