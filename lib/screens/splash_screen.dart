import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/auth_store.dart';
import '../models/batch_store.dart';
import 'dashboards_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _titleOffsetAnim;
  late final Animation<double> _haloScaleAnim;
  late final Animation<double> _haloOpacityAnim;
  late final Animation<double> _buttonGlowAnim;
  bool _checkingRememberedSession = true;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _scaleAnim = Tween<double>(begin: 0.84, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.28, 0.9, curve: Curves.easeOutCubic),
          ),
        );
    _titleOffsetAnim = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.22, 0.82, curve: Curves.easeOutCubic),
      ),
    );
    _haloScaleAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOut),
    );
    _haloOpacityAnim = Tween<double>(begin: 0.14, end: 0.26).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOut),
    );
    _buttonGlowAnim = Tween<double>(begin: 0.18, end: 0.3).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOut),
    );

    _introController.forward();
    _restoreRememberedSession();
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _restoreRememberedSession() async {
    final restored = await AuthStore.instance.restoreRememberedSession();
    if (restored) {
      try {
        await BatchStore.instance.loadForCurrentUser();
      } on Object {
        BatchStore.instance.clear();
      }
    }

    if (!mounted) {
      return;
    }
    if (restored) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DashboardScreen(promptCreateBatch: BatchStore.instance.isEmpty),
        ),
      );
      return;
    }
    setState(() => _checkingRememberedSession = false);
  }

  void _openLogin() {
    if (_checkingRememberedSession) {
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    const brandDarkGreen = Color(0xFF1B5E20);
    const brandGreen = Color(0xFF4CAF50);
    const textMutedGreen = Color(0xFF66BB6A);
    const buttonColor = Color(0xFF2E7D32);
    const buttonGradient = LinearGradient(
      colors: [Color(0xFF149B3F), Color(0xFF2E7D32)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_introController, _ambientController]),
        builder: (context, child) {
          final ambient = Curves.easeInOut.transform(_ambientController.value);
          final floatY = math.sin(ambient * math.pi * 2) * 12;
          final floatX = math.cos(ambient * math.pi * 2) * 8;
          final iconFloatY = math.sin(ambient * math.pi * 2) * 7;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEAF7EE), Color(0xFFF5FBF6), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -58 + (floatY * 0.5),
                  left: -48 - (floatX * 0.6),
                  child: _Blob(color: brandGreen.withOpacity(0.08), size: 260),
                ),
                Positioned(
                  bottom: 82 - (floatY * 0.35),
                  right: -68 + (floatX * 0.7),
                  child: _Blob(color: brandGreen.withOpacity(0.07), size: 300),
                ),
                Positioned(
                  top: 162 + (floatY * 0.4),
                  right: -38 - (floatX * 0.4),
                  child: _Blob(
                    color: const Color(0xFF81C784).withOpacity(0.06),
                    size: 180,
                  ),
                ),
                Positioned(
                  bottom: 198 - (floatY * 0.25),
                  left: -32 + (floatX * 0.4),
                  child: _Blob(
                    color: const Color(0xFFA5D6A7).withOpacity(0.08),
                    size: 160,
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TopWavePainter(
                      color: brandGreen.withOpacity(0.06 + (ambient * 0.03)),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -18 + (floatY * 0.3),
                  left: -28 - (floatX * 0.2),
                  child: CustomPaint(
                    size: const Size(280, 280),
                    painter: _ChickenSilhouettePainter(
                      color: brandGreen.withOpacity(0.06 + (ambient * 0.02)),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Transform.translate(
                          offset: Offset(0, iconFloatY),
                          child: ScaleTransition(
                            scale: _scaleAnim,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.scale(
                                  scale: _haloScaleAnim.value,
                                  child: Container(
                                    width: 216,
                                    height: 216,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          brandGreen.withOpacity(
                                            _haloOpacityAnim.value,
                                          ),
                                          brandGreen.withOpacity(0.02),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(44),
                                    boxShadow: [
                                      BoxShadow(
                                        color: brandGreen.withOpacity(0.15),
                                        blurRadius: 35,
                                        offset: const Offset(0, 12),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 124,
                                      height: 124,
                                      decoration: BoxDecoration(
                                        color: brandDarkGreen,
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          BoxShadow(
                                            color: brandDarkGreen.withOpacity(
                                              0.15,
                                            ),
                                            blurRadius: 15,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(30),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: Transform.scale(
                                                scale: 1.16,
                                                child: Image.asset(
                                                  'assets/images/chicklogo.png',
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      decoration:
                                                          const BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: [
                                                                Color(
                                                                  0xFF0E5023,
                                                                ),
                                                                Color(
                                                                  0xFF1B5E20,
                                                                ),
                                                              ],
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                            ),
                                                          ),
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons
                                                              .device_thermostat,
                                                          color: Colors.white,
                                                          size: 54,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            Positioned.fill(
                                              child: Transform.translate(
                                                offset: Offset(
                                                  (ambient - 0.5) * 46,
                                                  0,
                                                ),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.transparent,
                                                        Colors.white
                                                            .withOpacity(0.18),
                                                        Colors.transparent,
                                                      ],
                                                      stops: const [
                                                        0.22,
                                                        0.5,
                                                        0.78,
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      SlideTransition(
                        position: _slideAnim,
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: buttonGradient,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: buttonColor.withOpacity(
                                        _buttonGlowAnim.value,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _checkingRememberedSession
                                      ? null
                                      : _openLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Get Started',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Transform.translate(
                                        offset: Offset(floatX * 0.12, 0),
                                        child: const Icon(
                                          Icons.arrow_forward,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Transform.translate(
                          offset: Offset(0, _titleOffsetAnim.value),
                          child: Column(
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Chick',
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: brandDarkGreen,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: 'Temp',
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: brandGreen,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Smart Poultry Management',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textMutedGreen,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
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

class _TopWavePainter extends CustomPainter {
  const _TopWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.9, size.height * 0.08)
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.16,
        size.width * 0.35,
        size.height * 0.08,
        size.width * 0.25,
        size.height * 0.21,
      )
      ..cubicTo(
        size.width * 0.15,
        size.height * 0.30,
        size.width * 0.35,
        size.height * 0.38,
        size.width * 0.55,
        size.height * 0.31,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.23,
        size.width * 0.85,
        size.height * 0.09,
        size.width * 0.65,
        size.height * 0.16,
      )
      ..cubicTo(
        size.width * 0.50,
        size.height * 0.22,
        size.width * 0.55,
        size.height * 0.32,
        size.width * 0.68,
        size.height * 0.35,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TopWavePainter oldDelegate) {
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
        height * 0.22,
        width * 0.54,
        height * 0.12,
      )
      ..quadraticBezierTo(
        width * 0.60,
        height * 0.08,
        width * 0.65,
        height * 0.22,
      )
      ..quadraticBezierTo(
        width * 0.72,
        height * 0.15,
        width * 0.75,
        height * 0.30,
      )
      ..quadraticBezierTo(
        width * 0.82,
        height * 0.24,
        width * 0.82,
        height * 0.38,
      );

    canvas.drawPath(path, outlinePaint);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(width * 0.68, height * 0.52),
        width: width * 0.05,
        height: height * 0.07,
      ),
      fillPaint,
    );

    final beakPath = Path()
      ..moveTo(width * 0.92, height * 0.62)
      ..lineTo(width * 0.99, height * 0.65)
      ..lineTo(width * 0.91, height * 0.69)
      ..close();
    canvas.drawPath(beakPath, fillPaint);

    final wattlePath = Path()
      ..moveTo(width * 0.88, height * 0.71)
      ..cubicTo(
        width * 0.88,
        height * 0.76,
        width * 0.83,
        height * 0.78,
        width * 0.81,
        height * 0.73,
      )
      ..cubicTo(
        width * 0.79,
        height * 0.68,
        width * 0.85,
        height * 0.67,
        width * 0.88,
        height * 0.71,
      );
    canvas.drawPath(wattlePath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ChickenSilhouettePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
