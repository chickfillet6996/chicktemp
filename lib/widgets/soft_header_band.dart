import 'package:flutter/material.dart';

class SoftHeaderBand extends StatelessWidget {
  final double height;

  const SoftHeaderBand({
    super.key,
    this.height = 132,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF24562C).withOpacity(0.92),
                  const Color(0xFF3A7A3E).withOpacity(0.82),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -34,
            left: -22,
            child: _SoftOrb(size: 124, color: Colors.white.withOpacity(0.08)),
          ),
          Positioned(
            top: -18,
            right: -10,
            child: _SoftOrb(size: 120, color: Colors.white.withOpacity(0.09)),
          ),
          Positioned(
            bottom: -36,
            left: 92,
            child: _SoftOrb(
              size: 150,
              color: const Color(0xFF7FD28C).withOpacity(0.18),
            ),
          ),
          Positioned(
            left: 18,
            top: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _GhostBar(width: 132, height: 18),
                SizedBox(height: 10),
                _GhostBar(width: 88, height: 12),
              ],
            ),
          ),
          Positioned(
            right: 20,
            top: 24,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.02),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _SoftOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _GhostBar extends StatelessWidget {
  final double width;
  final double height;

  const _GhostBar({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
