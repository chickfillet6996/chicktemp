import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/auth_store.dart';
import '../widgets/settings_back_card.dart';
import '../widgets/settings_overlay_sheet.dart';
import '../widgets/user_avatar_content.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const AboutAppScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return SettingsOverlaySheet(
      headerBand: const _HeaderBand(),
      backgroundPainter: const _LeafLinePainter(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const horizontalPadding = 22.0;
          final compact = constraints.maxHeight < 560;
          final contentWidth = math.max(
            0.0,
            constraints.maxWidth - (horizontalPadding * 2),
          );

          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              compact ? 12 : 18,
              horizontalPadding,
              compact ? 14 : 22,
            ),
            child: Column(
              children: [
                _TopBar(onBack: () => Navigator.of(context).pop()),
                SizedBox(height: compact ? 18 : 40),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _AboutHeroCard(),
                          SizedBox(height: compact ? 12 : 18),
                          const _AboutDetailsCard(),
                          SizedBox(height: compact ? 16 : 26),
                          const _InfoGroup(
                            title: 'DEVELOPERS',
                            lines: [
                              'Aaron Asuncion',
                              'Kurt Yu',
                              'Kyle Reodique',
                              'Dustin Juri',
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _AboutHeroCard extends StatefulWidget {
  const _AboutHeroCard();

  @override
  State<_AboutHeroCard> createState() => _AboutHeroCardState();
}

class _AboutHeroCardState extends State<_AboutHeroCard>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
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
    const brandDarkGreen = Color(0xFF1B5E20);
    const brandGreen = Color(0xFF4CAF50);

    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_introController, _ambientController]),
        builder: (context, child) {
          final ambient = Curves.easeInOut.transform(_ambientController.value);
          final floatY = math.sin(ambient * math.pi * 2) * 7;

          return FadeTransition(
            opacity: _fadeAnim,
            child: Transform.translate(
              offset: Offset(0, floatY),
              child: ScaleTransition(
                scale: _scaleAnim,
                child: SizedBox(
                  width: 138,
                  height: 126,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: _haloScaleAnim.value,
                        child: Container(
                          width: 136,
                          height: 136,
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
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE7ECE5)),
                          boxShadow: [
                            BoxShadow(
                              color: brandGreen.withOpacity(0.15),
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
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: brandDarkGreen,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: brandDarkGreen.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Transform.scale(
                                      scale: 1.16,
                                      child: Image.asset(
                                        'assets/images/chicklogo.png',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                decoration: const BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color(0xFF0E5023),
                                                      Color(0xFF1B5E20),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.device_thermostat,
                                                  color: Colors.white,
                                                  size: 34,
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Transform.translate(
                                      offset: Offset((ambient - 0.5) * 32, 0),
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
          );
        },
      ),
    );
  }
}

class _AboutDetailsCard extends StatelessWidget {
  const _AboutDetailsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7ECE5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        children: [
          Text(
            'ChickTemp',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Color(0xFF16231A),
              height: 1.05,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'The smartest IoT-based poultry environmental control application. Built for efficiency, designed for farmers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.62,
              color: Color(0xFF5E6C63),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SettingsBackCard(onTap: onBack);
  }
}

class _InfoGroup extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _InfoGroup({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A8A81),
            letterSpacing: 0.65,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 13),
        ...lines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3C34),
                height: 1.42,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderBand extends StatelessWidget {
  const _HeaderBand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F6F2F), Color(0xFF47A34A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.white70),
                      SizedBox(width: 8),
                      Text(
                        'CHICKTEMP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'About App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Learn more about ChickTemp and its features',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              alignment: Alignment.center,
              child: UserAvatarContent(
                initials: AuthStore.instance.currentUserInitials,
                profilePhotoBase64:
                    AuthStore.instance.currentUser?.profilePhotoBase64 ?? '',
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeafLinePainter extends CustomPainter {
  const _LeafLinePainter();

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
