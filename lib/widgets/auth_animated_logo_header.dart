import 'dart:math' as math;

import 'package:flutter/material.dart';

const String _chickTempLogoAsset = 'assets/images/chicklogo.png';
const Color _brandDarkGreen = Color(0xFF1B5E20);
const Color _brandGreen = Color(0xFF02AC3F);
const Color _brandGlowGreen = Color(0xFF4CAF50);

class AuthAnimatedLogoHeader extends StatefulWidget {
  final double logoSize;
  final double innerLogoSize;
  final double brandGap;
  final double brandFontSize;

  const AuthAnimatedLogoHeader({
    super.key,
    this.logoSize = 110,
    this.innerLogoSize = 54,
    this.brandGap = 14,
    this.brandFontSize = 26,
  });

  @override
  State<AuthAnimatedLogoHeader> createState() => _AuthAnimatedLogoHeaderState();
}

class _AuthAnimatedLogoHeaderState extends State<AuthAnimatedLogoHeader>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _titleOffsetAnim;
  late final Animation<double> _haloScaleAnim;
  late final Animation<double> _haloOpacityAnim;

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

    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outerRadius = widget.logoSize * 0.255;
    final innerRadius = widget.innerLogoSize * 0.26;
    final haloSize = widget.logoSize * 1.96;

    return AnimatedBuilder(
      animation: Listenable.merge([_introController, _ambientController]),
      builder: (context, child) {
        final ambient = Curves.easeInOut.transform(_ambientController.value);
        final floatY = math.sin(ambient * math.pi * 2) * 7;

        return Column(
          children: [
            FadeTransition(
              opacity: _fadeAnim,
              child: Transform.translate(
                offset: Offset(0, floatY),
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: SizedBox(
                    width: widget.logoSize,
                    height: widget.logoSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        IgnorePointer(
                          child: Transform.scale(
                            scale: _haloScaleAnim.value,
                            child: SizedBox(
                              width: haloSize,
                              height: haloSize,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      _brandGlowGreen.withOpacity(
                                        _haloOpacityAnim.value,
                                      ),
                                      _brandGlowGreen.withOpacity(0.02),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: widget.logoSize,
                          height: widget.logoSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(outerRadius),
                            boxShadow: [
                              BoxShadow(
                                color: _brandGlowGreen.withOpacity(0.15),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: widget.innerLogoSize,
                              height: widget.innerLogoSize,
                              decoration: BoxDecoration(
                                color: _brandDarkGreen,
                                borderRadius: BorderRadius.circular(innerRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: _brandDarkGreen.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(innerRadius),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Transform.scale(
                                        scale: 1.16,
                                        child: Image.asset(
                                          _chickTempLogoAsset,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  decoration:
                                                      const BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            Color(0xFF0E5023),
                                                            Color(0xFF1B5E20),
                                                          ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        ),
                                                      ),
                                                  child: Icon(
                                                    Icons.device_thermostat,
                                                    color: Colors.white,
                                                    size:
                                                        widget.innerLogoSize *
                                                        0.48,
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Transform.translate(
                                        offset: Offset(
                                          (ambient - 0.5) *
                                              widget.innerLogoSize *
                                              0.85,
                                          0,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                Colors.white.withOpacity(0.18),
                                                Colors.transparent,
                                              ],
                                              stops: const [0.22, 0.5, 0.78],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
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
            ),
            SizedBox(height: widget.brandGap),
            FadeTransition(
              opacity: _fadeAnim,
              child: Transform.translate(
                offset: Offset(0, _titleOffsetAnim.value),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Chick',
                      style: TextStyle(
                        color: _brandDarkGreen,
                        fontSize: widget.brandFontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Temp',
                      style: TextStyle(
                        color: _brandGreen,
                        fontSize: widget.brandFontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
